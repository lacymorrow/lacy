#!/usr/bin/env zsh

# Integration tests for the ZSH adapter (lacy.plugin.zsh + lib/zsh/*).
# Each case drives a real interactive zsh through zsh/zpty in a sandbox HOME,
# types keys, and reads state that a dump widget writes to a file.
#
# Usage: zsh tests/test_zsh_adapter.zsh

zmodload zsh/zpty zsh/datetime zsh/zselect || { echo "SKIP: zsh/zpty unavailable"; exit 0; }

REPO="${0:A:h:h}"
T=$(mktemp -d "${TMPDIR:-/tmp}/lacy-zsh-adapter.XXXXXX")
T="${T:A}"
mkdir -p "$T/home"

PASS=0
FAIL=0
SKIP=0

cleanup() {
    zpty -d lz 2>/dev/null
    command rm -rf "$T"
}
trap cleanup EXIT

pass() { (( PASS++ )); printf '  ok   %s\n' "$1"; }
fail() { (( FAIL++ )); printf '  FAIL %s\n' "$1"; [[ -n "$2" ]] && printf '       %s\n' "$2"; }
skip() { (( SKIP++ )); printf '  skip %s (%s)\n' "$1" "$2"; }

assert_eq() {
    if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "expected [$2] got [$3]"; fi
}
assert_match() {
    if [[ "$3" == ${~2} ]]; then pass "$1"; else fail "$1" "pattern [$2] got [$3]"; fi
}
assert_contains() {
    if [[ "$3" == *"$2"* ]]; then pass "$1"; else fail "$1" "missing [$2] in [$3]"; fi
}
assert_nocontains() {
    if [[ "$3" != *"$2"* ]]; then pass "$1"; else fail "$1" "unexpected [$2] in [$3]"; fi
}

# ----------------------------------------------------------------------------
# zpty harness
# ----------------------------------------------------------------------------

_drain() {
    local chunk
    while zpty -rt lz chunk 2>/dev/null; do ZOUT+="$chunk"; done
}

_pause() { zselect -t "${1:-15}" 2>/dev/null; _drain; }

# Wait until the dump file has at least $1 lines (or $2 seconds pass)
_wait_lines() {
    local want=$1
    local -F deadline=$(( EPOCHREALTIME + ${2:-10} ))
    local -a lines
    while (( EPOCHREALTIME < deadline )); do
        _drain
        lines=("${(@f)$(<$T/dump)}")
        [[ -z "${lines[1]}" ]] && lines=()
        (( ${#lines} >= want )) && return 0
        zselect -t 5 2>/dev/null
    done
    return 1
}

# Line $1 of the dump file
_line() {
    local -a lines
    lines=("${(@f)$(<$T/dump)}")
    print -r -- "${lines[$1]}"
}

# Run a command line and wait for the dump file to reach $1 lines. The
# command must append exactly one line (for example via _state).
_run() {
    zpty -w lz "$2"
    _wait_lines "$1" "${3:-10}" && return 0
    printf '       (timeout; pty tail: %s)\n' "${${(V)ZOUT[-400,-1]}//\^\[/ESC}"
    return 1
}

# Wait for the zpty shell to exit
_wait_exit() {
    local -F deadline=$(( EPOCHREALTIME + ${1:-5} ))
    while (( EPOCHREALTIME < deadline )); do
        _drain
        zpty -t lz 2>/dev/null || return 0
        zselect -t 5 2>/dev/null
    done
    return 1
}

# Type text, let ZLE redraw, then run the dump widget and wait for its line
_type_dump() {
    local n=$1 text=$2
    [[ -n "$text" ]] && zpty -w -n lz "$text"
    _pause 20
    # One more keystroke with nothing queued behind it, so every pre-redraw
    # hook (zsh-syntax-highlighting skips while input is pending) runs again
    zpty -w -n lz $'\C-e'
    _pause 20
    zpty -w -n lz $'\C-xq'
    _wait_lines $n
}

# Start a sandboxed interactive zsh. $1 = lacy home name, $2 = extra setup
# lines run before sourcing the plugin, $3 = lines run after, rest = env.
_session() {
    local home_name=$1 pre=$2 post=$3
    shift 3
    zpty -d lz 2>/dev/null
    : >| "$T/dump"
    ZOUT=""

    cat >| "$T/setup.zsh" <<EOF
PS1='ZP> '
RPS1='USERR'
_dump() { print -r -- "PRE=[\$PREDISPLAY] POST=[\$POSTDISPLAY] BUF=[\$BUFFER] TYPE=[\$LACY_SHELL_INPUT_TYPE] RH=[\${(j:;:)region_highlight}]" >> "$T/dump"; }
zle -N _dump
bindkey '^Xq' _dump
_state() { print -r -- "\$*" >> "$T/dump"; }
$pre
source "$REPO/lacy.plugin.zsh"
lacy_shell_query_agent() { print -r -- "Q=[\$1]" >> "$T/dump"; }
$post
EOF

    local -a envs
    envs=(T="$T" REPO="$REPO" HOME="$T/home" PATH="$PATH" TERM=xterm-256color
          LANG=en_US.UTF-8 LACY_SHELL_HOME="$T/$home_name"
          LACY_PREHEAT_SERVER_PORT=14987 DO_NOT_TRACK=1 LACY_NO_TELEMETRY=1
          EDITOR=nano "$@")
    zpty lz "env -i ${(j: :)${(@q)envs}} zsh -f -i"
    zpty -w lz "source ${(q)T}/setup.zsh; _state READY"
    _wait_lines 1 15 || fail "session $home_name started" "no READY; output: ${(V)ZOUT[-300,-1]}"
    : >| "$T/dump"
    _pause 30
}

# ----------------------------------------------------------------------------
echo "ZSH adapter tests (zsh $ZSH_VERSION)"
echo "================================================================"

# --- 1. add-zle-hook-widget coexistence (stub hooks before and after) -------
echo "hook coexistence"
_session h1 \
    'autoload -Uz add-zle-hook-widget; PRE_N=0; POST_N=0; _pre_hook() { (( PRE_N++ )); return 0; }; add-zle-hook-widget line-pre-redraw _pre_hook' \
    '_post_hook() { (( POST_N++ )); return 0; }; add-zle-hook-widget line-pre-redraw _post_hook; _cnt() { print -r -- "PRE_N=$PRE_N POST_N=$POST_N" >> "$T/dump"; }; zle -N _cnt; bindkey "^Xn" _cnt'
_type_dump 1 'ls -la'
zpty -w -n lz $'\C-xn'
_wait_lines 2
l1=$(_line 1); l2=$(_line 2)
assert_contains "lacy hook fired (indicator shell)" 'PRE=[$ ] POST=[] BUF=[ls -la] TYPE=[shell]' "$l1"
assert_match "hook registered before lacy still fires" '*PRE_N=<1->*' "$l2"
assert_match "hook registered after lacy still fires" '*POST_N=<1->*' "$l2"

# Real zsh-syntax-highlighting, loaded before and after lacy
zsh_sh=""
for f in /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
         /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
         /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -r "$f" ]] && { zsh_sh="$f"; break; }
done
if [[ -n "$zsh_sh" ]]; then
    _session h2 "source ${(q)zsh_sh}" ''
    _type_dump 1 'ls -la'
    l1=$(_line 1)
    assert_contains "zsh-syntax-highlighting (loaded first) still highlights" 'memo=zsh-syntax-highlighting' "$l1"
    assert_contains "lacy highlights alongside it" 'memo=lacy' "$l1"

    _session h3 '' "source ${(q)zsh_sh}"
    _type_dump 1 'ls -la'
    l1=$(_line 1)
    assert_contains "zsh-syntax-highlighting (loaded after) highlights" 'memo=zsh-syntax-highlighting' "$l1"
    assert_contains "lacy still highlights after it" 'memo=lacy' "$l1"
else
    skip "real zsh-syntax-highlighting" "not installed"
fi

# --- 2. re-source idempotence, quit restores the user's setup ---------------
echo "re-source and quit"
_session r1 \
    '_mine() { :; }; zle -N _mine; bindkey "^@" _mine; bindkey "^I" _mine; TRAPINT() { print usertrap; return $(( 128 + $1 )); }' \
    'LACY_SHELL_LOADED=false; source "$REPO/lacy.plugin.zsh"; lacy_shell_query_agent() { print -r -- "Q=[$1]" >> "$T/dump"; }'
_run 1 '_a=(${(M)precmd_functions:#lacy_shell_precmd}); _b=(${(M)zshexit_functions:#lacy_shell_cleanup}); _state "PRECMD=${#_a} EXIT=${#_b}"'
_run 2 '_w=(); zstyle -a zle-line-pre-redraw widgets _w; _a=(${(M)_w:#*lacy_shell_line_pre_redraw}); _state "HOOKS=${#_a}"'
_run 3 '_state "BIND=$(bindkey -L "^@") TAB=$(bindkey -L "^I") EOF=${options[ignoreeof]}"'
_run 4 '_state "RPS1=$RPS1"'
assert_eq "precmd hook registered once after re-source" "PRECMD=1 EXIT=1" "$(_line 1)"
assert_eq "pre-redraw hook registered once after re-source" "HOOKS=1" "$(_line 2)"
assert_eq "only lacy widgets bound, ignoreeof untouched" \
    'BIND=bindkey "^@" lacy_shell_toggle_mode_widget TAB=bindkey "^I" _lacy_expand_or_accept EOF=off' "$(_line 3)"
assert_eq "mode badge appended to user RPS1" 'RPS1=USERR %F{75}AUTO%f' "$(_line 4)"

zpty -w lz 'mode agent'
_pause 50
zpty -w lz 'quit'
_pause 80
_run 5 '_a=(${(M)precmd_functions:#lacy_shell_precmd}); _state "EN=$LACY_SHELL_ENABLED PRECMD=${#_a} RPS1=$RPS1"' 20
_run 6 '_state "BIND=$(bindkey -L "^@") TAB=$(bindkey -L "^I") TRAP=${functions[TRAPINT]//$'"'\n'"'/ }"'
_run 7 '_w=(); zstyle -a zle-line-pre-redraw widgets _w; _a=(${(M)_w:#*lacy_*}); _state "HOOKS=${#_a} ASK=${+functions[ask]} STOP=${+aliases[stop]}"'
assert_eq "quit in agent mode leaves lacy, restores RPS1" "EN=false PRECMD=0 RPS1=USERR" "$(_line 5)"
assert_match "quit restores previous bindings and user TRAPINT" \
    'BIND=bindkey "^@" _mine TAB=bindkey "^I" _mine TRAP=*usertrap*' "$(_line 6)"
assert_eq "quit removes hooks and ask" "HOOKS=0 ASK=0 STOP=0" "$(_line 7)"

# `mode agent` above persisted to current_mode; start the re-entered lacy in
# auto so the state probe below runs in the shell, not the real agent.
_run 8 'print auto >| "$LACY_SHELL_HOME/current_mode"; _state reset-mode'
zpty -w lz 'lacy'
_pause 80
_run 9 '_state "EN=$LACY_SHELL_ENABLED BIND=$(bindkey -L "^@")"' 20
assert_eq "typing lacy re-enters" 'EN=true BIND=bindkey "^@" lacy_shell_toggle_mode_widget' "$(_line 9)"

# --- 3. exit routing ----------------------------------------------------------
echo "exit routing"
_session e1 '' 'lacy_shell_set_mode agent'
zpty -w lz 'exit'
if _wait_exit 5; then pass "exit in agent mode exits the shell"; else fail "exit in agent mode exits the shell"; fi

_session e2 '' ''
zpty -w lz 'exit'
if _wait_exit 5; then pass "exit in auto mode exits the shell"; else fail "exit in auto mode exits the shell"; fi

_session e3 '' ''
zpty -w -n lz $'\C-d'
if _wait_exit 5; then pass "Ctrl+D on empty line exits the shell"; else fail "Ctrl+D on empty line exits the shell"; fi

# --- 4. ask, agent queries, Ctrl+C ---------------------------------------------
echo "queries"
_session q1 '' ''
_run 1 'ask hello big world'
assert_eq "ask sends every word" "Q=[hello big world]" "$(_line 1)"
_run 2 'what files are here'
assert_eq "natural language goes to the agent" "Q=[what files are here]" "$(_line 2)"

# Ctrl+C at the prompt clears the line and keeps lacy
_run 3 '_state ready'
_pause 50
zpty -w -n lz 'abc def'
_pause 30
zpty -w -n lz $'\C-c'
_pause 80
_run 4 '_state "EN=$LACY_SHELL_ENABLED"'
assert_eq "Ctrl+C at prompt clears the line and keeps lacy" "EN=true" "$(_line 4)"
assert_nocontains "no press-again message" 'again' "$ZOUT"

# Ctrl+C during a query stops the spinner and restores MONITOR and NOTIFY
_session q2 '' 'lacy_shell_query_agent() { lacy_start_spinner; sleep 3; lacy_stop_spinner; }'
zpty -w lz 'what is going on here'
_pause 80
zpty -w -n lz $'\C-c'
_pause 80
_run 1 '_state "MON=${options[monitor]} NOTIFY=${options[notify]} PID=[$LACY_SPINNER_PID] EN=$LACY_SHELL_ENABLED"' 20
assert_eq "Ctrl+C mid-query restores job control, no hang" "MON=on NOTIFY=on PID=[] EN=true" "$(_line 1)"
assert_nocontains "Ctrl+C mid-query prints no spinner job notice" 'terminated' "$ZOUT"

# --- 5. indicator glyphs, colour and NO_COLOR ----------------------------------
echo "indicator"
_session c1 '' ''
_type_dump 1 'ls -la'
zpty -w -n lz $'\C-u'
_type_dump 2 'what is this'
zpty -w -n lz $'\C-u'
_type_dump 3 ''
l1=$(_line 1); l2=$(_line 2); l3=$(_line 3)
assert_contains "shell glyph" 'PRE=[$ ]' "$l1"
assert_contains "shell glyph colour and first word" 'RH=[P0 1 fg=34 memo=lacy;0 2 fg=34,bold memo=lacy]' "$l1"
assert_contains "agent glyph" 'PRE=[? ]' "$l2"
assert_contains "agent glyph colour and first word" 'RH=[P0 1 fg=200 memo=lacy;0 4 fg=200,bold memo=lacy]' "$l2"
assert_contains "neutral keeps the bar glyph" 'PRE=[▌ ]' "$l3"

_session c2 '' '' NO_COLOR=1 LANG=C
_type_dump 1 'ls -la'
zpty -w -n lz $'\C-u'
_type_dump 2 'what is this'
zpty -w -n lz $'\C-u'
_type_dump 3 ''
_run 4 '_state "RPS1=$RPS1"'
l1=$(_line 1); l2=$(_line 2); l3=$(_line 3)
assert_contains "NO_COLOR shell glyph" 'PRE=[$ ]' "$l1"
assert_contains "NO_COLOR agent glyph" 'PRE=[? ]' "$l2"
assert_contains "non-UTF-8 locale neutral glyph is ASCII" 'PRE=[| ]' "$l3"
assert_nocontains "NO_COLOR adds no lacy colour highlights" 'memo=lacy' "$l1$l2$l3"
assert_eq "NO_COLOR mode badge has no colour" "RPS1=USERR AUTO" "$(_line 4)"

# --- 6. first-run hint ----------------------------------------------------------
echo "first-run hint"
_session hint '' ''
_type_dump 1 ''
assert_contains "hint shown as ghost text on first prompt" \
    'POST=[what files are here   (Enter to ask, or just type)]' "$(_line 1)"
if [[ -e "$T/hint/.hinted" ]]; then pass "hint flag file written"; else fail "hint flag file written"; fi
zpty -w -n lz $'\r'
_wait_lines 2
assert_eq "Enter asks the hint query" "Q=[what files are here]" "$(_line 2)"
_session hint '' ''
_type_dump 1 ''
assert_contains "hint never shown again" 'POST=[]' "$(_line 1)"

# --- 7. no prompt re-render per keystroke (starship-like PS1) ------------------
echo "prompt re-render"
_session s1 '' 'setopt prompt_subst; _stub() { print -n x >> "$T/stub"; }; PS1='"'"'$(_stub)ZP> '"'"'; : >| "$T/stub"'
_run 1 '_state settled'
_pause 200
before=$(<$T/stub)
for key in l s $'\C-h' $'\C-h' w h a t ' ' i s ' ' t h i s; do
    zpty -w -n lz "$key"
    _pause 5
done
_pause 200
after=$(<$T/stub)
assert_eq "typing across shell/agent transitions re-renders no prompt" "${#before}" "${#after}"

zpty -d lz 2>/dev/null

echo "================================================================"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
(( FAIL == 0 )) && echo "ALL TESTS PASSED"
exit $(( FAIL > 0 ))
