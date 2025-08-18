#!/usr/bin/env zsh

# Prompt modifications for Lacy Shell

# Store original prompts
LACY_SHELL_ORIGINAL_PS1="$PS1"
LACY_SHELL_ORIGINAL_RPS1="$RPS1"
LACY_SHELL_BASE_PS1=""

# Mode indicator display style
LACY_SHELL_INDICATOR_STYLE="$LACY_SHELL_DEFAULT_INDICATOR_STYLE"

# Track if top bar is active
LACY_SHELL_TOP_BAR_ACTIVE=false
# PID of any scheduled top bar message redraw job
LACY_SHELL_MESSAGE_JOB_PID=""

# Helper: check if a PID is alive
lacy_shell_pid_is_alive() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        return 1
    fi
    kill -0 "$pid" 2>/dev/null
}

# Setup prompt integration
lacy_shell_setup_prompt() {
    # Store the base PS1 for later use
    LACY_SHELL_BASE_PS1="$PS1"
    
    # Ensure we don't register redundant precmd updaters; rely on lacy_shell_precmd
    precmd_functions=(${precmd_functions:#lacy_shell_update_prompt})
    
    # Set up terminal resize handler
    trap 'lacy_shell_handle_resize' WINCH
    
    # Initial prompt update
    lacy_shell_update_prompt
}

# Handle terminal resize
lacy_shell_handle_resize() {
    # Redraw based on current style
    if [[ "$LACY_SHELL_INDICATOR_STYLE" == "top" && "$LACY_SHELL_TOP_BAR_ACTIVE" == true ]]; then
        # If a message redraw job is pending, skip drawing to avoid overwriting the message
        if [[ -n "$LACY_SHELL_MESSAGE_JOB_PID" ]] && lacy_shell_pid_is_alive "$LACY_SHELL_MESSAGE_JOB_PID"; then
            return
        fi
        # Recalculate scroll region for new size
        local term_height=${LINES:-24}
        echo -ne "\033[2;${term_height}r"
        # Redraw the top bar
        lacy_shell_draw_top_bar
    fi
}

# Update prompt with mode indicator
lacy_shell_update_prompt() {
    # Store base PS1 if not already stored
    if [[ -z "$LACY_SHELL_BASE_PS1" ]]; then
        LACY_SHELL_BASE_PS1="$PS1"
    fi
    
    case "$LACY_SHELL_INDICATOR_STYLE" in
        "top")
            # If a message redraw job is pending, do not redraw the bar; keep the message visible
            if [[ -n "$LACY_SHELL_MESSAGE_JOB_PID" ]] && lacy_shell_pid_is_alive "$LACY_SHELL_MESSAGE_JOB_PID"; then
                PS1="$LACY_SHELL_BASE_PS1"
                RPS1=""
                return
            fi
            # Update top bar if active, otherwise set it up
            if [[ "$LACY_SHELL_TOP_BAR_ACTIVE" == true ]]; then
                # Just redraw the bar without resetting scroll region
                lacy_shell_draw_top_bar
            else
                lacy_shell_setup_top_bar
            fi
            # Keep prompt clean
            PS1="$LACY_SHELL_BASE_PS1"
            RPS1=""
            ;;
        "right")
            # Use right-side prompt for mode indicator
            local mode_indicator=$(lacy_shell_get_mode_indicator)
            RPS1="$mode_indicator"
            PS1="$LACY_SHELL_BASE_PS1"
            # Remove top bar if it was active
            lacy_shell_remove_top_bar
            ;;
        *)
            # Default: prompt style - prepend to left prompt
            local mode_indicator=$(lacy_shell_get_mode_indicator)
            PS1="${mode_indicator}  ${LACY_SHELL_BASE_PS1}"
            RPS1=""
            # Remove top bar if it was active
            lacy_shell_remove_top_bar
            ;;
    esac
    
    # Export the prompts to ensure they persist
    export PS1
    export RPS1
}

# Toggle between different indicator styles
lacy_shell_toggle_indicator_style() {
    case "$LACY_SHELL_INDICATOR_STYLE" in
        "prompt")
            LACY_SHELL_INDICATOR_STYLE="right"
            echo "Mode indicator switched to right-side prompt"
            ;;
        "right")
            LACY_SHELL_INDICATOR_STYLE="top"
            echo "Mode indicator switched to top status bar"
            ;;
        *)
            LACY_SHELL_INDICATOR_STYLE="prompt"
            echo "Mode indicator switched to left prompt"
            ;;
    esac
    
    # Force prompt update
    lacy_shell_update_prompt
}

# Setup top status bar with scroll region
lacy_shell_setup_top_bar() {
    # Save cursor position
    echo -ne "\033[s"
    
    # Get terminal dimensions
    local term_height=${LINES:-24}
    
    # Enable alternate screen buffer for better scrolling
    # This preserves the main buffer's scroll history
    if [[ "${LACY_SHELL_USE_ALT_SCREEN:-no}" == "yes" ]]; then
        echo -ne "\033[?1049h"  # Switch to alternate screen
    fi
    
    # Set scroll region (line 2 to bottom, leaving line 1 for status)
    # This allows the content area to scroll independently
    echo -ne "\033[2;${term_height}r"
    
    # Move to line 1 and draw the bar
    echo -ne "\033[1;1H"
    lacy_shell_draw_top_bar
    
    # Move to line 2 (start of scroll region)
    echo -ne "\033[2;1H"
    
    # Clear the scrollable area
    echo -ne "\033[J"
    
    # Mark top bar as active
    LACY_SHELL_TOP_BAR_ACTIVE=true
    
    # Position cursor at the start of the scrollable area
    echo -ne "\033[2;1H"
}

# Draw the top status bar
lacy_shell_draw_top_bar() {
    if [[ "$LACY_SHELL_TOP_BAR_ACTIVE" != true ]]; then
        return
    fi
    
    local mode_text=""
    local color=""
    
    # Get color and text based on mode
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell")
            mode_text="SHELL"
            color="205"  # Pink/Magenta
            ;;
        "agent")
            mode_text="AGENT"
            color="214"  # Bright yellow/orange
            ;;
        "auto")
            mode_text="AUTO"
            color="141"  # Purple
            ;;
        *)
            mode_text="!"
            color="196"  # Red
            ;;
    esac
    
    # Get terminal width
    local term_width=${COLUMNS:-80}
    
    # Create the status bar content (minimal)
    local left_text=" Lacy"
    local center_text="${mode_text}"
    local right_text="^Space "
    
    # Calculate padding
    local left_len=${#left_text}
    local center_len=${#center_text}
    local right_len=${#right_text}
    local total_len=$((left_len + center_len + right_len))
    local padding=$((term_width - total_len))
    local left_pad=$((padding / 2))
    local right_pad=$((padding - left_pad))
    
    # Save current cursor position and attributes
    echo -ne "\033[s"
    echo -ne "\033[7s"  # Save cursor attributes
    
    # Temporarily disable scroll region to draw on line 1
    echo -ne "\033[r"
    
    # Move to top line
    echo -ne "\033[1;1H"
    
    # Clear the line
    echo -ne "\033[K"
    
    # Draw the status bar with background
    echo -ne "\033[48;5;235m"  # Dark gray background
    echo -ne "\033[38;5;${color}m${left_text}\033[0m"
    echo -ne "\033[48;5;235m"  # Continue background
    printf "%${left_pad}s" ""  # Left padding
    echo -ne "\033[38;5;${color}m\033[1m${center_text}\033[0m"
    echo -ne "\033[48;5;235m"  # Continue background
    printf "%${right_pad}s" ""  # Right padding
    echo -ne "\033[38;5;245m${right_text}\033[0m"
    
    # Re-enable scroll region (line 2 to bottom)
    local term_height=${LINES:-24}
    echo -ne "\033[2;${term_height}r"
    
    # Restore cursor attributes and position
    echo -ne "\033[8"  # Restore cursor attributes
    echo -ne "\033[u"
}

# Show a temporary message in the top bar
lacy_shell_show_top_bar_message() {
    local message="$1"
    local duration="${2:-$LACY_SHELL_MESSAGE_DURATION_SEC}"
    
    if [[ "$LACY_SHELL_TOP_BAR_ACTIVE" != true ]]; then
        return
    fi
    
    # Cancel any previously scheduled redraw job
    if [[ -n "$LACY_SHELL_MESSAGE_JOB_PID" ]]; then
        kill -TERM "$LACY_SHELL_MESSAGE_JOB_PID" 2>/dev/null
        wait "$LACY_SHELL_MESSAGE_JOB_PID" 2>/dev/null
        LACY_SHELL_MESSAGE_JOB_PID=""
    fi
    
    # Temporarily disable job notifications
    local old_notify="${notify:-}"
    unsetopt notify 2>/dev/null
    setopt no_monitor 2>/dev/null
    
    # Get terminal width
    local term_width=${COLUMNS:-80}
    
    # Save current cursor position
    echo -ne "\033[s"
    
    # Temporarily disable scroll region to draw on line 1
    echo -ne "\033[r"
    
    # Move to top line
    echo -ne "\033[1;1H"
    
    # Clear the line
    echo -ne "\033[K"
    
    # Draw the message bar with subtle styling
    local left_text=" Lacy"
    local center_text="$message"
    
    # Calculate padding for center alignment
    local left_len=${#left_text}
    local center_len=${#center_text}
    local total_len=$((left_len + center_len))
    local padding=$((term_width - total_len))
    local left_pad=$((padding / 2))
    local right_pad=$((padding - left_pad))
    
    # Draw with subtle colors
    echo -ne "\033[48;5;235m"  # Dark gray background
    echo -ne "\033[38;5;245m${left_text}\033[0m"
    echo -ne "\033[48;5;235m"  # Continue background
    printf "%${left_pad}s" ""  # Left padding
    echo -ne "\033[38;5;250m${center_text}\033[0m"  # Light gray text for message
    echo -ne "\033[48;5;235m"  # Continue background
    printf "%${right_pad}s" ""  # Right padding to fill line
    echo -ne "\033[0m"
    
    # Re-enable scroll region
    local term_height=${LINES:-24}
    echo -ne "\033[2;${term_height}r"
    
    # Restore cursor position
    echo -ne "\033[u"
    
    # Schedule redraw of normal bar after duration
    # Use disown to prevent job notifications and track PID for cancellation
    {
        sleep "$duration"
        lacy_shell_draw_top_bar
    } 2>/dev/null &!
    LACY_SHELL_MESSAGE_JOB_PID=$!
    
    # Restore job notification settings
    if [[ -n "$old_notify" ]]; then
        setopt notify 2>/dev/null
    fi
    unsetopt no_monitor 2>/dev/null
}

# Remove top status bar and restore normal scrolling
lacy_shell_remove_top_bar() {
    # Always attempt to reset terminal state when removing top bar
    # This ensures cleanup even if state tracking is inconsistent
    
    # Cancel any scheduled redraw job to prevent bar from reappearing
    if [[ -n "$LACY_SHELL_MESSAGE_JOB_PID" ]]; then
        kill -TERM "$LACY_SHELL_MESSAGE_JOB_PID" 2>/dev/null
        wait "$LACY_SHELL_MESSAGE_JOB_PID" 2>/dev/null
        LACY_SHELL_MESSAGE_JOB_PID=""
    fi
    
    # Save cursor position
    echo -ne "\033[s"
    
    # Reset scroll region to full screen (entire terminal)
    echo -ne "\033[1;${LINES:-24}r"
    echo -ne "\033[r"
    
    # Exit alternate screen if it was used
    echo -ne "\033[?1049l"
    
    # Clear the entire first line where the bar was
    echo -ne "\033[1;1H"  # Move to line 1, column 1
    echo -ne "\033[2K"    # Clear entire line
    
    # Also clear any residual formatting
    echo -ne "\033[0m"    # Reset all attributes
    
    # Restore cursor position
    echo -ne "\033[u"
    
    # Mark top bar as inactive
    LACY_SHELL_TOP_BAR_ACTIVE=false
    
    # Force a prompt redraw to clean up display
    if [[ -n "$ZLE_VERSION" ]]; then
        zle && zle reset-prompt 2>/dev/null || true
    fi
}

# Draw mode indicator in fixed bottom-right position
lacy_shell_draw_bottom_right_indicator() {
    local mode_text=""
    local color=""
    local bg_color=""
    
    # Get color and text based on mode
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell")
            mode_text=" Shell "
            color="205"  # Pink/Magenta
            bg_color="235"  # Dark gray background
            ;;
        "agent")
            mode_text=" Agent "
            color="214"  # Bright yellow/orange
            bg_color="235"  # Dark gray background
            ;;
        "auto")
            mode_text=" Auto  "
            color="141"  # Purple
            bg_color="235"  # Dark gray background
            ;;
        *)
            mode_text="   !   "
            color="196"  # Red
            bg_color="235"  # Dark gray background
            ;;
    esac
    
    # Get terminal dimensions
    local term_width=${COLUMNS:-80}
    local term_height=${LINES:-24}
    
    # Calculate position (bottom right corner)
    local indicator_length=${#mode_text}
    local row=$((term_height))
    local col=$((term_width - indicator_length + 1))
    
    # Ensure we don't go out of bounds
    if [[ $col -lt 1 ]]; then
        col=1
    fi
    
    # Draw the indicator using tput for better compatibility
    if command -v tput >/dev/null 2>&1; then
        # Save cursor position
        tput sc
        # Move to bottom right
        tput cup $((row - 1)) $((col - 1))
        # Set colors and print
        echo -ne "\033[48;5;${bg_color}m\033[38;5;${color}m\033[1m${mode_text}\033[0m"
        # Restore cursor position
        tput rc
    else
        # Fallback to ANSI escape sequences
        echo -ne "\033[s"                                    # Save cursor
        echo -ne "\033[${row};${col}H"                      # Move to position
        echo -ne "\033[48;5;${bg_color}m\033[38;5;${color}m\033[1m${mode_text}\033[0m"
        echo -ne "\033[u"                                    # Restore cursor
    fi
}

# Get a simple text mode indicator (for scripts)
lacy_shell_get_mode_text() {
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell")
            echo "SHELL"
            ;;
        "agent")
            echo "AGENT"
            ;;
        "auto")
            echo "AUTO"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

# Restore original prompt
lacy_shell_restore_prompt() {
    PS1="$LACY_SHELL_ORIGINAL_PS1"
    RPS1="$LACY_SHELL_ORIGINAL_RPS1"
}

# Integration with Oh My Zsh themes
lacy_shell_setup_omz_integration() {
    # If Oh My Zsh is detected, integrate with themes
    if [[ -n "$ZSH" && -d "$ZSH" ]]; then
        # Create a custom prompt element that themes can use
        function lacy_shell_prompt_info() {
            echo "$(lacy_shell_get_mode_indicator)"
        }
        
        # Add to Oh My Zsh prompt functions
        if [[ -z "${PROMPT_FUNCTIONS[(r)lacy_shell_prompt_info]}" ]]; then
            PROMPT_FUNCTIONS+=(lacy_shell_prompt_info)
        fi
    fi
}

# Integration with Powerlevel10k
lacy_shell_setup_p10k_integration() {
    # Check if Powerlevel10k is being used
    if [[ -n "$POWERLEVEL9K_MODE" || -n "$POWERLEVEL10K_MODE" ]]; then
        # Define custom prompt segment for P10k
        function prompt_lacy_shell() {
            local mode_text=$(lacy_shell_get_mode_text)
            local color
            
            case "$LACY_SHELL_CURRENT_MODE" in
                "shell")
                    color="green"
                    ;;
                "agent")
                    color="blue"
                    ;;
                "auto")
                    color="yellow"
                    ;;
                *)
                    color="red"
                    ;;
            esac
            
            p10k segment -f "$color" -t "$mode_text"
        }
        
        # Register the segment
        if typeset -f p10k >/dev/null; then
            POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(lacy_shell)
        fi
    fi
}

# Auto-detect and integrate with various prompt systems
lacy_shell_auto_integrate_prompt() {
    # Try different integration methods
    lacy_shell_setup_omz_integration
    lacy_shell_setup_p10k_integration
    
    # Fallback to simple prompt modification
    lacy_shell_update_prompt
}
