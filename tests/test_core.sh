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
assert_eq "help → agent" "agent" "$(lacy_shell_classify_input 'help')"
assert_eq "stop → agent" "agent" "$(lacy_shell_classify_input 'stop')"
assert_eq "why → agent" "agent" "$(lacy_shell_classify_input 'why')"
assert_eq "how → agent" "agent" "$(lacy_shell_classify_input 'how')"
assert_eq "no → agent" "agent" "$(lacy_shell_classify_input 'no')"
assert_eq "nope → agent" "agent" "$(lacy_shell_classify_input 'nope')"

# Agent words — multi-word
assert_eq "what is this → agent" "agent" "$(lacy_shell_classify_input 'what is this')"
assert_eq "yes lets go → agent" "agent" "$(lacy_shell_classify_input 'yes lets go')"
assert_eq "no I dont → agent" "agent" "$(lacy_shell_classify_input 'no I dont want that')"
assert_eq "perfect lets move on → agent" "agent" "$(lacy_shell_classify_input 'perfect lets move on')"
assert_eq "thanks for the help → agent" "agent" "$(lacy_shell_classify_input 'thanks for the help')"

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
assert_eq "hint set after parse error" "This looks like a question for the agent. Try again without shell mode, or press Ctrl+Space to switch to Agent mode." "$LACY_NL_HINT"

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
