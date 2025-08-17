#!/usr/bin/env zsh

# Command execution logic for Lacy Shell

# Smart accept-line widget that handles agent queries
lacy_shell_smart_accept_line() {
    local input="$BUFFER"
    
    # Skip empty commands
    if [[ -z "$input" ]]; then
        zle .accept-line
        return
    fi
    
    # Emergency bypass - if input starts with !, force shell execution
    if [[ "$input" == !* ]]; then
        BUFFER="${input#!}"
        zle .accept-line
        return
    fi
    
    # Determine which mode to use
    local execution_mode=$(lacy_shell_detect_mode "$input")
    
    # In shell mode, always use normal shell execution
    if [[ "$execution_mode" == "shell" ]]; then
        zle .accept-line
        return
    fi
    
    # For auto mode, check if command might need TTY
    if [[ "$execution_mode" == "auto" ]]; then
        local first_word="${input%% *}"
        
        # If it's a known command and not obviously natural language, 
        # let shell handle it directly to preserve TTY
        if lacy_shell_command_exists "$first_word" && ! lacy_shell_is_obvious_natural_language "$input"; then
            # Let the shell execute it directly with proper TTY
            zle .accept-line
            return
        fi
    fi
    
    # Handle based on mode (agent or auto with non-command/natural language)
    case "$execution_mode" in
        "agent")
            # Check if we can actually use the agent
            if ! lacy_shell_check_api_keys >/dev/null 2>&1; then
                echo "⚠️  No API keys configured - executing as shell command instead"
                echo "   Configure API keys in ~/.lacy-shell/config.yaml to use AI features"
                zle .accept-line
                return
            fi
            
            # Add to history before clearing buffer
            print -s -- "$input"
            
            # Clear the line, accept to exit ZLE, then stream below a fresh line
            BUFFER=""
            zle .accept-line
            print -r -- ""
            lacy_shell_execute_agent "$input"
            ;;
        "auto")
            # Smart auto mode: for non-commands or natural language
            # Add to history before clearing buffer
            print -s -- "$input"
            
            BUFFER=""
            zle .accept-line
            print -r -- ""
            lacy_shell_execute_smart_auto "$input"
            ;;
        *)
            # Normal shell execution
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
    
    # Add timeout and error handling
    echo "🤖 Sending to AI agent: $query"
    
    # Query the agent with error handling
    if ! lacy_shell_query_agent "$query"; then
        echo "❌ Agent request failed or timed out. Try:"
        echo "   - Check your API keys: lacy_shell_check_api_keys"
        echo "   - Check internet connection"
        echo "   - Switch to shell mode: mode shell"
        echo "   - Run command directly: $query"
    fi
    
    # Do not touch ZLE redraw here; we've already exited ZLE before streaming
}

# Smart auto execution: only called for non-commands or natural language
lacy_shell_execute_smart_auto() {
    local input="$1"
    local first_word="${input%% *}"
    
    # This function is now only called when:
    # 1. Input is natural language, OR
    # 2. Command doesn't exist
    # Known commands are handled directly by the shell in auto mode
    
    # Check if agent is available
    if lacy_shell_check_api_keys >/dev/null 2>&1; then
        if lacy_shell_is_obvious_natural_language "$input"; then
            echo "🤖 Natural language detected, using AI agent"
        else
            echo "❓ Command not found, trying AI agent: $input"
        fi
        lacy_shell_execute_agent "$input"
    else
        echo "❌ Command not found and no AI agent available: $first_word"
        echo "   Configure API keys in ~/.lacy-shell/config.yaml to use AI features"
        echo "   Or check if the command is spelled correctly"
    fi
}

# Check if a command exists in the system
lacy_shell_command_exists() {
    local cmd="$1"
    
    # Handle built-in commands and common shell constructs
    case "$cmd" in
        cd|pwd|echo|export|alias|unalias|which|type|help|history|jobs|fg|bg|source|.|exit|logout)
            return 0
            ;;
        # Common system commands that should always be treated as commands
        timeout|nohup|sudo|env|time|nice|ionice|taskset|strace|ltrace)
            return 0
            ;;
    esac
    
    # Check using command -v (POSIX compliant)
    command -v "$cmd" >/dev/null 2>&1
}

# Check if input is obvious natural language
lacy_shell_is_obvious_natural_language() {
    local input="$1"
    local input_lower="${input:l}"
    
    # Question patterns
    if [[ "$input_lower" == \?* || "$input_lower" == *\? ]]; then
        return 0
    fi
    
    # Natural language starters
    local natural_starters=(
        "what" "how" "why" "when" "where" "who" "which" "can you" "could you"
        "would you" "please" "help me" "tell me" "show me" "explain" "describe"
        "i want" "i need" "i would like" "find me" "search for" "look for"
    )
    
    for starter in "${natural_starters[@]}"; do
        if [[ "$input_lower" == "$starter"* ]]; then
            return 0
        fi
    done
    
    # Only treat as natural language if it's a very long sentence (>10 words) 
    # AND doesn't start with a command AND has natural language patterns
    local word_count=$(echo "$input" | wc -w)
    if [[ $word_count -gt 10 ]]; then
        local first_word="${input%% *}"
        if ! lacy_shell_command_exists "$first_word"; then
            # Check if it has sentence-like patterns (articles, pronouns, etc.)
            if [[ "$input_lower" =~ " (the|a|an|this|that|these|those|i|you|we|they|it) " ]]; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# Precmd hook - called before each prompt
lacy_shell_precmd() {
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
            echo "%F{red}⚠️  Potentially dangerous command detected:%f"
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
        echo "%F{yellow}💡 Getting AI suggestion for failed command...%f"
        
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
    
    echo "%F{blue}🔍 Searching command history with AI...%f"
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
    echo "%F{blue}🔮 AI completion suggestions:%f"
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
    
    echo "%F{blue}📖 Context-aware help for: $topic%f"
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
    echo ""
    echo "👋 Exiting Lacy Shell..."
    echo ""
    
    # CRITICAL: Remove precmd hooks FIRST to prevent redrawing
    precmd_functions=(${precmd_functions:#lacy_shell_precmd})
    precmd_functions=(${precmd_functions:#lacy_shell_update_prompt})
    
    # Disable input interception
    zle -A .accept-line accept-line
    
    # Comprehensive terminal reset sequence
    # Reset all terminal attributes and clear any scroll regions
    echo -ne "\033c"  # Full terminal reset
    echo -ne "\033[0m"  # Reset all attributes
    echo -ne "\033[r"  # Reset scroll region to full screen
    echo -ne "\033[?1049l"  # Exit alternate screen if active
    echo -ne "\033[1;1H"  # Move to top-left
    echo -ne "\033[J"  # Clear from cursor to end of screen
    
    # Run cleanup
    lacy_shell_cleanup
    
    # Unset all lacy shell functions and aliases
    unalias ask suggest aihelp aicomplete hisearch clear_chat show_chat mode mode_style 2>/dev/null
    unalias mcp_test mcp_check mcp_debug mcp_restart mcp_logs mcp_start mcp_stop 2>/dev/null
    unalias disable_lacy enable_lacy test_smart_auto quit_lacy lacy_quit 2>/dev/null
    
    # Clear screen and reset terminal one more time
    clear
    
    echo "✅ Lacy Shell disabled. Normal shell behavior restored."
    echo "   To re-enable, source the plugin again or restart your shell."
    echo ""
}

# Mode switching commands (work in any mode)
lacy_shell_mode() {
    case "$1" in
        "shell"|"s")
            lacy_shell_set_mode "shell"
            echo ""
            echo "  %F{205}▌ Switched to SHELL mode%f"
            echo "  All commands execute directly in shell"
            echo ""
            ;;
        "agent"|"a")
            lacy_shell_set_mode "agent"
            echo ""
            echo "  %F{214}▌ Switched to AGENT mode%f"
            echo "  All input goes to AI agent"
            echo ""
            ;;
        "auto"|"u")
            lacy_shell_set_mode "auto"
            echo ""
            echo "  %F{141}▌ Switched to AUTO mode%f"
            echo "  Commands run in shell, natural language goes to AI"
            echo ""
            ;;
        "toggle"|"t")
            lacy_shell_toggle_mode
            local new_mode="$LACY_SHELL_CURRENT_MODE"
            echo ""
            case "$new_mode" in
                "shell")
                    echo "  %F{205}▌ Switched to SHELL mode%f"
                    ;;
                "agent")
                    echo "  %F{214}▌ Switched to AGENT mode%f"
                    ;;
                "auto")
                    echo "  %F{141}▌ Switched to AUTO mode%f"
                    ;;
            esac
            echo ""
            ;;
        "status")
            lacy_shell_mode_status
            ;;
        *)
            echo ""
            echo "Usage: mode [shell|agent|auto|toggle|status] or [s|a|u|t]"
            echo ""
            echo -n "Current mode: "
            case "$LACY_SHELL_CURRENT_MODE" in
                "shell")
                    echo "%F{205}▌ SHELL%f"
                    ;;
                "agent")
                    echo "%F{214}▌ AGENT%f"
                    ;;
                "auto")
                    echo "%F{141}▌ AUTO%f"
                    ;;
            esac
            echo ""
            ;;
    esac
}

# Export functions for direct use
alias ask="lacy_shell_query_agent"
alias suggest="lacy_shell_suggest_correction"
alias aihelp="lacy_shell_context_help"
alias aicomplete="lacy_shell_ai_complete"
alias hisearch="lacy_shell_ai_history_search"
alias clear_chat="lacy_shell_clear_conversation"
alias show_chat="lacy_shell_show_conversation"
alias mode="lacy_shell_mode"
alias mode_style="lacy_shell_toggle_indicator_style"

# MCP-related aliases
alias mcp_test="lacy_shell_test_mcp"
alias mcp_check="lacy_shell_check_mcp_packages"
alias mcp_debug="lacy_shell_debug_mcp"
alias mcp_restart="lacy_shell_restart_mcp_server"
alias mcp_logs="lacy_shell_mcp_logs"
alias mcp_start="lacy_shell_start_mcp_servers"
alias mcp_stop="lacy_shell_stop_mcp_servers"

# Emergency aliases for input issues
alias disable_lacy="lacy_shell_disable_interception"
alias enable_lacy="lacy_shell_enable_interception"

# Quit aliases
alias quit_lacy="lacy_shell_quit"
alias lacy_quit="lacy_shell_quit"

# Testing aliases
alias test_smart_auto="lacy_shell_test_smart_auto"

# Test smart auto mode
lacy_shell_test_smart_auto() {
    echo "Testing Smart Auto Mode"
    echo "======================"
    echo
    
    local test_cases=(
        "ls -la"                              # Should execute shell command
        "nonexistentcommand123"               # Should try shell, fail, then try agent
        "what files are in this directory?"   # Should go directly to agent (natural language)
        "git status"                          # Should execute shell command
        "how do I install python packages?"   # Should go directly to agent (natural language)
        "pwd"                                 # Should execute shell command
        "please help me with docker"          # Should go directly to agent (natural language)
        "invalidcmd --help"                   # Should try shell first, then fallback
    )
    
    echo "The following tests would demonstrate smart auto mode behavior:"
    echo
    
    for test_case in "${test_cases[@]}"; do
        echo "Input: '$test_case'"
        
        if lacy_shell_is_obvious_natural_language "$test_case"; then
            echo "  → Would go directly to AI agent (natural language detected)"
        else
            local first_word="${test_case%% *}"
            if lacy_shell_command_exists "$first_word"; then
                echo "  → Would execute shell command (command exists)"
            else
                echo "  → Would try shell first, then fallback to AI agent (command not found)"
            fi
        fi
        echo
    done
    
    echo "To test for real, switch to auto mode with: mode auto"
    echo "Then try typing any of the above commands."
}
