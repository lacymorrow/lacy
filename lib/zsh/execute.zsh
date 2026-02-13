#!/usr/bin/env zsh

# Command execution logic for Lacy Shell

# Smart accept-line widget that handles agent queries
lacy_shell_smart_accept_line() {
    # If Lacy Shell is disabled, use normal accept-line
    if [[ "$LACY_SHELL_ENABLED" != true ]]; then
        zle .accept-line
        return
    fi

    local input="$BUFFER"

    # Skip empty commands
    if [[ -z "$input" ]]; then
        zle .accept-line
        return
    fi

    # Classify using centralized detection (handles whitespace trimming internally)
    local classification
    classification=$(lacy_shell_classify_input "$input")

    case "$classification" in
        "neutral")
            zle .accept-line
            return
            ;;
        "shell")
            # Trim input to check for ! bypass
            local trimmed="$input"
            trimmed="${trimmed#"${trimmed%%[^[:space:]]*}"}"

            if [[ "$trimmed" == !* ]]; then
                # Strip the ! prefix, keep everything after it
                trimmed="${trimmed#!}"
                BUFFER="$trimmed"
            fi

            # Handle "exit" explicitly: in shell mode pass through to builtin,
            # in auto/agent mode quit lacy shell
            local first_word="${trimmed%% *}"
            if [[ "$first_word" == "exit" && "$LACY_SHELL_CURRENT_MODE" != "shell" ]]; then
                lacy_shell_quit
                return
            fi

            # In auto mode, flag commands with NL markers as reroute candidates.
            # Explicit "mode shell" should never re-route.
            if [[ "$LACY_SHELL_CURRENT_MODE" == "auto" ]] && lacy_shell_has_nl_markers "$trimmed"; then
                LACY_SHELL_REROUTE_CANDIDATE="$trimmed"
            else
                LACY_SHELL_REROUTE_CANDIDATE=""
            fi

            zle .accept-line
            return
            ;;
        "agent")
            # Add to history before clearing buffer
            print -s -- "$input"

            # Defer agent execution to precmd — output produced inside a ZLE
            # widget (after zle .accept-line) confuses ZLE's cursor tracking,
            # causing the prompt to overwrite short (one-line) results.
            LACY_SHELL_PENDING_QUERY="$input"
            BUFFER=""
            zle .accept-line
            ;;
    esac
}

# Disable input interception (emergency mode)
lacy_shell_disable_interception() {
    echo "🚨 Disabling Lacy Shell input interception"
    zle -A .accept-line accept-line
    echo "✅ Normal shell behavior restored"
    echo "   Run 'lacy_shell_enable_interception' to re-enable"
}

# Re-enable input interception
lacy_shell_enable_interception() {
    echo "🔄 Re-enabling Lacy Shell input interception"
    zle -N accept-line lacy_shell_smart_accept_line
    echo "✅ Lacy Shell features restored"
}

# Execute command via AI agent
lacy_shell_execute_agent() {
    local query="$1"

    if ! lacy_shell_query_agent "$query"; then
        # Only show install hints if query_agent didn't already format the error
        if [[ -z "$LACY_ACTIVE_TOOL" ]] && ! command -v lash >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1; then
            echo ""
            lacy_print_color 196 "  No AI tool configured"
            echo ""
            lacy_print_color 238 "  Install one:  npm install -g lashcode"
            lacy_print_color 238 "  Or configure: lacy setup"
            echo ""
        fi
    fi
}

# Smart auto execution: only called when first word is not a valid command
lacy_shell_execute_smart_auto() {
    local input="$1"
    # Let the agent handle it - mcp.zsh will show appropriate error if no tool available
    lacy_shell_execute_agent "$input"
}

# Precmd hook - called before each prompt
lacy_shell_precmd() {
    # Capture exit code immediately — must be the first line
    local last_exit=$?

    # Ensure terminal state is clean (safety net for interrupted spinners / agent tools)
    printf '\e[?25h'   # Cursor visible
    printf '\e[?7h'    # Line wrapping enabled

    # Don't run if disabled or quitting
    if [[ "$LACY_SHELL_ENABLED" != true || "$LACY_SHELL_QUITTING" == true ]]; then
        LACY_SHELL_REROUTE_CANDIDATE=""
        return
    fi

    # Check reroute candidate: if the command failed with a non-signal exit
    # code (< 128), re-route to agent. Exit codes >= 128 are signal-based
    # (e.g. 130=Ctrl+C, 137=SIGKILL) and should not trigger re-routing.
    if [[ -n "$LACY_SHELL_REROUTE_CANDIDATE" ]]; then
        local candidate="$LACY_SHELL_REROUTE_CANDIDATE"
        LACY_SHELL_REROUTE_CANDIDATE=""
        if (( last_exit != 0 && last_exit < LACY_SIGNAL_EXIT_THRESHOLD )); then
            lacy_shell_execute_agent "$candidate"
            return
        fi
    fi
    # Handle deferred quit triggered by Ctrl-D without letting EOF propagate
    if [[ "$LACY_SHELL_DEFER_QUIT" == true ]]; then
        LACY_SHELL_DEFER_QUIT=false
        LACY_SHELL_REROUTE_CANDIDATE=""
        lacy_shell_quit
        return
    fi
    # Handle pending agent query (deferred from ZLE widget for clean cursor tracking)
    if [[ -n "$LACY_SHELL_PENDING_QUERY" ]]; then
        local pending="$LACY_SHELL_PENDING_QUERY"
        LACY_SHELL_PENDING_QUERY=""
        # Restore query text on the prompt line above.
        # accept-line cleared it (BUFFER was emptied to prevent shell execution),
        # so we move up, rewrite the last prompt line + query, then move back down.
        local prompt_last="${LACY_SHELL_BASE_PS1##*$'\n'}%F{${LACY_COLOR_AGENT}}${LACY_INDICATOR_CHAR}%f "
        printf '\e[A\e[2K\r'
        print -Pn "$prompt_last"
        printf '%s\n' "$pending"
        lacy_shell_execute_agent "$pending"
    fi

    # If a Ctrl-C message is currently displayed, skip redraw to preserve it
    if [[ -n "$LACY_SHELL_MESSAGE_JOB_PID" ]] && kill -0 "$LACY_SHELL_MESSAGE_JOB_PID" 2>/dev/null; then
        return
    fi
    # Update prompt with current mode
    lacy_shell_update_prompt
}

# Enhanced command execution with confirmation for dangerous commands
lacy_shell_execute_with_confirmation() {
    local command="$1"

    # Check if command contains dangerous patterns
    for pattern in "${LACY_DANGEROUS_PATTERNS[@]}"; do
        if [[ "$command" == *"$pattern"* ]]; then
            echo ""
            print -P "%F{red}⚠️  Potentially dangerous command detected:%f"
            echo "   $command"
            echo ""
            read "response?Continue? (y/N): "
            if [[ "$response" != "y" && "$response" != "Y" ]]; then
                echo "Command cancelled."
                return 1
            fi
            break
        fi
    done
    
    # Execute the command
    eval "$command"
}

# Suggest command corrections using AI
lacy_shell_suggest_correction() {
    local failed_command="$1"
    local exit_code="$2"
    
    if [[ "$LACY_SHELL_CURRENT_MODE" == "auto" || "$LACY_SHELL_CURRENT_MODE" == "agent" ]]; then
        echo ""
        print -P "%F{yellow}💡 Getting AI suggestion for failed command...%f"
        
        local suggestion_query="The command '$failed_command' failed with exit code $exit_code. Please suggest a corrected version or alternative approach."
        lacy_shell_query_agent "$suggestion_query"
    fi
}

# Command history integration with AI
lacy_shell_ai_history_search() {
    local search_term="$1"
    
    if [[ -z "$search_term" ]]; then
        echo "Usage: lacy_shell_ai_history_search <search_term>"
        return 1
    fi
    
    # Get recent history
    local recent_history=$(fc -l -100 | tail -20)
    
    # Query AI for relevant commands
    local query="Based on my recent command history, suggest relevant commands for: $search_term

Recent history:
$recent_history

Please suggest specific commands that would help with '$search_term'."
    
    print -P "%F{blue}🔍 Searching command history with AI...%f"
    lacy_shell_query_agent "$query"
}

# Auto-complete enhancement with AI
lacy_shell_ai_complete() {
    local partial_command="$1"
    
    if [[ ${#partial_command} -lt 3 ]]; then
        return 0  # Don't trigger for very short inputs
    fi
    
    # Query AI for completion suggestions
    local query="Complete this shell command: $partial_command

Provide 3-5 most likely completions, considering:
- Current directory: $(pwd)
- Available files: $(ls -1 | head -10)
- Common shell patterns

Format as a simple list of completions."
    
    echo ""
    print -P "%F{blue}🔮 AI completion suggestions:%f"
    lacy_shell_query_agent "$query"
}

# Context-aware help system
lacy_shell_context_help() {
    local topic="$1"
    
    local context_info="
Current directory: $(pwd)
Files in directory: $(ls -1 | head -10)
Shell: $SHELL
OS: $(uname -s)
"
    
    local query="Provide help for: $topic

Context:
$context_info

Please provide:
1. Brief explanation
2. Usage examples
3. Common options/flags
4. Related commands
"
    
    print -P "%F{blue}📖 Context-aware help for: $topic%f"
    lacy_shell_query_agent "$query"
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

# Quit lacy shell function
lacy_shell_quit() {
    # Disable Lacy Shell immediately
    LACY_SHELL_ENABLED=false
    LACY_SHELL_QUITTING=true
    unset LACY_SHELL_ACTIVE

    echo ""
    echo "👋 Exiting Lacy Shell..."
    echo ""
    
    # CRITICAL: Remove precmd hooks FIRST to prevent redrawing
    precmd_functions=(${precmd_functions:#lacy_shell_precmd})
    precmd_functions=(${precmd_functions:#lacy_shell_update_prompt})
    
    # Disable input interception (only if ZLE is active)
    if [[ -n "$ZLE_VERSION" ]]; then
        zle -A .accept-line accept-line 2>/dev/null
    fi
    
    # Comprehensive terminal reset sequence
    # Reset all terminal attributes and clear any scroll regions
    # Avoid full terminal reset (\033c) because it can cause prompt systems to redraw unpredictably
    echo -ne "\033[0m"  # Reset all attributes
    echo -ne "\033[r"  # Reset scroll region to full screen
    echo -ne "\033[?7h"  # Enable line wrapping
    echo -ne "\033[?25h" # Ensure cursor is visible
    echo -ne "\033[?1049l"  # Exit alternate screen if active
    echo -ne "\033[1;1H"  # Move to top-left
    echo -ne "\033[J"  # Clear from cursor to end of screen
    
    # Stop any preheated servers
    lacy_preheat_cleanup

    # Run cleanup
    lacy_shell_cleanup
    
    # Prepare for prompt display if not in ZLE
    if [[ -z "$ZLE_VERSION" ]]; then
        print -r -- ""
    fi

    # Unset aliases
    unalias ask mode tool spinner quit_lacy quit stop disable_lacy enable_lacy 2>/dev/null

    # Define a `lacy` function so user can re-enter by typing `lacy`
    local _ldir="$LACY_SHELL_DIR"
    eval "lacy() {
        if [[ \$# -eq 0 ]]; then
            unfunction lacy 2>/dev/null
            LACY_SHELL_LOADED=false
            source \"${_ldir}/lacy.plugin.zsh\"
        else
            command lacy \"\$@\"
        fi
    }"

    # Restore original prompt
    lacy_shell_restore_prompt

    # Print newline and trigger prompt display
    echo ""
    if [[ -n "$ZLE_VERSION" ]]; then
        zle -I 2>/dev/null
        zle -R 2>/dev/null
        zle reset-prompt 2>/dev/null || true
    fi
}

# Mode switching commands (work in any mode)
lacy_shell_mode() {
    case "$1" in
        "shell"|"s")
            lacy_shell_set_mode "shell"
            lacy_shell_update_rprompt 2>/dev/null
            echo ""
            print -P "  %F{${LACY_COLOR_SHELL}}${LACY_INDICATOR_CHAR}%f SHELL mode - all commands execute directly"
            echo ""
            ;;
        "agent"|"a")
            lacy_shell_set_mode "agent"
            lacy_shell_update_rprompt 2>/dev/null
            echo ""
            print -P "  %F{${LACY_COLOR_AGENT}}${LACY_INDICATOR_CHAR}%f AGENT mode - all input goes to AI"
            echo ""
            ;;
        "auto"|"u")
            lacy_shell_set_mode "auto"
            lacy_shell_update_rprompt 2>/dev/null
            echo ""
            print -P "  %F{${LACY_COLOR_AUTO}}${LACY_INDICATOR_CHAR}%f AUTO mode - smart detection"
            echo ""
            ;;
        "toggle"|"t")
            lacy_shell_toggle_mode
            lacy_shell_update_rprompt 2>/dev/null
            local new_mode="$LACY_SHELL_CURRENT_MODE"
            echo ""
            case "$new_mode" in
                "shell") print -P "  %F{${LACY_COLOR_SHELL}}${LACY_INDICATOR_CHAR}%f SHELL mode" ;;
                "agent") print -P "  %F{${LACY_COLOR_AGENT}}${LACY_INDICATOR_CHAR}%f AGENT mode" ;;
                "auto")  print -P "  %F{${LACY_COLOR_AUTO}}${LACY_INDICATOR_CHAR}%f AUTO mode" ;;
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
                "shell") print -P "%F{${LACY_COLOR_SHELL}}SHELL%f" ;;
                "agent") print -P "%F{${LACY_COLOR_AGENT}}AGENT%f" ;;
                "auto")  print -P "%F{${LACY_COLOR_AUTO}}AUTO%f" ;;
            esac
            echo ""
            echo "Colors:"
            print -P "  %F{${LACY_COLOR_SHELL}}${LACY_INDICATOR_CHAR}%f Green  = shell command"
            print -P "  %F{${LACY_COLOR_AGENT}}${LACY_INDICATOR_CHAR}%f Magenta = agent query"
            echo ""
            ;;
    esac
}

# Tool management command
lacy_shell_tool() {
    case "$1" in
        "")
            echo ""
            if [[ "$LACY_ACTIVE_TOOL" == "custom" ]]; then
                echo "Active tool: custom (${LACY_CUSTOM_TOOL_CMD:-not configured})"
            else
                echo "Active tool: ${LACY_ACTIVE_TOOL:-auto-detect}"
            fi
            echo ""
            echo "Available tools:"
            for t in lash claude opencode gemini codex; do
                if command -v "$t" >/dev/null 2>&1; then
                    print -P "  %F{34}✓%f $t"
                else
                    print -P "  %F{238}○%f $t (not installed)"
                fi
            done
            if [[ -n "$LACY_CUSTOM_TOOL_CMD" ]]; then
                print -P "  %F{34}✓%f custom ($LACY_CUSTOM_TOOL_CMD)"
            else
                print -P "  %F{238}○%f custom (not configured)"
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
                    echo "Example: tool set custom \"claude --dangerously-skip-permissions -p\""
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
            echo "  tool set custom \"command -flags\""
            ;;
    esac
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

# Aliases
alias ask="lacy_shell_query_agent"
alias mode="lacy_shell_mode"
alias tool="lacy_shell_tool"
alias spinner="lacy_shell_spinner"
alias quit_lacy="lacy_shell_quit"
alias quit="lacy_shell_quit"
alias stop="lacy_shell_quit"
alias disable_lacy="lacy_shell_disable_interception"
alias enable_lacy="lacy_shell_enable_interception"
