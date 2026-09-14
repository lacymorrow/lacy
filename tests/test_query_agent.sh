#!/usr/bin/env bash

# Tests for lacy_shell_query_agent's generic path and tool validation
# Runs in both Bash 4+ and ZSH
#
# Usage:
#   bash tests/test_query_agent.sh
#   zsh  tests/test_query_agent.sh

# Note: no set -e, functions under test return nonzero on purpose

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

echo "Testing lacy_shell_query_agent in: ${LACY_SHELL_TYPE} (${ZSH_VERSION:-}${BASH_VERSION:-})"
echo "================================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_TMPDIR=$(mktemp -d)
export LACY_SHELL_HOME="$TEST_TMPDIR/home"
mkdir -p "$LACY_SHELL_HOME" "$TEST_TMPDIR/bin"
export PATH="$TEST_TMPDIR/bin:$PATH"

cleanup() { command rm -rf "$TEST_TMPDIR"; }
trap cleanup EXIT

source "$REPO_DIR/lib/core/constants.sh"
source "$REPO_DIR/lib/core/spinner.sh"
source "$REPO_DIR/lib/core/mcp.sh"
source "$REPO_DIR/lib/core/preheat.sh"
source "$REPO_DIR/lib/core/context.sh"

# Quiet the spinner and terminal context
lacy_start_spinner() { :; }
lacy_stop_spinner() { :; }
_lacy_build_query_context() { _LACY_CTX_RESULT="$1"; }

PASS=0
FAIL=0

assert_eq() {
    local test_name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $test_name"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
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

# Strip ANSI escapes so assertions see plain text
plain() { sed $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g'; }

# --- Fake tools -------------------------------------------------------------

# Exits 7. Three stdout lines (last without newline), three stderr lines.
cat > "$TEST_TMPDIR/bin/faketool" <<'EOF'
#!/bin/sh
printf 'out line one\n'
printf 'out line two\n'
printf 'out line three no newline'
printf 'err line one\n' >&2
printf 'err line two\n' >&2
printf 'Bun v1.2.3 (macOS arm64)' >&2
exit 7
EOF
chmod +x "$TEST_TMPDIR/bin/faketool"

# Exits 130 (Ctrl+C)
cat > "$TEST_TMPDIR/bin/sigtool" <<'EOF'
#!/bin/sh
printf 'partial\n'
exit 130
EOF
chmod +x "$TEST_TMPDIR/bin/sigtool"

# Exits 0 with two lines
cat > "$TEST_TMPDIR/bin/oktool" <<'EOF'
#!/bin/sh
printf 'first\nsecond\n'
exit 0
EOF
chmod +x "$TEST_TMPDIR/bin/oktool"

# A command that leaves a marker file; used as the query for the unknown-tool test
cat > "$TEST_TMPDIR/bin/lacy_test_marker_cmd" <<EOF
#!/bin/sh
: > "$TEST_TMPDIR/marker_was_executed"
EOF
chmod +x "$TEST_TMPDIR/bin/lacy_test_marker_cmd"

OUT="$TEST_TMPDIR/out"

# --- (c) exit code 7 propagates; lines kept apart; no-newline tail kept -----
echo "Generic path: failing tool"
LACY_ACTIVE_TOOL="custom"
LACY_CUSTOM_TOOL_CMD="faketool --flag"
lacy_shell_query_agent "hello there" > "$OUT" 2>&1
rc=$?
output=$(plain < "$OUT")
assert_eq "faketool: exit code 7 propagates" "7" "$rc"
assert_contains "faketool: stdout line one printed" "$output" "out line one"$'\n'
assert_contains "faketool: stdout line two printed on its own line" "$output" $'\n'"out line two"$'\n'
assert_not_contains "faketool: lines one and two not glued" "$output" "out line oneout line two"
line_two_count=$(printf '%s\n' "$output" | grep -c '^out line two$')
assert_eq "faketool: line two printed once" "1" "$line_two_count"
assert_contains "faketool: final line without newline preserved" "$output" "out line three no newline"
assert_contains "faketool: framed exit message" "$output" "custom exited with code 7"
assert_contains "faketool: stderr tail shown in frame" "$output" "err line two"
assert_contains "faketool: stderr final no-newline line kept" "$output" "Bun v1.2.3 (macOS arm64)"
assert_contains "faketool: recovery hint" "$output" "lacy doctor"

# --- (d) exit 130 prints nothing extra --------------------------------------
echo "Generic path: signal exit"
LACY_CUSTOM_TOOL_CMD="sigtool"
lacy_shell_query_agent "hello" > "$OUT" 2>&1
rc=$?
output=$(plain < "$OUT")
assert_eq "sigtool: exit code 130 propagates" "130" "$rc"
assert_not_contains "sigtool: no exit frame" "$output" "exited with code"
assert_not_contains "sigtool: no recovery hints" "$output" "lacy doctor"

# --- success path still prints all lines -------------------------------------
echo "Generic path: success"
LACY_CUSTOM_TOOL_CMD="oktool"
lacy_shell_query_agent "hello" > "$OUT" 2>&1
rc=$?
output=$(plain < "$OUT")
assert_eq "oktool: exit code 0" "0" "$rc"
assert_contains "oktool: first line" "$output" "first"$'\n'"second"
assert_not_contains "oktool: no exit frame" "$output" "exited with code"

# --- (e) unknown tool never runs the query ----------------------------------
echo "Tool validation"
LACY_ACTIVE_TOOL="nosuchtool"
LACY_CUSTOM_TOOL_CMD=""
lacy_shell_query_agent "lacy_test_marker_cmd" > "$OUT" 2>&1
rc=$?
output=$(plain < "$OUT")
assert_eq "unknown tool: returns 1" "1" "$rc"
assert_contains "unknown tool: names the tool" "$output" "Unknown tool 'nosuchtool'"
assert_contains "unknown tool: lists known tools" "$output" "lash, claude"
if [[ -e "$TEST_TMPDIR/marker_was_executed" ]]; then
    echo "  FAIL: unknown tool: query was executed as a command"
    FAIL=$(( FAIL + 1 ))
else
    PASS=$(( PASS + 1 ))
fi

# --- known tool that is not installed ---------------------------------------
LACY_ACTIVE_TOOL="goose"
PATH="$TEST_TMPDIR/bin:/usr/bin:/bin" lacy_shell_query_agent "lacy_test_marker_cmd" > "$OUT" 2>&1
rc=$?
output=$(plain < "$OUT")
if command -v goose >/dev/null 2>&1; then
    echo "  SKIP: goose is installed here; not-installed message not checked"
else
    assert_eq "missing tool: returns 1" "1" "$rc"
    assert_contains "missing tool: message" "$output" "goose is set as your tool but is not installed."
    assert_contains "missing tool: install hint" "$output" "brew install goose"
fi

# --- _lacy_run_tool_cmd refuses an empty command -----------------------------
_lacy_run_tool_cmd "" "lacy_test_marker_cmd" >/dev/null 2>&1
assert_eq "run_tool_cmd: empty command refused" "127" "$?"
_lacy_run_tool_cmd "   " "lacy_test_marker_cmd" >/dev/null 2>&1
assert_eq "run_tool_cmd: blank command refused" "127" "$?"
if [[ -e "$TEST_TMPDIR/marker_was_executed" ]]; then
    echo "  FAIL: run_tool_cmd: empty command ran the query"
    FAIL=$(( FAIL + 1 ))
else
    PASS=$(( PASS + 1 ))
fi

echo "================================================================"
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    echo "SOME TESTS FAILED"
    exit 1
fi
echo "ALL TESTS PASSED"
