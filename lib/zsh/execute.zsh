#!/usr/bin/env zsh

# Command execution logic for Lacy Shell

# Pending internal command (set by slash-command handler, dispatched by precmd)
LACY_SHELL_PENDING_CMD=""

# Smart accept-line widget that handles agent queries
lacy_shell_smart_accept_line() {
    # If Lacy Shell is disabled, use normal accept-line
    if [[ "$LACY_SHELL_ENABLED" != true ]]; then
        zle .accept-line
        return
    fi

    local input="$BUFFER"

    # Skip empty commands — also dismiss any ghost text suggestion
    if [[ -z "$input" ]]; then
        LACY_SHELL_SUGGESTION=""
        zle .accept-line
        return
    fi

    # Intercept slash-prefixed session commands (/new, /reset, /clear, /resume)
    local _slashcmd="$input"
    _slashcmd="${_slashcmd#"${_slashcmd%%[^[:space:]]*}"}"
    case "$_slashcmd" in
        /new|/reset|/clear|/resume)
            print -s -- "$input"
            fc -AI 2>/dev/null
            if [[ "$_slashcmd" == "/resume" ]]; then
                LACY_SHELL_PENDING_CMD="session_resume"
            else
                LACY_SHELL_PENDING_CMD="session_new"
            fi
            BUFFER=""
            zle .accept-line
            return
            ;;
    esac

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

            # Record command for terminal context (agent will see it on next query)
            _lacy_ctx_mark_command "$BUFFER"

            zle .accept-line
            return
            ;;
        "agent")
            # Strip @ agent bypass prefix if present
            local agent_input="$input"
            local _at_trimmed="${agent_input#"${agent_input%%[^[:space:]]*}"}"
            if [[ "$_at_trimmed" == @* ]]; then
                agent_input="${_at_trimmed#@}"
                agent_input="${agent_input#"${agent_input%%[^[:space:]]*}"}"
            fi

            # Add to history before clearing buffer
            print -s -- "$input"
            # Flush to HISTFILE immediately — needed for INC_APPEND_HISTORY / SHARE_HISTORY users,
            # since the subsequent empty-buffer accept-line doesn't trigger a file write.
            fc -AI 2>/dev/null

            # Defer agent execution to precmd — output produced inside a ZLE
            # widget (after zle .accept-line) confuses ZLE's cursor tracking,
            # causing the prompt to overwrite short (one-line) results.
            LACY_SHELL_PENDING_QUERY="$agent_input"
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

# lacy_shell_execute_agent is in lib/core/commands.sh

# Precmd hook - called before each prompt
lacy_shell_precmd() {
    # Capture exit code immediately — must be the first line
    local last_exit=$?

    # Track exit code for terminal context (only for real shell commands)
    _lacy_ctx_on_precmd $last_exit

    # Ensure terminal state is clean (safety net for interrupted spinners / agent tools)
    printf '\e[?25h'   # Cursor visible
    printf '\e[?7h'    # Line wrapping enabled

    # Don't run if disabled or quitting
    if [[ "$LACY_SHELL_ENABLED" != true || "$LACY_SHELL_QUITTING" == true ]]; then
        LACY_SHELL_REROUTE_CANDIDATE=""
        return
    fi

    # Clear any previous ghost text suggestion
    LACY_SHELL_SUGGESTION=""

    # Check reroute candidate: if the command failed with a non-signal exit
    # code (< 128), set ghost text suggestion to re-try via agent with @ prefix.
    if [[ -n "$LACY_SHELL_REROUTE_CANDIDATE" ]]; then
        local candidate="$LACY_SHELL_REROUTE_CANDIDATE"
        LACY_SHELL_REROUTE_CANDIDATE=""
        if (( last_exit != 0 && last_exit < LACY_SIGNAL_EXIT_THRESHOLD )); then
            LACY_SHELL_SUGGESTION="@ ${candidate}"
        fi
    fi
    # Handle deferred quit triggered by Ctrl-D without letting EOF propagate
    if [[ "$LACY_SHELL_DEFER_QUIT" == true ]]; then
        LACY_SHELL_DEFER_QUIT=false
        LACY_SHELL_REROUTE_CANDIDATE=""
        lacy_shell_quit
        return
    fi
    # Handle pending internal commands (from slash-prefixed session commands)
    if [[ -n "$LACY_SHELL_PENDING_CMD" ]]; then
        local _cmd="$LACY_SHELL_PENDING_CMD"
        LACY_SHELL_PENDING_CMD=""
        case "$_cmd" in
            session_new)    lacy_session_new ;;
            session_resume) lacy_session_resume ;;
        esac
    fi

    # Handle pending agent query (deferred from ZLE widget for clean cursor tracking)
    if [[ -n "$LACY_SHELL_PENDING_QUERY" ]]; then
        local pending="$LACY_SHELL_PENDING_QUERY"
        LACY_SHELL_PENDING_QUERY=""
        # Restore query text on the prompt block above.
        # accept-line cleared the buffer (to prevent shell execution), so the
        # prompt was displayed with no input text. Move up over the entire prompt
        # (which may span multiple lines), clear it, and reprint with the query.
        local _expanded_ps1
        _expanded_ps1=$(print -Pn "$LACY_SHELL_BASE_PS1")
        local _prompt_lines=1
        local _tmp="$_expanded_ps1"
        while [[ "$_tmp" == *$'\n'* ]]; do
            _tmp="${_tmp#*$'\n'}"
            (( _prompt_lines++ ))
        done
        # Move up to start of prompt block, clear to end of screen
        printf "\e[${_prompt_lines}A\e[J"
        # Reprint full prompt with agent-colored indicator + query text
        print -Pn "${LACY_SHELL_BASE_PS1}%F{${LACY_COLOR_AGENT}}${LACY_INDICATOR_CHAR}%f "
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

# Quit lacy shell function
lacy_shell_quit() {
    # Disable Lacy Shell immediately
    LACY_SHELL_ENABLED=false
    LACY_SHELL_QUITTING=true
    unset LACY_SHELL_ACTIVE

    echo ""
    lacy_print_color "$LACY_COLOR_NEUTRAL" "$LACY_MSG_QUIT"
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

    # Unset aliases and function overrides
    unalias ask mode tool spinner quit_lacy quit stop disable_lacy enable_lacy 2>/dev/null
    unfunction lacy 2>/dev/null

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

# lacy_shell_mode, lacy_shell_tool, lacy_shell_spinner, lacy_shell_clear_conversation,
# lacy_shell_show_conversation, and lacy() are in lib/core/commands.sh

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
