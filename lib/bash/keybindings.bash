#!/usr/bin/env bash

# Keybinding setup for Lacy Shell — Bash adapter
# Uses bind -x for Enter override and Ctrl+Space toggle

# Variables for double Ctrl-C detection
LACY_SHELL_LAST_INTERRUPT_TIME=0
LACY_SHELL_QUITTING=false
LACY_SHELL_INPUT_TYPE=""

# Save original IGNOREEOF
_LACY_ORIGINAL_IGNOREEOF="${IGNOREEOF:-}"

# Set up all keybindings
lacy_shell_setup_keybindings() {
    # Bind our classification function to a hidden key sequence.
    # We can't bind -x directly to \C-m because bind -x replaces the
    # key action entirely — accept-line never fires, so shell commands
    # never submit. Instead, \C-m is a macro: call classification, then
    # \C-j (accept-line). Classification can clear READLINE_LINE for
    # agent queries; accept-line then submits the (possibly empty) line.
    bind -x '"\C-x\C-l": lacy_shell_smart_accept_line_bash'
    bind '"\C-m": "\C-x\C-l\C-j"'

    # Ctrl+Space: Toggle mode
    # Bash can't redraw the prompt from bind -x (PS1 changes don't take
    # effect until next prompt cycle). So we bind Ctrl+Space to a macro
    # that clears the current line, types our internal toggle command,
    # and sends accept-line (\C-j). We use \C-j (newline) instead of
    # \C-m because \C-m is overridden by our macro.
    bind '"\C-@": "\C-a\C-k _lacy_mode_toggle_\C-j"'

    # Ensure \C-j is bound to accept-line (used by macros above)
    bind '"\C-j": accept-line'

    # Prevent Ctrl-D from exiting the shell
    IGNOREEOF=1000
}

# Hidden command executed by the Ctrl+Space macro.
# Runs as a real command so PROMPT_COMMAND fires afterward with updated PS1.
_lacy_mode_toggle_() {
    # Remove this injected command from history
    history -d "$(history 1 | awk '{print $1}')" 2>/dev/null
    lacy_shell_toggle_mode
    lacy_shell_update_prompt
    local new_mode="$LACY_SHELL_CURRENT_MODE"
    # Move up and clear the echoed command line, then print feedback
    printf '\e[A\e[2K\r'
    case "$new_mode" in
        "shell") printf '  \e[38;5;%dm%s\e[0m SHELL mode\n' "$LACY_COLOR_SHELL" "$LACY_INDICATOR_CHAR" ;;
        "agent") printf '  \e[38;5;%dm%s\e[0m AGENT mode\n' "$LACY_COLOR_AGENT" "$LACY_INDICATOR_CHAR" ;;
        "auto")  printf '  \e[38;5;%dm%s\e[0m AUTO mode\n' "$LACY_COLOR_AUTO" "$LACY_INDICATOR_CHAR" ;;
    esac
}

# Interrupt handler for double Ctrl-C quit
lacy_shell_interrupt_handler_bash() {
    # Don't handle if disabled
    if [[ "$LACY_SHELL_ENABLED" != true ]]; then
        return
    fi

    # Get current time in milliseconds (portable, no python3 overhead)
    local current_time
    if command -v gdate >/dev/null 2>&1; then
        current_time=$(gdate +%s%3N)
    elif date +%s%3N 2>/dev/null | grep -q '^[0-9]*$'; then
        current_time=$(date +%s%3N)
    else
        # macOS: second-precision fallback (adequate for double-tap detection)
        current_time=$(( $(date +%s) * 1000 ))
    fi

    local time_diff=$(( current_time - LACY_SHELL_LAST_INTERRUPT_TIME ))

    if [[ $time_diff -lt $LACY_SHELL_EXIT_TIMEOUT_MS ]]; then
        # Double Ctrl+C — quit
        echo ""
        lacy_shell_quit
    else
        LACY_SHELL_LAST_INTERRUPT_TIME=$current_time
        echo ""
        echo "Press Ctrl-C again to quit"
    fi
}

# Set up the interrupt handler
lacy_shell_setup_interrupt_handler() {
    trap 'lacy_shell_interrupt_handler_bash' INT
}

# EOF handler (Ctrl-D) — IGNOREEOF handles it, but we add deferred quit
lacy_shell_setup_eof_handler() {
    IGNOREEOF=1000
}

# Cleanup keybindings
lacy_shell_cleanup_keybindings_bash() {
    # Restore Enter to default readline behavior
    bind '"\C-m": accept-line' 2>/dev/null

    # Remove hidden classification key
    bind -r '"\C-x\C-l"' 2>/dev/null

    # Restore Ctrl+Space and \C-j to defaults
    bind '"\C-@": set-mark' 2>/dev/null
    bind '"\C-j": accept-line' 2>/dev/null

    # Restore IGNOREEOF
    if [[ -n "$_LACY_ORIGINAL_IGNOREEOF" ]]; then
        IGNOREEOF="$_LACY_ORIGINAL_IGNOREEOF"
    else
        unset IGNOREEOF
    fi

    # Remove interrupt trap
    trap - INT
}
