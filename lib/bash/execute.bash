#!/usr/bin/env bash

# Command execution logic for Lacy Shell — Bash adapter
# Uses bind -x for Enter override + PROMPT_COMMAND for post-exec

# Pending query (set by Enter handler, dispatched by PROMPT_COMMAND)
LACY_SHELL_PENDING_QUERY=""
LACY_SHELL_REROUTE_CANDIDATE=""
_lacy_last_exit=0

# Smart accept-line for Bash — called by bind -x on Enter
lacy_shell_smart_accept_line_bash() {
    # If disabled, let normal readline handle it
    if [[ "$LACY_SHELL_ENABLED" != true ]]; then
        return
    fi

    local input="$READLINE_LINE"

    # Skip empty commands
    if [[ -z "$input" ]]; then
        return
    fi

    # Classify using centralized detection
    local classification
    classification=$(lacy_shell_classify_input "$input")

    case "$classification" in
        "neutral")
            # Let readline process normally
            return
            ;;
        "shell")
            # Trim to check for ! bypass
            local trimmed="$input"
            trimmed="${trimmed#"${trimmed%%[^[:space:]]*}"}"

            if [[ "$trimmed" == !* ]]; then
                trimmed="${trimmed#!}"
                READLINE_LINE="$trimmed"
                READLINE_POINT=${#trimmed}
            fi

            # Handle "exit" — in auto/agent mode quit lacy shell
            local first_word="${trimmed%% *}"
            if [[ "$first_word" == "exit" && "$LACY_SHELL_CURRENT_MODE" != "shell" ]]; then
                READLINE_LINE=""
                READLINE_POINT=0
                lacy_shell_quit
                return
            fi

            # In auto mode, flag commands with NL markers as reroute candidates
            if [[ "$LACY_SHELL_CURRENT_MODE" == "auto" ]] && lacy_shell_has_nl_markers "$trimmed"; then
                LACY_SHELL_REROUTE_CANDIDATE="$trimmed"
            else
                LACY_SHELL_REROUTE_CANDIDATE=""
            fi

            # Let readline execute the command normally
            return
            ;;
        "agent")
            # Add to Bash history
            history -s -- "$input"

            # Defer agent execution to PROMPT_COMMAND
            LACY_SHELL_PENDING_QUERY="$input"
            READLINE_LINE=""
            READLINE_POINT=0
            return
            ;;
    esac
}

# Execute command via AI agent
lacy_shell_execute_agent() {
    local query="$1"

    if ! lacy_shell_query_agent "$query"; then
        if [[ -z "$LACY_ACTIVE_TOOL" ]] && ! command -v lash >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1; then
            # No tool found at all
            echo ""
            lacy_print_color 196 "  No AI tool configured"
            echo ""
            lacy_print_color 238 "  Install one:  npm install -g lashcode"
            lacy_print_color 238 "  Or configure: lacy setup"
            echo ""
        else
            # Tool was found but failed — show recovery hints
            local _tool="${LACY_ACTIVE_TOOL}"
            if [[ -z "$_tool" ]]; then
                local _t
                for _t in lash claude opencode gemini codex; do
                    if command -v "$_t" >/dev/null 2>&1; then
                        _tool="$_t"
                        break
                    fi
                done
            fi
            echo ""
            lacy_print_color 238 "  Try: tool set <name>    Switch to a different tool"
            lacy_print_color 238 "       ask \"your query\"   Send directly to agent"
            lacy_print_color 238 "       lacy doctor        Diagnose issues"
            echo ""
        fi
    fi
}

# Precmd equivalent for Bash — called via PROMPT_COMMAND
lacy_shell_precmd_bash() {
    # Capture exit code immediately
    _lacy_last_exit=$?

    # Ensure terminal state is clean
    printf '\e[?25h'   # Cursor visible
    printf '\e[?7h'    # Line wrapping enabled

    # Don't run if disabled or quitting
    if [[ "$LACY_SHELL_ENABLED" != true || "$LACY_SHELL_QUITTING" == true ]]; then
        LACY_SHELL_REROUTE_CANDIDATE=""
        return
    fi

    # Check reroute candidate
    if [[ -n "$LACY_SHELL_REROUTE_CANDIDATE" ]]; then
        local candidate="$LACY_SHELL_REROUTE_CANDIDATE"
        LACY_SHELL_REROUTE_CANDIDATE=""
        if (( _lacy_last_exit != 0 && _lacy_last_exit < LACY_SIGNAL_EXIT_THRESHOLD )); then
            lacy_shell_execute_agent "$candidate"
            return
        fi
    fi

    # Handle deferred quit triggered by Ctrl-D
    if [[ "$LACY_SHELL_DEFER_QUIT" == true ]]; then
        LACY_SHELL_DEFER_QUIT=false
        LACY_SHELL_REROUTE_CANDIDATE=""
        lacy_shell_quit
        return
    fi

    # Handle pending agent query
    if [[ -n "$LACY_SHELL_PENDING_QUERY" ]]; then
        local pending="$LACY_SHELL_PENDING_QUERY"
        LACY_SHELL_PENDING_QUERY=""
        # Show the query text that was cleared from readline
        printf '\e[38;5;%dm%s\e[0m %s\n' "$LACY_COLOR_AGENT" "$LACY_INDICATOR_CHAR" "$pending"
        lacy_shell_execute_agent "$pending"
    fi

    # Update prompt
    lacy_shell_update_prompt
}

# Mode switching command (Bash version — uses printf instead of print -P)
lacy_shell_mode() {
    case "$1" in
        "shell"|"s")
            lacy_shell_set_mode "shell"
            echo ""
            printf '  \e[38;5;%dm%s\e[0m SHELL mode - all commands execute directly\n' "$LACY_COLOR_SHELL" "$LACY_INDICATOR_CHAR"
            echo ""
            ;;
        "agent"|"a")
            lacy_shell_set_mode "agent"
            echo ""
            printf '  \e[38;5;%dm%s\e[0m AGENT mode - all input goes to AI\n' "$LACY_COLOR_AGENT" "$LACY_INDICATOR_CHAR"
            echo ""
            ;;
        "auto"|"u")
            lacy_shell_set_mode "auto"
            echo ""
            printf '  \e[38;5;%dm%s\e[0m AUTO mode - smart detection\n' "$LACY_COLOR_AUTO" "$LACY_INDICATOR_CHAR"
            echo ""
            ;;
        "toggle"|"t")
            lacy_shell_toggle_mode
            local new_mode="$LACY_SHELL_CURRENT_MODE"
            echo ""
            case "$new_mode" in
                "shell") printf '  \e[38;5;%dm%s\e[0m SHELL mode\n' "$LACY_COLOR_SHELL" "$LACY_INDICATOR_CHAR" ;;
                "agent") printf '  \e[38;5;%dm%s\e[0m AGENT mode\n' "$LACY_COLOR_AGENT" "$LACY_INDICATOR_CHAR" ;;
                "auto")  printf '  \e[38;5;%dm%s\e[0m AUTO mode\n' "$LACY_COLOR_AUTO" "$LACY_INDICATOR_CHAR" ;;
            esac
            echo ""
            ;;
        "status")
            lacy_shell_mode_status
            ;;
        *)
            echo ""
            echo "Usage: mode [shell|agent|auto|toggle|status]"
            echo ""
            echo -n "Current: "
            case "$LACY_SHELL_CURRENT_MODE" in
                "shell") printf '\e[38;5;%dmSHELL\e[0m\n' "$LACY_COLOR_SHELL" ;;
                "agent") printf '\e[38;5;%dmAGENT\e[0m\n' "$LACY_COLOR_AGENT" ;;
                "auto")  printf '\e[38;5;%dmAUTO\e[0m\n' "$LACY_COLOR_AUTO" ;;
            esac
            echo ""
            echo "Colors:"
            printf '  \e[38;5;%dm%s\e[0m Green  = shell command\n' "$LACY_COLOR_SHELL" "$LACY_INDICATOR_CHAR"
            printf '  \e[38;5;%dm%s\e[0m Magenta = agent query\n' "$LACY_COLOR_AGENT" "$LACY_INDICATOR_CHAR"
            echo ""
            ;;
    esac
}

# Tool management command (Bash version)
lacy_shell_tool() {
    case "$1" in
        "")
            echo ""
            if [[ "$LACY_ACTIVE_TOOL" == "custom" ]]; then
                echo "Active tool: custom (${LACY_CUSTOM_TOOL_CMD:-not configured})"
            elif [[ -z "$LACY_ACTIVE_TOOL" ]]; then
                local _detected=""
                local _t
                for _t in lash claude opencode gemini codex; do
                    if command -v "$_t" >/dev/null 2>&1; then
                        _detected="$_t"
                        break
                    fi
                done
                if [[ -n "$_detected" ]]; then
                    echo "Active tool: auto-detect (using $_detected)"
                else
                    echo "Active tool: auto-detect (no tools found)"
                fi
            else
                echo "Active tool: ${LACY_ACTIVE_TOOL}"
            fi
            echo ""
            echo "Available tools:"
            local t
            for t in lash claude opencode gemini codex; do
                if command -v "$t" >/dev/null 2>&1; then
                    printf '  \e[38;5;34m✓\e[0m %s\n' "$t"
                else
                    printf '  \e[38;5;238m○\e[0m %s (not installed)\n' "$t"
                fi
            done
            if [[ -n "$LACY_CUSTOM_TOOL_CMD" ]]; then
                printf '  \e[38;5;34m✓\e[0m custom (%s)\n' "$LACY_CUSTOM_TOOL_CMD"
            else
                printf '  \e[38;5;238m○\e[0m custom (not configured)\n'
            fi
            echo ""
            echo "Usage: tool set <name>"
            echo "       tool set custom \"command -flags\""
            echo ""
            ;;
        set)
            if [[ -z "$2" ]]; then
                echo "Usage: tool set <name>"
                echo "Options: lash, claude, opencode, gemini, codex, custom, auto"
                echo "  tool set custom \"command -flags\""
                return 1
            fi
            if [[ "$2" == "auto" ]]; then
                lacy_preheat_cleanup
                LACY_ACTIVE_TOOL=""
                export LACY_ACTIVE_TOOL
                echo "Tool set to: auto-detect"
            elif [[ "$2" == "custom" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: tool set custom \"command -flags\""
                    return 1
                fi
                lacy_preheat_cleanup
                LACY_ACTIVE_TOOL="custom"
                LACY_CUSTOM_TOOL_CMD="$3"
                export LACY_ACTIVE_TOOL LACY_CUSTOM_TOOL_CMD
                echo "Tool set to: custom ($LACY_CUSTOM_TOOL_CMD)"
            else
                lacy_preheat_cleanup
                LACY_ACTIVE_TOOL="$2"
                export LACY_ACTIVE_TOOL
                echo "Tool set to: $2"
            fi
            ;;
        *)
            echo "Usage: tool [set <name>]"
            echo "Options: lash, claude, opencode, gemini, codex, custom, auto"
            ;;
    esac
}

# Quit lacy shell
lacy_shell_quit() {
    LACY_SHELL_ENABLED=false
    LACY_SHELL_QUITTING=true
    unset LACY_SHELL_ACTIVE

    echo ""
    echo "Exiting Lacy Shell..."
    echo ""

    # Remove our PROMPT_COMMAND entry
    if [[ -n "$_LACY_ORIGINAL_PROMPT_COMMAND" ]]; then
        PROMPT_COMMAND="$_LACY_ORIGINAL_PROMPT_COMMAND"
    else
        PROMPT_COMMAND=""
    fi

    # Cleanup keybindings
    lacy_shell_cleanup_keybindings_bash

    # Terminal reset
    printf '\e[0m'      # Reset attributes
    printf '\e[?7h'     # Line wrapping
    printf '\e[?25h'    # Cursor visible

    # Stop preheated servers
    lacy_preheat_cleanup

    # Unset functions used as commands
    unset -f ask mode tool spinner quit stop 2>/dev/null

    # Define a `lacy` function so user can re-enter by typing `lacy`
    local _ldir="$LACY_SHELL_DIR"
    eval "lacy() {
        if [[ \$# -eq 0 ]]; then
            unset -f lacy 2>/dev/null
            LACY_SHELL_LOADED=false
            source \"${_ldir}/lacy.plugin.bash\"
        else
            command lacy \"\$@\"
        fi
    }"

    # Restore prompt
    lacy_shell_restore_prompt

    echo ""

    LACY_SHELL_QUITTING=false
    LACY_SHELL_LOADED=false
}

# Conversation management
lacy_shell_clear_conversation() {
    rm -f "$LACY_SHELL_CONVERSATION_FILE"
    echo "Conversation history cleared"
}

lacy_shell_show_conversation() {
    if [[ -f "$LACY_SHELL_CONVERSATION_FILE" ]]; then
        cat "$LACY_SHELL_CONVERSATION_FILE"
    else
        echo "No conversation history found"
    fi
}

# Spinner animation command
lacy_shell_spinner() {
    case "$1" in
        "")
            echo ""
            echo "Active spinner: ${LACY_SPINNER_STYLE:-braille}"
            echo ""
            echo "Available animations:"
            lacy_list_spinner_animations
            echo ""
            echo "Usage: spinner set <name>"
            echo "       spinner preview [name|all]"
            echo ""
            ;;
        set)
            if [[ -z "$2" ]]; then
                echo "Usage: spinner set <name>"
                echo "Available: ${LACY_SPINNER_ANIMATIONS[*]} random"
                return 1
            fi
            if [[ "$2" == "random" ]] || _lacy_in_list "$2" "${LACY_SPINNER_ANIMATIONS[@]}"; then
                LACY_SPINNER_STYLE="$2"
                export LACY_SPINNER_STYLE
                echo "Spinner set to: $2"
            else
                echo "Unknown animation: $2"
                echo "Available: ${LACY_SPINNER_ANIMATIONS[*]} random"
                return 1
            fi
            ;;
        preview)
            if [[ "$2" == "all" ]]; then
                echo "Previewing all animations (Ctrl+C to stop)"
                echo ""
                lacy_preview_all_spinners 5
            else
                local style="${2:-${LACY_SPINNER_STYLE:-braille}}"
                if [[ "$style" != "random" ]] && ! _lacy_in_list "$style" "${LACY_SPINNER_ANIMATIONS[@]}"; then
                    echo "Unknown animation: $style"
                    return 1
                fi
                local _saved="$LACY_SPINNER_STYLE"
                LACY_SPINNER_STYLE="$style"
                echo "Previewing: $style (Ctrl+C to stop)"
                lacy_start_spinner
                sleep 3
                lacy_stop_spinner
                LACY_SPINNER_STYLE="$_saved"
            fi
            ;;
        *)
            echo "Usage: spinner [set <name> | preview [name|all]]"
            ;;
    esac
}

# Define command functions (Bash uses functions, not aliases, for reliability)
ask() { lacy_shell_query_agent "$*"; }
mode() { lacy_shell_mode "$@"; }
tool() { lacy_shell_tool "$@"; }
spinner() { lacy_shell_spinner "$@"; }
quit() { lacy_shell_quit; }
stop() { lacy_shell_quit; }
