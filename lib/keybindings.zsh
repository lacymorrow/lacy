#!/usr/bin/env zsh

# Keybinding setup for Lacy Shell

# Variables for double Ctrl-C detection
LACY_SHELL_LAST_INTERRUPT_TIME=0
LACY_SHELL_QUITTING=false
# Exit timeout configuration is defined in constants.zsh

# Track current input type for real-time indicator
LACY_SHELL_INPUT_TYPE=""  # "shell" or "agent"

# ============================================================================
# Real-time Shell/Agent Indicator
# ============================================================================

# Check if input will go to shell or agent
# Delegates to centralized detection in detection.zsh
lacy_shell_detect_input_type() {
    lacy_shell_classify_input "$1"
}

# Update the indicator based on current input (called on every keystroke)
lacy_shell_update_input_indicator() {
    [[ "$LACY_SHELL_ENABLED" != true ]] && return
    [[ "$LACY_SHELL_PROMPT_INITIALIZED" != true ]] && return
    [[ -z "$LACY_SHELL_BASE_PS1" ]] && return

    local input_type=$(lacy_shell_detect_input_type "$BUFFER")

    # Only update prompt if type changed (avoids flickering)
    if [[ "$input_type" != "$LACY_SHELL_INPUT_TYPE" ]]; then
        LACY_SHELL_INPUT_TYPE="$input_type"

        # Build new PS1 with colored indicator
        # Colors chosen for maximum distinction:
        #   Green (34) = shell command
        #   Magenta (200) = agent query
        #   Dark gray (238) = neutral/empty
        local indicator
        case "$input_type" in
            "shell")
                indicator="%F{34}▌%f"
                ;;
            "agent")
                indicator="%F{200}▌%f"
                ;;
            *)
                indicator="%F{238}▌%f"
                ;;
        esac

        # Update prompt with indicator (appended after prompt, before cursor)
        PS1="${LACY_SHELL_BASE_PS1}${indicator} "

        # Request prompt redraw
        zle && zle reset-prompt
    fi

    # Highlight the first word in the buffer based on classification.
    # Runs on every pre-redraw (not just type changes) because the
    # first word boundaries shift as the user types.
    region_highlight=()
    if [[ -n "$BUFFER" ]]; then
        # Find start of first word (skip leading whitespace)
        local i=0
        while (( i < ${#BUFFER} )) && [[ "${BUFFER:$i:1}" == [[:space:]] ]]; do
            (( i++ ))
        done
        # Find end of first word
        local j=$i
        while (( j < ${#BUFFER} )) && [[ "${BUFFER:$j:1}" != [[:space:]] ]]; do
            (( j++ ))
        done
        if (( j > i )); then
            case "$input_type" in
                "shell")
                    region_highlight+=("$i $j fg=34,bold")
                    ;;
                "agent")
                    region_highlight+=("$i $j fg=200,bold")
                    ;;
            esac
        fi
    fi
}

# ZLE widget that runs before each redraw
lacy_shell_line_pre_redraw() {
    lacy_shell_update_input_indicator
}

# Register the pre-redraw hook
zle -N zle-line-pre-redraw lacy_shell_line_pre_redraw

# Set up all keybindings
lacy_shell_setup_keybindings() {
    # Only add our custom bindings - don't touch existing terminal shortcuts

    # Primary mode toggle - Ctrl+Space (most universal)
    bindkey '^@' lacy_shell_toggle_mode_widget      # Ctrl+Space: Toggle mode

    # Alternative keybindings
    bindkey '^T' lacy_shell_toggle_mode_widget      # Ctrl+T: Toggle mode (backup)

    # Direct mode switches (Ctrl+X prefix)
    # bindkey '^X^A' lacy_shell_agent_mode_widget     # Ctrl+X Ctrl+A: Agent mode
    # bindkey '^X^S' lacy_shell_shell_mode_widget     # Ctrl+X Ctrl+S: Shell mode
    # bindkey '^X^U' lacy_shell_auto_mode_widget      # Ctrl+X Ctrl+U: Auto mode
    # bindkey '^X^H' lacy_shell_help_widget           # Ctrl+X Ctrl+H: Help

    # Terminal scrolling keybindings
    # bindkey '^[[5~' lacy_shell_scroll_up_widget     # Page Up: Scroll up
    # bindkey '^[[6~' lacy_shell_scroll_down_widget   # Page Down: Scroll down
    # bindkey '^Y' lacy_shell_scroll_up_line_widget   # Ctrl+Y: Scroll up one line
    # bindkey '^E' lacy_shell_scroll_down_line_widget # Ctrl+E: Scroll down one line

    # Override Ctrl+D behavior
    bindkey '^D' lacy_shell_delete_char_or_quit_widget  # Ctrl+D: Quit if buffer empty
}

# Widget to toggle mode
lacy_shell_toggle_mode_widget() {
    lacy_shell_toggle_mode
    zle reset-prompt
}

# Widget to switch to agent mode
lacy_shell_agent_mode_widget() {
    lacy_shell_set_mode "agent"
    zle reset-prompt
}

# Widget to switch to shell mode
lacy_shell_shell_mode_widget() {
    lacy_shell_set_mode "shell"
    zle reset-prompt
}

# Widget to switch to auto mode
lacy_shell_auto_mode_widget() {
    lacy_shell_set_mode "auto"
    zle reset-prompt
}

# Widget to show help
lacy_shell_help_widget() {
    echo ""
    echo "Lacy Shell"
    echo ""
    echo "Modes:"
    echo "  Shell  Normal shell execution"
    echo "  Agent  AI-powered assistance"
    echo "  Auto   Smart detection"
    echo ""
    echo "Keys:"
    echo "  Ctrl+Space     Toggle mode"
    echo "  Ctrl+D         Quit"
    echo "  Ctrl+C (2x)    Quit"
    echo ""
    echo "Commands:"
    echo "  ask \"text\"     Query AI"
    echo "  quit_lacy      Exit"
    echo ""
    zle reset-prompt
}

# Widget to clear/cancel current input (was quit)
lacy_shell_quit_widget() {
    # Clear the current line buffer
    BUFFER=""
    # Reset the prompt
    zle reset-prompt
}

# Widget for Ctrl+D - quit if buffer empty, else delete char
lacy_shell_delete_char_or_quit_widget() {
    if [[ -z "$BUFFER" ]]; then
        # Buffer is empty - request deferred quit and consume Ctrl-D safely
        LACY_SHELL_DEFER_QUIT=true
        BUFFER=" :"
        zle .accept-line
    else
        # Buffer has content - normal delete char behavior
        zle delete-char-or-list
    fi
}


# Scrolling widgets
lacy_shell_scroll_up_widget() {
    # Scroll terminal buffer up (page)
    zle -I
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        printf '\e]1337;ScrollPageUp\a'
    elif [[ "$TERM" == "xterm"* ]] || [[ "$TERM" == "screen"* ]]; then
        # Send shift+page up for terminal scrollback
        printf '\e[5;2~'
    else
        # Generic terminal: try to scroll with tput
        tput rin 5 2>/dev/null || printf '\e[5S'
    fi
}

lacy_shell_scroll_down_widget() {
    # Scroll terminal buffer down (page)
    zle -I
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        printf '\e]1337;ScrollPageDown\a'
    elif [[ "$TERM" == "xterm"* ]] || [[ "$TERM" == "screen"* ]]; then
        # Send shift+page down for terminal scrollback
        printf '\e[6;2~'
    else
        # Generic terminal: try to scroll with tput
        tput ri 5 2>/dev/null || printf '\e[5T'
    fi
}

lacy_shell_scroll_up_line_widget() {
    # Scroll terminal buffer up (single line)
    zle -I
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        printf '\e]1337;ScrollLineUp\a'
    elif [[ "$TERM" == "xterm"* ]] || [[ "$TERM" == "screen"* ]]; then
        printf '\eOA'
    else
        # Generic terminal: scroll one line
        tput rin 1 2>/dev/null || printf '\e[S'
    fi
}

lacy_shell_scroll_down_line_widget() {
    # Scroll terminal buffer down (single line)
    zle -I
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        printf '\e]1337;ScrollLineDown\a'
    elif [[ "$TERM" == "xterm"* ]] || [[ "$TERM" == "screen"* ]]; then
        printf '\eOB'
    else
        # Generic terminal: scroll one line
        tput ri 1 2>/dev/null || printf '\e[T'
    fi
}

# Enhanced execute line widget that shows mode info
lacy_shell_execute_line_widget() {
    local input="$BUFFER"

    # If buffer is empty, just accept line normally
    if [[ -z "$input" ]]; then
        zle accept-line
        return
    fi

    # Silent execution - mode shows in prompt

    # Accept the line for normal processing
    zle accept-line
}

# Interrupt handler for double Ctrl-C quit
lacy_shell_interrupt_handler() {
    # Don't handle if disabled
    if [[ "$LACY_SHELL_ENABLED" != true ]]; then
        return 130
    fi

    # Get current time in milliseconds (portable method)
    local current_time
    if command -v gdate >/dev/null 2>&1; then
        # macOS with GNU date installed
        current_time=$(gdate +%s%3N)
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS without GNU date - use python for milliseconds
        current_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
    else
        # Linux and other systems with GNU date
        current_time=$(date +%s%3N)
    fi

    local time_diff=$(( current_time - LACY_SHELL_LAST_INTERRUPT_TIME ))

    # Check if this is a double Ctrl+C within threshold
    if [[ $time_diff -lt $LACY_SHELL_EXIT_TIMEOUT_MS ]]; then
        # Double Ctrl+C detected - quit Lacy Shell
        LACY_SHELL_QUITTING=true

        # Remove precmd hooks IMMEDIATELY to prevent redraw
        precmd_functions=(${precmd_functions:#lacy_shell_precmd})
        precmd_functions=(${precmd_functions:#lacy_shell_update_prompt})

        echo ""
        lacy_shell_quit
        return 130
    else
        # Single Ctrl+C - show hint
        LACY_SHELL_LAST_INTERRUPT_TIME=$current_time
        echo ""
        echo "Press Ctrl-C again to quit"
        return 130
    fi
}

# Set up the interrupt handler
lacy_shell_setup_interrupt_handler() {
    TRAPINT() {
        # Don't handle if already disabled
        if [[ "$LACY_SHELL_ENABLED" != true ]]; then
            return 130
        fi

        # Get current time
        local current_time
        if command -v gdate >/dev/null 2>&1; then
            current_time=$(gdate +%s%3N)
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            current_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
        else
            current_time=$(date +%s%3N)
        fi

        local time_diff=$(( current_time - LACY_SHELL_LAST_INTERRUPT_TIME ))

        if [[ $time_diff -lt $LACY_SHELL_EXIT_TIMEOUT_MS ]]; then
            # Double Ctrl+C - quit
            lacy_shell_quit
            # After quitting, force prompt redraw (best-effort)
            zle -I 2>/dev/null
            zle -R 2>/dev/null
            zle reset-prompt 2>/dev/null
            # Remove this trap itself after quit
            trap - INT
            return 130
        else
            # Single Ctrl+C
            LACY_SHELL_LAST_INTERRUPT_TIME=$current_time
            echo ""
            echo "Press Ctrl-C again to quit"
            return 130
        fi
    }
}

# EOF handler setup for Ctrl-D
lacy_shell_setup_eof_handler() {
    # Prevent Ctrl-D from exiting the shell at all
    # The widget will handle quitting lacy shell
    setopt IGNORE_EOF
    export IGNOREEOF=1000
}

# Cleanup all keybindings
lacy_shell_cleanup_keybindings() {
    # Restore keybindings we override
    bindkey '^D' delete-char-or-list
    bindkey '^@' set-mark-command
    bindkey '^T' transpose-chars

    # Remove real-time indicator hook
    zle -D zle-line-pre-redraw 2>/dev/null

    # Remove custom widgets
    zle -D lacy_shell_toggle_mode_widget 2>/dev/null
    zle -D lacy_shell_delete_char_or_quit_widget 2>/dev/null
}

# Register widgets
zle -N lacy_shell_toggle_mode_widget
zle -N lacy_shell_delete_char_or_quit_widget

# Alternative keybindings that don't conflict with system shortcuts
lacy_shell_setup_safe_keybindings() {
    # Use Alt-based bindings that are less likely to conflict
    bindkey '^[^M' lacy_shell_toggle_mode_widget    # Alt+Enter
    bindkey '^[1' lacy_shell_shell_mode_widget      # Alt+1
    bindkey '^[2' lacy_shell_agent_mode_widget      # Alt+2
    bindkey '^[3' lacy_shell_auto_mode_widget       # Alt+3
    bindkey '^[h' lacy_shell_help_widget            # Alt+H

    echo "Using safe keybindings:"
    echo "  Alt+Enter: Toggle mode"
    echo "  Alt+1:     Shell mode"
    echo "  Alt+2:     Agent mode"
    echo "  Alt+3:     Auto mode"
    echo "  Alt+H:     Help"
}
