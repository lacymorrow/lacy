#!/usr/bin/env bash

# Prompt handling for Lacy Shell: Bash adapter
# - Mode badge and glyph in the left prompt (no right prompt in Bash)
# - No real-time indicator (Bash lacks per-keystroke hooks)

# Store original prompt (captured later, after user's profile loads)
LACY_SHELL_ORIGINAL_PS1=""
LACY_SHELL_BASE_PS1=""
LACY_SHELL_PROMPT_INITIALIZED=false

# The PS1 lacy built last. A different PS1 at prompt time means an earlier
# PROMPT_COMMAND hook (starship, __git_ps1) rebuilt it, and that is the base.
_LACY_BASH_LAST_PS1=""

# Setup prompt integration (called during init, defers to first PROMPT_COMMAND)
lacy_shell_setup_prompt() {
    LACY_SHELL_PROMPT_INITIALIZED=false
}

# Actually initialize the prompt (called on first PROMPT_COMMAND)
lacy_shell_init_prompt_once() {
    [[ "$LACY_SHELL_PROMPT_INITIALIZED" == true ]] && return

    # Capture the user's fully-loaded prompt
    LACY_SHELL_ORIGINAL_PS1="${PS1:-}"
    LACY_SHELL_BASE_PS1="${PS1:-}"
    _LACY_BASH_LAST_PS1=""

    # Mark initialized BEFORE calling update_prompt to prevent infinite recursion
    # (update_prompt calls init_prompt_once, which would call update_prompt again)
    LACY_SHELL_PROMPT_INITIALIZED=true

    # Set initial prompt with mode badge
    lacy_shell_update_prompt
}

# Set _LACY_BASH_MODE_TEXT, _LACY_BASH_MODE_COLOR and _LACY_BASH_MODE_GLYPH
# for a mode. The glyph carries the mode without colour: shell $, agent ?
_lacy_bash_mode_style() {
    case "$1" in
        "shell")
            _LACY_BASH_MODE_TEXT="SHELL"
            _LACY_BASH_MODE_COLOR="$LACY_COLOR_SHELL"
            _LACY_BASH_MODE_GLYPH='$'
            ;;
        "agent")
            _LACY_BASH_MODE_TEXT="AGENT"
            _LACY_BASH_MODE_COLOR="$LACY_COLOR_AGENT"
            _LACY_BASH_MODE_GLYPH='?'
            ;;
        "auto")
            _LACY_BASH_MODE_TEXT="AUTO"
            _LACY_BASH_MODE_COLOR="$LACY_COLOR_AUTO"
            _LACY_BASH_MODE_GLYPH="$LACY_INDICATOR_CHAR"
            ;;
        *)
            _LACY_BASH_MODE_TEXT="?"
            _LACY_BASH_MODE_COLOR="$LACY_COLOR_NEUTRAL"
            _LACY_BASH_MODE_GLYPH="$LACY_INDICATOR_CHAR"
            ;;
    esac
}

# Print a line in a 256-colour code, or plain when NO_COLOR is set
_lacy_bash_print_color() {
    if [[ -n "${NO_COLOR:-}" ]]; then
        printf '%s\n' "$2"
    else
        printf '\e[38;5;%dm%s\e[0m\n' "$1" "$2"
    fi
}

# Print "  <glyph> <MODE> mode" for a mode change
_lacy_bash_print_mode_msg() {
    local msg
    case "$1" in
        "shell") msg="${LACY_MSG_MODE_SHELL_SHORT:-SHELL mode}" ;;
        "agent") msg="${LACY_MSG_MODE_AGENT_SHORT:-AGENT mode}" ;;
        *)       msg="${LACY_MSG_MODE_AUTO_SHORT:-AUTO mode}" ;;
    esac
    _lacy_bash_mode_style "$1"
    if [[ -n "${NO_COLOR:-}" ]]; then
        printf '  %s %s\n' "$_LACY_BASH_MODE_GLYPH" "$msg"
    else
        printf '  \e[38;5;%dm%s\e[0m %s\n' "$_LACY_BASH_MODE_COLOR" "$_LACY_BASH_MODE_GLYPH" "$msg"
    fi
}

# Update prompt with mode badge
lacy_shell_update_prompt() {
    # Initialize on first call
    lacy_shell_init_prompt_once

    if [[ "${PS1:-}" != "$_LACY_BASH_LAST_PS1" ]]; then
        LACY_SHELL_BASE_PS1="${PS1:-}"
    fi

    _lacy_bash_mode_style "$LACY_SHELL_CURRENT_MODE"

    # Build prompt: MODE glyph base_ps1. The glyph is followed by a space
    # inside the colour span so `$` is never read as an expansion.
    if [[ -n "${NO_COLOR:-}" ]]; then
        PS1="${_LACY_BASH_MODE_TEXT} ${_LACY_BASH_MODE_GLYPH} ${LACY_SHELL_BASE_PS1}"
    else
        PS1="\[\e[38;5;${_LACY_BASH_MODE_COLOR}m\]${_LACY_BASH_MODE_TEXT} ${_LACY_BASH_MODE_GLYPH} \[\e[0m\]${LACY_SHELL_BASE_PS1}"
    fi
    _LACY_BASH_LAST_PS1="$PS1"
}

# Restore the user's prompt: the latest one a PROMPT_COMMAND hook built, else
# the one captured at load
lacy_shell_restore_prompt() {
    if [[ -n "$LACY_SHELL_BASE_PS1" ]]; then
        PS1="$LACY_SHELL_BASE_PS1"
    elif [[ -n "$LACY_SHELL_ORIGINAL_PS1" ]]; then
        PS1="$LACY_SHELL_ORIGINAL_PS1"
    fi
}

# Stubs for removed features (from ZSH adapter)
lacy_shell_remove_top_bar() { :; }
lacy_shell_show_top_bar_message() { :; }
