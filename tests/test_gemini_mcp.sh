#!/usr/bin/env bash

# Test Gemini MCP refactoring (helper and retry logic)
# Runs in Bash 4+ and ZSH

if [[ -n "$ZSH_VERSION" ]]; then
    LACY_SHELL_TYPE="zsh"
elif [[ -n "$BASH_VERSION" ]]; then
    LACY_SHELL_TYPE="bash"
else
    echo "FAIL: Unsupported shell"
    exit 1
fi

echo "Testing Gemini MCP Refactoring in: ${LACY_SHELL_TYPE}"
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

# Mock tool command execution
MOCK_EXIT_CODE=0
MOCK_RESPONSE='{"session_id": "new-id", "response": "success"}'
_lacy_run_tool_cmd() {
    echo "$MOCK_RESPONSE"
    return $MOCK_EXIT_CODE
}

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

section() {
    echo ""
    echo "--- $1 ---"
}

# ============================================================================
# Tests
# ============================================================================

section "Helper Function: _lacy_gemini_query_exec"

# Initial query (no session)
LACY_GEMINI_SESSION_ID=""
out=$(_lacy_gemini_query_exec "hello")
assert_eq "Initial query should succeed" 0 $?
assert_eq "Initial query should return mock response" "$MOCK_RESPONSE" "$out"

# Query with session
LACY_GEMINI_SESSION_ID="old-id"
out=$(_lacy_gemini_query_exec "hello")
assert_eq "Resumed query should succeed" 0 $?
assert_eq "Resumed query should return mock response" "$MOCK_RESPONSE" "$out"

section "Retry Logic in lacy_shell_query_agent"

# Simulate a failure on resume followed by a success on retry
LACY_GEMINI_SESSION_ID="bad-id"
LACY_ACTIVE_TOOL="gemini"

# Mock behavior: first call fails (if --resume), second call succeeds (if no --resume)
_lacy_run_tool_cmd() {
    if [[ "$1" == *" --resume "* ]]; then
        return 1
    else
        echo "$MOCK_RESPONSE"
        return 0
    fi
}

# Run query agent
out=$(lacy_shell_query_agent "retry-test" 2>/dev/null)
if [[ "$out" == *"success"* ]]; then
    PASS=$(( PASS + 1 ))
    printf '  \e[32m✓\e[0m %s\n' "Retry logic should eventually return success"
else
    printf '  \e[31m✗\e[0m %s\n' "Retry logic should eventually return success"
    echo "    Actual output: $out"
    FAIL=$(( FAIL + 1 ))
fi

# Cleanup
rm -rf "$TEST_TMPDIR"

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
