#!/usr/bin/env bash

# Bash adapter behaviour tests: PS2 continuation lines, PROMPT_COMMAND
# ordering, vi-mode bindings, keybinding cleanup, exit/quit routing, NO_COLOR.
# Interactive cases drive a real `bash -i` in a pty (needs python3).
#
# Usage:
#   /opt/homebrew/bin/bash tests/test_bash_adapter.bash   # macOS
#   bash tests/test_bash_adapter.bash                     # Linux

if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "SKIP: Bash 4+ required (have ${BASH_VERSION})"
    exit 0
fi

echo "Testing Lacy Shell Bash adapter behaviour in: bash ${BASH_VERSION}"
echo "================================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lacy-bash-adapter.XXXXXX")"
if [[ -n "${LACY_TEST_KEEP:-}" ]]; then
    echo "Keeping test files in $TMP_ROOT"
else
    trap 'command rm -rf "$TMP_ROOT"' EXIT
fi

PASS=0
FAIL=0
SKIP=0

pass() { PASS=$(( PASS + 1 )); }
fail() {
    echo "  FAIL: $1"
    [[ -n "${2:-}" ]] && echo "    $2"
    FAIL=$(( FAIL + 1 ))
}

assert_eq() {
    if [[ "$2" == "$3" ]]; then pass; else fail "$1" "expected [$2] got [$3]"; fi
}

assert_true() {
    local name="$1"; shift
    if "$@"; then pass; else fail "$name"; fi
}

assert_false() {
    local name="$1"; shift
    if "$@"; then fail "$name"; else pass; fi
}

# ============================================================================
# Unit tests (non-interactive, sourced modules)
# ============================================================================

(
    export HOME="$TMP_ROOT/unit-home"
    mkdir -p "$HOME"
    export LACY_SHELL_HOME="$HOME/.lacy" DO_NOT_TRACK=1 LACY_NO_TELEMETRY=1
    LACY_SHELL_TYPE="bash"
    _LACY_ARR_OFFSET=0
    LACY_SHELL_DIR="$REPO_DIR"
    source "$REPO_DIR/lib/bash/init.bash"

    echo ""
    echo "--- PS2 gate and exit/quit routing (accept-line handler) ---"

    LACY_SHELL_ENABLED=true
    LACY_SHELL_CURRENT_MODE="auto"
    _lacy_ctx_mark_command() { :; }

    accept() {
        _LACY_BASH_AT_PS1="$1"
        READLINE_LINE="$2"
        READLINE_POINT=${#2}
        LACY_SHELL_PENDING_QUERY=""
        lacy_shell_smart_accept_line_bash
    }

    accept 0 "done"
    assert_eq "PS2 'done' left for readline" "done" "$READLINE_LINE"
    assert_eq "PS2 'done' not queued" "" "$LACY_SHELL_PENDING_QUERY"
    accept 0 "then what happens next"
    assert_eq "PS2 NL-looking line left for readline" "then what happens next" "$READLINE_LINE"
    accept 1 "what is this"
    assert_eq "PS1 agent line cleared" "" "$READLINE_LINE"
    assert_eq "PS1 agent line queued" "what is this" "$LACY_SHELL_PENDING_QUERY"
    assert_eq "flag cleared after first accept" "0" "$_LACY_BASH_AT_PS1"
    accept 1 "for i in 1 2"
    assert_eq "PS1 shell line kept" "for i in 1 2" "$READLINE_LINE"

    LACY_SHELL_CURRENT_MODE="agent"
    accept 1 "exit"
    assert_eq "agent mode: exit goes to shell" "exit" "$READLINE_LINE"
    assert_eq "agent mode: exit not queued" "" "$LACY_SHELL_PENDING_QUERY"
    accept 1 "exit 3"
    assert_eq "agent mode: exit 3 goes to shell" "exit 3" "$READLINE_LINE"
    accept 1 "quit"
    assert_eq "agent mode: quit goes to shell" "quit" "$READLINE_LINE"
    assert_eq "agent mode: quit not queued" "" "$LACY_SHELL_PENDING_QUERY"
    accept 1 "ls -la"
    assert_eq "agent mode: ls queued" "ls -la" "$LACY_SHELL_PENDING_QUERY"
    LACY_SHELL_CURRENT_MODE="auto"
    accept 1 "exit"
    assert_eq "auto mode: exit goes to shell" "exit" "$READLINE_LINE"

    echo ""
    echo "--- Removed commands ---"
    has_func() { declare -F "$1" >/dev/null; }
    assert_false "stop function removed" has_func stop
    assert_false "spinner function removed" has_func spinner
    assert_false "double Ctrl-C handler removed" has_func lacy_shell_interrupt_handler_bash
    assert_true "quit function present" has_func quit

    echo ""
    echo "--- PROMPT_COMMAND hooks ---"

    PROMPT_COMMAND='history -a;'
    _lacy_bash_install_prompt_hooks
    assert_eq "string: capture first, precmd last" \
        "_lacy_bash_capture_exit"$'\n'"history -a;"$'\n'"lacy_shell_precmd_bash" "$PROMPT_COMMAND"
    assert_true "string with trailing ; still parses" "$BASH" -n <<< "$PROMPT_COMMAND"
    _lacy_bash_install_prompt_hooks
    assert_eq "install twice does not duplicate" \
        "_lacy_bash_capture_exit"$'\n'"history -a;"$'\n'"lacy_shell_precmd_bash" "$PROMPT_COMMAND"
    _lacy_bash_remove_prompt_hooks
    assert_eq "remove restores user value" "history -a;" "$PROMPT_COMMAND"

    unset PROMPT_COMMAND
    _pc_out="$(set -u; _lacy_bash_install_prompt_hooks && printf '%s' "$PROMPT_COMMAND")"
    assert_eq "unset PROMPT_COMMAND under set -u" \
        "_lacy_bash_capture_exit"$'\n'"lacy_shell_precmd_bash" "$_pc_out"

    if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
        PROMPT_COMMAND=(user_hook_a user_hook_b)
        _lacy_bash_install_prompt_hooks
        assert_eq "array: element count" "4" "${#PROMPT_COMMAND[@]}"
        assert_eq "array: capture first" "_lacy_bash_capture_exit" "${PROMPT_COMMAND[0]}"
        assert_eq "array: precmd last" "lacy_shell_precmd_bash" "${PROMPT_COMMAND[3]}"
        _lacy_bash_remove_prompt_hooks
        assert_eq "array: remove restores" "user_hook_a user_hook_b" "${PROMPT_COMMAND[*]}"
        unset PROMPT_COMMAND
    fi

    false
    _lacy_bash_capture_exit
    assert_eq "capture hook passes \$? through" "1" "$?"
    assert_eq "capture hook records \$?" "1" "$_lacy_last_exit"

    echo ""
    echo "--- Prompt badge: rebuilt PS1, glyphs, NO_COLOR ---"

    LACY_SHELL_PROMPT_INITIALIZED=false
    PS1='base> '
    LACY_SHELL_CURRENT_MODE="shell"
    unset NO_COLOR
    lacy_shell_update_prompt
    assert_true "colour badge has escape" test "${PS1#*\\e[38;5;34m}" != "$PS1"
    assert_true "shell glyph \$ in badge" test "${PS1#*SHELL \$ }" != "$PS1"
    # A hook rebuilds PS1 before lacy runs: the rebuilt prompt becomes the base
    PS1='rebuilt> '
    lacy_shell_update_prompt
    assert_true "badge applied to rebuilt PS1" test "${PS1%rebuilt> }" != "$PS1"
    assert_true "old base gone" test "${PS1#*base> }" == "$PS1"

    export NO_COLOR=1
    LACY_SHELL_CURRENT_MODE="agent"
    lacy_shell_update_prompt
    assert_eq "NO_COLOR agent badge" "AGENT ? rebuilt> " "$PS1"
    LACY_SHELL_CURRENT_MODE="shell"
    lacy_shell_update_prompt
    assert_eq "NO_COLOR shell badge" "SHELL \$ rebuilt> " "$PS1"
    assert_eq "NO_COLOR mode message" "  ? AGENT mode" "$(_lacy_bash_print_mode_msg agent)"
    unset NO_COLOR
    assert_eq "auto glyph: bar in a UTF-8 locale" "$LACY_INDICATOR_CHAR" \
        "$(LC_ALL=en_US.UTF-8; _lacy_bash_mode_style auto; printf '%s' "$_LACY_BASH_MODE_GLYPH")"
    assert_eq "auto glyph: | outside UTF-8" "|" \
        "$(LC_ALL=C; _lacy_bash_mode_style auto; printf '%s' "$_LACY_BASH_MODE_GLYPH")"

    echo ""
    echo "--- Completions ---"
    COMP_WORDS=(lacy tool set "")
    COMP_CWORD=3
    _lacy_completions
    _comp=" ${COMPREPLY[*]} "
    for _t in "${LACY_TOOL_LIST[@]}" custom auto; do
        if [[ "$_comp" == *" $_t "* ]]; then pass; else fail "completion lists $_t" "got:$_comp"; fi
    done

    echo "UNIT_COUNTS $PASS $FAIL"
) > "$TMP_ROOT/unit.out" 2>&1
grep -v '^UNIT_COUNTS' "$TMP_ROOT/unit.out"
read -r _ _up _uf < <(grep '^UNIT_COUNTS' "$TMP_ROOT/unit.out" || echo "UNIT_COUNTS 0 1")
PASS=$(( PASS + _up ))
FAIL=$(( FAIL + _uf ))

# ============================================================================
# Interactive tests (bash -i in a pty)
# ============================================================================

echo ""
echo "--- Interactive (pty) ---"

if ! command -v python3 >/dev/null 2>&1; then
    echo "  SKIP: python3 not found"
    SKIP=$(( SKIP + 1 ))
else
    SBX="$TMP_ROOT/pty-home"
    mkdir -p "$SBX/.lacy" "$SBX/bin"

    cat > "$SBX/bin/fakeagent" <<'AGENT'
#!/bin/sh
case "$*" in *slowly*) sleep 8 ;; esac
printf 'FAKE_AGENT:%s\n' "$*"
AGENT
    chmod +x "$SBX/bin/fakeagent"

    cat > "$SBX/.lacy/config.yaml" <<CONFIG
agent_tools:
  active: custom
  custom_command: $SBX/bin/fakeagent
CONFIG

    cat > "$TMP_ROOT/pty_driver.py" <<'PY'
import os, pty, re, select, signal, sys, time

keys_file, out_file = sys.argv[1], sys.argv[2]
argv = sys.argv[3:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)

buf = bytearray()
exited = False

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

drain(10, until=b"P1> ")
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
        drain(0.25)
try:
    os.write(fd, b"echo __PTY_DONE__\r")
except OSError:
    pass
drain(20, until=b"\n__PTY_DONE__")

done_pid, _ = os.waitpid(pid, os.WNOHANG)
if done_pid == pid:
    exited = True
else:
    os.kill(pid, signal.SIGKILL)
    os.waitpid(pid, 0)

text = buf.decode("utf-8", "replace").replace("\r", "")
text = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)
text = re.sub(r"\x1b\][^\x07]*\x07", "", text)
if exited:
    text += "\n__CHILD_EXITED__\n"
open(out_file, "w").write(text)
PY

    # run_session NAME RC_EXTRA KEYS...
    run_session() {
        local name="$1" rc_extra="$2"
        shift 2
        command rm -f "$SBX/.lacy/current_mode"
        cat > "$TMP_ROOT/$name.rc" <<RC
export DO_NOT_TRACK=1 LACY_NO_TELEMETRY=1 LACY_SHELL_HOME="$SBX/.lacy"
PS2='P2> '
rebuild_ps1() { HOOK_SAW=\$?; PS1='P1> '; }
$rc_extra
source "$REPO_DIR/lacy.plugin.bash"
RC
        printf '%s\n' "$@" > "$TMP_ROOT/$name.keys"
        HOME="$SBX" INPUTRC="$SBX/no-inputrc" TERM=xterm \
            python3 "$TMP_ROOT/pty_driver.py" "$TMP_ROOT/$name.keys" "$TMP_ROOT/$name.out" \
            "$BASH" --noprofile --rcfile "$TMP_ROOT/$name.rc" -i
    }

    has_line() { grep -qxF -- "$2" "$1"; }
    has_text() { grep -qF -- "$2" "$1"; }
    has_both() { grep -F -- "$2" "$1" | grep -qF -- "$3"; }

    # --- Session A: emacs, string PROMPT_COMMAND that rebuilds PS1 ---
    run_session a "PROMPT_COMMAND='rebuild_ps1'" \
        'for i in 1 2' 'do echo iter$i' 'done' \
        'if true' 'then echo INSIDE_IF' 'fi' \
        '{' 'echo IN_GROUP' '}' \
        'cat <<EOF' 'do the thing' 'EOF' \
        'echo "open' 'done"' \
        'false' 'echo HOOK_SAW=$HOOK_SAW' \
        '#raw \x03' \
        'echo __MARK_BADGE__' \
        'what is this' \
        'echo __MARK_AFTER_QUERY__' \
        'sleep 1' 'what is typed ahead' \
        'trap -p INT; echo __TRAP1_END__' \
        'echo __READY$((1+1))__' '#until __READY2__' \
        'tell me slowly' '#wait 2' '#raw \x03' '#wait 0.5' \
        'echo AFTER_INT' \
        'trap -p INT; echo __TRAP2_END__' \
        'mode agent' 'echo __AGENT_MODE_PROBE__' 'quit' \
        'echo CLEANUP_X=[$(bind -m emacs -X | grep -c "C-x")]' \
        'echo CLEANUP_VX=[$(bind -m vi-insert -X | grep -c "C-x")]' \
        'echo CLEANUP_S=[$(bind -m emacs -s | grep -c "C-x")]' \
        'bind -m emacs -p | grep -F "\"\\C-m\"" | sed "s/^/ENTER_IS /"' \
        'bind -m emacs -p | grep -F "\"\\C-@\"" | sed "s/^/CTRLSPACE_IS /"' \
        'bind -m emacs -p | grep -F "\"\\C-j\"" | sed "s/^/CTRLJ_IS /"' \
        'echo PC=[$PROMPT_COMMAND]'
    OUT="$TMP_ROOT/a.out"

    assert_true "for/do/done on PS2 runs (iter1)" has_line "$OUT" "iter1"
    assert_true "for/do/done on PS2 runs (iter2)" has_line "$OUT" "iter2"
    assert_true "if/then/fi on PS2 runs" has_line "$OUT" "INSIDE_IF"
    assert_true "{ ... } on PS2 runs" has_line "$OUT" "IN_GROUP"
    assert_true "heredoc body stays in heredoc" has_line "$OUT" "do the thing"
    assert_false "heredoc body not sent to agent" has_both "$OUT" "FAKE_AGENT:" "do the thing"
    assert_true "open quote continues on PS2" has_line "$OUT" 'done'
    assert_true "user hook sees the command's exit status" has_line "$OUT" "HOOK_SAW=1"
    assert_false "Ctrl-C at prompt prints no quit hint" has_text "$OUT" "again to quit"
    assert_true "badge survives a PS1-rebuilding hook" has_both "$OUT" "P1> echo __MARK_BADGE__" "AUTO"
    assert_true "agent query at PS1 reaches agent" has_both "$OUT" "FAKE_AGENT:" "what is this"
    assert_true "shell works after a query" has_line "$OUT" "__MARK_AFTER_QUERY__"
    assert_true "Enter typed ahead during a command is classified" has_both "$OUT" "FAKE_AGENT:" "what is typed ahead"
    assert_true "no INT trap at rest" grep -qx -- "__TRAP1_END__" "$OUT"
    assert_false "no leftover INT trap text" has_text "$OUT" "trap -- "
    assert_true "Ctrl-C aborts a running query" has_line "$OUT" "AFTER_INT"
    assert_false "aborted query printed no answer" has_both "$OUT" "FAKE_AGENT:" "slowly"
    assert_true "INT trap restored after query" has_line "$OUT" "__TRAP2_END__"
    assert_true "agent mode routes to agent" has_both "$OUT" "FAKE_AGENT:" "__AGENT_MODE_PROBE__"
    assert_false "agent mode: quit not sent to agent" has_both "$OUT" "FAKE_AGENT:" "quit"
    assert_true "agent mode: quit leaves lacy" has_text "$OUT" "Exiting Lacy Shell"
    assert_true "cleanup removes hidden key (emacs -X)" has_line "$OUT" "CLEANUP_X=[0]"
    assert_true "cleanup removes hidden key (vi-insert -X)" has_line "$OUT" "CLEANUP_VX=[0]"
    assert_true "cleanup removes Enter macro" has_line "$OUT" "CLEANUP_S=[0]"
    assert_true "cleanup restores Enter" has_line "$OUT" 'ENTER_IS "\C-m": accept-line'
    assert_true "cleanup restores Ctrl-Space" has_line "$OUT" 'CTRLSPACE_IS "\C-@": set-mark'
    assert_true "cleanup restores Ctrl-J" has_line "$OUT" 'CTRLJ_IS "\C-j": accept-line'
    assert_true "cleanup restores PROMPT_COMMAND" has_line "$OUT" "PC=[rebuild_ps1]"

    # --- Session B: exit in agent mode leaves the shell ---
    run_session b "PROMPT_COMMAND='rebuild_ps1'" \
        'mode agent' 'echo __B_PROBE__' '#wait 0.5' 'exit' 'echo SHOULD_NOT_RUN'
    OUT="$TMP_ROOT/b.out"
    assert_true "agent mode active in session B" has_both "$OUT" "FAKE_AGENT:" "__B_PROBE__"
    assert_false "agent mode: exit not sent to agent" has_both "$OUT" "FAKE_AGENT:" "exit"
    assert_true "agent mode: exit ends the shell" has_line "$OUT" "__CHILD_EXITED__"
    assert_false "nothing runs after exit" has_line "$OUT" "SHOULD_NOT_RUN"

    # --- Session C: set -o vi, array PROMPT_COMMAND ---
    rc_c="set -o vi"
    array_pc=false
    if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
        rc_c+=$'\n'"PROMPT_COMMAND=(rebuild_ps1)"
        array_pc=true
    else
        rc_c+=$'\n'"PROMPT_COMMAND='rebuild_ps1'"
    fi
    run_session c "$rc_c" \
        'bind -m vi-insert -X | sed "s/^/VIX /"' \
        'bind -m vi-command -X | sed "s/^/VCX /"' \
        'for i in 1 2' 'do echo viter$i' 'done' \
        'what is this in vi' \
        'echo __MARK_VI_BADGE__' \
        'declare -p PROMPT_COMMAND | sed "s/^/PCDECL1 /"' \
        'quit' \
        'declare -p PROMPT_COMMAND | sed "s/^/PCDECL2 /"'
    OUT="$TMP_ROOT/c.out"
    assert_true "vi-insert Enter bound" has_line "$OUT" 'VIX "\C-x\C-l" "lacy_shell_smart_accept_line_bash"'
    assert_true "vi-command Enter bound" has_line "$OUT" 'VCX "\C-x\C-l" "lacy_shell_smart_accept_line_bash"'
    assert_true "vi-insert Ctrl-Space bound" has_line "$OUT" 'VIX "\C-@" "_lacy_ctrl_space_toggle"'
    assert_true "vi mode: PS2 loop runs" has_line "$OUT" "viter2"
    assert_true "vi mode: agent query routed" has_both "$OUT" "FAKE_AGENT:" "what is this in vi"
    assert_true "vi mode: badge present" has_both "$OUT" "P1> echo __MARK_VI_BADGE__" "AUTO"
    if [[ "$array_pc" == true ]]; then
        assert_true "array PROMPT_COMMAND: hooks around user entry" has_text "$OUT" \
            'PCDECL1 declare -a PROMPT_COMMAND=([0]="_lacy_bash_capture_exit" [1]="rebuild_ps1" [2]="lacy_shell_precmd_bash")'
        assert_true "array PROMPT_COMMAND: quit restores" has_text "$OUT" \
            'PCDECL2 declare -a PROMPT_COMMAND=([0]="rebuild_ps1")'
    fi
fi

echo ""
echo "================================================================"
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED"
    exit 1
fi
echo "ALL TESTS PASSED"
exit 0
