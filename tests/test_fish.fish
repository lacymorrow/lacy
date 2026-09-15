#!/usr/bin/env fish

# Fish adapter tests: classification parity with lib/core/detection.sh for
# the probe inputs in tests/test_core.sh, config and mode persistence,
# NO_COLOR badge, key binding and prompt wrappers, and (with python3) an
# interactive fish in a pty for Enter routing, history, $status, exit/quit.
#
# Usage: fish tests/test_fish.fish   (LACY_TEST_KEEP=1 keeps the temp files)

set -g REPO_DIR (dirname (dirname (realpath (status filename))))
set -g TMP_ROOT (mktemp -d "$TMPDIR/lacy-fish-test.XXXXXX" 2>/dev/null; or mktemp -d)
set -gx LACY_SHELL_HOME "$TMP_ROOT/unit/.lacy"
mkdir -p $LACY_SHELL_HOME
set -e NO_COLOR

echo "Testing Lacy Shell fish adapter in: fish $version"
echo "================================================================"

set -g PASS 0
set -g FAIL 0
set -g SKIP 0

function pass
    set PASS (math $PASS + 1)
end

function fail --argument-names name detail
    echo "  FAIL: $name"
    test -n "$detail"; and echo "    $detail"
    set FAIL (math $FAIL + 1)
end

function assert_eq --argument-names name expected actual
    if test "$expected" = "$actual"
        pass
    else
        fail $name "expected [$expected] got [$actual]"
    end
end

# assert_true NAME COMMAND ARGS...  (runs the command as given, no eval)
function assert_true --argument-names name
    if $argv[2..-1]
        pass
    else
        fail $name
    end
end

function assert_false --argument-names name
    if $argv[2..-1]
        fail $name
    else
        pass
    end
end

source $REPO_DIR/lib/fish/config.fish
source $REPO_DIR/lib/fish/detection.fish

function probe --argument-names expected input
    set -l got (_lacy_classify_input "$input")
    assert_eq "'$input' -> $expected" $expected "$got"
end

# ============================================================================
# Classification (probe inputs from tests/test_core.sh)
# ============================================================================

echo ""
echo "--- Detection: auto mode ---"
set -g LACY_SHELL_MODE auto

for input in 'ls -la' 'git status' 'cd /home' 'npm install' 'pwd' 'help' \
        'RUST_LOG=debug cargo run' 'FOO=bar node index.js' 'FOO=bar BAZ=qux node index.js' \
        'CC=gcc make -j4' 'FOO=bar' 'asdfgh' '!rm /tmp/test' '  ls -la' \
        'function of this module'
    probe shell $input
end

for input in 'what files' 'fix the bug' 'hello there' 'perfect' 'yes' 'sure' 'thanks' \
        'ok' 'great' 'cool' 'nice' 'awesome' 'lgtm' 'stop' 'why' 'how' 'no' 'nope' \
        'gotcha' 'roger' 'understood' 'kudos' 'noice' 'sheesh' 'oof' 'meh' 'duh' 'bummer' \
        'lol' 'omg' 'idk' 'btw' 'tbh' 'fyi' 'debug' 'deploy' 'implement' 'diagnose' \
        'troubleshoot' 'rollback' 'suggest' 'recommend' 'imagine' \
        'why?' 'how?' 'no!' 'yes.' 'sure!' 'do?' \
        'what is this' 'yes lets go' 'no I dont want that' 'perfect lets move on' \
        'thanks for the help' 'FOO=bar nonexistent_cmd thing' '  what files' \
        'do We already have a way to uninstall?' 'done with this task' \
        'then what happens next' 'else something' 'in the codebase' 'select all users' \
        'what' 'do we have tests' 'in the codebase where is auth'
    probe agent $input
end

echo ""
echo "--- Detection: shell syntax first tokens ---"
for input in './nonexistent.sh --flag' '~/bin/nonexistent arg' '/usr/bin/nonexistent arg' \
        '\ls -la' '< file cat' '<<< "here" cat' '> out ls' '2>/dev/null ls' '&>log ls' \
        '(cd /tmp && ls)' '[[ -f x ]] && echo yes' '{ ls; } > out' 'function foo() { :; }' \
        'FOO="a b" ls' 'x=$(ls) && echo hi' 'FOO=1 && ls' '! true' '"unterminated' '# note'
    probe shell $input
end
probe shell 'ls'\n'echo hi'
probe agent 'what is this'\n'ls'
probe shell 'ls'\t'-la'

echo ""
echo "--- Detection: agent words that are also commands ---"
for input in 'which python' 'which -a git' 'yes | head' 'yes | apt-get install -y' \
        'nice -n 10 make' 'who root' '"/usr/local/bin/my tool"' \
        '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --flag' \
        "'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --flag"
    probe shell $input
end
for input in 'which version should I install' 'nice work' 'who' 'who am I' \
        '@ make sure the tests pass' '@fix the bug in auth'
    probe agent $input
end

echo ""
echo "--- Detection: user functions and aliases ---"
alias stop 'kill -STOP'
alias lint 'npm run lint'
alias cancel 'echo cancel'
function render; end
function deploy; end
for input in stop lint cancel render deploy
    probe shell $input
end
probe agent 'stop it please'
functions -e stop lint cancel render deploy
probe agent stop
probe agent deploy
# Not portable to fish, so not probed here: `continue` cannot be a function
# name (it is a fish keyword), and `coproc` is bash syntax fish cannot run.

echo ""
echo "--- Detection: locked modes ---"
set -g LACY_SHELL_MODE shell
probe shell 'what files'
probe shell ''
set -g LACY_SHELL_MODE agent
probe agent 'ls -la'
probe agent ''
set -g LACY_SHELL_MODE auto
probe neutral ''

echo ""
echo "--- Generated word lists ---"
function core_value --argument-names expr
    bash -c 'source "$1/lib/core/constants.sh"; eval "echo $2"' _ $REPO_DIR $expr
end
assert_eq "agent word count matches core" (core_value '${#LACY_AGENT_WORDS[@]}') (count $LACY_AGENT_WORDS)
assert_eq "reserved word count matches core" (core_value '${#LACY_SHELL_RESERVED_WORDS[@]}') (count $LACY_SHELL_RESERVED_WORDS)
assert_eq "NL marker count matches core" (core_value '${#LACY_NL_MARKERS[@]}') (count $LACY_NL_MARKERS)
assert_eq "tool list matches core" (core_value '"${LACY_TOOL_LIST[*]}"') "$LACY_TOOL_LIST"

# ============================================================================
# Config and mode persistence
# ============================================================================

echo ""
echo "--- Config and startup mode ---"
set -l cfg "$LACY_SHELL_HOME/config.yaml"
set -l mode_file "$LACY_SHELL_HOME/current_mode"

command rm -f $cfg $mode_file
_lacy_init_mode
assert_eq "no file, no config -> auto" auto $LACY_SHELL_MODE

printf '%s\n' 'spinner:' '  default: agent' 'modes:' '  default: shell' > $cfg
_lacy_init_mode
assert_eq "modes.default read from its own section" shell $LACY_SHELL_MODE

printf 'agent\n' > $mode_file
_lacy_init_mode
assert_eq "current_mode file wins over modes.default" agent $LACY_SHELL_MODE

printf 'bogus\n' > $mode_file
_lacy_init_mode
assert_eq "invalid current_mode falls back to modes.default" shell $LACY_SHELL_MODE

_lacy_set_mode auto
read -l saved < $mode_file
assert_eq "_lacy_set_mode persists to current_mode" auto "$saved"
_lacy_set_mode junk 2>/dev/null
assert_eq "_lacy_set_mode rejects junk" 1 $status

printf '%s\n' 'agent_tools:' '  active: claude # note' '  custom_command: "echo hi # kept"' > $cfg
_lacy_load_config
assert_eq "unquoted value drops trailing comment" claude "$LACY_ACTIVE_TOOL"
assert_eq "quoted value keeps #" "echo hi # kept" "$LACY_CUSTOM_TOOL_CMD"

# ============================================================================
# Prompt badge, NO_COLOR, wrappers
# ============================================================================

source $REPO_DIR/lib/fish/execute.fish

echo ""
echo "--- Badge and NO_COLOR ---"
function fish_right_prompt
    printf THEME
end
source $REPO_DIR/lib/fish/prompt.fish

set -gx NO_COLOR 1
set -g LACY_SHELL_MODE shell
assert_eq "NO_COLOR shell badge" 'THEME$ SHELL' (fish_right_prompt)
set -g LACY_SHELL_MODE agent
assert_eq "NO_COLOR agent badge" 'THEME? AGENT' (fish_right_prompt)
assert_eq "NO_COLOR mode line" '  ? AGENT mode' (_lacy_print_mode_line)
set -e NO_COLOR
set -l colored (_lacy_mode_badge)
assert_true "colour badge has an escape" string match -q -- "*"\e"[38;5;200m*" "$colored"
_lacy_restore_right_prompt
assert_eq "right prompt restored" THEME (fish_right_prompt)

echo ""
echo "--- fish_user_key_bindings wrapper ---"
function fish_user_key_bindings
    echo USER_BINDINGS_RAN
end
source $REPO_DIR/lib/fish/keybindings.fish
set -l body (functions fish_user_key_bindings | string join ' ')
assert_false "wrapper does not eval" string match -q -- "*eval*" "$body"
assert_eq "user bindings still run" USER_BINDINGS_RAN (fish_user_key_bindings 2>&1 | string join ,)
source $REPO_DIR/lib/fish/keybindings.fish
assert_eq "second source does not wrap the wrapper" USER_BINDINGS_RAN (fish_user_key_bindings 2>&1 | string join ,)
set -l enter_binding
if test $_LACY_FISH_MAJOR -ge 4
    set enter_binding (bind -M insert enter 2>/dev/null)
else
    set enter_binding (bind -M insert \r 2>/dev/null)
end
assert_true "Enter bound in vi insert mode" string match -q -- "*_lacy_accept_line*" "$enter_binding"
_lacy_remove_bindings >/dev/null
assert_eq "remove restores user function" USER_BINDINGS_RAN (fish_user_key_bindings 2>&1 | string join ,)
assert_false "copy removed" functions -q _lacy_user_key_bindings

# ============================================================================
# Interactive fish in a pty
# ============================================================================

echo ""
echo "--- Interactive (pty) ---"

if not command -q python3
    echo "  SKIP: python3 not found"
    set SKIP (math $SKIP + 1)
else
    set -l sbx "$TMP_ROOT/pty"
    mkdir -p $sbx/.lacy $sbx/bin $sbx/.config/fish/conf.d $sbx/.local/share $sbx/.cache
    printf '%s\n' '#!/bin/sh' \
        'case "$*" in *slowly*) sleep 8 ;; esac' \
        'printf "FAKE_AGENT:%s\n" "$*"' \
        'case "$*" in *fail*) exit 7 ;; esac' > $sbx/bin/fakeagent
    chmod +x $sbx/bin/fakeagent
    printf '%s\n' 'agent_tools:' '  active: custom' "  custom_command: $sbx/bin/fakeagent" > $sbx/.lacy/config.yaml
    printf '%s\n' "source $REPO_DIR/lacy.plugin.fish" > $sbx/.config/fish/conf.d/lacy.fish
    printf '%s\n' 'function fish_greeting; end' 'function fish_prompt; printf "F1> "; end' > $sbx/.config/fish/config.fish

    echo '
import os, pty, re, select, signal, sys, time
keys_file, out_file = sys.argv[1], sys.argv[2]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[3], sys.argv[3:])
buf = bytearray()
def drain(seconds, until=None):
    end = time.time() + seconds
    while time.time() < end:
        if until is not None and until in buf:
            return
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                return
            if not data:
                return
            buf.extend(data)
            # Answer the Primary Device Attributes query fish 4 sends at startup
            if b"\x1b[c" in data:
                os.write(fd, b"\x1b[?62;22c")
drain(15, until=b"F1> ")
for line in open(keys_file).read().splitlines():
    if line.startswith("#wait "):
        drain(float(line[6:]))
    elif line.startswith("#until "):
        drain(20, until=line[7:].encode())
    elif line.startswith("#raw "):
        os.write(fd, line[5:].encode().decode("unicode_escape").encode("latin-1"))
        drain(0.3)
    else:
        try:
            os.write(fd, line.encode() + b"\r")
        except OSError:
            break
        drain(0.4)
try:
    os.write(fd, b"echo __PTY_DONE__\r")
except OSError:
    pass
drain(20, until=b"\n__PTY_DONE__")
exited = os.waitpid(pid, os.WNOHANG)[0] == pid
if not exited:
    os.kill(pid, signal.SIGKILL)
    os.waitpid(pid, 0)
text = buf.decode("utf-8", "replace").replace("\r", "")
text = re.sub(r"\x1b\[[0-9;?<>=]*[ -/]*[@-~]", "", text)
text = re.sub(r"\x1b\][^\x07\x1b]*(\x07|\x1b\x5c)", "", text)
text = re.sub(r"\x1b[=>]", "", text)
if exited:
    text += "\n__CHILD_EXITED__\n"
open(out_file, "w").write(text)
' > $TMP_ROOT/pty_driver.py

    set -g FISH_BIN (status fish-path 2>/dev/null; or command -s fish)
    set -g SBX $sbx

    function run_fish_session --argument-names name
        printf '%s\n' $argv[2..-1] > $TMP_ROOT/$name.keys
        env HOME=$SBX XDG_CONFIG_HOME=$SBX/.config XDG_DATA_HOME=$SBX/.local/share \
            XDG_CACHE_HOME=$SBX/.cache LACY_SHELL_HOME=$SBX/.lacy TERM=xterm \
            DO_NOT_TRACK=1 LACY_NO_TELEMETRY=1 \
            python3 $TMP_ROOT/pty_driver.py $TMP_ROOT/$name.keys $TMP_ROOT/$name.out $FISH_BIN -i
    end

    function has_line --argument-names file text
        grep -qxF -- $text $file
    end
    function has_text --argument-names file text
        grep -qF -- $text $file
    end
    function has_both --argument-names file a b
        grep -F -- $a $file | grep -qF -- $b
    end

    # Session A: routing, history, status, Ctrl+C, quit
    command rm -f $sbx/.lacy/current_mode
    run_fish_session a \
        'what is this' \
        'please fail now' \
        'echo STATUS=$status' \
        'echo HIST_Q=(history search --exact "please fail now" | count)' \
        'echo HIST_ASK=(history search --prefix " ask" | count)(history search --prefix "ask " | count)' \
        'for i in 1 2' 'echo fiter$i' 'end' \
        'which ls >/dev/null; and echo WHICH_RAN' \
        'echo __READY(math 1 + 1)__' '#until __READY2__' \
        'tell me slowly' '#wait 2' '#raw \x03' '#wait 0.5' \
        'echo AFTER_INT' \
        'mode agent' 'echo __FISH_AGENT_PROBE__' \
        'quit' \
        'bind -M default enter | string match -q "*_lacy*"; and echo ENTER_LACY; or echo ENTER_RESTORED' \
        'echo MODE_FILE=(cat $LACY_SHELL_HOME/current_mode)'
    set -l out $TMP_ROOT/a.out
    assert_true "agent query reaches agent" has_both $out FAKE_AGENT: "what is this"
    assert_true "\$status is the agent's exit code" has_line $out STATUS=7
    assert_true "typed query saved to history" has_line $out HIST_Q=1
    assert_true "ask rewrite not saved to history" has_line $out HIST_ASK=00
    assert_true "multi-line for loop runs" has_line $out fiter2
    assert_true "which ls runs in shell" has_line $out WHICH_RAN
    assert_true "Ctrl+C aborts a running query" has_line $out AFTER_INT
    assert_false "aborted query printed no answer" has_both $out FAKE_AGENT: slowly
    assert_true "agent mode routes to agent" has_both $out FAKE_AGENT: __FISH_AGENT_PROBE__
    assert_false "agent mode: quit not sent to agent" has_both $out FAKE_AGENT: quit
    assert_true "quit leaves lacy" has_text $out "Exiting Lacy Shell"
    assert_true "quit restores Enter" has_line $out ENTER_RESTORED
    assert_true "mode persisted" has_line $out MODE_FILE=agent

    # Session B: startup mode from current_mode, exit leaves the shell
    run_fish_session b \
        'echo __FISH_B_PROBE__' '#wait 0.5' 'exit' 'echo SHOULD_NOT_RUN'
    set -l out $TMP_ROOT/b.out
    assert_true "startup mode read from current_mode (agent)" has_both $out FAKE_AGENT: __FISH_B_PROBE__
    assert_false "agent mode: exit not sent to agent" has_both $out FAKE_AGENT: exit
    assert_true "agent mode: exit ends the shell" has_line $out __CHILD_EXITED__
    assert_false "nothing runs after exit" has_line $out SHOULD_NOT_RUN
end

# ============================================================================
# Query log gate and no-tool message
# ============================================================================
echo "--- query log off by default, no-tool message lists every tool ---"
source $REPO_DIR/lib/fish/execute.fish
begin
    set -l fakebin $TMP_ROOT/logbin
    mkdir -p $fakebin
    printf '#!/bin/sh\necho FAKE_CLAUDE_OK\n' > $fakebin/claude
    chmod +x $fakebin/claude
    set -l old_path $PATH
    set -gx PATH $fakebin $PATH
    set -l log $LACY_SHELL_HOME/logs/queries.log
    command rm -f $log

    printf 'agent_tools:\n  active: claude\n' > $LACY_SHELL_HOME/config.yaml
    _lacy_query_agent "log gate probe" >/dev/null 2>&1
    assert_false "query log: not written by default" test -e $log

    printf 'agent_tools:\n  active: claude\nlogging:\n  queries: true\n' > $LACY_SHELL_HOME/config.yaml
    _lacy_query_agent "log gate probe on" >/dev/null 2>&1
    assert_true "query log: written when logging.queries is true" test -s $log

    set -gx PATH $old_path
    command rm -f $log $LACY_SHELL_HOME/config.yaml
end
set -l no_tool_out (NO_COLOR=1 _lacy_print_no_tool | string collect)
for t in $LACY_TOOL_LIST
    assert_true "no-tool message lists $t" string match -q -- "*$t *" $no_tool_out
end

if set -q LACY_TEST_KEEP
    echo "Keeping test files in $TMP_ROOT"
else
    command rm -rf $TMP_ROOT
end

echo ""
echo "================================================================"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
if test $FAIL -gt 0
    echo FAILED
    exit 1
end
echo "ALL TESTS PASSED"
