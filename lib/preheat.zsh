#!/usr/bin/env zsh

# Agent preheating for Lacy Shell
# - Background server for lash/opencode (eliminates cold-start)
# - Session reuse for claude (conversation continuity)

# === State ===
LACY_PREHEAT_SERVER_PID=""
LACY_PREHEAT_SERVER_PASSWORD=""
LACY_PREHEAT_SERVER_PID_FILE="$LACY_SHELL_HOME/.server.pid"
LACY_PREHEAT_CLAUDE_SESSION_ID=""
LACY_PREHEAT_SESSION_FILE="$LACY_SHELL_HOME/.claude_session_id"

# ============================================================================
# Background Server (lash + opencode)
# ============================================================================

# Start background server for lash or opencode
# Usage: lacy_preheat_server_start <tool>  (tool is "lash" or "opencode")
lacy_preheat_server_start() {
    local tool="$1"

    # Already running?
    if lacy_preheat_server_is_healthy; then
        return 0
    fi

    # Clean up stale PID from previous session
    lacy_preheat_server_stop 2>/dev/null

    # Generate random password for this session
    LACY_PREHEAT_SERVER_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 32 || date +%s%N)

    # Start server in background
    "$tool" serve --port "$LACY_PREHEAT_SERVER_PORT" >/dev/null 2>&1 &
    LACY_PREHEAT_SERVER_PID=$!

    # Save PID to file for crash recovery
    echo "$LACY_PREHEAT_SERVER_PID" > "$LACY_PREHEAT_SERVER_PID_FILE"

    # Wait for server to become healthy (up to 3 seconds)
    local attempts=0
    while (( attempts < 30 )); do
        if lacy_preheat_server_is_healthy; then
            return 0
        fi
        sleep 0.1
        (( attempts++ ))
    done

    # Failed to start — clean up
    lacy_preheat_server_stop 2>/dev/null
    return 1
}

# Check if server is alive and responding
lacy_preheat_server_is_healthy() {
    # Check PID is set and process exists
    if [[ -z "$LACY_PREHEAT_SERVER_PID" ]]; then
        # Try to recover PID from file
        if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
            LACY_PREHEAT_SERVER_PID=$(cat "$LACY_PREHEAT_SERVER_PID_FILE" 2>/dev/null)
        fi
        [[ -z "$LACY_PREHEAT_SERVER_PID" ]] && return 1
    fi

    # Process alive?
    kill -0 "$LACY_PREHEAT_SERVER_PID" 2>/dev/null || return 1

    # HTTP health check
    curl -sf --max-time 1 "http://localhost:${LACY_PREHEAT_SERVER_PORT}/health" >/dev/null 2>&1
}

# Send query to background server via REST API
# Usage: lacy_preheat_server_query <query>
# Outputs: response text to stdout
lacy_preheat_server_query() {
    local query="$1"
    local response

    # JSON-escape the query (handle quotes and backslashes)
    local escaped_query
    escaped_query=$(printf '%s' "$query" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

    response=$(curl -sf --max-time 120 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"prompt\": \"${escaped_query}\"}" \
        "http://localhost:${LACY_PREHEAT_SERVER_PORT}/api/chat" 2>/dev/null)

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        return 1
    fi

    # Extract result text from JSON response
    # Try jq first, fall back to grep/sed
    if command -v jq >/dev/null 2>&1; then
        echo "$response" | jq -r '.result // .response // .message // .content // empty' 2>/dev/null
    else
        # Best-effort JSON extraction without jq
        echo "$response" | sed 's/.*"result"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//' | sed 's/\\n/\n/g'
    fi
}

# Stop background server and clean up
lacy_preheat_server_stop() {
    # Kill by in-memory PID
    if [[ -n "$LACY_PREHEAT_SERVER_PID" ]]; then
        kill "$LACY_PREHEAT_SERVER_PID" 2>/dev/null
        wait "$LACY_PREHEAT_SERVER_PID" 2>/dev/null
        LACY_PREHEAT_SERVER_PID=""
    fi

    # Kill by PID file (handles orphans from crashed sessions)
    if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
        local file_pid
        file_pid=$(cat "$LACY_PREHEAT_SERVER_PID_FILE" 2>/dev/null)
        if [[ -n "$file_pid" ]]; then
            kill "$file_pid" 2>/dev/null
            wait "$file_pid" 2>/dev/null
        fi
        rm -f "$LACY_PREHEAT_SERVER_PID_FILE"
    fi

    LACY_PREHEAT_SERVER_PASSWORD=""
}

# ============================================================================
# Claude Session Reuse
# ============================================================================

# Restore session ID from disk (called at init)
lacy_preheat_claude_restore_session() {
    if [[ -f "$LACY_PREHEAT_SESSION_FILE" ]]; then
        LACY_PREHEAT_CLAUDE_SESSION_ID=$(cat "$LACY_PREHEAT_SESSION_FILE" 2>/dev/null)
    fi
}

# Build claude command with session reuse flags
# Outputs: command string to stdout
lacy_preheat_claude_build_cmd() {
    if [[ -n "$LACY_PREHEAT_CLAUDE_SESSION_ID" ]]; then
        echo "claude --resume ${LACY_PREHEAT_CLAUDE_SESSION_ID} --output-format json -p"
    else
        echo "claude --output-format json -p"
    fi
}

# Capture session ID from claude JSON output and persist to disk
# Usage: lacy_preheat_claude_capture_session <json_output>
lacy_preheat_claude_capture_session() {
    local json="$1"
    local session_id=""

    if command -v jq >/dev/null 2>&1; then
        session_id=$(echo "$json" | jq -r '.session_id // empty' 2>/dev/null)
    else
        # Fallback: grep for session_id in JSON
        session_id=$(echo "$json" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//' | sed 's/"//')
    fi

    if [[ -n "$session_id" ]]; then
        LACY_PREHEAT_CLAUDE_SESSION_ID="$session_id"
        echo "$session_id" > "$LACY_PREHEAT_SESSION_FILE"
    fi
}

# Extract result text from claude JSON output
# Usage: lacy_preheat_claude_extract_result <json_output>
# Outputs: result text to stdout
lacy_preheat_claude_extract_result() {
    local json="$1"

    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r '.result // empty' 2>/dev/null
    else
        # Fallback: extract result field
        echo "$json" | grep -o '"result"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"result"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' | sed 's/\\n/\n/g'
    fi
}

# Reset stale session (called on --resume failure)
lacy_preheat_claude_reset_session() {
    LACY_PREHEAT_CLAUDE_SESSION_ID=""
    rm -f "$LACY_PREHEAT_SESSION_FILE"
}

# ============================================================================
# Lifecycle
# ============================================================================

# Initialize preheating (called at plugin load)
lacy_preheat_init() {
    # Restore claude session from disk
    lacy_preheat_claude_restore_session

    # Eager server start if configured
    if [[ "$LACY_PREHEAT_EAGER" == "true" ]]; then
        local tool="${LACY_ACTIVE_TOOL}"

        # Only start for tools that support serve
        if [[ "$tool" == "lash" || "$tool" == "opencode" ]]; then
            lacy_preheat_server_start "$tool" &
            # Don't wait — let it start in background
            disown 2>/dev/null
        fi
    fi
}

# Cleanup preheating (called on quit/exit)
lacy_preheat_cleanup() {
    lacy_preheat_server_stop
    # Note: do NOT delete claude session file — it's intentionally persistent
}
