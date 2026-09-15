#!/usr/bin/env bash

# Runtime tests for the shared core: query log privacy, control characters in
# terminal captures, custom_command quoting, per-query output, NO_COLOR,
# session-new messages, signal handling, the server query result variable,
# AppleScript capture memory, telemetry re-sourcing, and spinner styles.
# Uses fake tools only. Never starts a real agent or server.
# Runs in both Bash 4+ and ZSH.
#
# Usage:
#   bash tests/test_runtime.sh
#   zsh  tests/test_runtime.sh

if [[ -n "$ZSH_VERSION" ]]; then
    LACY_SHELL_TYPE="zsh"
    _LACY_ARR_OFFSET=1
    setopt NO_MONITOR
elif [[ -n "$BASH_VERSION" ]]; then
    if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
        echo "SKIP: Bash 4+ required (have ${BASH_VERSION})"
        exit 0
    fi
    LACY_SHELL_TYPE="bash"
    _LACY_ARR_OFFSET=0
else
    echo "FAIL: Unsupported shell"
    exit 1
fi

echo "Testing core runtime in: ${LACY_SHELL_TYPE} (${ZSH_VERSION:-}${BASH_VERSION:-})"
echo "================================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PY3="$(command -v python3 2>/dev/null)"

TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/lacy-test-runtime.XXXXXX")
export HOME="$TEST_TMPDIR/fakehome"
export LACY_SHELL_HOME="$TEST_TMPDIR/home"
export LACY_SHELL_CONFIG_FILE="$LACY_SHELL_HOME/config.yaml"
export LACY_SHELL_MODE_FILE="$LACY_SHELL_HOME/current_mode"
export LACY_PREHEAT_SERVER_PORT=14987
mkdir -p "$HOME" "$LACY_SHELL_HOME" "$TEST_TMPDIR/bin" "$TEST_TMPDIR/work"
# Only fake tools and the base system: no real agent CLI can be picked up
export PATH="$TEST_TMPDIR/bin:/usr/bin:/bin"
cd "$TEST_TMPDIR/work" || exit 1
unset NO_COLOR TMUX STY TERM_PROGRAM 2>/dev/null

cleanup() { cd / && command rm -rf "$TEST_TMPDIR"; }
trap cleanup EXIT

source "$REPO_DIR/lib/core/constants.sh"
source "$REPO_DIR/lib/core/config.sh"
source "$REPO_DIR/lib/core/animations.sh"
source "$REPO_DIR/lib/core/spinner.sh"
source "$REPO_DIR/lib/core/mcp.sh"
source "$REPO_DIR/lib/core/preheat.sh"
source "$REPO_DIR/lib/core/context.sh"
source "$REPO_DIR/lib/core/commands.sh"

# Quiet the spinner
lacy_start_spinner() { :; }
lacy_stop_spinner() { :; }

PASS=0
FAIL=0

assert_eq() {
    local test_name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $test_name"
        echo "    Expected: [$expected]"
        echo "    Actual:   [$actual]"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_contains() {
    local test_name="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $test_name"
        echo "    Missing: $needle"
        echo "    In:      $haystack"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_not_contains() {
    local test_name="$1" haystack="$2" needle="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $test_name"
        echo "    Unexpected: $needle"
        echo "    In:         $haystack"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_true() {
    local test_name="$1"
    shift
    if "$@"; then
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $test_name"
        FAIL=$(( FAIL + 1 ))
    fi
}

plain() { sed $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g'; }
count_lines() { if [[ -f "$1" ]]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
perms() { ls -l "$1" | cut -c1-10; }

OUT="$TEST_TMPDIR/out"

# --- Fake tools --------------------------------------------------------------

# Writes each argument on its own line, bracketed, to $ARGDUMP_OUT
cat > "$TEST_TMPDIR/bin/argdump" <<'EOF'
#!/bin/sh
: > "$ARGDUMP_OUT"
for a in "$@"; do printf '[%s]\n' "$a" >> "$ARGDUMP_OUT"; done
printf 'argdump ok\n'
EOF
mkdir -p "$TEST_TMPDIR/bin dir"
cp "$TEST_TMPDIR/bin/argdump" "$TEST_TMPDIR/bin dir/spaced tool"

# Stands in for codex; exit code from $FAKE_EXIT
cat > "$TEST_TMPDIR/bin/codex" <<'EOF'
#!/bin/sh
printf 'codex answer\n'
exit "${FAKE_EXIT:-0}"
EOF

# Stands in for claude/gemini: logs its arguments, exits $FAKE_EXIT (default 130)
cat > "$TEST_TMPDIR/bin/claude" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$AGENT_LOG"
exit "${FAKE_EXIT:-130}"
EOF
cp "$TEST_TMPDIR/bin/claude" "$TEST_TMPDIR/bin/gemini"

# Stands in for curl in the server query: writes $FAKE_CURL_BODY to -o and
# prints $FAKE_CURL_CODE as the HTTP status
cat > "$TEST_TMPDIR/bin/curl" <<'EOF'
#!/bin/sh
out=""
while [ $# -gt 0 ]; do
    case "$1" in -o) out="$2"; shift ;; esac
    shift
done
[ -n "$out" ] && printf '%s' "$FAKE_CURL_BODY" > "$out"
printf '%s' "${FAKE_CURL_CODE:-200}"
exit 0
EOF

# Stands in for osascript: logs each call; FAKE_OSA=deny fails, slow hangs
cat > "$TEST_TMPDIR/bin/osascript" <<'EOF'
#!/bin/sh
printf 'call\n' >> "$OSA_LOG"
case "$FAKE_OSA" in
    deny) printf 'Not authorized to send Apple events\n' >&2; exit 1 ;;
    slow) sleep 5; printf 'late\n' ;;
    *)    printf 'screen from osascript\n' ;;
esac
EOF
chmod +x "$TEST_TMPDIR/bin/"* "$TEST_TMPDIR/bin dir/spaced tool"

export ARGDUMP_OUT="$TEST_TMPDIR/argdump.out"
export AGENT_LOG="$TEST_TMPDIR/agent.log"
export OSA_LOG="$TEST_TMPDIR/osa.log"

# ============================================================================
echo "NO_COLOR print helpers"
# ============================================================================

assert_eq "color: escapes by default" $'\e[38;5;34mhello\e[0m' "$(lacy_print_color 34 hello)"
assert_eq "color: text is not expanded" $'\e[38;5;34m100% %F{red} \\e\e[0m' "$(lacy_print_color 34 '100% %F{red} \e')"
assert_eq "NO_COLOR: plain line" '100% %F{red} \e' "$(NO_COLOR=1 lacy_print_color 34 '100% %F{red} \e')"
assert_eq "NO_COLOR: plain, no newline" 'abc' "$(NO_COLOR=1 lacy_print_color_n 200 'abc')"
out=$(NO_COLOR=1 _lacy_print_no_tool)
assert_not_contains "NO_COLOR: no-tool message has no escapes" "$out" $'\e'

# ============================================================================
echo "No AI tool: one message, no prompt"
# ============================================================================

_saved_tool_list=("${LACY_TOOL_LIST[@]}")
_any_real=false
for _t in "${LACY_TOOL_LIST[@]}"; do
    [[ "$_t" == "claude" || "$_t" == "gemini" || "$_t" == "codex" ]] && continue
    command -v "$_t" >/dev/null 2>&1 && _any_real=true
done
LACY_TOOL_LIST=(lash opencode hermes copilot goose amp aider)
if [[ "$_any_real" == true ]]; then
    echo "  SKIP: a real agent CLI is on the base PATH"
else
    LACY_ACTIVE_TOOL=""
    lacy_shell_execute_agent "hello there" < /dev/null > "$OUT" 2>&1
    out=$(plain < "$OUT")
    assert_eq "no tool: message printed exactly once" "1" "$(grep -c 'No AI tool found' "$OUT")"
    assert_contains "no tool: install hint" "$out" "npm install -g lashcode"
    assert_contains "no tool: setup hint" "$out" "lacy setup"
    assert_not_contains "no tool: no generic recovery block" "$out" "Try: tool set"
    assert_not_contains "no tool: no install prompt" "$out" "[Y/n]"
fi
LACY_TOOL_LIST=("${_saved_tool_list[@]}")

# ============================================================================
echo "Per-query output: no Using line, resume hint only after failure"
# ============================================================================

LACY_TOOL_LIST=(codex)
LACY_ACTIVE_TOOL=""
FAKE_EXIT=0 lacy_shell_query_agent "what is here" > "$OUT" 2>&1
rc=$?
out=$(plain < "$OUT")
assert_eq "success: rc 0" "0" "$rc"
assert_contains "success: answer shown" "$out" "codex answer"
assert_not_contains "success: no auto-detected line" "$out" "Using"
assert_not_contains "success: no resume command" "$out" "codex exec resume"
assert_contains "success: last session saved silently" "$(cat "$LACY_LAST_SESSION_FILE" 2>/dev/null)" "codex"

FAKE_EXIT=3 lacy_shell_query_agent "what is here" > "$OUT" 2>&1
rc=$?
out=$(plain < "$OUT")
assert_eq "failure: rc 3" "3" "$rc"
assert_contains "failure: resume hint shown" "$out" "Resume: codex exec resume --last"
assert_contains "failure: doctor hint" "$out" "lacy doctor"
LACY_TOOL_LIST=("${_saved_tool_list[@]}")

# ============================================================================
echo "custom_command quoting"
# ============================================================================

custom_cmd=$(cat <<'EOF'
argdump --system "don't panic" 'a b' "x \"y\" \\z" plain\ word '$(touch pwned1)' $(touch pwned2) ;
EOF
)
command rm -f "$ARGDUMP_OUT"
_lacy_run_tool_cmd "$custom_cmd" "my query" > "$OUT" 2>&1
assert_eq "quoting: rc" "0" "$?"
expected_args=$(cat <<'EOF'
[--system]
[don't panic]
[a b]
[x "y" \z]
[plain word]
[$(touch pwned1)]
[$(touch]
[pwned2)]
[;]
[my query]
EOF
)
assert_eq "quoting: argv split like a shell, nothing expanded" "$expected_args" "$(cat "$ARGDUMP_OUT")"
if [[ -e pwned1 || -e pwned2 ]]; then
    echo "  FAIL: quoting: command substitution was executed"
    FAIL=$(( FAIL + 1 ))
else
    PASS=$(( PASS + 1 ))
fi

command rm -f "$ARGDUMP_OUT"
_lacy_run_tool_cmd "argdump 'oops" "q" > "$OUT" 2>&1
assert_eq "quoting: unbalanced quote refused" "127" "$?"
assert_true "quoting: unbalanced quote never runs" test ! -e "$ARGDUMP_OUT"

LACY_ACTIVE_TOOL="custom"
LACY_CUSTOM_TOOL_CMD="'$TEST_TMPDIR/bin dir/spaced tool' --flag"
lacy_shell_query_agent "multi word query" > "$OUT" 2>&1
assert_eq "quoting: quoted path with spaces runs" "0" "$?"
assert_eq "quoting: flag passed" "[--flag]" "$(sed -n 1p "$ARGDUMP_OUT")"
assert_eq "quoting: query is one final argument" "2" "$(count_lines "$ARGDUMP_OUT")"
assert_contains "quoting: final argument carries the query" "$(sed -n 2p "$ARGDUMP_OUT")" "multi word query]"

LACY_CUSTOM_TOOL_CMD="argdump \"unterminated"
lacy_shell_query_agent "hello" > "$OUT" 2>&1
assert_eq "quoting: query_agent refuses unbalanced command" "1" "$?"
assert_contains "quoting: says why" "$(plain < "$OUT")" "unbalanced quotes"

# ============================================================================
echo "Query log: off by default, opt-in writes only the raw query, 0600"
# ============================================================================

LOG_FILE="$LACY_SHELL_HOME/logs/queries.log"
cat > "$LACY_SHELL_CONFIG_FILE" <<'EOF'
agent_tools:
  active: custom
  custom_command: argdump
EOF
lacy_shell_load_config > /dev/null 2>&1
assert_eq "log: default off" "false" "$LACY_LOG_QUERIES"
lacy_shell_query_agent "secret question" > "$OUT" 2>&1
assert_true "log: no file when off" test ! -e "$LOG_FILE"

cat > "$LACY_SHELL_CONFIG_FILE" <<'EOF'
agent_tools:
  active: custom
  custom_command: argdump
logging:
  queries: true
EOF
lacy_shell_load_config > /dev/null 2>&1
assert_eq "log: opt-in read" "true" "$LACY_LOG_QUERIES"
_lacy_test_capture_secret() { printf 'SCREEN_SECRET line\n'; }
_LACY_CTX_TERMINAL_CAPTURE_CMD="_lacy_test_capture_secret"
_LACY_CTX_OUTPUT_ENABLED=true
_lacy_ctx_reset
_lacy_ctx_mark_command "npm test --token"
_lacy_ctx_on_precmd 1
lacy_shell_query_agent $'why did it fail\nsecond line' > "$OUT" 2>&1
assert_contains "log: the tool did get terminal context" "$(cat "$ARGDUMP_OUT")" "SCREEN_SECRET"
assert_eq "log: file mode 600" "-rw-------" "$(perms "$LOG_FILE")"
log_text=$(cat "$LOG_FILE")
assert_contains "log: raw query, newline escaped" "$log_text" 'why did it fail\nsecond line'
assert_not_contains "log: no screen capture" "$log_text" "SCREEN_SECRET"
assert_not_contains "log: no cwd" "$log_text" "[cwd:"
assert_not_contains "log: no recent commands" "$log_text" "npm test"
_LACY_CTX_TERMINAL_CAPTURE_CMD=""

chmod 644 "$LOG_FILE"
lacy_shell_load_config > /dev/null 2>&1
assert_eq "log: an old world-readable log is tightened on load" "-rw-------" "$(perms "$LOG_FILE")"

printf 'x' > "$LACY_SHELL_HOME/.config_cache"
lacy_shell_load_config > /dev/null 2>&1
assert_true "config cache: stale .config_cache removed" test ! -e "$LACY_SHELL_HOME/.config_cache"

# ============================================================================
echo "Control characters from screen capture produce valid JSON"
# ============================================================================

_lacy_test_capture_ctrl() {
    printf 'plain \033[31mred\033[0m \033]8;;https://example.com/x\033\\link\033]8;;\033\\ bell\a done\r\n'
    printf '\033]0;window title\a\001\177tab\there "quote" back\\slash\n'
}
_LACY_CTX_TERMINAL_CAPTURE_CMD="_lacy_test_capture_ctrl"
_LACY_CTX_OUTPUT_ENABLED=true
_lacy_ctx_reset
_lacy_build_query_context "burn"
_lacy_ctx_mark_command "ls"
_lacy_ctx_on_precmd 0
_lacy_build_query_context "explain"
ctx="$_LACY_CTX_RESULT"
assert_contains "capture: text kept" "$ctx" "plain red link bell done"
assert_contains "capture: tab and quotes kept" "$ctx" $'tab\there "quote" back\\slash'
assert_not_contains "capture: no ESC" "$ctx" $'\033'
assert_not_contains "capture: no BEL" "$ctx" $'\a'
assert_not_contains "capture: no CR" "$ctx" $'\r'
assert_not_contains "capture: no DEL" "$ctx" $'\177'
assert_not_contains "capture: no SOH" "$ctx" $'\001'
assert_not_contains "capture: OSC 8 target removed" "$ctx" "example.com"
assert_not_contains "capture: OSC title removed" "$ctx" "window title"
_LACY_CTX_TERMINAL_CAPTURE_CMD=""

escaped=$(_lacy_json_escape_str "$ctx")
raw_ctrl=$'a\001b\033c\ad\177e\bf\fg\th\ni\rj"k\\l'
escaped_raw=$(_lacy_json_escape_str "$raw_ctrl")
assert_eq "json escape: control bytes dropped, the rest escaped" 'abcdefg\th\ni\rj\"k\\l' "$escaped_raw"
if [[ -n "$PY3" ]]; then
    printf '{"t":"%s"}' "$escaped" | "$PY3" -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null
    assert_eq "json: capture context parses" "0" "$?"
    printf '{"t":"%s"}' "$escaped_raw" | "$PY3" -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null
    assert_eq "json: raw control string parses" "0" "$?"
    decoded=$(printf '{"t":"%s"}' "$escaped" | "$PY3" -c 'import json,sys; sys.stdout.write(json.load(sys.stdin)["t"])')
    assert_eq "json: round-trips to the cleaned text" "$ctx" "$decoded"
else
    echo "  SKIP: python3 not found; JSON parse checks skipped"
fi

# ============================================================================
echo "AppleScript capture: bounded, and a failure is remembered"
# ============================================================================

if true; then
    # 1 s budget: enough for a fake osascript under load, well under the 5 s hang
    LACY_CTX_CAPTURE_TIMEOUT_TICKS=10
    _LACY_CTX_TERMINAL_CAPTURE_CMD="_lacy_ctx_iterm2_capture"

    command rm -f "$OSA_LOG"
    _LACY_CTX_CAPTURE_DISABLED=false
    _lacy_ctx_reset
    _lacy_build_query_context "burn"
    _lacy_ctx_mark_command "ls"; _lacy_ctx_on_precmd 0
    FAKE_OSA=ok _lacy_build_query_context "q1"
    assert_contains "osascript ok: screen included" "$_LACY_CTX_RESULT" "screen from osascript"
    assert_eq "osascript ok: still enabled" "false" "$_LACY_CTX_CAPTURE_DISABLED"

    command rm -f "$OSA_LOG"
    export FAKE_OSA=deny
    _lacy_ctx_mark_command "ls"; _lacy_ctx_on_precmd 0
    _lacy_build_query_context "q2"
    assert_not_contains "osascript denied: no output block" "$_LACY_CTX_RESULT" "[terminal-output]"
    assert_eq "osascript denied: remembered" "true" "$_LACY_CTX_CAPTURE_DISABLED"
    _lacy_ctx_mark_command "ls"; _lacy_ctx_on_precmd 0
    _lacy_build_query_context "q3"
    assert_eq "osascript denied: not asked again" "1" "$(count_lines "$OSA_LOG")"

    export FAKE_OSA=slow
    _LACY_CTX_CAPTURE_DISABLED=false
    _lacy_ctx_mark_command "ls"; _lacy_ctx_on_precmd 0
    _t0=$SECONDS
    _lacy_build_query_context "q4"
    _elapsed=$(( SECONDS - _t0 ))
    assert_true "osascript slow: capture returns within the budget" test "$_elapsed" -le 3
    assert_eq "osascript slow: remembered" "true" "$_LACY_CTX_CAPTURE_DISABLED"
    unset FAKE_OSA

    _LACY_CTX_TERMINAL_CAPTURE_CMD="false"
    _LACY_CTX_CAPTURE_DISABLED=false
    _lacy_ctx_mark_command "ls"; _lacy_ctx_on_precmd 0
    _lacy_build_query_context "q5"
    assert_eq "non-AppleScript failure is not remembered" "false" "$_LACY_CTX_CAPTURE_DISABLED"
    _LACY_CTX_TERMINAL_CAPTURE_CMD=""
    LACY_CTX_CAPTURE_TIMEOUT_TICKS=20
fi

# ============================================================================
echo "Signals: Ctrl+C never re-runs the query or drops the session"
# ============================================================================

LACY_ACTIVE_TOOL="claude"
LACY_PREHEAT_CLAUDE_SESSION_ID="sess-123"
echo "sess-123" > "$LACY_PREHEAT_SESSION_FILE"
command rm -f "$AGENT_LOG"
FAKE_EXIT=130 lacy_shell_query_agent "long question" > "$OUT" 2>&1
rc=$?
out=$(plain < "$OUT")
assert_eq "claude signal: rc 130" "130" "$rc"
assert_eq "claude signal: tool ran once" "1" "$(count_lines "$AGENT_LOG")"
assert_contains "claude signal: with --resume" "$(cat "$AGENT_LOG")" "--resume sess-123"
assert_eq "claude signal: session kept" "sess-123" "$LACY_PREHEAT_CLAUDE_SESSION_ID"
assert_not_contains "claude signal: no hints" "$out" "lacy doctor"

command rm -f "$AGENT_LOG"
export FAKE_EXIT=130
lacy_shell_execute_agent "long question" > "$OUT" 2>&1
unset FAKE_EXIT
assert_not_contains "execute_agent signal: no recovery hints" "$(plain < "$OUT")" "Try: tool set"

command rm -f "$AGENT_LOG"
LACY_PREHEAT_CLAUDE_SESSION_ID="sess-123"
echo "sess-123" > "$LACY_PREHEAT_SESSION_FILE"
FAKE_EXIT=1 lacy_shell_query_agent "long question" > "$OUT" 2>&1
assert_eq "claude plain failure: retried once without --resume" "2" "$(count_lines "$AGENT_LOG")"

LACY_ACTIVE_TOOL="gemini"
LACY_GEMINI_SESSION_ID="gem-1"
echo "gem-1" > "$LACY_GEMINI_SESSION_ID_FILE"
command rm -f "$AGENT_LOG"
FAKE_EXIT=130 lacy_shell_query_agent "long question" > "$OUT" 2>&1
rc=$?
assert_eq "gemini signal: rc 130" "130" "$rc"
assert_eq "gemini signal: tool ran once" "1" "$(count_lines "$AGENT_LOG")"
assert_eq "gemini signal: session kept" "gem-1" "$LACY_GEMINI_SESSION_ID"

# ============================================================================
echo "Server query: results and session changes land in the calling shell"
# ============================================================================

_lacy_preheat_server_create_session() {
    LACY_PREHEAT_SERVER_SESSION_ID="new-sess"
    echo "new-sess" > "$LACY_PREHEAT_SERVER_SESSION_FILE"
    return 0
}
LACY_PREHEAT_SERVER_SESSION_ID=""
export FAKE_CURL_CODE=200
export FAKE_CURL_BODY='[{"role":"assistant","parts":[{"type":"text","text":"hi from server"}]}]'
_lacy_preheat_server_query_into "hello"
rc=$?
assert_eq "server: rc ok" "$LACY_SERVER_QUERY_OK" "$rc"
if [[ -n "$PY3" ]] || command -v jq >/dev/null 2>&1; then
    assert_eq "server: result variable" "hi from server" "$_LACY_SERVER_RESULT"
fi
assert_eq "server: new session visible without re-reading a file" "new-sess" "$LACY_PREHEAT_SERVER_SESSION_ID"

export FAKE_CURL_CODE=404
export FAKE_CURL_BODY='{"error":"not found"}'
_lacy_preheat_server_query_into "hello"
rc=$?
assert_eq "server 404: rc session gone" "$LACY_SERVER_QUERY_SESSION_GONE" "$rc"
assert_eq "server 404: reset sticks in this shell" "" "$LACY_PREHEAT_SERVER_SESSION_ID"
unset FAKE_CURL_CODE FAKE_CURL_BODY

# ============================================================================
echo "Session new: says what actually happened"
# ============================================================================

LACY_ACTIVE_TOOL="claude"
lacy_session_new > "$OUT" 2>&1
assert_eq "new (claude): rc 0" "0" "$?"
assert_contains "new (claude): started" "$(plain < "$OUT")" "New session started"

LACY_ACTIVE_TOOL="lash"
lacy_preheat_server_is_healthy() { return 1; }
lacy_session_new > "$OUT" 2>&1
assert_eq "new (lash, no server): rc 0" "0" "$?"
assert_contains "new (lash, no server): cleared" "$(plain < "$OUT")" "Session cleared"
assert_not_contains "new (lash, no server): no false claim" "$(plain < "$OUT")" "New session started"

lacy_preheat_server_is_healthy() { return 0; }
_lacy_preheat_server_create_session() { return 1; }
lacy_session_new > "$OUT" 2>&1
assert_eq "new (lash, create fails): rc 1" "1" "$?"
assert_contains "new (lash, create fails): says so" "$(plain < "$OUT")" "Could not open a new lash session"
assert_not_contains "new (lash, create fails): no false claim" "$(plain < "$OUT")" "New session started"

_lacy_preheat_server_create_session() { LACY_PREHEAT_SERVER_SESSION_ID="s2"; return 0; }
lacy_session_new > "$OUT" 2>&1
assert_eq "new (lash, created): rc 0" "0" "$?"
assert_contains "new (lash, created): started" "$(plain < "$OUT")" "New session started"

# Put the real functions back
source "$REPO_DIR/lib/core/preheat.sh"

# ============================================================================
echo "Telemetry and spinner"
# ============================================================================

telemetry_err=$( { source "$REPO_DIR/lib/core/telemetry.sh"; source "$REPO_DIR/lib/core/telemetry.sh"; } 2>&1 )
assert_eq "telemetry: re-source prints nothing" "" "$telemetry_err"

assert_eq "spinner: two styles" "2" "${#LACY_SPINNER_ANIMATIONS[@]}"
lacy_set_spinner_animation ascii
for _f in "${LACY_SPINNER_ANIM[@]}"; do break; done
assert_eq "spinner: ascii frames" "|   " "$_f"
lacy_set_spinner_animation random
for _f in "${LACY_SPINNER_ANIM[@]}"; do break; done
assert_eq "spinner: unknown style is braille" "⠋⠀⠀⠀" "$_f"
_lacy_config_reset_vars
assert_eq "spinner: default style braille" "braille" "$LACY_SPINNER_STYLE"

echo "================================================================"
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    echo "SOME TESTS FAILED"
    exit 1
fi
echo "ALL TESTS PASSED"
