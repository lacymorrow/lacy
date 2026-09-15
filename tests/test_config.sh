#!/usr/bin/env bash

# Tests for lib/core/config.sh: the YAML subset parser, stale variable
# clearing, modes.default, a directory in place of config.yaml, the default
# template, and `tool set` persistence (comments kept, symlinks kept).
# Runs in both Bash 4+ and ZSH.
#
# Usage:
#   bash tests/test_config.sh
#   zsh  tests/test_config.sh

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

echo "Testing config in: ${LACY_SHELL_TYPE} (${ZSH_VERSION:-}${BASH_VERSION:-})"
echo "================================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/lacy-test-config.XXXXXX")
export HOME="$TEST_TMPDIR/fakehome"
export LACY_SHELL_HOME="$TEST_TMPDIR/home"
export LACY_SHELL_CONFIG_FILE="$LACY_SHELL_HOME/config.yaml"
export LACY_SHELL_MODE_FILE="$LACY_SHELL_HOME/current_mode"
mkdir -p "$HOME" "$LACY_SHELL_HOME" "$TEST_TMPDIR/work"
cd "$TEST_TMPDIR/work" || exit 1

cleanup() { cd / && command rm -rf "$TEST_TMPDIR"; }
trap cleanup EXIT

source "$REPO_DIR/lib/core/constants.sh"
source "$REPO_DIR/lib/core/config.sh"
source "$REPO_DIR/lib/core/modes.sh"
source "$REPO_DIR/lib/core/mcp.sh"
source "$REPO_DIR/lib/core/commands.sh"

# tool set stops a preheat server; there is none here
lacy_preheat_cleanup() { :; }

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

OUT="$TEST_TMPDIR/out"
CFG="$LACY_SHELL_CONFIG_FILE"

# Load the config, keep output in $OUT and the return code in $rc
load() {
    lacy_shell_load_config > "$OUT" 2>&1
    rc=$?
}

# ============================================================================
echo "YAML subset parsing"
# ============================================================================

cat > "$CFG" <<'EOF'
# top comment
agent_tools:
  # active: gemini
  active: claude   # trailing comment
  custom_command: "my-cmd --tag #notacomment"
api_keys:
  openai: sk-abc#def
EOF
load
assert_eq "comments: rc" "0" "$rc"
assert_eq "comments: trailing comment dropped" "claude" "$LACY_ACTIVE_TOOL"
assert_eq "comments: # inside quotes kept" "my-cmd --tag #notacomment" "$LACY_CUSTOM_TOOL_CMD"
assert_eq "comments: api_keys no longer read" "" "${LACY_SHELL_API_OPENAI:-}"

cat > "$CFG" <<'EOF'
agent_tools:
  active: "custom"
  custom_command: "claude --system-prompt 'don''t panic' -p"
EOF
load
assert_eq "quotes: outer pair stripped" "custom" "$LACY_ACTIVE_TOOL"
assert_eq "quotes: inner quotes kept" "claude --system-prompt 'don''t panic' -p" "$LACY_CUSTOM_TOOL_CMD"

printf 'agent_tools:\n\tactive:\tcodex\n' > "$CFG"
load
assert_eq "tabs: tab indentation and separator" "codex" "$LACY_ACTIVE_TOOL"

printf 'agent_tools:\r\n  active: opencode\r\npreheat:\r\n  server_port: 5000\r\n' > "$CFG"
load
assert_eq "crlf: value has no carriage return" "opencode" "$LACY_ACTIVE_TOOL"
assert_eq "crlf: port" "5000" "$LACY_PREHEAT_SERVER_PORT"

cat > "$CFG" <<'EOF'
agent_tools:
  active: lash
  extra:
    active: gemini
    deeper:
      custom_command: nope
EOF
load
assert_eq "nested: deeper active ignored" "lash" "$LACY_ACTIVE_TOOL"
assert_eq "nested: deeper custom_command ignored" "" "$LACY_CUSTOM_TOOL_CMD"

cat > "$CFG" <<'EOF'
agent_tools:
  active:
  custom_command: ""
preheat:
  server_port: ''
  eager: null
EOF
load
assert_eq "empty: active" "" "$LACY_ACTIVE_TOOL"
assert_eq "empty: quoted empty custom_command" "" "$LACY_CUSTOM_TOOL_CMD"
assert_eq "empty: port falls back to default" "4096" "$LACY_PREHEAT_SERVER_PORT"
assert_eq "empty: null eager is false" "false" "$LACY_PREHEAT_EAGER"

cat > "$CFG" <<'EOF'
agent_tools:
  active: claude
  active: gemini
EOF
load
assert_eq "dupes: last value wins" "gemini" "$LACY_ACTIVE_TOOL"

cat > "$CFG" <<'EOF'
agent_tools:
  active: custom
  custom_command: "sh -c 'echo $(touch pwned1) `touch pwned2` $HOME; touch pwned3' --"
EOF
expected_meta=$(cat <<'EOF'
sh -c 'echo $(touch pwned1) `touch pwned2` $HOME; touch pwned3' --
EOF
)
load
assert_eq "metachars: value kept verbatim" "$expected_meta" "$LACY_CUSTOM_TOOL_CMD"
if [[ -e pwned1 || -e pwned2 || -e pwned3 ]]; then
    echo "  FAIL: metachars: something in the value was executed"
    FAIL=$(( FAIL + 1 ))
else
    PASS=$(( PASS + 1 ))
fi

cat > "$CFG" <<'EOF'
agent_tools_extra:
  active: WRONG
agent_tools:
  active: lash
modes_x:
  default: agent
modes:
  default: shell
EOF
load
assert_eq "prefix sections: exact section names only" "lash" "$LACY_ACTIVE_TOOL"
assert_eq "prefix sections: modes.default" "shell" "$LACY_CONFIG_DEFAULT_MODE"

cat > "$CFG" <<'EOF'
agent_tools:
  active: custom
  custom_command: claude --prompt "it's broken" --sep 'a\b' -p
EOF
load
assert_eq "backslash and apostrophe survive" "claude --prompt \"it's broken\" --sep 'a\\b' -p" "$LACY_CUSTOM_TOOL_CMD"

cat > "$CFG" <<'EOF'
agent_tools: claude
  active: gemini
logging:
  queries: 'null'
spinner:
  style: ascii
EOF
load
assert_eq "inline scalar is not a section" "" "$LACY_ACTIVE_TOOL"
assert_eq "quoted 'null' is a string, not a boolean true" "false" "$LACY_LOG_QUERIES"
assert_eq "spinner.style read" "ascii" "$LACY_SPINNER_STYLE"

cat > "$CFG" <<'EOF'
preheat:
  eager: yes
  server_port: 80a
logging:
  queries: True
EOF
load
assert_eq "bool: yes is true" "true" "$LACY_PREHEAT_EAGER"
assert_eq "bool: True is true" "true" "$LACY_LOG_QUERIES"
assert_eq "non-numeric port falls back" "4096" "$LACY_PREHEAT_SERVER_PORT"

# ============================================================================
echo "Stale variables are cleared before parsing"
# ============================================================================

export LACY_ACTIVE_TOOL="claude"
export LACY_CUSTOM_TOOL_CMD="leftover --cmd"
export LACY_LOG_QUERIES="true"
export LACY_PREHEAT_SERVER_PORT="9999"
cat > "$CFG" <<'EOF'
agent_tools:
  active:
EOF
load
assert_eq "stale: active cleared" "" "$LACY_ACTIVE_TOOL"
assert_eq "stale: custom command cleared" "" "$LACY_CUSTOM_TOOL_CMD"
assert_eq "stale: logging back to default" "false" "$LACY_LOG_QUERIES"
assert_eq "stale: port back to default" "4096" "$LACY_PREHEAT_SERVER_PORT"
assert_eq "stale: child processes see the cleared value" "" "$(sh -c 'printf %s "$LACY_ACTIVE_TOOL"')"

# ============================================================================
echo "modes.default and startup mode"
# ============================================================================

command rm -f "$LACY_SHELL_MODE_FILE"
printf 'modes:\n  default: shell\n' > "$CFG"
load
lacy_shell_init_mode
assert_eq "modes.default used when no current_mode file" "shell" "$LACY_SHELL_CURRENT_MODE"

echo "agent" > "$LACY_SHELL_MODE_FILE"
lacy_shell_init_mode
assert_eq "current_mode file wins over modes.default" "agent" "$LACY_SHELL_CURRENT_MODE"

echo "bogus" > "$LACY_SHELL_MODE_FILE"
lacy_shell_init_mode
assert_eq "invalid current_mode file falls back to modes.default" "shell" "$LACY_SHELL_CURRENT_MODE"

command rm -f "$LACY_SHELL_MODE_FILE"
printf 'agent_tools:\n  active:\n' > "$CFG"
load
lacy_shell_init_mode
assert_eq "no modes.default means auto" "auto" "$LACY_SHELL_CURRENT_MODE"

printf 'modes:\n  default: "agent"  # quoted\n' > "$CFG"
load
lacy_shell_init_mode
assert_eq "quoted modes.default" "agent" "$LACY_SHELL_CURRENT_MODE"

printf 'modes:\n  default: banana\n' > "$CFG"
load
lacy_shell_init_mode
assert_eq "invalid modes.default means auto" "auto" "$LACY_SHELL_CURRENT_MODE"
assert_contains "invalid modes.default is reported" "$(cat "$OUT")" "modes.default 'banana'"

# ============================================================================
echo "Default template and missing config"
# ============================================================================

command rm -f "$CFG"
load
assert_eq "missing: rc" "0" "$rc"
assert_contains "missing: creation reported" "$(cat "$OUT")" "Created default configuration"
expected_template=$(cat <<'EOF'
# Lacy Shell configuration
agent_tools:
  # lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, custom
  # Leave empty to auto-detect.
  active:
  # custom_command: "your-command --flags"

modes:
  default: auto  # shell, agent, or auto

# preheat:
#   eager: false
#   server_port: 4096

# logging:
#   queries: false  # true writes ~/.lacy/logs/queries.log (owner-only)
EOF
)
assert_eq "template: exact canonical text" "$expected_template" "$(cat "$CFG")"
printf '%s\n' "$expected_template" > "$TEST_TMPDIR/expected_template"
if cmp -s "$TEST_TMPDIR/expected_template" "$CFG"; then
    PASS=$(( PASS + 1 ))
else
    echo "  FAIL: template: byte-identical, one trailing newline"
    FAIL=$(( FAIL + 1 ))
fi
assert_eq "template: modes.default auto" "auto" "$LACY_CONFIG_DEFAULT_MODE"
assert_eq "template: auto-detect tool" "" "$LACY_ACTIVE_TOOL"

# ============================================================================
echo "Directory in place of config.yaml"
# ============================================================================

command rm -f "$CFG"
mkdir -p "$CFG"
load
assert_eq "directory: rc 1" "1" "$rc"
assert_contains "directory: clear error" "$(cat "$OUT")" "is a directory"
assert_not_contains "directory: does not claim creation" "$(cat "$OUT")" "Created default configuration"
assert_eq "directory: defaults kept" "" "$LACY_ACTIVE_TOOL"
lacy_config_set agent_tools active claude > "$OUT" 2>&1
assert_eq "directory: config set refuses" "1" "$?"
assert_contains "directory: config set reason" "$_LACY_CONFIG_SET_ERROR" "is a directory"
command rm -rf "$CFG"

# ============================================================================
echo "tool set persists to config.yaml"
# ============================================================================

cat > "$CFG" <<'EOF'
# my notes
agent_tools:
  # pick one
  active: claude   # trailing comment
  # custom_command: "x"

modes:
  default: shell  # shell, agent, or auto

other:
  keep: me
EOF
lacy_shell_tool set gemini > "$OUT" 2>&1
rc=$?
assert_eq "set gemini: rc" "0" "$rc"
assert_contains "set gemini: message" "$(cat "$OUT")" "Tool set to: gemini"
assert_contains "set gemini: saved" "$(cat "$OUT")" "Saved to"
expected_file=$(cat <<'EOF'
# my notes
agent_tools:
  # pick one
  active: gemini   # trailing comment
  # custom_command: "x"

modes:
  default: shell  # shell, agent, or auto

other:
  keep: me
EOF
)
assert_eq "set gemini: only the value changed" "$expected_file" "$(cat "$CFG")"
load
assert_eq "set gemini: reload reads it" "gemini" "$LACY_ACTIVE_TOOL"
assert_eq "set gemini: other keys intact" "shell" "$LACY_CONFIG_DEFAULT_MODE"

custom_value=$(cat <<'EOF'
argdump --flag 'two words' "q\"x" --tag #hash
EOF
)
lacy_shell_tool set custom "$custom_value" > "$OUT" 2>&1
assert_eq "set custom: rc" "0" "$?"
load
assert_eq "set custom: active" "custom" "$LACY_ACTIVE_TOOL"
assert_eq "set custom: command round-trips exactly" "$custom_value" "$LACY_CUSTOM_TOOL_CMD"
assert_contains "set custom: comments kept" "$(cat "$CFG")" "# my notes"
assert_contains "set custom: commented example kept" "$(cat "$CFG")" '# custom_command: "x"'
assert_contains "set custom: unrelated section kept" "$(cat "$CFG")" "  keep: me"

custom_value2="tool --tag '#x' --y"
lacy_shell_tool set custom "$custom_value2" > "$OUT" 2>&1
load
assert_eq "set custom: quoted hash round-trips" "$custom_value2" "$LACY_CUSTOM_TOOL_CMD"

lacy_shell_tool set auto > "$OUT" 2>&1
assert_eq "set auto: rc" "0" "$?"
load
assert_eq "set auto: active empty after reload" "" "$LACY_ACTIVE_TOOL"
assert_contains "set auto: key left empty" "$(cat "$CFG")" "  active:   # trailing comment"

before=$(cat "$CFG")
lacy_shell_tool set nosuchtool > "$OUT" 2>&1
assert_eq "set unknown: rc 1" "1" "$?"
assert_contains "set unknown: message" "$(cat "$OUT")" "Unknown tool: nosuchtool"
assert_eq "set unknown: file untouched" "$before" "$(cat "$CFG")"

lacy_shell_tool set custom "argdump 'unbalanced" > "$OUT" 2>&1
assert_eq "set custom unbalanced: rc 1" "1" "$?"
assert_eq "set custom unbalanced: file untouched" "$before" "$(cat "$CFG")"

# Symlinked config stays a symlink
command rm -f "$CFG"
printf 'agent_tools:\n  active: lash\n' > "$TEST_TMPDIR/real.yaml"
ln -s "$TEST_TMPDIR/real.yaml" "$CFG"
lacy_shell_tool set claude > "$OUT" 2>&1
assert_eq "symlink: rc" "0" "$?"
if [[ -L "$CFG" ]]; then PASS=$(( PASS + 1 )); else echo "  FAIL: symlink: config.yaml is still a symlink"; FAIL=$(( FAIL + 1 )); fi
assert_contains "symlink: target updated" "$(cat "$TEST_TMPDIR/real.yaml")" "  active: claude"
command rm -f "$CFG"

# Key missing from its section: inserted under the header
printf 'agent_tools:\n    custom_command: x\nmodes:\n  default: agent\n' > "$CFG"
lacy_shell_tool set lash > "$OUT" 2>&1
load
assert_eq "insert key: reload" "lash" "$LACY_ACTIVE_TOOL"
assert_eq "insert key: sibling kept" "x" "$LACY_CUSTOM_TOOL_CMD"
assert_contains "insert key: uses the section's indentation" "$(cat "$CFG")" $'agent_tools:\n    active: lash'
assert_eq "insert key: other section kept" "agent" "$LACY_CONFIG_DEFAULT_MODE"

# Section missing: appended
printf 'modes:\n  default: shell\n' > "$CFG"
lacy_shell_tool set codex > "$OUT" 2>&1
load
assert_eq "append section: reload" "codex" "$LACY_ACTIVE_TOOL"
assert_eq "append section: modes kept" "shell" "$LACY_CONFIG_DEFAULT_MODE"

# Missing config: tool set creates the default one, then sets the value
command rm -f "$CFG"
lacy_shell_tool set amp > "$OUT" 2>&1
load
assert_eq "no config: created and set" "amp" "$LACY_ACTIVE_TOOL"
assert_contains "no config: template kept" "$(cat "$CFG")" "# Leave empty to auto-detect."

echo "================================================================"
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    echo "SOME TESTS FAILED"
    exit 1
fi
echo "ALL TESTS PASSED"
