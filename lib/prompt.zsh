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

# ============================================================================
# Terminal State Helpers (reduces code duplication)
# ============================================================================

# Helper: check if a PID is alive
lacy_shell_pid_is_alive() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        return 1
    fi
    kill -0 "$pid" 2>/dev/null
}

# Save cursor position
lacy_shell_cursor_save() {
    echo -ne "\033[s"
}

# Restore cursor position
lacy_shell_cursor_restore() {
    echo -ne "\033[u"
}

# Set scroll region (line start to line end)
lacy_shell_set_scroll_region() {
    local start="${1:-2}"
    local end="${2:-${LINES:-24}}"
    echo -ne "\033[${start};${end}r"
}

# Reset scroll region to full terminal
lacy_shell_reset_scroll_region() {
    echo -ne "\033[r"
}

# Move cursor to specific position
lacy_shell_cursor_move() {
    local row="$1"
    local col="${2:-1}"
    echo -ne "\033[${row};${col}H"
}

# Clear the current line
lacy_shell_clear_line() {
    echo -ne "\033[K"
}

# Clear entire line (not just from cursor)
lacy_shell_clear_entire_line() {
    echo -ne "\033[2K"
}

# Reset all text attributes
lacy_shell_reset_attrs() {
    echo -ne "\033[0m"
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
        lacy_shell_set_scroll_region 2 "$term_height"
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
    lacy_shell_cursor_save

    # Get terminal dimensions
    local term_height=${LINES:-24}

    # Enable alternate screen buffer for better scrolling
    # This preserves the main buffer's scroll history
    if [[ "${LACY_SHELL_USE_ALT_SCREEN:-no}" == "yes" ]]; then
        echo -ne "\033[?1049h"  # Switch to alternate screen
    fi

    # Set scroll region (line 2 to bottom, leaving line 1 for status)
    # This allows the content area to scroll independently
    lacy_shell_set_scroll_region 2 "$term_height"

    # Move to line 1 and draw the bar
    lacy_shell_cursor_move 1 1
    lacy_shell_draw_top_bar

    # Move to line 2 (start of scroll region)
    lacy_shell_cursor_move 2 1

    # Clear the scrollable area
    echo -ne "\033[J"

    # Mark top bar as active
    LACY_SHELL_TOP_BAR_ACTIVE=true

    # Position cursor at the start of the scrollable area
    lacy_shell_cursor_move 2 1
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
    local right_text="ctrl + space "
    
    # Calculate padding
    local left_len=${#left_text}
    local center_len=${#center_text}
    local right_len=${#right_text}
    local total_len=$((left_len + center_len + right_len))
    local padding=$((term_width - total_len))
    local left_pad=$((padding / 2))
    local right_pad=$((padding - left_pad))
    
    # Save current cursor position and attributes
    lacy_shell_cursor_save
    echo -ne "\033[7s"  # Save cursor attributes

    # Temporarily disable scroll region to draw on line 1
    lacy_shell_reset_scroll_region
    lacy_shell_cursor_move 1 1
    lacy_shell_clear_line

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
    lacy_shell_set_scroll_region 2 "$term_height"

    # Restore cursor attributes and position
    echo -ne "\033[8"  # Restore cursor attributes
    lacy_shell_cursor_restore
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
    lacy_shell_cursor_save

    # Temporarily disable scroll region to draw on line 1
    lacy_shell_reset_scroll_region
    lacy_shell_cursor_move 1 1
    lacy_shell_clear_line

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
    lacy_shell_reset_attrs

    # Re-enable scroll region
    local term_height=${LINES:-24}
    lacy_shell_set_scroll_region 2 "$term_height"

    # Restore cursor position
    lacy_shell_cursor_restore
    
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
    lacy_shell_cursor_save

    # Reset scroll region to full screen (entire terminal)
    lacy_shell_set_scroll_region 1 "${LINES:-24}"
    lacy_shell_reset_scroll_region

    # Exit alternate screen if it was used
    echo -ne "\033[?1049l"

    # Clear the entire first line where the bar was
    lacy_shell_cursor_move 1 1
    lacy_shell_clear_entire_line
    lacy_shell_reset_attrs

    # Restore cursor position
    lacy_shell_cursor_restore

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
        lacy_shell_cursor_save
        lacy_shell_cursor_move "$row" "$col"
        echo -ne "\033[48;5;${bg_color}m\033[38;5;${color}m\033[1m${mode_text}\033[0m"
        lacy_shell_cursor_restore
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
