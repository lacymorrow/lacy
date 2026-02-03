#!/usr/bin/env zsh

# Prompt handling for Lacy Shell
# - Real-time colored indicator: green (shell) vs magenta (agent)
# - Mode indicator in right prompt

# Store original prompts (captured later, after user's profile loads)
LACY_SHELL_ORIGINAL_PS1=""
LACY_SHELL_ORIGINAL_RPS1=""
LACY_SHELL_BASE_PS1=""
LACY_SHELL_PROMPT_INITIALIZED=false

# Setup prompt integration (called during init, but defers actual setup)
lacy_shell_setup_prompt() {
    # Don't capture PS1 yet - wait for first precmd when user's prompt is ready
    LACY_SHELL_PROMPT_INITIALIZED=false
}

# Actually initialize the prompt (called on first precmd)
lacy_shell_init_prompt_once() {
    [[ "$LACY_SHELL_PROMPT_INITIALIZED" == true ]] && return

    # Now capture the user's fully-loaded prompt
    LACY_SHELL_ORIGINAL_PS1="$PS1"
    LACY_SHELL_ORIGINAL_RPS1="$RPS1"
    LACY_SHELL_BASE_PS1="$PS1"

    # Initialize with neutral indicator (appended after prompt, before cursor)
    LACY_SHELL_INPUT_TYPE="neutral"
    PS1="${LACY_SHELL_BASE_PS1}%F{238}▌%f "

    # Set right prompt with mode indicator
    lacy_shell_update_rprompt

    LACY_SHELL_PROMPT_INITIALIZED=true
}

# Update right prompt with mode indicator
lacy_shell_update_rprompt() {
    local mode_text mode_color
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell")
            mode_text="SHELL"
            mode_color="34"  # Green
            ;;
        "agent")
            mode_text="AGENT"
            mode_color="200"  # Magenta
            ;;
        "auto")
            mode_text="AUTO"
            mode_color="75"  # Blue
            ;;
        *)
            mode_text="?"
            mode_color="238"
            ;;
    esac

    RPS1="%F{${mode_color}}${mode_text}%f %F{238}[Ctrl+Space]%f"
}

# Update prompt (called by precmd)
lacy_shell_update_prompt() {
    # Initialize on first call
    lacy_shell_init_prompt_once

    # Reset to neutral indicator (appended after prompt, before cursor)
    LACY_SHELL_INPUT_TYPE="neutral"
    PS1="${LACY_SHELL_BASE_PS1}%F{238}▌%f "

    # Update mode in right prompt
    lacy_shell_update_rprompt
}

# Restore original prompt
lacy_shell_restore_prompt() {
    if [[ -n "$LACY_SHELL_ORIGINAL_PS1" ]]; then
        PS1="$LACY_SHELL_ORIGINAL_PS1"
    fi
    if [[ -n "$LACY_SHELL_ORIGINAL_RPS1" ]]; then
        RPS1="$LACY_SHELL_ORIGINAL_RPS1"
    else
        RPS1=""
    fi
}

# Stubs for removed features
lacy_shell_remove_top_bar() { :; }
lacy_shell_show_top_bar_message() { :; }
