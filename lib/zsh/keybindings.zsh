#!/usr/bin/env zsh

# Keybinding setup for Lacy Shell
#
# ============================================================================
# Plugin Coexistence: region_highlight & POSTDISPLAY
# ============================================================================
#
# This file manages two ZLE features that are shared with other plugins
# (notably zsh-autosuggestions): `region_highlight` and `POSTDISPLAY`.
#
# region_highlight
# ----------------
# An array of highlight specs applied to the input buffer + POSTDISPLAY.
# Multiple plugins write to it (autosuggestions for gray suggestion text,
# syntax-highlighting for colorized input, etc.).
#
# Problem:  Lacy needs to highlight the first word (green/magenta) on every
#           keystroke, which requires removing the previous first-word
#           highlight. Naively resetting `region_highlight=()` destroys
#           highlights from other plugins — causing autosuggestion text to
#           turn white (default fg) instead of staying gray.
#
# Solution: Tag every Lacy highlight entry with `memo=lacy` (a ZSH 5.8+
#           region_highlight feature that is ignored by the renderer but lets
#           plugins identify their own entries). On each pre-redraw, strip
#           only memo=lacy entries:
#
#               region_highlight=("${(@)region_highlight:#*memo=lacy*}")
#
#           This preserves highlights from autosuggestions, syntax-highlighting,
#           and any other plugin.
#
# POSTDISPLAY
# -----------
# Text rendered after BUFFER (the user's input). Both Lacy (ghost text
# suggestions after a reroute candidate fails) and zsh-autosuggestions
# (history-based suggestions) write to POSTDISPLAY.
#
# Problem:  When both plugins set POSTDISPLAY in the same redraw cycle, the
#           last writer wins. If autosuggestions runs after Lacy's pre-redraw
#           hook (via add-zle-hook-widget, which coexists with our zle -N
#           registration), it overwrites Lacy's ghost text with an empty
#           string (no history match for an empty buffer).
#
# Solution: When Lacy's ghost text is active, call _zsh_autosuggest_clear
#           (if available) before setting POSTDISPLAY. This tells
#           autosuggestions to stop managing POSTDISPLAY for this cycle.
#           When the user starts typing (BUFFER becomes non-empty), Lacy
#           clears its ghost text and autosuggestions resumes normally.
#
# Right Arrow / Tab (suggestion accept)
# --------------------------------------
# Both Lacy and autosuggestions use right arrow / tab to accept suggestions.
# Lacy's widgets (_lacy_forward_char_or_accept, _lacy_expand_or_accept)
# check for Lacy ghost text first. If present, they accept it into BUFFER.
# If not, they fall through to `forward-char` / `expand-or-complete`
# (WITHOUT the dot prefix) so that autosuggestions' widget wrappers still
# fire and can accept their own suggestions.
#
# Key detail: `zle .forward-char` (dot prefix) calls the raw ZSH builtin,
# bypassing any widget wrapping. `zle forward-char` (no dot) calls the
# named widget, which autosuggestions may have replaced with its wrapper.
# We use the no-dot form so autosuggestions works when Lacy has no ghost text.
#
# ============================================================================

# Interrupt state and input type are initialized in constants.sh

# Ghost text suggestion (shown as POSTDISPLAY after a reroute candidate fails)
LACY_SHELL_SUGGESTION=""
LACY_SHELL_OWN_POSTDISPLAY=false  # true when Lacy is managing POSTDISPLAY

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
        # Colors chosen for maximum distinction (see constants.zsh)
        local indicator
        case "$input_type" in
            "shell")
                indicator="%F{${LACY_COLOR_SHELL}}${LACY_INDICATOR_CHAR}%f"
                ;;
            "agent")
                indicator="%F{${LACY_COLOR_AGENT}}${LACY_INDICATOR_CHAR}%f"
                ;;
            *)
                indicator="%F{${LACY_COLOR_NEUTRAL}}${LACY_INDICATOR_CHAR}%f"
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
    # Remove only our previous highlight (tagged with "memo=lacy") —
    # preserve highlights from zsh-autosuggestions and other plugins.
    region_highlight=("${(@)region_highlight:#*memo=lacy*}")
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
                    region_highlight+=("$i $j fg=${LACY_COLOR_SHELL},bold memo=lacy")
                    ;;
                "agent")
                    region_highlight+=("$i $j fg=${LACY_COLOR_AGENT},bold memo=lacy")
                    ;;
            esac
        fi
    fi

    # Ghost text suggestion — show inline placeholder when buffer is empty.
    # See file header for POSTDISPLAY coexistence design with zsh-autosuggestions.
    if [[ -n "$LACY_SHELL_SUGGESTION" ]]; then
        if [[ -z "$BUFFER" ]]; then
            # Clear autosuggestions' POSTDISPLAY before writing ours.
            # Without this, autosuggestions' pre-redraw hook (registered via
            # add-zle-hook-widget) runs after ours and overwrites POSTDISPLAY
            # with "" (no history match for empty input), making ghost text
            # invisible. _zsh_autosuggest_clear tells it to stop for this cycle.
            unset POSTDISPLAY
            (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear
            POSTDISPLAY="$LACY_SHELL_SUGGESTION"
            LACY_SHELL_OWN_POSTDISPLAY=true
            region_highlight+=("${#BUFFER} $((${#BUFFER} + ${#POSTDISPLAY})) fg=${LACY_COLOR_NEUTRAL} memo=lacy")
        else
            # User started typing — clear ghost text, autosuggestions resumes
            LACY_SHELL_SUGGESTION=""
            POSTDISPLAY=""
            LACY_SHELL_OWN_POSTDISPLAY=false
        fi
    elif [[ "$LACY_SHELL_OWN_POSTDISPLAY" == true ]]; then
        # Suggestion was cleared externally (precmd) — clean up POSTDISPLAY
        POSTDISPLAY=""
        LACY_SHELL_OWN_POSTDISPLAY=false
    fi
}

# ZLE widget that runs before each redraw
lacy_shell_line_pre_redraw() {
    lacy_shell_update_input_indicator
}

# ZLE widget that runs when a new line of input starts — set up ghost text
# before the first pre-redraw so it's visible on the very first render.
# Same POSTDISPLAY coexistence pattern as in lacy_shell_update_input_indicator.
lacy_shell_line_init() {
    if [[ -n "$LACY_SHELL_SUGGESTION" && -z "$BUFFER" ]]; then
        # Suppress autosuggestions before claiming POSTDISPLAY (see file header)
        (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear
        POSTDISPLAY="$LACY_SHELL_SUGGESTION"
        LACY_SHELL_OWN_POSTDISPLAY=true
        region_highlight+=("0 ${#POSTDISPLAY} fg=${LACY_COLOR_NEUTRAL} memo=lacy")
    fi
}

# Register hooks
zle -N zle-line-pre-redraw lacy_shell_line_pre_redraw
zle -N zle-line-init lacy_shell_line_init

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

    # Fix Command+Delete on macOS: send ^U, which ZSH defaults to kill-whole-line.
    # Rebind to backward-kill-line so only text before the cursor is deleted.
    bindkey '^U' backward-kill-line

    # Ghost text suggestion accept (right arrow, tab)
    bindkey '^[[C' _lacy_forward_char_or_accept   # Right arrow
    bindkey '^[OC' _lacy_forward_char_or_accept   # Right arrow (alt sequence)
    bindkey '^I' _lacy_expand_or_accept           # Tab
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
        lacy_print_color "$LACY_COLOR_NEUTRAL" "$LACY_MSG_CTRL_C_HINT"
        return 130
    fi
}

# Set up the interrupt handler
lacy_shell_setup_interrupt_handler() {
    TRAPINT() {
        # CRITICAL: Only intercept SIGINT when ZLE (the line editor) is active,
        # i.e., the user is at the prompt. When a foreground child process is
        # running (e.g., `lash`, `vim`, `python`), we must NOT intercept SIGINT
        # — let it propagate to the child's process group normally. Without this
        # guard, Ctrl+C, paste, and other keyboard shortcuts break in child
        # processes because SIGINT never reaches them.
        if [[ -z "$ZLE_STATE" ]]; then
            # No ZLE active — a child process is running. Use default behavior.
            return $(( 128 + $1 ))
        fi

        # Don't handle if already disabled
        if [[ "$LACY_SHELL_ENABLED" != true ]]; then
            return $(( 128 + $1 ))
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
            unfunction TRAPINT 2>/dev/null
            return 130
        else
            # Single Ctrl+C
            LACY_SHELL_LAST_INTERRUPT_TIME=$current_time
            echo ""
            lacy_print_color "$LACY_COLOR_NEUTRAL" "$LACY_MSG_CTRL_C_HINT"
            return 130
        fi
    }
}

# EOF handler setup for Ctrl-D
lacy_shell_setup_eof_handler() {
    # Prevent Ctrl-D from exiting the shell at all
    # The widget will handle quitting lacy shell
    setopt IGNORE_EOF
    # Note: we intentionally do NOT export IGNOREEOF to the environment.
    # Exporting it would leak into child processes (lash, vim, python, etc.)
    # and alter their EOF handling behavior. The ZSH setopt above is sufficient
    # for the interactive shell itself.
    IGNOREEOF=1000
}

# Cleanup all keybindings
lacy_shell_cleanup_keybindings() {
    # Restore keybindings we override
    bindkey '^D' delete-char-or-list
    bindkey '^@' set-mark-command
    bindkey '^T' transpose-chars
    bindkey '^U' kill-whole-line

    # Restore suggestion accept bindings
    bindkey '^[[C' forward-char
    bindkey '^[OC' forward-char
    bindkey '^I' expand-or-complete

    # Remove hooks
    zle -D zle-line-pre-redraw 2>/dev/null
    zle -D zle-line-init 2>/dev/null

    # Remove custom widgets
    zle -D lacy_shell_toggle_mode_widget 2>/dev/null
    zle -D lacy_shell_delete_char_or_quit_widget 2>/dev/null
    zle -D _lacy_forward_char_or_accept 2>/dev/null
    zle -D _lacy_expand_or_accept 2>/dev/null
}

# Accept ghost text suggestion into buffer.
# Called by right arrow and tab widgets below.
_lacy_try_accept_suggestion() {
    if [[ -n "$LACY_SHELL_SUGGESTION" && -z "$BUFFER" ]]; then
        BUFFER="$LACY_SHELL_SUGGESTION"
        CURSOR=${#BUFFER}
        LACY_SHELL_SUGGESTION=""
        POSTDISPLAY=""
        LACY_SHELL_OWN_POSTDISPLAY=false
        return 0  # consumed — caller should NOT fall through
    fi
    return 1  # no ghost text — caller should fall through to default widget
}

# Right arrow: accept Lacy ghost text if present, otherwise delegate to
# forward-char (no dot prefix — lets autosuggestions' wrapper accept its
# own suggestion). See file header for why the dot prefix matters.
_lacy_forward_char_or_accept() {
    _lacy_try_accept_suggestion || zle forward-char
}

# Tab: accept Lacy ghost text if present, otherwise delegate to
# expand-or-complete (no dot prefix — same reason as above).
_lacy_expand_or_accept() {
    _lacy_try_accept_suggestion || zle expand-or-complete
}

# Register widgets
zle -N lacy_shell_toggle_mode_widget
zle -N lacy_shell_delete_char_or_quit_widget
zle -N _lacy_forward_char_or_accept
zle -N _lacy_expand_or_accept

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
