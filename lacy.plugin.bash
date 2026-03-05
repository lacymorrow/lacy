#!/usr/bin/env bash

# Lacy Shell - Smart shell plugin with MCP support (Bash adapter)

# Prevent multiple sourcing of module definitions
if [[ "${LACY_SHELL_LOADED:-}" == "true" ]]; then
    return 0
fi
LACY_SHELL_LOADED=true

# Plugin directory
LACY_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shell type identification (used by shared core)
LACY_SHELL_TYPE="bash"
_LACY_ARR_OFFSET=0

# Load shared core + Bash adapter modules (defines functions, does NOT activate)
source "$LACY_SHELL_DIR/lib/bash/init.bash" || {
    LACY_SHELL_LOADED=false
    return 1
}

# Initialize internals — called from lacy_shell_activate
lacy_shell_init() {
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

# Cleanup — called on deactivation and shell EXIT trap
lacy_shell_cleanup() {
    lacy_stop_spinner 2>/dev/null
    lacy_preheat_cleanup
    lacy_shell_cleanup_mcp
    lacy_shell_cleanup_keybindings_bash
    trap - INT
    unset IGNOREEOF
    # Restore original PROMPT_COMMAND
    if [[ -n "${_LACY_ORIGINAL_PROMPT_COMMAND+x}" ]]; then
        PROMPT_COMMAND="$_LACY_ORIGINAL_PROMPT_COMMAND"
        unset _LACY_ORIGINAL_PROMPT_COMMAND
    fi
    LACY_SHELL_QUITTING=false
    LACY_SHELL_ENABLED=false
    unset LACY_SHELL_ACTIVE
}

# Activate: hook into Bash and start Lacy Shell.
# Safe to call multiple times — guards against double-activation.
lacy_shell_activate() {
    if [[ "${LACY_SHELL_ACTIVE:-}" == "1" ]]; then
        printf '\e[38;5;200m  Lacy is already active  (type '"'"'lacy off'"'"' to deactivate)\e[0m\n'
        return 0
    fi

    LACY_SHELL_ENABLED=true
    export LACY_SHELL_ACTIVE=1

    # Capture current PROMPT_COMMAND so cleanup can restore it
    _LACY_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
    if [[ -n "$PROMPT_COMMAND" ]]; then
        PROMPT_COMMAND="lacy_shell_precmd_bash; ${PROMPT_COMMAND}"
    else
        PROMPT_COMMAND="lacy_shell_precmd_bash"
    fi

    lacy_shell_init
    trap lacy_shell_cleanup EXIT
}

# lacy() — persistent shell function, survives deactivation.
lacy() {
    case "${1:-}" in
        on|start|activate)
            lacy_shell_activate
            ;;
        off|stop|deactivate)
            lacy_shell_quit
            ;;
        "")
            if [[ "${LACY_SHELL_ACTIVE:-}" == "1" ]]; then
                command lacy status
            else
                lacy_shell_activate
            fi
            ;;
        *)
            command lacy "$@"
            ;;
    esac
}

# ============================================================================
# Auto-start
# Default: activate immediately (preserves existing behaviour).
# To suppress: export LACY_AUTO_START=false  (in .bashrc, before sourcing lacy)
# ============================================================================
if [[ "${LACY_AUTO_START:-true}" != "false" ]]; then
    lacy_shell_activate
fi
