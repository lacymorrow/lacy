#!/usr/bin/env zsh

# Lacy Shell - Smart shell plugin with MCP support

# Prevent multiple sourcing
if [[ "${LACY_SHELL_LOADED:-}" == "true" ]]; then
    return 0
fi
LACY_SHELL_LOADED=true

# Plugin directory
LACY_SHELL_DIR="${0:A:h}"

# Shell type identification (used by shared core)
LACY_SHELL_TYPE="zsh"
_LACY_ARR_OFFSET=1

# Load shared core + ZSH adapter modules
source "$LACY_SHELL_DIR/lib/zsh/init.zsh"

# Initialize
lacy_shell_init() {
    # Performance optimization: Initialize caches early
    lacy_shell_init_detection_cache

    lacy_shell_load_config
    lacy_shell_setup_keybindings
    lacy_shell_init_mcp
    lacy_preheat_init
    lacy_shell_setup_prompt
    lacy_shell_init_mode
    lacy_shell_setup_interrupt_handler
    lacy_shell_setup_eof_handler
}

# Cleanup
lacy_shell_cleanup() {
    lacy_stop_spinner 2>/dev/null
    lacy_shell_remove_top_bar
    lacy_preheat_cleanup
    lacy_shell_cleanup_mcp
    lacy_shell_cleanup_keybindings
    unfunction TRAPINT 2>/dev/null
    trap - INT
    unsetopt IGNORE_EOF
    unset IGNOREEOF
    LACY_SHELL_QUITTING=false
    LACY_SHELL_ENABLED=false
    LACY_SHELL_LOADED=false
}

# Set up hooks
zle -N accept-line lacy_shell_smart_accept_line
precmd_functions+=(lacy_shell_precmd)

# Initialize
lacy_shell_init

# Cleanup on exit
trap lacy_shell_cleanup EXIT
