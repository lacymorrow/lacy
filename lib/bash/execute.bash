#!/usr/bin/env bash

# Command execution logic for Lacy Shell — Bash adapter
# Uses bind -x for Enter override + PROMPT_COMMAND for post-exec

# Pending query (set by Enter handler, dispatched by PROMPT_COMMAND)
LACY_SHELL_PENDING_QUERY=""
LACY_SHELL_REROUTE_CANDIDATE=""
LACY_SHELL_PENDING_CMD=""
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

    # Intercept slash-prefixed session commands (/new, /reset, /clear, /resume)
    local _slashcmd="$input"
    _slashcmd="${_slashcmd#"${_slashcmd%%[^[:space:]]*}"}"
    case "$_slashcmd" in
        /new|/reset|/clear|/resume)
            history -s -- "$input"
            history -a 2>/dev/null
            if [[ "$_slashcmd" == "/resume" ]]; then
                LACY_SHELL_PENDING_CMD="session_resume"
            else
                LACY_SHELL_PENDING_CMD="session_new"
            fi
            READLINE_LINE=""
            READLINE_POINT=0
            return
            ;;
    esac

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
            # Strip @ agent bypass prefix if present
            local agent_input="$input"
            local _at_trimmed="${agent_input#"${agent_input%%[^[:space:]]*}"}"
            if [[ "$_at_trimmed" == @* ]]; then
                agent_input="${_at_trimmed#@}"
                agent_input="${agent_input#"${agent_input%%[^[:space:]]*}"}"
            fi

            # Add to Bash history
            history -s -- "$input"
            # Flush to HISTFILE immediately — needed when HISTFILE/PROMPT_COMMAND
            # write-on-exit isn't sufficient (e.g. with HISTAPPEND set).
            history -a 2>/dev/null

            # Defer agent execution to PROMPT_COMMAND
            LACY_SHELL_PENDING_QUERY="$agent_input"
            READLINE_LINE=""
            READLINE_POINT=0
            return
            ;;
    esac
}

# lacy_shell_execute_agent is in lib/core/commands.sh

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

    # Check reroute candidate: show hint to re-try via agent with @ prefix
    if [[ -n "$LACY_SHELL_REROUTE_CANDIDATE" ]]; then
        local candidate="$LACY_SHELL_REROUTE_CANDIDATE"
        LACY_SHELL_REROUTE_CANDIDATE=""
        if (( _lacy_last_exit != 0 && _lacy_last_exit < LACY_SIGNAL_EXIT_THRESHOLD )); then
            printf '  \e[38;5;%dm%s\e[0m \e[38;5;%dm@ %s\e[0m\n' \
                "$LACY_COLOR_AGENT" "$LACY_INDICATOR_CHAR" \
                "$LACY_COLOR_NEUTRAL" "$candidate"
        fi
    fi

    # Handle deferred quit triggered by Ctrl-D
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

# lacy_shell_mode, lacy_shell_tool, lacy_shell_spinner, lacy_shell_clear_conversation,
# lacy_shell_show_conversation, and lacy() are in lib/core/commands.sh

# Quit lacy shell
lacy_shell_quit() {
    LACY_SHELL_ENABLED=false
    LACY_SHELL_QUITTING=true
    unset LACY_SHELL_ACTIVE

    echo ""
    lacy_print_color "$LACY_COLOR_NEUTRAL" "$LACY_MSG_QUIT"
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
    unset -f ask mode tool spinner quit stop lacy 2>/dev/null

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

# Define command functions (Bash uses functions, not aliases, for reliability)
ask() { lacy_shell_query_agent "$*"; }
mode() { lacy_shell_mode "$@"; }
tool() { lacy_shell_tool "$@"; }
spinner() { lacy_shell_spinner "$@"; }
quit() { lacy_shell_quit; }
stop() { lacy_shell_quit; }
