#!/usr/bin/env bash

# Lacy Shell - Smart shell plugin with MCP support (Bash adapter)

# Prevent multiple sourcing
if [[ "${LACY_SHELL_LOADED:-}" == "true" ]]; then
    return 0
fi
LACY_SHELL_LOADED=true

# Plugin directory
LACY_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shell type identification (used by shared core)
LACY_SHELL_TYPE="bash"
_LACY_ARR_OFFSET=0

# Load shared core + Bash adapter modules
source "$LACY_SHELL_DIR/lib/bash/init.bash" || {
    LACY_SHELL_LOADED=false
    return 1
}

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
    lacy_preheat_cleanup
    lacy_shell_cleanup_mcp
    lacy_shell_cleanup_keybindings_bash
    trap - INT
    unset IGNOREEOF
    LACY_SHELL_QUITTING=false
    LACY_SHELL_ENABLED=false
    LACY_SHELL_LOADED=false
}

# Set up PROMPT_COMMAND for post-execution hooks
_LACY_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
if [[ -n "$PROMPT_COMMAND" ]]; then
    PROMPT_COMMAND="lacy_shell_precmd_bash; ${PROMPT_COMMAND}"
else
    PROMPT_COMMAND="lacy_shell_precmd_bash"
fi

# Initialize
lacy_shell_init

# Cleanup on exit
trap lacy_shell_cleanup EXIT
