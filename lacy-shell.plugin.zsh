#!/usr/bin/env zsh

# Lacy Shell - Smart shell plugin with MCP support

# Plugin directory
LACY_SHELL_DIR="${0:A:h}"

# Load modules in order
source "$LACY_SHELL_DIR/lib/constants.zsh"
source "$LACY_SHELL_DIR/lib/config.zsh"
source "$LACY_SHELL_DIR/lib/modes.zsh"
source "$LACY_SHELL_DIR/lib/mcp.zsh"
source "$LACY_SHELL_DIR/lib/detection.zsh"
source "$LACY_SHELL_DIR/lib/keybindings.zsh"
source "$LACY_SHELL_DIR/lib/prompt.zsh"
source "$LACY_SHELL_DIR/lib/execute.zsh"

# Initialize
lacy_shell_init() {
    lacy_shell_load_config
    lacy_shell_setup_keybindings
    lacy_shell_init_mcp
    lacy_shell_setup_prompt
    lacy_shell_init_mode
    lacy_shell_setup_interrupt_handler
    lacy_shell_setup_eof_handler
}

# Cleanup
lacy_shell_cleanup() {
    lacy_shell_remove_top_bar
    lacy_shell_cleanup_mcp
    lacy_shell_cleanup_keybindings
    unfunction TRAPINT 2>/dev/null
    unsetopt IGNORE_EOF
    unset IGNOREEOF
    LACY_SHELL_QUITTING=false
}

# Set up hooks
zle -N accept-line lacy_shell_smart_accept_line
precmd_functions+=(lacy_shell_precmd)

# Initialize
lacy_shell_init

# Cleanup on exit
trap lacy_shell_cleanup EXIT