#!/usr/bin/env bash

# Command execution logic for Lacy Shell: Bash adapter
# Enter runs lacy_shell_smart_accept_line_bash (see keybindings.bash); agent
# queries are dispatched from PROMPT_COMMAND.

# Pending query (set by Enter handler, dispatched by PROMPT_COMMAND)
LACY_SHELL_PENDING_QUERY=""
LACY_SHELL_REROUTE_CANDIDATE=""
LACY_SHELL_PENDING_CMD=""
_lacy_last_exit=0

# 1 while the primary prompt (PS1) is up, 0 once its first line is accepted.
# Continuation lines (PS2: an open quote, `for ... do`, a heredoc body) see 0
# and go straight to accept-line. Classifying them sent `done` or `fi` to the
# agent, cleared the line, and left the shell waiting at `>` forever.
_LACY_BASH_AT_PS1=0

# Smart accept-line for Bash, called through the Enter macro
lacy_shell_smart_accept_line_bash() {
    if [[ "$_LACY_BASH_AT_PS1" != 1 ]]; then
        return
    fi
    _LACY_BASH_AT_PS1=0

    # If disabled, let normal readline handle it
    if [[ "$LACY_SHELL_ENABLED" != true ]]; then
        return
    fi

    local input="$READLINE_LINE"

    # Skip empty commands
    if [[ -z "$input" ]]; then
        return
    fi

    local trimmed="$input"
    trimmed="${trimmed#"${trimmed%%[^[:space:]]*}"}"

    # Intercept slash-prefixed session commands (/new, /reset, /clear, /resume)
    case "$trimmed" in
        /new|/reset|/clear|/resume)
            history -s -- "$input"
            history -a 2>/dev/null
            if [[ "$trimmed" == "/resume" ]]; then
                LACY_SHELL_PENDING_CMD="session_resume"
            else
                LACY_SHELL_PENDING_CMD="session_new"
            fi
            READLINE_LINE=""
            READLINE_POINT=0
            return
            ;;
    esac

    # `exit` always leaves the shell and `quit` always leaves lacy, in every
    # mode. Checked before classification so agent mode cannot take them.
    local first_word="${trimmed%%[[:space:]]*}"
    if [[ "$first_word" == "exit" || "$first_word" == "quit" ]]; then
        LACY_SHELL_REROUTE_CANDIDATE=""
        return
    fi

    # Classify using centralized detection.
    # Read the result variable instead of $( ) to avoid a fork on every Enter.
    local classification
    lacy_shell_classify_input "$input" >/dev/null
    classification="$_LACY_CLASSIFY_RESULT"

    case "$classification" in
        "neutral")
            # Let readline process normally
            return
            ;;
        "shell")
            # Bypass only when ! is glued to the command (`!rm -rf x`).
            # `! true` with a space is the shell's own negation: leave it alone.
            if [[ "$trimmed" == \![^[:space:]]* ]]; then
                trimmed="${trimmed#!}"
                READLINE_LINE="$trimmed"
                READLINE_POINT=${#trimmed}
            fi

            # In auto mode, flag commands with NL markers as reroute candidates
            if [[ "$LACY_SHELL_CURRENT_MODE" == "auto" ]] && lacy_shell_has_nl_markers "$trimmed"; then
                LACY_SHELL_REROUTE_CANDIDATE="$trimmed"
            else
                LACY_SHELL_REROUTE_CANDIDATE=""
            fi

            # Record command for terminal context (agent will see it on next query)
            _lacy_ctx_mark_command "$READLINE_LINE"

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
            # Flush to HISTFILE immediately: needed when HISTFILE/PROMPT_COMMAND
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

# ============================================================================
# PROMPT_COMMAND hooks
# ============================================================================
# _lacy_bash_capture_exit runs first and passes $? through unchanged.
# lacy_shell_precmd_bash runs last, so the mode badge lands on top of any PS1
# an earlier hook (starship, __git_ps1, bash-it) rebuilt.

_lacy_bash_capture_exit() {
    _lacy_last_exit=$?
    return "$_lacy_last_exit"
}

# True when PROMPT_COMMAND is an array that bash runs element by element (5.1+)
_lacy_bash_prompt_command_is_array() {
    (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )) || return 1
    [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]
}

_lacy_bash_install_prompt_hooks() {
    _lacy_bash_remove_prompt_hooks
    if _lacy_bash_prompt_command_is_array; then
        PROMPT_COMMAND=(_lacy_bash_capture_exit "${PROMPT_COMMAND[@]}" lacy_shell_precmd_bash)
    elif [[ -n "${PROMPT_COMMAND:-}" ]]; then
        # Newlines, not `;`: a user value ending in `;` would make `;;`
        PROMPT_COMMAND="_lacy_bash_capture_exit"$'\n'"${PROMPT_COMMAND}"$'\n'"lacy_shell_precmd_bash"
    else
        PROMPT_COMMAND="_lacy_bash_capture_exit"$'\n'"lacy_shell_precmd_bash"
    fi
}

# Take lacy's hooks out of PROMPT_COMMAND, leaving everything else as it is now
_lacy_bash_remove_prompt_hooks() {
    if _lacy_bash_prompt_command_is_array; then
        local -a kept=()
        local entry
        for entry in "${PROMPT_COMMAND[@]}"; do
            case "$entry" in
                _lacy_bash_capture_exit|lacy_shell_precmd_bash) continue ;;
            esac
            kept+=("$entry")
        done
        PROMPT_COMMAND=("${kept[@]}")
    else
        local pc="${PROMPT_COMMAND:-}" nl=$'\n'
        pc="${pc//_lacy_bash_capture_exit$nl/}"
        pc="${pc//${nl}lacy_shell_precmd_bash/}"
        case "$pc" in
            _lacy_bash_capture_exit|lacy_shell_precmd_bash) pc="" ;;
        esac
        PROMPT_COMMAND="$pc"
    fi
}

# Precmd equivalent for Bash, the last PROMPT_COMMAND hook
lacy_shell_precmd_bash() {
    # The primary prompt is about to be drawn: its next line gets classified
    _LACY_BASH_AT_PS1=1

    # Track exit code for terminal context (only for real shell commands)
    _lacy_ctx_on_precmd "$_lacy_last_exit"

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
            if [[ -n "${NO_COLOR:-}" ]]; then
                printf '  ? @ %s\n' "$candidate"
            else
                printf '  \e[38;5;%dm?\e[0m \e[38;5;%dm@ %s\e[0m\n' \
                    "$LACY_COLOR_AGENT" "$LACY_COLOR_NEUTRAL" "$candidate"
            fi
        fi
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
        if [[ -n "${NO_COLOR:-}" ]]; then
            printf '? %s\n' "$pending"
        else
            printf '\e[38;5;%dm?\e[0m %s\n' "$LACY_COLOR_AGENT" "$pending"
        fi
        _lacy_bash_run_query "$pending"
    fi

    # Update prompt
    lacy_shell_update_prompt
}

# Run an agent query. Ctrl+C reaches the tool through the terminal as usual;
# this temporary trap only stops the spinner. The user's own INT trap, if
# any, is put back afterwards.
_lacy_bash_run_query() {
    local saved_int
    saved_int="$(trap -p INT)"
    trap '_lacy_bash_query_interrupt' INT
    lacy_shell_execute_agent "$1"
    if [[ -n "$saved_int" ]]; then
        eval "$saved_int"
    else
        trap - INT
    fi
}

_lacy_bash_query_interrupt() {
    lacy_stop_spinner 2>/dev/null
    LACY_SHELL_AGENT_RUNNING=false
    printf '\n'
}

# lacy_shell_mode, lacy_shell_tool, lacy_shell_clear_conversation,
# lacy_shell_show_conversation, and lacy() are in lib/core/commands.sh

# Quit lacy shell (the shell itself keeps running)
lacy_shell_quit() {
    LACY_SHELL_ENABLED=false
    LACY_SHELL_QUITTING=true
    unset LACY_SHELL_ACTIVE

    echo ""
    _lacy_bash_print_color "$LACY_COLOR_NEUTRAL" "${LACY_MSG_QUIT:-Exiting Lacy Shell...}"
    echo ""

    _lacy_bash_remove_prompt_hooks
    lacy_shell_cleanup_keybindings_bash

    # Terminal reset
    [[ -z "${NO_COLOR:-}" ]] && printf '\e[0m'
    printf '\e[?7h'     # Line wrapping
    printf '\e[?25h'    # Cursor visible

    # Stop preheated servers
    lacy_preheat_cleanup

    # Unset functions used as commands
    unset -f ask mode tool quit lacy 2>/dev/null

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
ask() { _lacy_bash_run_query "$*"; }
mode() { lacy_shell_mode "$@"; }
tool() { lacy_shell_tool "$@"; }
quit() { lacy_shell_quit; }
