#!/usr/bin/env zsh

# Mode management for Lacy Shell

# Available modes
LACY_SHELL_MODES=("shell" "agent" "auto")
LACY_SHELL_CURRENT_MODE="auto"

# Mode descriptions
typeset -A LACY_SHELL_MODE_DESCRIPTIONS
LACY_SHELL_MODE_DESCRIPTIONS[shell]="Normal shell execution"
LACY_SHELL_MODE_DESCRIPTIONS[agent]="AI agent assistance via MCP"
LACY_SHELL_MODE_DESCRIPTIONS[auto]="Try shell commands first, fallback to AI agent"

# Set mode
lacy_shell_set_mode() {
    local new_mode="$1"
    
    if [[ ! " ${LACY_SHELL_MODES[@]} " =~  ${new_mode}  ]]; then
        echo "Invalid mode: $new_mode. Available modes: ${LACY_SHELL_MODES[*]}"
        return 1
    fi
    
    LACY_SHELL_CURRENT_MODE="$new_mode"
    lacy_shell_save_mode "$new_mode"
    
    if typeset -f lacy_shell_update_prompt > /dev/null; then
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
    
    for i in {1..${#LACY_SHELL_MODES}}; do
        if [[ "${LACY_SHELL_MODES[$i]}" == "$LACY_SHELL_CURRENT_MODE" ]]; then
            current_index=$i
            break
        fi
    done
    
    local next_index=$(( (current_index % ${#LACY_SHELL_MODES}) + 1 ))
    lacy_shell_set_mode "${LACY_SHELL_MODES[$next_index]}"
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
        local saved_mode=$(cat "$LACY_SHELL_MODE_FILE" 2>/dev/null)
        if [[ " ${LACY_SHELL_MODES[@]} " =~  ${saved_mode}  ]]; then
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
        "shell") print -P "%F{34}SHELL%f" ;;
        "agent") print -P "%F{200}AGENT%f" ;;
        "auto")  print -P "%F{75}AUTO%f" ;;
        *)       print -P "%F{238}unknown%f" ;;
    esac
    echo ""
    echo "Description: ${LACY_SHELL_MODE_DESCRIPTIONS[$LACY_SHELL_CURRENT_MODE]}"
    echo ""
    echo "Colors:"
    print -P "  %F{34}▌%f Green   = shell command"
    print -P "  %F{200}▌%f Magenta = agent query"
    print -P "  %F{75}▌%f Blue    = auto mode"
    echo ""
}