#!/usr/bin/env bash

# Test harness for core detection/config/modes
# Runs in both Bash 4+ and ZSH
#
# Usage:
#   bash tests/test_core.sh
#   zsh  tests/test_core.sh

# Note: no set -e — tests use functions that return nonzero intentionally

# Determine which shell we're running in
if [[ -n "$ZSH_VERSION" ]]; then
    LACY_SHELL_TYPE="zsh"
    _LACY_ARR_OFFSET=1
elif [[ -n "$BASH_VERSION" ]]; then
    LACY_SHELL_TYPE="bash"
    _LACY_ARR_OFFSET=0
else
    echo "FAIL: Unsupported shell"
    exit 1
fi

echo "Testing Lacy Shell core in: ${LACY_SHELL_TYPE} (${ZSH_VERSION:-}${BASH_VERSION:-})"
echo "================================================================"

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source core modules
source "$REPO_DIR/lib/core/constants.sh"
source "$REPO_DIR/lib/core/detection.sh"
source "$REPO_DIR/lib/core/modes.sh"

# Test counter
PASS=0
FAIL=0

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$expected" == "$actual" ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $test_name"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_true() {
    local test_name="$1"
    shift
    if "$@"; then
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $test_name (returned false)"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_false() {
    local test_name="$1"
    shift
    if "$@"; then
        echo "  FAIL: $test_name (returned true)"
        FAIL=$(( FAIL + 1 ))
    else
        PASS=$(( PASS + 1 ))
    fi
}

# ============================================================================
# Detection Tests
# ============================================================================

echo ""
echo "--- Detection: classify_input ---"

LACY_SHELL_CURRENT_MODE="auto"

# Basic commands → shell
assert_eq "ls -la → shell" "shell" "$(lacy_shell_classify_input 'ls -la')"
assert_eq "git status → shell" "shell" "$(lacy_shell_classify_input 'git status')"
assert_eq "cd /home → shell" "shell" "$(lacy_shell_classify_input 'cd /home')"
assert_eq "npm install → shell" "shell" "$(lacy_shell_classify_input 'npm install')"
assert_eq "pwd → shell" "shell" "$(lacy_shell_classify_input 'pwd')"

# Natural language → agent
assert_eq "what files → agent" "agent" "$(lacy_shell_classify_input 'what files')"
assert_eq "fix the bug → agent" "agent" "$(lacy_shell_classify_input 'fix the bug')"
assert_eq "hello there → agent" "agent" "$(lacy_shell_classify_input 'hello there')"

# Agent words — single-word conversational
assert_eq "perfect → agent" "agent" "$(lacy_shell_classify_input 'perfect')"
assert_eq "yes → agent" "agent" "$(lacy_shell_classify_input 'yes')"
assert_eq "sure → agent" "agent" "$(lacy_shell_classify_input 'sure')"
assert_eq "thanks → agent" "agent" "$(lacy_shell_classify_input 'thanks')"
assert_eq "ok → agent" "agent" "$(lacy_shell_classify_input 'ok')"
assert_eq "great → agent" "agent" "$(lacy_shell_classify_input 'great')"
assert_eq "cool → agent" "agent" "$(lacy_shell_classify_input 'cool')"
assert_eq "nice → agent" "agent" "$(lacy_shell_classify_input 'nice')"
assert_eq "awesome → agent" "agent" "$(lacy_shell_classify_input 'awesome')"
assert_eq "lgtm → agent" "agent" "$(lacy_shell_classify_input 'lgtm')"
assert_eq "help → shell (real builtin)" "shell" "$(lacy_shell_classify_input 'help')"
assert_eq "stop → agent" "agent" "$(lacy_shell_classify_input 'stop')"
assert_eq "why → agent" "agent" "$(lacy_shell_classify_input 'why')"
assert_eq "how → agent" "agent" "$(lacy_shell_classify_input 'how')"
assert_eq "no → agent" "agent" "$(lacy_shell_classify_input 'no')"
assert_eq "nope → agent" "agent" "$(lacy_shell_classify_input 'nope')"

# Agent words — with trailing punctuation
assert_eq "why? → agent" "agent" "$(lacy_shell_classify_input 'why?')"
assert_eq "how? → agent" "agent" "$(lacy_shell_classify_input 'how?')"
assert_eq "no! → agent" "agent" "$(lacy_shell_classify_input 'no!')"
assert_eq "yes. → agent" "agent" "$(lacy_shell_classify_input 'yes.')"
assert_eq "sure! → agent" "agent" "$(lacy_shell_classify_input 'sure!')"
assert_eq "do? → agent" "agent" "$(lacy_shell_classify_input 'do?')"

# Agent words — multi-word
assert_eq "what is this → agent" "agent" "$(lacy_shell_classify_input 'what is this')"
assert_eq "yes lets go → agent" "agent" "$(lacy_shell_classify_input 'yes lets go')"
assert_eq "no I dont → agent" "agent" "$(lacy_shell_classify_input 'no I dont want that')"
assert_eq "perfect lets move on → agent" "agent" "$(lacy_shell_classify_input 'perfect lets move on')"
assert_eq "thanks for the help → agent" "agent" "$(lacy_shell_classify_input 'thanks for the help')"

# Inline env var assignments → shell
assert_eq "RUST_LOG=debug cargo run → shell" "shell" "$(lacy_shell_classify_input 'RUST_LOG=debug cargo run')"
assert_eq "FOO=bar node index.js → shell" "shell" "$(lacy_shell_classify_input 'FOO=bar node index.js')"
assert_eq "FOO=bar BAZ=qux node index.js → shell" "shell" "$(lacy_shell_classify_input 'FOO=bar BAZ=qux node index.js')"
assert_eq "CC=gcc make -j4 → shell" "shell" "$(lacy_shell_classify_input 'CC=gcc make -j4')"
assert_eq "FOO=bar (bare assignment, no cmd) → shell" "shell" "$(lacy_shell_classify_input 'FOO=bar')"
assert_eq "FOO=bar nonexistent thing → agent" "agent" "$(lacy_shell_classify_input 'FOO=bar nonexistent_cmd thing')"

# Single word non-command → shell (typo)
assert_eq "asdfgh → shell" "shell" "$(lacy_shell_classify_input 'asdfgh')"

# Emergency bypass
assert_eq "!rm → shell" "shell" "$(lacy_shell_classify_input '!rm /tmp/test')"

# Leading whitespace
assert_eq "  ls -la → shell" "shell" "$(lacy_shell_classify_input '  ls -la')"
assert_eq "  what files → agent" "agent" "$(lacy_shell_classify_input '  what files')"

# Empty input in auto mode → neutral
assert_eq "empty → neutral" "neutral" "$(lacy_shell_classify_input '')"

# Shell mode: everything → shell
LACY_SHELL_CURRENT_MODE="shell"
assert_eq "shell mode: what → shell" "shell" "$(lacy_shell_classify_input 'what files')"
assert_eq "shell mode: empty → shell" "shell" "$(lacy_shell_classify_input '')"

# Agent mode: everything → agent
LACY_SHELL_CURRENT_MODE="agent"
assert_eq "agent mode: ls → agent" "agent" "$(lacy_shell_classify_input 'ls -la')"
assert_eq "agent mode: empty → agent" "agent" "$(lacy_shell_classify_input '')"

LACY_SHELL_CURRENT_MODE="auto"

# ============================================================================
# Reserved Words Tests (Layer 1)
# ============================================================================

echo ""
echo "--- Detection: reserved words → agent ---"

LACY_SHELL_CURRENT_MODE="auto"

assert_eq "do question → agent" "agent" "$(lacy_shell_classify_input 'do We already have a way to uninstall?')"
assert_eq "done with this → agent" "agent" "$(lacy_shell_classify_input 'done with this task')"
assert_eq "then what → agent" "agent" "$(lacy_shell_classify_input 'then what happens next')"
assert_eq "else something → agent" "agent" "$(lacy_shell_classify_input 'else something')"
assert_eq "in the codebase → agent" "agent" "$(lacy_shell_classify_input 'in the codebase')"
assert_eq "function of module → agent" "agent" "$(lacy_shell_classify_input 'function of this module')"
assert_eq "select all users → agent" "agent" "$(lacy_shell_classify_input 'select all users')"

# ============================================================================
# NL Markers Tests
# ============================================================================

echo ""
echo "--- Detection: has_nl_markers ---"

assert_true "kill the process on localhost" lacy_shell_has_nl_markers "kill the process on localhost:3000"
assert_true "make the tests pass" lacy_shell_has_nl_markers "make the tests pass"
assert_true "go ahead and fix it" lacy_shell_has_nl_markers "go ahead and fix it"
assert_true "find out how auth works" lacy_shell_has_nl_markers "find out how auth works"
assert_true "find the file" lacy_shell_has_nl_markers "find the file"
assert_true "go ahead" lacy_shell_has_nl_markers "go ahead"
assert_true "kill -9 my baby (my is NL)" lacy_shell_has_nl_markers "kill -9 my baby"
assert_false "kill -9 (no bare words)" lacy_shell_has_nl_markers "kill -9"
assert_false "git push origin main (no NL marker)" lacy_shell_has_nl_markers "git push origin main"
assert_false "echo hello | grep the (has pipe)" lacy_shell_has_nl_markers "echo hello | grep the"

# ============================================================================
# Natural Language Detection Tests (Layer 2)
# ============================================================================

echo ""
echo "--- Detection: detect_natural_language ---"

# Successful commands — no detection
lacy_shell_detect_natural_language "ls -la" "file1" 0
assert_eq "exit 0 → no detect" "1" "$?"

# Non-NL second word — no detection
lacy_shell_detect_natural_language "ls foo" "no such file or directory" 1
assert_eq "non-NL second word → no detect" "1" "$?"

# Parse error with NL second word
lacy_shell_detect_natural_language "do We already have a way to uninstall?" "(eval):1: parse error near do" 1
assert_eq "parse error + NL word → detect" "0" "$?"

# go ahead — unknown command
lacy_shell_detect_natural_language "go ahead and fix it" "go ahead: unknown command" 2
assert_eq "go ahead → detect" "0" "$?"

# make sure — no rule to make target
lacy_shell_detect_natural_language "make sure the tests pass" "make: *** No rule to make target 'sure'.  Stop." 2
assert_eq "make sure → detect" "0" "$?"

# git me — not a git command
lacy_shell_detect_natural_language "git me the latest changes" "git: 'me' is not a git command." 1
assert_eq "git me → detect" "0" "$?"

# find out — unknown primary
lacy_shell_detect_natural_language "find out how the auth works" "find: out: unknown primary or operator" 1
assert_eq "find out → detect" "0" "$?"

# find the file — no such file or directory
lacy_shell_detect_natural_language "find the file" "find: the: No such file or directory" 1
assert_eq "find the file → detect" "0" "$?"

# go ahead — unknown command (2 words)
lacy_shell_detect_natural_language "go ahead" "go ahead: unknown command" 2
assert_eq "go ahead (2 words) → detect" "0" "$?"

# Real command error — no detection
lacy_shell_detect_natural_language "grep -r foo" "grep: warning: recursive search" 1
assert_eq "real grep error → no detect" "1" "$?"

# ============================================================================
# Mode Tests
# ============================================================================

echo ""
echo "--- Modes ---"

LACY_SHELL_MODE_FILE="/tmp/lacy_test_mode_$$"
LACY_SHELL_DEFAULT_MODE="auto"

lacy_shell_set_mode "shell"
assert_eq "set shell" "shell" "$LACY_SHELL_CURRENT_MODE"

lacy_shell_set_mode "agent"
assert_eq "set agent" "agent" "$LACY_SHELL_CURRENT_MODE"

lacy_shell_set_mode "auto"
assert_eq "set auto" "auto" "$LACY_SHELL_CURRENT_MODE"

# Toggle: auto → shell → agent → auto
lacy_shell_toggle_mode
assert_eq "toggle auto→shell" "shell" "$LACY_SHELL_CURRENT_MODE"
lacy_shell_toggle_mode
assert_eq "toggle shell→agent" "agent" "$LACY_SHELL_CURRENT_MODE"
lacy_shell_toggle_mode
assert_eq "toggle agent→auto" "auto" "$LACY_SHELL_CURRENT_MODE"

# Mode description
assert_eq "desc shell" "Normal shell execution" "$(lacy_mode_description 'shell')"
assert_eq "desc agent" "AI agent assistance via MCP" "$(lacy_mode_description 'agent')"

# Cleanup
rm -f "$LACY_SHELL_MODE_FILE"

# ============================================================================
# Helpers Tests
# ============================================================================

echo ""
echo "--- Helpers ---"

# _lacy_lowercase
assert_eq "lowercase HELLO" "hello" "$(_lacy_lowercase 'HELLO')"
assert_eq "lowercase MiXeD" "mixed" "$(_lacy_lowercase 'MiXeD')"

# _lacy_in_list
assert_true "in_list found" _lacy_in_list "b" "a" "b" "c"
assert_false "in_list not found" _lacy_in_list "d" "a" "b" "c"

# Tool cmd lookup
source "$REPO_DIR/lib/core/mcp.sh"
assert_eq "tool cmd lash" "lash run -c" "$(lacy_tool_cmd 'lash')"
assert_eq "tool cmd claude" "claude -p" "$(lacy_tool_cmd 'claude')"
assert_eq "tool cmd unknown" "" "$(lacy_tool_cmd 'unknown')"

# ============================================================================
# Telemetry JSON Escaping Tests
# ============================================================================

echo ""
echo "--- Telemetry: JSON escape ---"

source "$REPO_DIR/lib/core/telemetry.sh" 2>/dev/null || true

assert_eq "escape plain" "hello" "$(_lacy_json_escape_str 'hello')"
assert_eq "escape double quote" 'say \"hi\"' "$(_lacy_json_escape_str 'say "hi"')"
assert_eq "escape backslash" 'a\\b' "$(_lacy_json_escape_str 'a\b')"
assert_eq "escape newline" 'line1\nline2' "$(_lacy_json_escape_str $'line1\nline2')"
assert_eq "escape tab" 'a\tb' "$(_lacy_json_escape_str $'a\tb')"
assert_eq "escape combo" 'q\"\\n' "$(_lacy_json_escape_str 'q"\n')"

# ============================================================================
# Context Tests
# ============================================================================

echo ""
echo "--- Context: delta-based query context ---"

source "$REPO_DIR/lib/core/context.sh"

# Helper: check if string contains substring
_str_contains() { [[ "$1" == *"$2"* ]]; }
_str_not_contains() { [[ "$1" != *"$2"* ]]; }

# Reset to known state
_lacy_ctx_reset

# First query — should include cwd (differs from empty string)
_lacy_build_query_context "hello"
result="$_LACY_CTX_RESULT"
assert_true "first query includes cwd" _str_contains "$result" "[cwd: "
assert_true "first query includes query" _str_contains "$result" "hello"

# Second query, nothing changed — bare query
_lacy_build_query_context "hello again"
result="$_LACY_CTX_RESULT"
assert_eq "no-change → bare query" "hello again" "$result"

# Mark a command and trigger precmd
_lacy_ctx_mark_command "npm test"
_lacy_ctx_on_precmd 1

# Query should include exit code and recent command
_lacy_build_query_context "why did that fail"
result="$_LACY_CTX_RESULT"
assert_true "exit code included" _str_contains "$result" "[exit: 1]"
assert_true "recent cmd included" _str_contains "$result" "[recent: npm test]"
assert_true "query at end" _str_contains "$result" "why did that fail"

# After building context, counters reset — next query should be bare
_lacy_build_query_context "explain more"
result="$_LACY_CTX_RESULT"
assert_eq "after reset → bare query" "explain more" "$result"

# Multiple commands between queries
_lacy_ctx_mark_command "ls -la"
_lacy_ctx_on_precmd 0
_lacy_ctx_mark_command "cd /tmp"
_lacy_ctx_on_precmd 0
_lacy_ctx_mark_command "git status"
_lacy_ctx_on_precmd 0

_lacy_build_query_context "what happened"
result="$_LACY_CTX_RESULT"
assert_true "multiple cmds use pipe separator" _str_contains "$result" "ls -la | cd /tmp | git status"
# Exit code 0 should NOT be included
assert_true "exit 0 not included" _str_not_contains "$result" "[exit:"

# Reset clears state — forces full context on next query
_lacy_ctx_reset
_lacy_build_query_context "hello after reset"
result="$_LACY_CTX_RESULT"
assert_true "after reset includes cwd" _str_contains "$result" "[cwd: "

# Exit code only included when commands ran
_lacy_ctx_reset
# Simulate: no commands ran, but _LACY_CTX_LAST_EXIT_CODE might be stale
_LACY_CTX_LAST_EXIT_CODE=1
_LACY_CTX_CMDS_SINCE_QUERY=0
_lacy_build_query_context "test stale exit"
result="$_LACY_CTX_RESULT"
# Should NOT include exit code since no commands ran
assert_true "stale exit code not included" _str_not_contains "$result" "[exit:"

# Command buffer cap at max
_lacy_ctx_reset
# Burn through the first-query cwd delta
_lacy_build_query_context "burn"
for i in $(seq 1 15); do
    _lacy_ctx_mark_command "cmd$i"
    _lacy_ctx_on_precmd 0
done
_lacy_build_query_context "check buffer cap"
result="$_LACY_CTX_RESULT"
# Should contain cmd6 through cmd15 (last 10), not cmd1-cmd5
assert_true "old cmds trimmed (cmd5)" _str_not_contains "$result" "cmd5 |"
assert_true "recent cmds kept" _str_contains "$result" "cmd15"

# Detached HEAD — should show short hash, not literal "HEAD"
_lacy_ctx_reset
# Burn first-query delta
_lacy_build_query_context "burn"
# Simulate detached HEAD by checking the function handles it
# (Can't easily detach HEAD in test, but verify the branch name is never "HEAD")
_current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ "$_current_branch" != "HEAD" ]]; then
    # Normal branch — git context should contain branch name
    _lacy_ctx_reset
    _lacy_build_query_context "test git"
    result="$_LACY_CTX_RESULT"
    assert_true "git branch in context" _str_contains "$result" "[git: $_current_branch]"
fi

# ============================================================================
# Terminal Output Context Tests
# ============================================================================

echo ""
echo "--- Context: terminal output capture ---"

# Save original state
_saved_capture_cmd="$_LACY_CTX_TERMINAL_CAPTURE_CMD"
_saved_output_enabled="$_LACY_CTX_OUTPUT_ENABLED"

# In test environment, no terminal emulator API is available
assert_eq "no capture cmd in test env" "" "$_saved_capture_cmd"

# Without capture cmd, no output block in context
_LACY_CTX_TERMINAL_CAPTURE_CMD=""
_LACY_CTX_OUTPUT_ENABLED=true
_lacy_ctx_reset
_lacy_ctx_mark_command "npm test"
_lacy_ctx_on_precmd 1
_lacy_build_query_context "why fail"
result="$_LACY_CTX_RESULT"
assert_true "no output block without capture" _str_not_contains "$result" "[terminal-output]"

# Simulate capture by setting the variable to echo
_LACY_CTX_TERMINAL_CAPTURE_CMD="echo 'Error: test failed'"
_LACY_CTX_OUTPUT_ENABLED=true
_lacy_ctx_reset
# Burn cwd delta
_lacy_build_query_context "burn"
_lacy_ctx_mark_command "npm test"
_lacy_ctx_on_precmd 1
_lacy_build_query_context "why fail"
result="$_LACY_CTX_RESULT"
assert_true "output block present with capture" _str_contains "$result" "[terminal-output]"
assert_true "output content present" _str_contains "$result" "Error: test failed"
assert_true "output block closed" _str_contains "$result" "[/terminal-output]"

# Disabled via config
_LACY_CTX_OUTPUT_ENABLED=false
_lacy_ctx_mark_command "npm test"
_lacy_ctx_on_precmd 1
_lacy_build_query_context "why fail disabled"
result="$_LACY_CTX_RESULT"
assert_true "no output when disabled" _str_not_contains "$result" "[terminal-output]"

# No capture when no commands ran
_LACY_CTX_OUTPUT_ENABLED=true
_LACY_CTX_TERMINAL_CAPTURE_CMD="echo 'should not appear'"
_lacy_ctx_reset
_lacy_build_query_context "burn"
_lacy_build_query_context "no commands ran"
result="$_LACY_CTX_RESULT"
assert_true "no output when no commands ran" _str_not_contains "$result" "[terminal-output]"

# JSON escape helper
assert_eq "json escape newlines" 'hello\nworld' "$(_lacy_json_escape_str $'hello\nworld')"
assert_eq "json escape quotes" 'say \"hi\"' "$(_lacy_json_escape_str 'say "hi"')"
assert_eq "json escape backslash" 'path\\to' "$(_lacy_json_escape_str 'path\to')"

# --- Terminal detection priority tests ---
echo ""
echo "--- Context: terminal detection ---"

# Save env vars we'll be modifying
_saved_TMUX="${TMUX:-}"
_saved_STY="${STY:-}"
_saved_KITTY_PID="${KITTY_PID:-}"
_saved_TERM_PROGRAM="${TERM_PROGRAM:-}"
_saved_WEZTERM_EXECUTABLE="${WEZTERM_EXECUTABLE:-}"

# Clean slate for detection tests
unset TMUX STY KITTY_PID TERM_PROGRAM WEZTERM_EXECUTABLE 2>/dev/null

# tmux detection: set TMUX, verify capture command
TMUX="/tmp/tmux-test/default,12345,0"
_lacy_ctx_detect_terminal
assert_eq "tmux detected" "tmux capture-pane -p" "$_LACY_CTX_TERMINAL_CAPTURE_CMD"
unset TMUX

# screen detection: set STY, verify helper function
STY="12345.pts-0.host"
_lacy_ctx_detect_terminal
assert_eq "screen detected" "_lacy_ctx_screen_capture" "$_LACY_CTX_TERMINAL_CAPTURE_CMD"
unset STY

# tmux takes priority over Kitty
TMUX="/tmp/tmux-test/default,12345,0"
KITTY_PID="99999"
_lacy_ctx_detect_terminal
assert_eq "tmux beats kitty" "tmux capture-pane -p" "$_LACY_CTX_TERMINAL_CAPTURE_CMD"
unset TMUX KITTY_PID

# tmux takes priority over screen
TMUX="/tmp/tmux-test/default,12345,0"
STY="12345.pts-0.host"
_lacy_ctx_detect_terminal
assert_eq "tmux beats screen" "tmux capture-pane -p" "$_LACY_CTX_TERMINAL_CAPTURE_CMD"
unset TMUX STY

# No env vars set -> no capture (in test env without real terminals)
_lacy_ctx_detect_terminal
assert_eq "no terminal no capture" "" "$_LACY_CTX_TERMINAL_CAPTURE_CMD"

# macOS iTerm2 detection (only runs on Darwin)
if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
    TERM_PROGRAM="iTerm.app"
    _lacy_ctx_detect_terminal
    assert_eq "iterm2 detected" "_lacy_ctx_iterm2_capture" "$_LACY_CTX_TERMINAL_CAPTURE_CMD"
    unset TERM_PROGRAM

    TERM_PROGRAM="Apple_Terminal"
    _lacy_ctx_detect_terminal
    assert_eq "terminal.app detected" "_lacy_ctx_terminal_app_capture" "$_LACY_CTX_TERMINAL_CAPTURE_CMD"
    unset TERM_PROGRAM
fi

# Capture via helper function works (simulate with a test function)
_lacy_test_capture_func() { echo "captured via function"; }
_LACY_CTX_TERMINAL_CAPTURE_CMD="_lacy_test_capture_func"
_LACY_CTX_OUTPUT_ENABLED=true
_lacy_ctx_reset
_lacy_build_query_context "burn"
_lacy_ctx_mark_command "make build"
_lacy_ctx_on_precmd 1
_lacy_build_query_context "what happened"
result="$_LACY_CTX_RESULT"
assert_true "function-based capture works" _str_contains "$result" "captured via function"
assert_true "function capture has block" _str_contains "$result" "[terminal-output]"
unset -f _lacy_test_capture_func

# Restore env vars
TMUX="$_saved_TMUX"; [[ -z "$TMUX" ]] && unset TMUX 2>/dev/null
STY="$_saved_STY"; [[ -z "$STY" ]] && unset STY 2>/dev/null
KITTY_PID="$_saved_KITTY_PID"; [[ -z "$KITTY_PID" ]] && unset KITTY_PID 2>/dev/null
TERM_PROGRAM="$_saved_TERM_PROGRAM"; [[ -z "$TERM_PROGRAM" ]] && unset TERM_PROGRAM 2>/dev/null
WEZTERM_EXECUTABLE="$_saved_WEZTERM_EXECUTABLE"; [[ -z "$WEZTERM_EXECUTABLE" ]] && unset WEZTERM_EXECUTABLE 2>/dev/null

# Restore original state
_LACY_CTX_TERMINAL_CAPTURE_CMD="$_saved_capture_cmd"
_LACY_CTX_OUTPUT_ENABLED="$_saved_output_enabled"

# ============================================================================
# Results
# ============================================================================

echo ""
echo "================================================================"
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED"
    exit 1
else
    echo "ALL TESTS PASSED"
    exit 0
fi
