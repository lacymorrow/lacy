#!/usr/bin/env bash

# Test Gemini session resume functionality
# Runs in Bash 4+ and ZSH
#
# Usage:
#   bash tests/test_gemini.sh
#   zsh  tests/test_gemini.sh

# Determine which shell we're running in
if [[ -n "$ZSH_VERSION" ]]; then
    LACY_SHELL_TYPE="zsh"
elif [[ -n "$BASH_VERSION" ]]; then
    LACY_SHELL_TYPE="bash"
else
    echo "FAIL: Unsupported shell"
    exit 1
fi

echo "Testing Gemini Session Resume in: ${LACY_SHELL_TYPE}"
echo "================================================================"

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Set up test environment
TEST_TMPDIR=$(mktemp -d)
export LACY_SHELL_HOME="$TEST_TMPDIR"

# Source core modules
source "$REPO_DIR/lib/core/constants.sh"
source "$REPO_DIR/lib/core/mcp.sh"
source "$REPO_DIR/lib/core/preheat.sh"

# Mock dependencies
lacy_start_spinner() { :; }
lacy_stop_spinner() { :; }
lacy_print_color() { :; }

# Test counter
PASS=0
FAIL=0

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$expected" == "$actual" ]]; then
        PASS=$(( PASS + 1 ))
        printf '  \e[32m✓\e[0m %s\n' "$test_name"
    else
        printf '  \e[31m✗\e[0m %s\n' "$test_name"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

summary() {
    echo ""
    echo "================================================================"
    printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
    if (( FAIL > 0 )); then
        printf '\e[31mFAILED\e[0m\n'
        exit 1
    else
        printf '\e[32mALL PASSED\e[0m\n'
        exit 0
    fi
}

# ============================================================================
# Gemini Session Tests
# ============================================================================

section() {
    echo ""
    echo "--- $1 ---"
}

section "Gemini Session State"

# Initial state
assert_eq "LACY_GEMINI_SESSION_ID should be empty" "" "$LACY_GEMINI_SESSION_ID"
assert_eq "Initial build cmd" "gemini  -p" "$(lacy_preheat_gemini_build_cmd)"

# Capture session
MOCK_JSON='{"session_id": "test-uuid-123", "response": "hello"}'
lacy_preheat_gemini_capture_session "$MOCK_JSON"

assert_eq "LACY_GEMINI_SESSION_ID should be captured" "test-uuid-123" "$LACY_GEMINI_SESSION_ID"
assert_eq "Session ID should be persisted to file" "test-uuid-123" "$(cat "$LACY_GEMINI_SESSION_ID_FILE")"
assert_eq "Resumed build cmd" "gemini --resume test-uuid-123  -p" "$(lacy_preheat_gemini_build_cmd)"

# Extract result
assert_eq "Extract result from JSON" "hello" "$(lacy_preheat_gemini_extract_result "$MOCK_JSON")"

# Restore session (simulating new shell)
LACY_GEMINI_SESSION_ID=""
lacy_preheat_gemini_restore_session
assert_eq "Restore session from file" "test-uuid-123" "$LACY_GEMINI_SESSION_ID"

# Reset session
lacy_preheat_gemini_reset_session
assert_eq "LACY_GEMINI_SESSION_ID should be cleared" "" "$LACY_GEMINI_SESSION_ID"
if [[ ! -f "$LACY_GEMINI_SESSION_ID_FILE" ]]; then
    PASS=$(( PASS + 1 ))
    printf '  \e[32m✓\e[0m %s\n' "Session file should be removed"
else
    printf '  \e[31m✗\e[0m %s\n' "Session file should be removed"
    FAIL=$(( FAIL + 1 ))
fi

# Cleanup
rm -rf "$TEST_TMPDIR"

summary
