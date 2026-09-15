#!/usr/bin/env zsh

# Lacy Shell - talk to your shell

# Prevent multiple sourcing
if [[ "${LACY_SHELL_LOADED:-}" == "true" ]]; then
    return 0
fi
LACY_SHELL_LOADED=true
LACY_SHELL_ENABLED=true
LACY_SHELL_QUITTING=false
export LACY_SHELL_ACTIVE=1

# Plugin directory
LACY_SHELL_DIR="${0:A:h}"

# Shell type identification (used by shared core)
LACY_SHELL_TYPE="zsh"
_LACY_ARR_OFFSET=1

# Load shared core + ZSH adapter modules
source "$LACY_SHELL_DIR/lib/zsh/init.zsh"

autoload -Uz add-zsh-hook

# Initialize
lacy_shell_init() {
    # Performance optimization: Initialize caches early
    lacy_shell_init_detection_cache

    lacy_shell_load_config
    lacy_shell_setup_keybindings
    lacy_preheat_init
    lacy_shell_setup_prompt
    lacy_shell_init_mode
}

# Cleanup (quit and shell exit). Safe to run more than once.
lacy_shell_cleanup() {
    lacy_stop_spinner 2>/dev/null
    lacy_preheat_cleanup
    lacy_shell_cleanup_keybindings
    lacy_shell_restore_prompt
    add-zsh-hook -d precmd lacy_shell_precmd
    LACY_SHELL_QUITTING=false
    LACY_SHELL_ENABLED=false
    LACY_SHELL_LOADED=false
    unset LACY_SHELL_ACTIVE
}

# Set up hooks (add-zsh-hook skips duplicates, so re-sourcing is safe)
zle -N accept-line lacy_shell_smart_accept_line
add-zsh-hook precmd lacy_shell_precmd

# Initialize
lacy_shell_init

# One-time install tracking (background, fail-silent)
_lacy_track_first_load

# Cleanup on shell exit. Not an EXIT trap: when this file is sourced inside a
# function (zinit, antidote, or the `lacy` function after `quit`) an EXIT trap
# fires on function return, not on shell exit. zshexit hooks only fire when
# the shell really exits.
add-zsh-hook zshexit lacy_shell_cleanup
