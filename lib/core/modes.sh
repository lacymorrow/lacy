#!/usr/bin/env bash

# Mode management for Lacy Shell
# Shared across Bash 4+ and ZSH

# Available modes
LACY_SHELL_MODES=("shell" "agent" "auto")
LACY_SHELL_CURRENT_MODE="auto"

# Mode description helper (replaces associative array for portability)
lacy_mode_description() {
    case "$1" in
        shell) echo "Normal shell execution" ;;
        agent) echo "AI agent assistance via MCP" ;;
        auto)  echo "Try shell commands first, fallback to AI agent" ;;
        *)     echo "Unknown mode" ;;
    esac
}

# Set mode
lacy_shell_set_mode() {
    local new_mode="$1"

    if ! _lacy_in_list "$new_mode" "${LACY_SHELL_MODES[@]}"; then
        echo "Invalid mode: $new_mode. Available modes: ${LACY_SHELL_MODES[*]}"
        return 1
    fi

    LACY_SHELL_CURRENT_MODE="$new_mode"
    lacy_shell_save_mode "$new_mode"

    if type lacy_shell_update_prompt &>/dev/null; then
        lacy_shell_update_prompt
    fi
}

# Get current mode
lacy_shell_get_mode() {
    echo "$LACY_SHELL_CURRENT_MODE"
}

# Toggle between modes
lacy_shell_toggle_mode() {
    local current_index=0
    local i count

    count=${#LACY_SHELL_MODES[@]}

    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        # ZSH: 1-based indexing
        for (( i = 1; i <= count; i++ )); do
            if [[ "${LACY_SHELL_MODES[$i]}" == "$LACY_SHELL_CURRENT_MODE" ]]; then
                current_index=$i
                break
            fi
        done
        local next_index=$(( (current_index % count) + 1 ))
        lacy_shell_set_mode "${LACY_SHELL_MODES[$next_index]}"
    else
        # Bash: 0-based indexing
        for (( i = 0; i < count; i++ )); do
            if [[ "${LACY_SHELL_MODES[$i]}" == "$LACY_SHELL_CURRENT_MODE" ]]; then
                current_index=$i
                break
            fi
        done
        local next_index=$(( (current_index + 1) % count ))
        lacy_shell_set_mode "${LACY_SHELL_MODES[$next_index]}"
    fi
}

# Direct mode switches
lacy_shell_agent_mode() {
    lacy_shell_set_mode "agent"
}

lacy_shell_shell_mode() {
    lacy_shell_set_mode "shell"
}

lacy_shell_auto_mode() {
    lacy_shell_set_mode "auto"
}

# Mode persistence
lacy_shell_save_mode() {
    mkdir -p "$(dirname "$LACY_SHELL_MODE_FILE")"
    echo "$1" > "$LACY_SHELL_MODE_FILE"
}

lacy_shell_init_mode() {
    if [[ -f "$LACY_SHELL_MODE_FILE" ]]; then
        local saved_mode
        saved_mode=$(cat "$LACY_SHELL_MODE_FILE" 2>/dev/null)
        if _lacy_in_list "$saved_mode" "${LACY_SHELL_MODES[@]}"; then
            LACY_SHELL_CURRENT_MODE="$saved_mode"
        else
            LACY_SHELL_CURRENT_MODE="$LACY_SHELL_DEFAULT_MODE"
        fi
    else
        LACY_SHELL_CURRENT_MODE="$LACY_SHELL_DEFAULT_MODE"
    fi
}

# Show mode status
lacy_shell_mode_status() {
    echo ""
    echo -n "Current mode: "
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell") lacy_print_color "$LACY_COLOR_SHELL" "SHELL" ;;
        "agent") lacy_print_color "$LACY_COLOR_AGENT" "AGENT" ;;
        "auto")  lacy_print_color "$LACY_COLOR_AUTO" "AUTO" ;;
        *)       lacy_print_color "$LACY_COLOR_NEUTRAL" "unknown" ;;
    esac
    echo ""
    echo "Description: $(lacy_mode_description "$LACY_SHELL_CURRENT_MODE")"
    echo ""
    echo "Colors:"
    lacy_print_color "$LACY_COLOR_SHELL" "  ${LACY_INDICATOR_CHAR} Green   = shell command"
    lacy_print_color "$LACY_COLOR_AGENT" "  ${LACY_INDICATOR_CHAR} Magenta = agent query"
    lacy_print_color "$LACY_COLOR_AUTO" "  ${LACY_INDICATOR_CHAR} Blue    = auto mode"
    echo ""
}
