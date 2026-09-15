#!/usr/bin/env bash

# Keybinding setup for Lacy Shell: Bash adapter
# Enter becomes a readline macro that presses a hidden key bound (bind -x) to
# classification, then a second hidden key bound to accept-line. Bound in
# emacs, vi-insert and vi-command so `set -o vi` users get the same routing.

# Track agent execution state for interrupt handling (set by the spinner)
LACY_SHELL_AGENT_RUNNING=false

_LACY_BASH_KEYMAPS=(emacs vi-insert vi-command)
_LACY_BASH_KEY_CLASSIFY='\C-x\C-l'
_LACY_BASH_KEY_ACCEPT='\C-x\C-j'

# Bindings lacy replaced, as "keymap<TAB>kind<TAB>bind-argument" entries.
# kind is -x for shell-command bindings, -- for functions and macros.
_LACY_BASH_SAVED_BINDS=()

# Remember what KEY does in KEYMAP so cleanup can put it back.
_lacy_bash_save_binding() {
    local keymap="$1" key="$2" line cmd
    local prefix="\"${key}\""
    local tab=$'\t'

    # bind -X prints `"key" "command"`; bind -x takes `"key": command`
    while IFS= read -r line; do
        if [[ "$line" == "$prefix \""* ]]; then
            cmd="${line#"$prefix \""}"
            cmd="${cmd%\"}"
            cmd="${cmd//\\\"/\"}"
            # Our own binding from an earlier load is not the user's
            [[ "$cmd" == _lacy_* || "$cmd" == lacy_shell_* ]] && break
            _LACY_BASH_SAVED_BINDS+=("${keymap}${tab}-x${tab}${prefix}: ${cmd}")
            return
        fi
    done < <(bind -m "$keymap" -X 2>/dev/null)

    # Macros (bind -s) and readline functions (bind -p) print `"key": value`
    while IFS= read -r line; do
        if [[ "$line" == "$prefix: "* ]]; then
            [[ "$line" == *"$_LACY_BASH_KEY_CLASSIFY"* ]] && break
            _LACY_BASH_SAVED_BINDS+=("${keymap}${tab}--${tab}${line}")
            return
        fi
    done < <(bind -m "$keymap" -s 2>/dev/null; bind -m "$keymap" -p 2>/dev/null)

    # Enter must never end up dead after cleanup
    if [[ "$key" == '\C-m' || "$key" == '\C-j' ]]; then
        _LACY_BASH_SAVED_BINDS+=("${keymap}${tab}--${tab}${prefix}: accept-line")
    fi
}

# Set up all keybindings
lacy_shell_setup_keybindings() {
    _LACY_BASH_SAVED_BINDS=()
    local km
    for km in "${_LACY_BASH_KEYMAPS[@]}"; do
        _lacy_bash_save_binding "$km" '\C-m'
        _lacy_bash_save_binding "$km" '\C-j'
        _lacy_bash_save_binding "$km" '\C-@'

        # bind -x directly on \C-m would replace accept-line, so commands
        # would never submit. The classifier may clear READLINE_LINE (agent
        # query); accept-line then submits the possibly empty line. The
        # macro ends on a hidden accept-line key, not on \C-j.
        bind -m "$km" -x "\"${_LACY_BASH_KEY_CLASSIFY}\": lacy_shell_smart_accept_line_bash"
        bind -m "$km" "\"${_LACY_BASH_KEY_ACCEPT}\": accept-line"
        bind -m "$km" "\"\\C-m\": \"${_LACY_BASH_KEY_CLASSIFY}${_LACY_BASH_KEY_ACCEPT}\""
        # Enter typed while a command is still running reaches readline as
        # \C-j (the terminal maps CR to NL), so \C-j gets the same macro.
        # Cleanup puts the user's own \C-j binding back.
        bind -m "$km" "\"\\C-j\": \"${_LACY_BASH_KEY_CLASSIFY}${_LACY_BASH_KEY_ACCEPT}\""

        # Ctrl+Space: toggle mode, keeping the in-progress line
        bind -m "$km" -x '"\C-@": _lacy_ctrl_space_toggle'
    done
}

# Ctrl+Space handler via bind -x.
# Toggles mode, prints feedback, updates PS1, and restores the user's
# in-progress input.
_lacy_ctrl_space_toggle() {
    local saved_line="$READLINE_LINE"
    local saved_point="$READLINE_POINT"

    lacy_shell_toggle_mode
    lacy_shell_update_prompt

    printf '\n'
    _lacy_bash_print_mode_msg "$LACY_SHELL_CURRENT_MODE"

    READLINE_LINE="$saved_line"
    READLINE_POINT="$saved_point"
}

# Remove lacy's bindings and put back the ones it replaced
lacy_shell_cleanup_keybindings_bash() {
    local km entry rest kind arg
    for km in "${_LACY_BASH_KEYMAPS[@]}"; do
        # bind -r takes the bare key sequence. Quoting it ('"\C-x\C-l"')
        # passes the quotes through and removes nothing.
        bind -m "$km" -r "$_LACY_BASH_KEY_CLASSIFY" 2>/dev/null
        bind -m "$km" -r "$_LACY_BASH_KEY_ACCEPT" 2>/dev/null
        bind -m "$km" -r '\C-m' 2>/dev/null
        bind -m "$km" -r '\C-j' 2>/dev/null
        bind -m "$km" -r '\C-@' 2>/dev/null
    done

    if (( ${#_LACY_BASH_SAVED_BINDS[@]} > 0 )); then
        for entry in "${_LACY_BASH_SAVED_BINDS[@]}"; do
            km="${entry%%$'\t'*}"
            rest="${entry#*$'\t'}"
            kind="${rest%%$'\t'*}"
            arg="${rest#*$'\t'}"
            if [[ "$kind" == "-x" ]]; then
                bind -m "$km" -x "$arg" 2>/dev/null
            else
                bind -m "$km" "$arg" 2>/dev/null
            fi
        done
    fi
    _LACY_BASH_SAVED_BINDS=()
}
