#!/usr/bin/env zsh

# Lacy Shell - Smart shell plugin with MCP support

# Prevent multiple sourcing of module definitions
if [[ "${LACY_SHELL_LOADED:-}" == "true" ]]; then
    return 0
fi
LACY_SHELL_LOADED=true

# Plugin directory
LACY_SHELL_DIR="${0:A:h}"

# Shell type identification (used by shared core)
LACY_SHELL_TYPE="zsh"
_LACY_ARR_OFFSET=1

# Load shared core + ZSH adapter modules (defines functions, does NOT activate)
source "$LACY_SHELL_DIR/lib/zsh/init.zsh"

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
    unset LACY_SHELL_ACTIVE
}

# Activate: hook into ZSH and start Lacy Shell.
# Safe to call multiple times — guards against double-activation.
lacy_shell_activate() {
    if [[ "${LACY_SHELL_ACTIVE:-}" == "1" ]]; then
        lacy_print_color "${LACY_COLOR_AGENT}" "  Lacy is already active  (type 'lacy off' to deactivate)"
        return 0
    fi

    LACY_SHELL_ENABLED=true
    export LACY_SHELL_ACTIVE=1

    # Hook into ZSH
    zle -N accept-line lacy_shell_smart_accept_line
    preexec_functions+=(lacy_shell_preexec)
    precmd_functions+=(lacy_shell_precmd)

    lacy_shell_init
    trap lacy_shell_cleanup EXIT
}

# lacy() — persistent shell function, survives deactivation.
# Routes `lacy on/off` to activation/deactivation; delegates everything
# else to the `lacy` CLI binary.
lacy() {
    case "${1:-}" in
        on|start|activate)
            lacy_shell_activate
            ;;
        off|stop|deactivate)
            lacy_shell_quit
            ;;
        "")
            # No args while active → show status; while inactive → activate
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
# To suppress: export LACY_AUTO_START=false  (in .zshrc, before sourcing lacy)
# ============================================================================
if [[ "${LACY_AUTO_START:-true}" != "false" ]]; then
    lacy_shell_activate
fi
