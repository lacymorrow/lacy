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

            zle .accept-line
            return
            ;;
        "agent")
            # Add to history before clearing buffer
            print -s -- "$input"

            # Clear the line, accept to exit ZLE, then stream below a fresh line
            BUFFER=""
            zle .accept-line
            print -r -- ""
            lacy_shell_execute_agent "$input"
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
        echo ""
        echo "❌ Agent request failed. Try:"
        echo "   - Install lash: npm install -g lash-cli"
        echo "   - Or configure API keys in ~/.lacy/config.yaml"
        echo ""
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
    # Ensure cursor is visible (safety net for interrupted spinners)
    printf '\e[?25h'
    # Don't run if disabled or quitting
    if [[ "$LACY_SHELL_ENABLED" != true || "$LACY_SHELL_QUITTING" == true ]]; then
        return
    fi
    # Handle deferred quit triggered by Ctrl-D without letting EOF propagate
    if [[ "$LACY_SHELL_DEFER_QUIT" == true ]]; then
        LACY_SHELL_DEFER_QUIT=false
        lacy_shell_quit
        return
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
    local dangerous_commands=("rm -rf" "sudo rm" "mkfs" "dd if=" ">" "truncate")
    
    # Check if command contains dangerous patterns
    for pattern in "${dangerous_commands[@]}"; do
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
    
    # Run cleanup
    lacy_shell_cleanup
    
    # Prepare for prompt display if not in ZLE
    if [[ -z "$ZLE_VERSION" ]]; then
        print -r -- ""
    fi

    # Unset aliases
    unalias ask mode tool quit_lacy quit stop disable_lacy enable_lacy 2>/dev/null
    
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
            print -P "  %F{34}▌%f SHELL mode - all commands execute directly"
            echo ""
            ;;
        "agent"|"a")
            lacy_shell_set_mode "agent"
            lacy_shell_update_rprompt 2>/dev/null
            echo ""
            print -P "  %F{200}▌%f AGENT mode - all input goes to AI"
            echo ""
            ;;
        "auto"|"u")
            lacy_shell_set_mode "auto"
            lacy_shell_update_rprompt 2>/dev/null
            echo ""
            print -P "  %F{75}▌%f AUTO mode - smart detection"
            echo ""
            ;;
        "toggle"|"t")
            lacy_shell_toggle_mode
            lacy_shell_update_rprompt 2>/dev/null
            local new_mode="$LACY_SHELL_CURRENT_MODE"
            echo ""
            case "$new_mode" in
                "shell") print -P "  %F{34}▌%f SHELL mode" ;;
                "agent") print -P "  %F{200}▌%f AGENT mode" ;;
                "auto")  print -P "  %F{75}▌%f AUTO mode" ;;
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
                "shell") print -P "%F{34}SHELL%f" ;;
                "agent") print -P "%F{200}AGENT%f" ;;
                "auto")  print -P "%F{75}AUTO%f" ;;
            esac
            echo ""
            echo "Colors:"
            print -P "  %F{34}▌%f Green  = shell command"
            print -P "  %F{200}▌%f Magenta = agent query"
            echo ""
            ;;
    esac
}

# Tool management command
lacy_shell_tool() {
    case "$1" in
        "")
            echo ""
            echo "Active tool: ${LACY_ACTIVE_TOOL:-auto-detect}"
            echo ""
            echo "Available tools:"
            for t in lash claude opencode gemini codex; do
                if command -v "$t" >/dev/null 2>&1; then
                    print -P "  %F{34}✓%f $t"
                else
                    print -P "  %F{238}○%f $t (not installed)"
                fi
            done
            echo ""
            echo "Usage: tool set <name>"
            echo ""
            ;;
        set)
            if [[ -z "$2" ]]; then
                echo "Usage: tool set <name>"
                echo "Options: lash, claude, opencode, gemini, codex, auto"
                return 1
            fi
            if [[ "$2" == "auto" ]]; then
                LACY_ACTIVE_TOOL=""
                export LACY_ACTIVE_TOOL
                echo "Tool set to: auto-detect"
            else
                LACY_ACTIVE_TOOL="$2"
                export LACY_ACTIVE_TOOL
                echo "Tool set to: $2"
            fi
            ;;
        *)
            echo "Usage: tool [set <name>]"
            echo "Options: lash, claude, opencode, gemini, codex, auto"
            ;;
    esac
}

# Aliases
alias ask="lacy_shell_query_agent"
alias mode="lacy_shell_mode"
alias tool="lacy_shell_tool"
alias quit_lacy="lacy_shell_quit"
alias quit="lacy_shell_quit"
alias stop="lacy_shell_quit"
alias disable_lacy="lacy_shell_disable_interception"
alias enable_lacy="lacy_shell_enable_interception"
