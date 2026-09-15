#!/usr/bin/env zsh

# Keybinding and line editor integration for Lacy Shell
#
# ============================================================================
# Plugin Coexistence: hooks, PREDISPLAY, region_highlight, POSTDISPLAY
# ============================================================================
#
# This file shares ZLE resources with other plugins (notably
# zsh-syntax-highlighting, zsh-autosuggestions, powerlevel10k, starship).
#
# Hooks
# -----
# Lacy registers zle-line-init and zle-line-pre-redraw through
# add-zle-hook-widget. `zle -N zle-line-pre-redraw ...` would replace the
# dispatcher that zsh-syntax-highlighting registered, silently killing it.
# add-zle-hook-widget stops calling later hooks when one returns non-zero, so
# every Lacy hook ends with `return 0`.
#
# PREDISPLAY (live indicator)
# ---------------------------
# The shell/agent indicator is rendered in PREDISPLAY (text drawn between the
# prompt and the buffer), never by rewriting PS1. PS1 belongs to the user's
# prompt system. Rewriting it and calling reset-prompt re-ran starship on every
# transition and fought p10k over who owns PS1. Lacy only writes PREDISPLAY
# when it is empty or still holds Lacy's last value, so widgets that use it
# (narrow-to-region, read-from-minibuffer) are left alone.
#
# region_highlight
# ----------------
# Multiple plugins write highlight specs to region_highlight. Lacy tags its
# entries with `memo=lacy` and removes only those on each redraw:
#
#     region_highlight=("${(@)region_highlight:#*memo=lacy*}")
#
# memo= needs zsh 5.9. On older zsh the tag is dropped when the array is read
# back, so Lacy entries could never be filtered out again and would pile up.
# There Lacy skips its highlights entirely (the indicator glyph still shows).
# With NO_COLOR set, Lacy adds no colour highlights either.
#
# POSTDISPLAY (ghost text)
# ------------------------
# Text rendered after BUFFER. Lacy (ghost text after a failed reroute
# candidate, and the one-time first-run hint) and zsh-autosuggestions both
# write it. When Lacy's ghost text is active, call _zsh_autosuggest_clear
# (if available) before setting POSTDISPLAY. When the user starts typing,
# Lacy clears its ghost text and autosuggestions resumes normally.
#
# Keys
# ----
# Lacy binds Ctrl+Space (mode toggle) plus Right arrow and Tab (accept ghost
# text). Each key's previous binding is saved with `bindkey -L` and restored
# verbatim on cleanup. When there is no ghost text, Right arrow and Tab call
# the widget that was bound before Lacy loaded (fzf-completion, autosuggest
# wrappers, ...), by name and without the dot prefix, so wrappers still fire.
#
# ============================================================================

autoload -Uz add-zle-hook-widget is-at-least
zmodload zsh/langinfo 2>/dev/null

if is-at-least 5.9; then
    _LACY_ZLE_HL=1
else
    _LACY_ZLE_HL=0
fi

# Ghost text suggestion (shown as POSTDISPLAY while the buffer is empty)
LACY_SHELL_SUGGESTION=""          # text accepted into BUFFER
LACY_SHELL_SUGGESTION_DISPLAY=""  # text shown, when it differs (first-run hint)
LACY_SHELL_HINT_ACTIVE=false      # true while the first-run hint is showing
LACY_SHELL_OWN_POSTDISPLAY=false  # true when Lacy is managing POSTDISPLAY
_LACY_PREDISPLAY=""               # last indicator string Lacy wrote

# Keys Lacy binds, their saved `bindkey -L` lines, and the widget each was
# bound to before Lacy loaded
_LACY_BOUND_KEYS=('^@' '^[[C' '^[OC' '^I')
typeset -gA _LACY_SAVED_BINDINGS _LACY_PREV_WIDGET

# ============================================================================
# Real-time Shell/Agent Indicator
# ============================================================================

# First word bounds of $1 as 0-based [start, end) in _LACY_FW_START and
# _LACY_FW_END. Parameter expansion only: a per-character loop took ~90ms on
# a 5000-char paste.
_lacy_first_word_bounds() {
    local lead="${1#"${1%%[^[:space:]]*}"}"
    local fw="${lead%%[[:space:]]*}"
    _LACY_FW_START=$(( ${#1} - ${#lead} ))
    _LACY_FW_END=$(( _LACY_FW_START + ${#fw} ))
}

# Write the indicator for an input type into PREDISPLAY (if Lacy owns it).
# Sets _LACY_INDICATOR_COLOR; returns 0 when PREDISPLAY was written.
_lacy_set_indicator() {
    local glyph
    case "$1" in
        "shell") glyph='$'; _LACY_INDICATOR_COLOR="$LACY_COLOR_SHELL" ;;
        "agent") glyph='?'; _LACY_INDICATOR_COLOR="$LACY_COLOR_AGENT" ;;
        *)       glyph="$LACY_INDICATOR_CHAR"; _LACY_INDICATOR_COLOR="$LACY_COLOR_NEUTRAL" ;;
    esac
    # Outside a UTF-8 locale ZLE draws the multibyte bar as escaped bytes
    [[ "${langinfo[CODESET]-}" == (UTF-8|utf8) ]] || [[ "$glyph" == [\$?] ]] || glyph='|'
    [[ -n "$PREDISPLAY" && "$PREDISPLAY" != "$_LACY_PREDISPLAY" ]] && return 1
    _LACY_PREDISPLAY="$glyph "
    PREDISPLAY="$_LACY_PREDISPLAY"
    return 0
}

# Show Lacy's ghost text in POSTDISPLAY (buffer must be empty)
_lacy_show_ghost_text() {
    # Clear autosuggestions' POSTDISPLAY before writing ours, otherwise it
    # overwrites the ghost text with "" (no history match for empty input).
    (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear
    POSTDISPLAY="${LACY_SHELL_SUGGESTION_DISPLAY:-$LACY_SHELL_SUGGESTION}"
    LACY_SHELL_OWN_POSTDISPLAY=true
    if (( _LACY_ZLE_HL )) && [[ -z ${NO_COLOR-} ]]; then
        region_highlight+=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=${LACY_COLOR_NEUTRAL} memo=lacy")
    fi
}

# Forget the ghost text suggestion. Clears POSTDISPLAY only if it still shows
# Lacy's text, so an autosuggestion written this cycle survives.
_lacy_clear_suggestion() {
    local shown="${LACY_SHELL_SUGGESTION_DISPLAY:-$LACY_SHELL_SUGGESTION}"
    if [[ "$LACY_SHELL_OWN_POSTDISPLAY" == true ]]; then
        [[ "$POSTDISPLAY" == "$shown" ]] && POSTDISPLAY=""
        LACY_SHELL_OWN_POSTDISPLAY=false
    fi
    LACY_SHELL_SUGGESTION=""
    LACY_SHELL_SUGGESTION_DISPLAY=""
    LACY_SHELL_HINT_ACTIVE=false
}

# Update the indicator based on current input (called on every redraw).
# No forks and no reset-prompt: the prompt is never re-rendered here.
lacy_shell_update_input_indicator() {
    [[ "$LACY_SHELL_ENABLED" != true ]] && return 0

    lacy_shell_classify_input "$BUFFER" >/dev/null
    local input_type="$_LACY_CLASSIFY_RESULT"
    LACY_SHELL_INPUT_TYPE="$input_type"

    local own_pre=0
    _lacy_set_indicator "$input_type" && own_pre=1

    if (( _LACY_ZLE_HL )); then
        # Remove only our previous highlights; keep other plugins' entries
        region_highlight=("${(@)region_highlight:#*memo=lacy*}")
        if [[ -z ${NO_COLOR-} ]]; then
            (( own_pre )) && region_highlight+=("P0 1 fg=${_LACY_INDICATOR_COLOR} memo=lacy")
            # First word follows the classification colour
            if [[ -n "$BUFFER" && "$input_type" != "neutral" ]]; then
                _lacy_first_word_bounds "$BUFFER"
                if (( _LACY_FW_END > _LACY_FW_START )); then
                    region_highlight+=("$_LACY_FW_START $_LACY_FW_END fg=${_LACY_INDICATOR_COLOR},bold memo=lacy")
                fi
            fi
        fi
    fi

    if [[ -n "$LACY_SHELL_SUGGESTION" ]]; then
        if [[ -z "$BUFFER" ]]; then
            _lacy_show_ghost_text
        else
            # User started typing: ghost text goes, autosuggestions resumes
            _lacy_clear_suggestion
        fi
    elif [[ "$LACY_SHELL_OWN_POSTDISPLAY" == true ]]; then
        # Suggestion was cleared externally (precmd): clean up POSTDISPLAY
        POSTDISPLAY=""
        LACY_SHELL_OWN_POSTDISPLAY=false
    fi
    return 0
}

# zle-line-pre-redraw hook
lacy_shell_line_pre_redraw() {
    lacy_shell_update_input_indicator
    return 0
}

# zle-line-init hook: draw the indicator and ghost text before the first
# redraw so they are visible on the very first render
lacy_shell_line_init() {
    lacy_shell_update_input_indicator
    return 0
}

# ============================================================================
# Keybindings
# ============================================================================

lacy_shell_setup_keybindings() {
    local key line
    for key in "${_LACY_BOUND_KEYS[@]}"; do
        line=$(bindkey -L "$key" 2>/dev/null)
        # Never save our own binding (plugin sourced again without cleanup)
        if [[ "$line" != *" lacy_shell_"* && "$line" != *" _lacy_"* ]]; then
            _LACY_SAVED_BINDINGS[$key]="$line"
            _LACY_PREV_WIDGET[$key]="${${(z)line}[-1]}"
        fi
    done

    bindkey '^@' lacy_shell_toggle_mode_widget    # Ctrl+Space: toggle mode
    bindkey '^[[C' _lacy_forward_char_or_accept   # Right arrow
    bindkey '^[OC' _lacy_forward_char_or_accept   # Right arrow (alt sequence)
    bindkey '^I' _lacy_expand_or_accept           # Tab

    if [[ -o zle ]]; then
        add-zle-hook-widget line-pre-redraw lacy_shell_line_pre_redraw
        add-zle-hook-widget line-init lacy_shell_line_init
    fi
}

lacy_shell_cleanup_keybindings() {
    local key
    for key in "${(@k)_LACY_SAVED_BINDINGS}"; do
        [[ -n "${_LACY_SAVED_BINDINGS[$key]}" ]] && eval "${_LACY_SAVED_BINDINGS[$key]}"
    done
    _LACY_SAVED_BINDINGS=()
    _LACY_PREV_WIDGET=()

    if [[ -o zle ]]; then
        add-zle-hook-widget -d line-pre-redraw lacy_shell_line_pre_redraw 2>/dev/null
        add-zle-hook-widget -d line-init lacy_shell_line_init 2>/dev/null
    fi
}

# Widget to toggle mode (the pre-redraw hook updates the indicator)
lacy_shell_toggle_mode_widget() {
    lacy_shell_toggle_mode
    zle reset-prompt
}

# Accept ghost text suggestion into buffer.
# Called by right arrow and tab widgets below.
_lacy_try_accept_suggestion() {
    if [[ -n "$LACY_SHELL_SUGGESTION" && -z "$BUFFER" ]]; then
        local text="$LACY_SHELL_SUGGESTION"
        _lacy_clear_suggestion
        POSTDISPLAY=""
        BUFFER="$text"
        CURSOR=${#BUFFER}
        return 0  # consumed: caller should NOT fall through
    fi
    return 1  # no ghost text: caller should fall through to default widget
}

# Call the widget a key was bound to before Lacy loaded, else a default
_lacy_call_prev_widget() {
    local key="$1" fallback="$2"
    local w="${_LACY_PREV_WIDGET[$key]}"
    [[ -z "$w" || "$w" == undefined-key ]] && w="$fallback"
    zle "$w"
}

# Right arrow: accept Lacy ghost text if present, otherwise the previous widget
_lacy_forward_char_or_accept() {
    _lacy_try_accept_suggestion && return
    if [[ "$KEYS" == $'\eOC' ]]; then
        _lacy_call_prev_widget '^[OC' forward-char
    else
        _lacy_call_prev_widget '^[[C' forward-char
    fi
}

# Tab: accept Lacy ghost text if present, otherwise the previous widget
_lacy_expand_or_accept() {
    _lacy_try_accept_suggestion && return
    _lacy_call_prev_widget '^I' expand-or-complete
}

# ============================================================================
# Ctrl+C
# ============================================================================

# Ctrl+C is left entirely to the shell: Lacy defines no TRAPINT, so at the
# prompt it clears the line (a TRAPINT function changes that default), and
# during a query it interrupts the running function. Queries run inside
# `{ ... } always { _lacy_query_interrupt_cleanup }` so an interrupted query
# still stops the spinner and restores MONITOR and NOTIFY. After a query that
# finished normally the spinner state is already clear and this does nothing.
# The spinner is reaped with `wait` before MONITOR comes back on, otherwise
# zsh prints a "[N] + terminated { trap ... }" job notice. wait is safe in an
# always block; it would deadlock in a trap, which is one reason Lacy has none.
_lacy_query_interrupt_cleanup() {
    if [[ -n "$LACY_SPINNER_PID" ]]; then
        kill "$LACY_SPINNER_PID" 2>/dev/null
        wait "$LACY_SPINNER_PID" 2>/dev/null
        LACY_SPINNER_PID=""
        printf '\e[?25h\e[2K\r' >&2
    fi
    LACY_SHELL_AGENT_RUNNING=false
    if [[ -n "$LACY_SPINNER_MONITOR_WAS_SET" ]]; then
        setopt MONITOR
        LACY_SPINNER_MONITOR_WAS_SET=""
    fi
    if [[ -n "$LACY_SPINNER_NOTIFY_WAS_SET" ]]; then
        setopt NOTIFY
        LACY_SPINNER_NOTIFY_WAS_SET=""
    fi
    return 0
}

# Register widgets
zle -N lacy_shell_toggle_mode_widget
zle -N _lacy_forward_char_or_accept
zle -N _lacy_expand_or_accept
zle -N lacy_shell_line_pre_redraw
zle -N lacy_shell_line_init
