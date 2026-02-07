#!/usr/bin/env bash

# Bash-specific integration tests for Lacy Shell
# Requires Bash 4+ (macOS: brew install bash)
#
# Usage:
#   /opt/homebrew/bin/bash tests/test_bash.bash   # macOS with Homebrew bash
#   bash tests/test_bash.bash                      # Linux

# Bail if Bash < 4
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "SKIP: Bash 4+ required (have ${BASH_VERSION})"
    echo "  macOS: /opt/homebrew/bin/bash tests/test_bash.bash"
    exit 0
fi

# Note: no set -e — tests use functions that return nonzero intentionally

echo "Testing Lacy Shell Bash adapter in: bash ${BASH_VERSION}"
echo "================================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Set up environment as the plugin would
LACY_SHELL_TYPE="bash"
_LACY_ARR_OFFSET=0
LACY_SHELL_DIR="$REPO_DIR"

# Source core + bash adapter
source "$REPO_DIR/lib/core/constants.sh"
source "$REPO_DIR/lib/core/config.sh"
source "$REPO_DIR/lib/core/modes.sh"
source "$REPO_DIR/lib/core/spinner.sh"
source "$REPO_DIR/lib/core/mcp.sh"
source "$REPO_DIR/lib/core/preheat.sh"
source "$REPO_DIR/lib/core/detection.sh"

# Source bash-specific modules (skip keybindings — needs interactive shell)
source "$REPO_DIR/lib/bash/prompt.bash"
source "$REPO_DIR/lib/bash/execute.bash"

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

# ============================================================================
# Detection in Bash 4+
# ============================================================================

echo ""
echo "--- Bash Detection ---"

LACY_SHELL_CURRENT_MODE="auto"

assert_eq "ls → shell" "shell" "$(lacy_shell_classify_input 'ls -la')"
assert_eq "what files → agent" "agent" "$(lacy_shell_classify_input 'what files')"
assert_eq "fix the bug → agent" "agent" "$(lacy_shell_classify_input 'fix the bug')"
assert_eq "yes → agent" "agent" "$(lacy_shell_classify_input 'yes lets go')"
assert_eq "empty → neutral" "neutral" "$(lacy_shell_classify_input '')"

# Bash-specific: ${var,,} lowercase works
assert_eq "lowercase" "hello" "$(_lacy_lowercase 'HELLO')"

# ============================================================================
# Bash Prompt
# ============================================================================

echo ""
echo "--- Bash Prompt ---"

# Test prompt building
PS1='$ '
LACY_SHELL_ORIGINAL_PS1=""
LACY_SHELL_BASE_PS1=""
LACY_SHELL_PROMPT_INITIALIZED=false
lacy_shell_setup_prompt
lacy_shell_init_prompt_once

# After init, PS1 should contain the mode badge
if [[ "$PS1" == *"AUTO"* ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "  FAIL: PS1 should contain AUTO badge"
    echo "    PS1: $PS1"
    FAIL=$(( FAIL + 1 ))
fi

# Mode switch should update prompt
lacy_shell_set_mode "shell"
lacy_shell_update_prompt
if [[ "$PS1" == *"SHELL"* ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "  FAIL: PS1 should contain SHELL badge after mode switch"
    FAIL=$(( FAIL + 1 ))
fi

# ============================================================================
# Bash Mode Switching
# ============================================================================

echo ""
echo "--- Bash Modes ---"

LACY_SHELL_MODE_FILE="/tmp/lacy_test_mode_bash_$$"

lacy_shell_set_mode "auto"
assert_eq "auto mode" "auto" "$LACY_SHELL_CURRENT_MODE"

lacy_shell_toggle_mode
assert_eq "toggle → shell" "shell" "$LACY_SHELL_CURRENT_MODE"

lacy_shell_toggle_mode
assert_eq "toggle → agent" "agent" "$LACY_SHELL_CURRENT_MODE"

lacy_shell_toggle_mode
assert_eq "toggle → auto" "auto" "$LACY_SHELL_CURRENT_MODE"

rm -f "$LACY_SHELL_MODE_FILE"

# ============================================================================
# Bash Functions
# ============================================================================

echo ""
echo "--- Bash Functions ---"

# Check that command functions exist
if type ask &>/dev/null; then PASS=$(( PASS + 1 )); else echo "  FAIL: ask function missing"; FAIL=$(( FAIL + 1 )); fi
if type mode &>/dev/null; then PASS=$(( PASS + 1 )); else echo "  FAIL: mode function missing"; FAIL=$(( FAIL + 1 )); fi
if type tool &>/dev/null; then PASS=$(( PASS + 1 )); else echo "  FAIL: tool function missing"; FAIL=$(( FAIL + 1 )); fi
if type quit &>/dev/null; then PASS=$(( PASS + 1 )); else echo "  FAIL: quit function missing"; FAIL=$(( FAIL + 1 )); fi

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
