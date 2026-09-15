#!/usr/bin/env zsh

# Integration tests for preheat server lifecycle (lash + opencode)
# Usage: zsh tests/test_preheat_server.zsh

setopt NO_MONITOR  # suppress job control messages

# ============================================================================
# Test configuration
# ============================================================================

TEST_PORT=14096
TEST_TMPDIR=$(mktemp -d)
SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

# Override before sourcing constants.zsh (`:=` pattern respects pre-existing)
export LACY_SHELL_HOME="$TEST_TMPDIR"
export LACY_PREHEAT_SERVER_PORT="$TEST_PORT"

# ============================================================================
# Source modules (minimal chain — no ZLE/prompt deps)
# ============================================================================

source "$REPO_ROOT/lib/core/constants.sh"
source "$REPO_ROOT/lib/core/spinner.sh"
source "$REPO_ROOT/lib/core/mcp.sh"
source "$REPO_ROOT/lib/core/preheat.sh"
source "$REPO_ROOT/lib/core/context.sh"

# ============================================================================
# Assertion helpers
# ============================================================================

_PASS=0 _FAIL=0 _SKIP=0

pass() {
    (( _PASS++ ))
    printf '  \e[32m✓\e[0m %s\n' "$1"
}

fail() {
    (( _FAIL++ ))
    printf '  \e[31m✗\e[0m %s\n' "$1"
    [[ -n "$2" ]] && printf '    %s\n' "$2"
}

skip() {
    (( _SKIP++ ))
    printf '  \e[33m⊘\e[0m %s (skipped: %s)\n' "$1" "$2"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass "$label"
    else
        fail "$label" "expected='$expected' actual='$actual'"
    fi
}

assert_nonblank() {
    local label="$1" value="$2"
    if [[ -n "$value" ]]; then
        pass "$label"
    else
        fail "$label" "expected non-blank value"
    fi
}

assert_empty() {
    local label="$1" value="$2"
    if [[ -z "$value" ]]; then
        pass "$label"
    else
        fail "$label" "expected empty, got='$value'"
    fi
}

summary() {
    echo ""
    printf '=%.0s' {1..60}; echo ""
    printf 'Results: %d passed, %d failed, %d skipped\n' "$_PASS" "$_FAIL" "$_SKIP"
    if (( _FAIL > 0 )); then
        printf '\e[31mFAILED\e[0m\n'
        return 1
    else
        printf '\e[32mALL PASSED\e[0m\n'
        return 0
    fi
}

section() {
    echo ""
    printf '--- %s ---\n' "$1"
}

# ============================================================================
# Cleanup (runs on exit, Ctrl-C, assertion failure)
# ============================================================================

cleanup() {
    # Stop server via library function
    lacy_preheat_server_stop 2>/dev/null

    # Fallback: kill anything on the test port
    local pids
    pids=$(lsof -ti "tcp:$TEST_PORT" 2>/dev/null)
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill 2>/dev/null
        sleep 0.3
        pids=$(lsof -ti "tcp:$TEST_PORT" 2>/dev/null)
        [[ -n "$pids" ]] && echo "$pids" | xargs kill -9 2>/dev/null
    fi

    # Remove temp directory
    rm -rf "$TEST_TMPDIR"
}

trap cleanup EXIT INT TERM

# ============================================================================
# Helpers
# ============================================================================

# Create a mock server script that mimics the lash/opencode REST API.
# Uses raw sockets for fast startup (< 100ms) since the preheat start
# function only waits ~3s for health.
create_mock_server() {
    local tool="$1"
    local mock_bin="$TEST_TMPDIR/bin/$tool"
    mkdir -p "$TEST_TMPDIR/bin"

    cat > "$mock_bin" << 'MOCK_SERVER'
#!/usr/bin/env python3
"""Fast mock server mimicking lash/opencode REST API using raw sockets."""
import socket, json, sys, uuid, threading, time

if "serve" not in sys.argv:
    print(f"Unknown command: {sys.argv[1:]}", file=sys.stderr)
    sys.exit(1)

port = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else 4096
sessions = {}

def handle_client(conn):
    try:
        data = conn.recv(65536).decode()
        if not data:
            conn.close()
            return
        lines = data.split("\r\n")
        method, path, _ = lines[0].split(" ", 2)

        # Extract body (after blank line)
        body = ""
        for i, line in enumerate(lines):
            if line == "":
                body = "\r\n".join(lines[i + 1:])
                break

        status_code = 404
        resp_body = json.dumps({"error": "not found"})

        if method == "GET" and path == "/global/health":
            status_code = 200
            resp_body = json.dumps({"status": "ok"})

        elif method == "POST" and path == "/session":
            sid = str(uuid.uuid4())
            sessions[sid] = []
            status_code = 200
            resp_body = json.dumps({"id": sid})

        elif method == "POST" and path.startswith("/session/") and path.endswith("/message"):
            sid = path.split("/")[2]
            if sid in sessions:
                d = json.loads(body) if body.strip() else {}
                qt = ""
                for p in d.get("parts", []):
                    if p.get("type") == "text":
                        qt = p["text"]
                sessions[sid].append(qt)
                if "MOCK_SLOW" in qt:
                    time.sleep(3)  # longer than the test's message timeout
                if "MOCK_FAIL" in qt:
                    status_code = 500
                    resp_body = json.dumps({"info": {"error": {"name": "ProviderError",
                        "data": {"message": "mock provider exploded"}}}})
                elif "MOCK_EMPTY" in qt:
                    status_code = 200
                    resp_body = json.dumps([{"role": "assistant", "parts": [{"type": "step-finish"}]}])
                else:
                    status_code = 200
                    resp_body = json.dumps([{
                        "role": "assistant",
                        "parts": [{"type": "text", "text": f"Mock response to: {qt}"}]
                    }])
            # else: 404 (default)

        status_text = {200: "OK", 404: "Not Found"}.get(status_code, "Error")
        resp = (
            f"HTTP/1.1 {status_code} {status_text}\r\n"
            f"Content-Type: application/json\r\n"
            f"Content-Length: {len(resp_body)}\r\n"
            f"Connection: close\r\n"
            f"\r\n"
            f"{resp_body}"
        )
        conn.sendall(resp.encode())
    except Exception:
        pass
    finally:
        conn.close()

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", port))
srv.listen(5)

while True:
    conn, _ = srv.accept()
    threading.Thread(target=handle_client, args=(conn,), daemon=True).start()
MOCK_SERVER

    chmod +x "$mock_bin"
}

# Check that a tool (mock) is available on PATH
ensure_mock_on_path() {
    local tool="$1"
    if [[ ! -x "$TEST_TMPDIR/bin/$tool" ]]; then
        create_mock_server "$tool"
    fi
    export PATH="$TEST_TMPDIR/bin:$PATH"
}

# Wait for the test port to be free (up to 3 seconds)
wait_for_port_free() {
    local attempts=0
    while (( attempts < 30 )); do
        if ! lsof -ti "tcp:$TEST_PORT" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
        (( attempts++ ))
    done
    # Force kill anything still on the port
    local pids
    pids=$(lsof -ti "tcp:$TEST_PORT" 2>/dev/null)
    [[ -n "$pids" ]] && echo "$pids" | xargs kill -9 2>/dev/null
    sleep 0.3
}

# Reset preheat state between tool test runs
reset_preheat_state() {
    lacy_preheat_server_stop 2>/dev/null
    LACY_PREHEAT_SERVER_PID=""
    LACY_PREHEAT_SERVER_PASSWORD=""
    LACY_PREHEAT_SERVER_SESSION_ID=""
    rm -f "$LACY_PREHEAT_SERVER_PID_FILE"
    wait_for_port_free
}

# ============================================================================
# Tests
# ============================================================================

run_tests_for_tool() {
    local tool="$1"

    section "Tests for: $tool"

    ensure_mock_on_path "$tool"
    reset_preheat_state

    # ------------------------------------------------------------------
    # Test 1: Server lifecycle
    # ------------------------------------------------------------------
    lacy_preheat_server_start "$tool"
    local start_rc=$?

    assert_eq "$tool: server start returns 0" "0" "$start_rc"
    assert_nonblank "$tool: PID is set after start" "$LACY_PREHEAT_SERVER_PID"

    # PID file written
    if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
        local file_pid
        file_pid=$(cat "$LACY_PREHEAT_SERVER_PID_FILE")
        assert_eq "$tool: PID file matches in-memory PID" "$LACY_PREHEAT_SERVER_PID" "$file_pid"
    else
        fail "$tool: PID file written" "file not found at $LACY_PREHEAT_SERVER_PID_FILE"
    fi

    # Health check
    lacy_preheat_server_is_healthy
    assert_eq "$tool: server is healthy" "0" "$?"

    # Stop
    local saved_pid="$LACY_PREHEAT_SERVER_PID"
    lacy_preheat_server_stop
    assert_empty "$tool: PID cleared after stop" "$LACY_PREHEAT_SERVER_PID"

    # Process is actually gone
    sleep 0.3
    if kill -0 "$saved_pid" 2>/dev/null; then
        fail "$tool: process gone after stop" "PID $saved_pid still alive"
    else
        pass "$tool: process gone after stop"
    fi

    # ------------------------------------------------------------------
    # Test 2: Health endpoint validation
    # ------------------------------------------------------------------
    reset_preheat_state
    lacy_preheat_server_start "$tool"

    local health_body
    health_body=$(curl -sf --max-time 2 "http://localhost:${TEST_PORT}/global/health" 2>/dev/null)
    local health_rc=$?

    assert_eq "$tool: health endpoint reachable" "0" "$health_rc"

    # Verify it's JSON, not HTML (SPA fallback would return <!DOCTYPE or <html)
    if printf '%s' "$health_body" | grep -q '^<'; then
        fail "$tool: health returns JSON (not HTML)" "got HTML: ${health_body:0:80}"
    else
        # Verify it parses as JSON
        if printf '%s' "$health_body" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
            pass "$tool: health returns JSON (not HTML)"
        else
            fail "$tool: health returns JSON (not HTML)" "not valid JSON: ${health_body:0:80}"
        fi
    fi

    # ------------------------------------------------------------------
    # Test 3: Session creation
    # ------------------------------------------------------------------
    local session_json
    session_json=$(curl -sf --max-time 5 \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{}' \
        "http://localhost:${TEST_PORT}/session" 2>/dev/null)

    local session_id
    session_id=$(printf '%s' "$session_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('id',''))" 2>/dev/null)

    assert_nonblank "$tool: session creation returns an ID" "$session_id"

    # ------------------------------------------------------------------
    # Test 4: Job control suppression
    # ------------------------------------------------------------------
    reset_preheat_state

    local start_output
    start_output=$(lacy_preheat_server_start "$tool" 2>&1)

    # Check that output does NOT contain job control noise like "[1] 12345"
    if printf '%s' "$start_output" | grep -qE '^\[[0-9]+\] [0-9]+'; then
        fail "$tool: no job control output from start" "got: $start_output"
    else
        pass "$tool: no job control output from start"
    fi

    # ------------------------------------------------------------------
    # Test 5: Stale session reset
    # ------------------------------------------------------------------
    # Set a fake session ID and try to query — should fail and clear it.
    # Redirect to file instead of $() to preserve global state changes.
    LACY_PREHEAT_SERVER_SESSION_ID="fake-session-id-that-does-not-exist"

    local _stale_out="$TEST_TMPDIR/_stale_out"
    lacy_preheat_server_query "hello" > "$_stale_out" 2>/dev/null
    local stale_rc=$?

    # The mock answers 404 for an unknown session: distinct "session gone" code
    assert_eq "$tool: stale session query returns SESSION_GONE" "$LACY_SERVER_QUERY_SESSION_GONE" "$stale_rc"
    assert_empty "$tool: stale session ID cleared" "$LACY_PREHEAT_SERVER_SESSION_ID"

    # ------------------------------------------------------------------
    # Test 6: Message sending (uses mock server, no API key needed)
    # ------------------------------------------------------------------
    LACY_PREHEAT_SERVER_SESSION_ID=""

    local _query_out="$TEST_TMPDIR/_query_out"
    lacy_preheat_server_query "say hello" > "$_query_out" 2>/dev/null
    local query_rc=$?
    local query_result
    query_result=$(cat "$_query_out")

    assert_eq "$tool: mock query returns 0" "0" "$query_rc"
    assert_nonblank "$tool: mock query returns text" "$query_result"

    # ------------------------------------------------------------------
    # Test 7: Session reuse
    # ------------------------------------------------------------------
    local first_session="$LACY_PREHEAT_SERVER_SESSION_ID"
    assert_nonblank "$tool: session ID set after first query" "$first_session"

    # Second query should reuse the same session
    local _query_out2="$TEST_TMPDIR/_query_out2"
    lacy_preheat_server_query "say goodbye" > "$_query_out2" 2>/dev/null
    local query_rc2=$?

    assert_eq "$tool: second query returns 0" "0" "$query_rc2"
    assert_eq "$tool: session ID reused" "$first_session" "$LACY_PREHEAT_SERVER_SESSION_ID"

    # ------------------------------------------------------------------
    # Test 8: Full mcp.zsh integration
    # ------------------------------------------------------------------
    LACY_ACTIVE_TOOL="$tool"
    LACY_PREHEAT_SERVER_SESSION_ID=""

    # Stub spinner to avoid terminal noise
    lacy_start_spinner() { : }
    lacy_stop_spinner() { : }

    local _mcp_out="$TEST_TMPDIR/_mcp_out"
    lacy_shell_query_agent "what is 2+2" > "$_mcp_out" 2>/dev/null
    local mcp_rc=$?
    local mcp_result
    mcp_result=$(cat "$_mcp_out")

    assert_eq "$tool: mcp integration returns 0" "0" "$mcp_rc"
    assert_nonblank "$tool: mcp integration returns text" "$mcp_result"
    assert_nonblank "$tool: server PID set during integration" "$LACY_PREHEAT_SERVER_PID"

    # ------------------------------------------------------------------
    # Test 9: query outcomes that must not re-send the prompt
    # ------------------------------------------------------------------
    local _strip=$'s/\x1b\\[[0-9;?]*[a-zA-Z]//g'
    local session_before="$LACY_PREHEAT_SERVER_SESSION_ID"

    # Timeout: keep the session, say it is still running, return 0
    local _saved_timeout="$LACY_SESSION_MESSAGE_TIMEOUT"
    LACY_SESSION_MESSAGE_TIMEOUT=1
    lacy_shell_query_agent "MOCK_SLOW please" > "$_mcp_out" 2>/dev/null
    mcp_rc=$?
    LACY_SESSION_MESSAGE_TIMEOUT="$_saved_timeout"
    mcp_result=$(sed "$_strip" "$_mcp_out")
    assert_eq "$tool: timeout returns 0" "0" "$mcp_rc"
    if [[ "$mcp_result" == *"still running: $tool --session $session_before"* ]]; then
        pass "$tool: timeout prints the still-running line"
    else
        fail "$tool: timeout prints the still-running line" "got: $mcp_result"
    fi
    assert_eq "$tool: timeout keeps the session" "$session_before" "$LACY_PREHEAT_SERVER_SESSION_ID"
    sleep 2.5  # let the slow mock request finish before the next one

    # HTTP error: framed message from .info.error, no fallthrough, return 1
    lacy_shell_query_agent "MOCK_FAIL please" > "$_mcp_out" 2>/dev/null
    mcp_rc=$?
    mcp_result=$(sed "$_strip" "$_mcp_out")
    assert_eq "$tool: http error returns 1" "1" "$mcp_rc"
    if [[ "$mcp_result" == *"Error from $tool"* && "$mcp_result" == *"mock provider exploded"* ]]; then
        pass "$tool: http error is framed with the server message"
    else
        fail "$tool: http error is framed with the server message" "got: $mcp_result"
    fi
    assert_eq "$tool: http error keeps the session" "$session_before" "$LACY_PREHEAT_SERVER_SESSION_ID"

    # 200 with no text part
    lacy_shell_query_agent "MOCK_EMPTY please" > "$_mcp_out" 2>/dev/null
    mcp_rc=$?
    mcp_result=$(sed "$_strip" "$_mcp_out")
    assert_eq "$tool: empty response returns 0" "0" "$mcp_rc"
    if [[ "$mcp_result" == *"(no text response)"* ]]; then
        pass "$tool: empty response is labelled"
    else
        fail "$tool: empty response is labelled" "got: $mcp_result"
    fi

    # Gone session through the $(...) path: parent resets its copy
    LACY_PREHEAT_SERVER_SESSION_ID="gone-session-id"
    lacy_shell_query_agent "hello again" > "$_mcp_out" 2>/dev/null
    mcp_rc=$?
    assert_eq "$tool: gone session returns 1" "1" "$mcp_rc"
    assert_empty "$tool: gone session is reset in the parent" "$LACY_PREHEAT_SERVER_SESSION_ID"

    # Clean up for next tool
    reset_preheat_state
}

# ============================================================================
# Orphan and stale-PID tests (npm wrapper vs the process holding the port)
# ============================================================================

run_lifecycle_tests() {
    local tool="lash"
    section "Server lifecycle: orphans and stale PIDs"

    ensure_mock_on_path "$tool"
    reset_preheat_state

    # ------------------------------------------------------------------
    # (a) Recorded PID is a dead wrapper; the listener it spawned survives.
    #     Mirrors the npm `lash` wrapper: it spawns the real server and
    #     forwards no signals, so killing it orphans the port holder.
    # ------------------------------------------------------------------
    sh -c "python3 '$TEST_TMPDIR/bin/$tool' serve --port $TEST_PORT; exit \$?" </dev/null >/dev/null 2>&1 &
    local wrapper_pid=$!
    disown 2>/dev/null
    local i=0
    while (( i < 50 )) && ! lsof -tiTCP:$TEST_PORT -sTCP:LISTEN >/dev/null 2>&1; do sleep 0.1; (( i++ )); done
    local listener_pid
    listener_pid=$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null | head -1)
    assert_nonblank "orphan: mock listener is up" "$listener_pid"

    # Record the wrapper (as the old code did), then kill only the wrapper
    echo "$wrapper_pid" > "$LACY_PREHEAT_SERVER_PID_FILE"
    LACY_PREHEAT_SERVER_PID="$wrapper_pid"
    kill "$wrapper_pid" 2>/dev/null
    sleep 0.3
    assert_nonblank "orphan: listener survives the wrapper (the bug)" \
        "$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null)"

    lacy_preheat_server_stop
    sleep 0.3
    local still
    still=$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null)
    assert_empty "orphan: stop frees the port when the recorded PID is dead" "$still"
    if kill -0 "$listener_pid" 2>/dev/null; then
        fail "orphan: listener process is gone" "PID $listener_pid still alive"
        kill -9 "$listener_pid" 2>/dev/null
    else
        pass "orphan: listener process is gone"
    fi
    [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]] && fail "orphan: PID file removed" "still exists" || pass "orphan: PID file removed"

    # ------------------------------------------------------------------
    # (a2) Live wrapper whose child holds the port: both go away on stop.
    # ------------------------------------------------------------------
    reset_preheat_state
    sh -c "python3 '$TEST_TMPDIR/bin/$tool' serve --port $TEST_PORT; exit \$?" </dev/null >/dev/null 2>&1 &
    wrapper_pid=$!
    disown 2>/dev/null
    i=0
    while (( i < 50 )) && ! lsof -tiTCP:$TEST_PORT -sTCP:LISTEN >/dev/null 2>&1; do sleep 0.1; (( i++ )); done
    echo "$wrapper_pid" > "$LACY_PREHEAT_SERVER_PID_FILE"
    LACY_PREHEAT_SERVER_PID="$wrapper_pid"
    lacy_preheat_server_stop
    sleep 0.3
    still=$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null)
    assert_empty "wrapper: stop frees the port held by the wrapper's child" "$still"
    kill -0 "$wrapper_pid" 2>/dev/null && fail "wrapper: wrapper process is gone" "PID $wrapper_pid alive" || pass "wrapper: wrapper process is gone"

    # ------------------------------------------------------------------
    # (b) Stale PID file pointing at an unrelated process is left alone.
    # ------------------------------------------------------------------
    reset_preheat_state
    sleep 300 &
    local sleeper_pid=$!
    disown 2>/dev/null
    echo "$sleeper_pid" > "$LACY_PREHEAT_SERVER_PID_FILE"
    LACY_PREHEAT_SERVER_PID="$sleeper_pid"
    lacy_preheat_server_stop
    sleep 0.2
    if kill -0 "$sleeper_pid" 2>/dev/null; then
        pass "stale PID: unrelated process is not killed"
    else
        fail "stale PID: unrelated process is not killed" "sleep $sleeper_pid was killed"
    fi
    kill "$sleeper_pid" 2>/dev/null
    assert_empty "stale PID: in-memory PID cleared" "$LACY_PREHEAT_SERVER_PID"

    # ------------------------------------------------------------------
    # (c) start() records the listener PID, not the wrapper PID
    # ------------------------------------------------------------------
    reset_preheat_state
    # Wrap the mock in a shell so `$!` is a wrapper, like the npm shim
    local shim="$TEST_TMPDIR/bin/shimtool"
    printf '#!/bin/sh\nexec "$0.real" "$@"\n' > "$shim"
    printf '#!/bin/sh\npython3 "%s/bin/%s" "$@"\n' "$TEST_TMPDIR" "$tool" > "$shim.real"
    chmod +x "$shim" "$shim.real"
    lacy_preheat_server_start shimtool
    local start_rc=$?
    assert_eq "listener PID: start returns 0 through a wrapper" "0" "$start_rc"
    listener_pid=$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null | head -1)
    assert_eq "listener PID: recorded PID is the port holder" "$listener_pid" "$(cat "$LACY_PREHEAT_SERVER_PID_FILE")"
    assert_eq "listener PID: in-memory PID is the port holder" "$listener_pid" "$LACY_PREHEAT_SERVER_PID"
    lacy_preheat_server_stop
    sleep 0.3
    assert_empty "listener PID: stop frees the port" "$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null)"

    # ------------------------------------------------------------------
    # (d) cleanup only stops the server when this is the last lacy shell
    # ------------------------------------------------------------------
    reset_preheat_state
    lacy_preheat_server_start "$tool"
    sleep 300 &
    local other_shell=$!
    disown 2>/dev/null
    : > "$LACY_SHELL_HOME/.server_session_id_$other_shell"
    lacy_preheat_cleanup
    assert_nonblank "shared server: cleanup keeps the server while another shell is alive" \
        "$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null)"
    kill "$other_shell" 2>/dev/null
    wait "$other_shell" 2>/dev/null
    lacy_preheat_cleanup
    sleep 0.3
    assert_empty "shared server: cleanup stops the server when last shell exits" \
        "$(lsof -tiTCP:$TEST_PORT -sTCP:LISTEN 2>/dev/null)"
    [[ -f "$LACY_SHELL_HOME/.server_session_id_$other_shell" ]] && \
        fail "shared server: dead shell marker removed" "still exists" || \
        pass "shared server: dead shell marker removed"

    reset_preheat_state
}

# ============================================================================
# Main
# ============================================================================

echo "Preheat Server Integration Tests"
echo "Port: $TEST_PORT | Temp: $TEST_TMPDIR"

# Check prerequisites
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 required for mock server"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl required for HTTP tests"
    exit 1
fi

# Run tests for each tool
run_tests_for_tool "lash"
run_tests_for_tool "opencode"
run_lifecycle_tests

# Print summary and exit with appropriate code
summary
exit $?
