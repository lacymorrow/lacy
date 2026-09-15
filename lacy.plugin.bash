#!/usr/bin/env bash

# Lacy Shell - Smart shell plugin (Bash adapter)

# Prevent multiple sourcing
if [[ "${LACY_SHELL_LOADED:-}" == "true" ]]; then
    return 0
fi
LACY_SHELL_LOADED=true
export LACY_SHELL_ACTIVE=1

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
    lacy_preheat_init
    lacy_shell_setup_prompt
    lacy_shell_init_mode
    _lacy_bash_install_prompt_hooks
}

# Cleanup
lacy_shell_cleanup() {
    lacy_stop_spinner 2>/dev/null
    lacy_preheat_cleanup
    lacy_shell_cleanup_keybindings_bash
    _lacy_bash_remove_prompt_hooks
    LACY_SHELL_QUITTING=false
    LACY_SHELL_ENABLED=false
    LACY_SHELL_LOADED=false
    unset LACY_SHELL_ACTIVE
}

# Initialize
lacy_shell_init

# One-time install tracking (background, fail-silent)
declare -F _lacy_track_first_load >/dev/null && _lacy_track_first_load

# Cleanup on exit
trap lacy_shell_cleanup EXIT
