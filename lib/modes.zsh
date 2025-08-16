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

# Set the current mode
lacy_shell_set_mode() {
    local new_mode="$1"
    
    # Validate mode
    if [[ ! " ${LACY_SHELL_MODES[@]} " =~ " ${new_mode} " ]]; then
        echo "Invalid mode: $new_mode. Available modes: ${LACY_SHELL_MODES[*]}"
        return 1
    fi
    
    LACY_SHELL_CURRENT_MODE="$new_mode"
    
    # Save mode to persistence file
    lacy_shell_save_mode "$new_mode"
    
    # Update prompt if function exists
    if typeset -f lacy_shell_update_prompt > /dev/null; then
        lacy_shell_update_prompt
    fi
    
    # Quiet mode switching - indicator shows in prompt
}

# Get current mode
lacy_shell_get_mode() {
    echo "$LACY_SHELL_CURRENT_MODE"
}

# Toggle between modes
lacy_shell_toggle_mode() {
    local current_index=0
    local next_index=0
    
    # Find current mode index
    for i in {1..${#LACY_SHELL_MODES}}; do
        if [[ "${LACY_SHELL_MODES[$i]}" == "$LACY_SHELL_CURRENT_MODE" ]]; then
            current_index=$i
            break
        fi
    done
    
    # Calculate next mode index (wrap around)
    next_index=$(( (current_index % ${#LACY_SHELL_MODES}) + 1 ))
    
    # Set new mode
    lacy_shell_set_mode "${LACY_SHELL_MODES[$next_index]}"
}

# Switch directly to agent mode
lacy_shell_agent_mode() {
    lacy_shell_set_mode "agent"
}

# Switch directly to shell mode  
lacy_shell_shell_mode() {
    lacy_shell_set_mode "shell"
}

# Switch directly to auto mode
lacy_shell_auto_mode() {
    lacy_shell_set_mode "auto"
}

# Get mode indicator for prompt (matching lash colors)
lacy_shell_get_mode_indicator() {
    # Using colors that match lash's theme:
    # Shell = Secondary (Dolly/pink-ish)
    # Agent = Accent (Zest/bright yellow-orange) 
    # Auto = Primary (Charple/purple)
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell")
            # Shell mode - pink/magenta bar with bold text
            echo "%F{205}▌%f %B%F{205}Shell%b%f"
            ;;
        "agent")
            # Agent mode - bright yellow/orange bar with bold text
            echo "%F{214}▌%f %B%F{214}Agent%b%f"
            ;;
        "auto")
            # Auto mode - purple bar with bold text
            echo "%F{141}▌%f %B%F{141}Auto %b%f"
            ;;
        *)
            # Unknown mode - red bar
            echo "%F{196}▌%f %B%F{196}!%b%f"
            ;;
    esac
}

# Mode persistence functions
LACY_SHELL_MODE_FILE="${HOME}/.lacy-shell/current_mode"

# Save current mode to file
lacy_shell_save_mode() {
    local mode="$1"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$LACY_SHELL_MODE_FILE")"
    
    # Save mode to file
    echo "$mode" > "$LACY_SHELL_MODE_FILE"
}

# Load saved mode from file
lacy_shell_load_saved_mode() {
    # Check if mode file exists
    if [[ -f "$LACY_SHELL_MODE_FILE" ]]; then
        local saved_mode=$(cat "$LACY_SHELL_MODE_FILE" 2>/dev/null)
        
        # Validate the saved mode
        if [[ " ${LACY_SHELL_MODES[@]} " =~ " ${saved_mode} " ]]; then
            echo "$saved_mode"
            return 0
        fi
    fi
    
    # Return default mode if no valid saved mode
    echo "${LACY_SHELL_DEFAULT_MODE:-auto}"
}

# Initialize mode on startup
lacy_shell_init_mode() {
    local saved_mode=$(lacy_shell_load_saved_mode)
    local default_mode="${LACY_SHELL_DEFAULT_MODE:-auto}"
    
    LACY_SHELL_CURRENT_MODE="$saved_mode"
    
    # Show persistence info in debug mode only
    if [[ -n "$LACY_SHELL_DEBUG" && "$saved_mode" != "$default_mode" ]]; then
        echo "Restored mode: $saved_mode"
    fi
    
    # Don't save on init to avoid overwriting with default
    # The mode will be saved when user explicitly changes it
}

# Show mode persistence status
lacy_shell_mode_status() {
    echo "Current mode: $LACY_SHELL_CURRENT_MODE"
    echo "Default mode: ${LACY_SHELL_DEFAULT_MODE:-auto}"
    
    if [[ -f "$LACY_SHELL_MODE_FILE" ]]; then
        local saved_mode=$(cat "$LACY_SHELL_MODE_FILE" 2>/dev/null)
        echo "Saved mode: $saved_mode"
        echo "Mode file: $LACY_SHELL_MODE_FILE"
    else
        echo "No saved mode (using default)"
    fi
}
