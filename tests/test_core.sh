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

# Hard agent indicators
assert_eq "what → agent" "agent" "$(lacy_shell_classify_input 'what is this')"
assert_eq "yes lets go → agent" "agent" "$(lacy_shell_classify_input 'yes lets go')"
assert_eq "no I dont → agent" "agent" "$(lacy_shell_classify_input 'no I dont want that')"

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
# NL Markers Tests
# ============================================================================

echo ""
echo "--- Detection: has_nl_markers ---"

assert_true "kill the process on localhost" lacy_shell_has_nl_markers "kill the process on localhost:3000"
assert_true "make the tests pass" lacy_shell_has_nl_markers "make the tests pass"
assert_false "kill -9 my baby (2 bare words)" lacy_shell_has_nl_markers "kill -9 my baby"
assert_false "kill -9 (single word)" lacy_shell_has_nl_markers "kill -9"
assert_false "git push origin main (no NL marker)" lacy_shell_has_nl_markers "git push origin main"
assert_false "echo hello | grep the (has pipe)" lacy_shell_has_nl_markers "echo hello | grep the"

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
