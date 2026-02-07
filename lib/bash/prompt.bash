#!/usr/bin/env bash

# Prompt handling for Lacy Shell — Bash adapter
# - Mode badge in left prompt (no right prompt in Bash)
# - No real-time indicator (Bash lacks per-keystroke hooks)

# Store original prompt (captured later, after user's profile loads)
LACY_SHELL_ORIGINAL_PS1=""
LACY_SHELL_BASE_PS1=""
LACY_SHELL_PROMPT_INITIALIZED=false

# Setup prompt integration (called during init, defers to first PROMPT_COMMAND)
lacy_shell_setup_prompt() {
    LACY_SHELL_PROMPT_INITIALIZED=false
}

# Actually initialize the prompt (called on first PROMPT_COMMAND)
lacy_shell_init_prompt_once() {
    [[ "$LACY_SHELL_PROMPT_INITIALIZED" == true ]] && return

    # Capture the user's fully-loaded prompt
    LACY_SHELL_ORIGINAL_PS1="$PS1"
    LACY_SHELL_BASE_PS1="$PS1"

    # Mark initialized BEFORE calling update_prompt to prevent infinite recursion
    # (update_prompt calls init_prompt_once, which would call update_prompt again)
    LACY_SHELL_PROMPT_INITIALIZED=true

    # Set initial prompt with mode badge
    lacy_shell_update_prompt
}

# Get ANSI color escape for a 256-color code
_lacy_bash_color() {
    printf '\[\e[38;5;%dm\]' "$1"
}

_lacy_bash_reset() {
    printf '\[\e[0m\]'
}

# Update prompt with mode badge
lacy_shell_update_prompt() {
    # Initialize on first call
    lacy_shell_init_prompt_once

    local mode_text mode_color
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell")
            mode_text="SHELL"
            mode_color="$LACY_COLOR_SHELL"
            ;;
        "agent")
            mode_text="AGENT"
            mode_color="$LACY_COLOR_AGENT"
            ;;
        "auto")
            mode_text="AUTO"
            mode_color="$LACY_COLOR_AUTO"
            ;;
        *)
            mode_text="?"
            mode_color="$LACY_COLOR_NEUTRAL"
            ;;
    esac

    # Build prompt: [MODE] indicator original_ps1
    local badge
    badge="$(_lacy_bash_color "$mode_color")${mode_text}$(_lacy_bash_reset)"
    local indicator
    indicator="$(_lacy_bash_color "$LACY_COLOR_NEUTRAL")${LACY_INDICATOR_CHAR}$(_lacy_bash_reset)"

    PS1="${badge} ${indicator} ${LACY_SHELL_BASE_PS1}"
}

# Restore original prompt
lacy_shell_restore_prompt() {
    if [[ -n "$LACY_SHELL_ORIGINAL_PS1" ]]; then
        PS1="$LACY_SHELL_ORIGINAL_PS1"
    fi
}

# Stubs for removed features (from ZSH adapter)
lacy_shell_remove_top_bar() { :; }
lacy_shell_show_top_bar_message() { :; }
