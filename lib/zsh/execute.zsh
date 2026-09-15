#!/usr/bin/env zsh

# Command execution logic for Lacy Shell

# Pending internal command (set by the accept-line widget, dispatched by precmd)
LACY_SHELL_PENDING_CMD=""

# First-run hint: shown once ever, on the first empty prompt after load
LACY_HINT_QUERY="what files are here"
LACY_HINT_DISPLAY="what files are here   (Enter to ask, or just type)"

# Smart accept-line widget that handles agent queries
lacy_shell_smart_accept_line() {
    # If Lacy Shell is disabled, use normal accept-line
    if [[ "$LACY_SHELL_ENABLED" != true ]]; then
        zle .accept-line
        return
    fi

    local input="$BUFFER"

    # Empty line: Enter asks the first-run hint; any other ghost text is dismissed
    if [[ -z "$input" ]]; then
        if [[ "$LACY_SHELL_HINT_ACTIVE" == true && -n "$LACY_SHELL_SUGGESTION" ]]; then
            local hint="$LACY_SHELL_SUGGESTION"
            _lacy_clear_suggestion
            _lacy_submit_agent_query "$hint" "$hint"
            return
        fi
        _lacy_clear_suggestion
        zle .accept-line
        return
    fi

    local trimmed="${input#"${input%%[^[:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[^[:space:]]}"}"

    # Checked before classification, in every mode:
    # `exit` always exits the shell, `quit` leaves Lacy.
    case "$trimmed" in
        exit|exit\ <->)
            zle .accept-line
            return
            ;;
        quit|/new|/reset|/clear|/resume)
            local _cmd_hist="${input//\\/\\\\}"
            print -s -- "$_cmd_hist"
            fc -AI 2>/dev/null
            case "$trimmed" in
                quit)    LACY_SHELL_PENDING_CMD="quit" ;;
                /resume) LACY_SHELL_PENDING_CMD="session_resume" ;;
                *)       LACY_SHELL_PENDING_CMD="session_new" ;;
            esac
            BUFFER=""
            zle .accept-line
            return
            ;;
    esac

    # Classify using centralized detection (handles whitespace trimming internally).
    # Read the result variable instead of $( ) to avoid a fork on every Enter.
    local classification
    lacy_shell_classify_input "$input" >/dev/null
    classification="$_LACY_CLASSIFY_RESULT"

    case "$classification" in
        "neutral")
            zle .accept-line
            return
            ;;
        "shell")
            # Bypass only when ! is glued to the command (`!rm -rf x`).
            # `! true` with a space is the shell's own negation: leave it alone.
            if [[ "$trimmed" == \![^[:space:]]* ]]; then
                trimmed="${trimmed#!}"
                BUFFER="$trimmed"
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
            _lacy_submit_agent_query "$agent_input" "$input"
            ;;
    esac
}

# Hand an agent query to precmd and accept the line.
# Output produced inside a ZLE widget confuses ZLE's cursor tracking, so the
# query runs in precmd. BUFFER is emptied so the shell runs nothing; the typed
# text moves to POSTDISPLAY so the accepted line still shows it, with no need
# to re-render the user's prompt.
# Usage: _lacy_submit_agent_query <query> <text as typed>
_lacy_submit_agent_query() {
    local query="$1" shown="$2"

    # Add to history before clearing buffer.
    # Double backslashes before print -s: ZSH's print processes \X escape
    # sequences even with -s, so "Google\ Chrome" becomes "Google Chrome".
    # Doubling (\ -> \\) makes print convert \\ -> \, preserving the original.
    local _hist_input="${shown//\\/\\\\}"
    print -s -- "$_hist_input"
    # Flush to HISTFILE immediately, needed for INC_APPEND_HISTORY / SHARE_HISTORY
    # users, since the subsequent empty-buffer accept-line doesn't write the file.
    fc -AI 2>/dev/null

    LACY_SHELL_PENDING_QUERY="$query"
    BUFFER=""
    (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear
    POSTDISPLAY="$shown"
    LACY_SHELL_OWN_POSTDISPLAY=false

    local own_pre=0
    _lacy_set_indicator agent && own_pre=1
    if (( _LACY_ZLE_HL )); then
        region_highlight=("${(@)region_highlight:#*memo=lacy*}")
        if [[ -z ${NO_COLOR-} ]]; then
            (( own_pre )) && region_highlight+=("P0 1 fg=${LACY_COLOR_AGENT} memo=lacy")
            _lacy_first_word_bounds "$shown"
            if (( _LACY_FW_END > _LACY_FW_START )); then
                region_highlight+=("$_LACY_FW_START $_LACY_FW_END fg=${LACY_COLOR_AGENT},bold memo=lacy")
            fi
        fi
    fi

    zle .accept-line
}

# Arm the first-run hint (once ever; flag file written when armed)
_lacy_arm_first_run_hint() {
    [[ "$LACY_SHELL_CURRENT_MODE" == "shell" ]] && return
    [[ -e "$LACY_SHELL_HOME/.hinted" ]] && return
    [[ -n "$LACY_SHELL_SUGGESTION" ]] && return
    [[ -d "$LACY_SHELL_HOME" ]] || mkdir -p "$LACY_SHELL_HOME" 2>/dev/null || return
    { : >| "$LACY_SHELL_HOME/.hinted" } 2>/dev/null || return
    LACY_SHELL_SUGGESTION="$LACY_HINT_QUERY"
    LACY_SHELL_SUGGESTION_DISPLAY="$LACY_HINT_DISPLAY"
    LACY_SHELL_HINT_ACTIVE=true
}

# lacy_shell_execute_agent is in lib/core/commands.sh

# Precmd hook - called before each prompt
lacy_shell_precmd() {
    # Capture exit code immediately; must be the first line
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
    LACY_SHELL_SUGGESTION_DISPLAY=""
    LACY_SHELL_HINT_ACTIVE=false

    # Check reroute candidate: if the command failed with a non-signal exit
    # code (< 128), set ghost text suggestion to re-try via agent with @ prefix.
    if [[ -n "$LACY_SHELL_REROUTE_CANDIDATE" ]]; then
        local candidate="$LACY_SHELL_REROUTE_CANDIDATE"
        LACY_SHELL_REROUTE_CANDIDATE=""
        if (( last_exit != 0 && last_exit < LACY_SIGNAL_EXIT_THRESHOLD )); then
            LACY_SHELL_SUGGESTION="@ ${candidate}"
        fi
    fi

    # Handle pending internal commands (quit and slash-prefixed session commands)
    if [[ -n "$LACY_SHELL_PENDING_CMD" ]]; then
        local _cmd="$LACY_SHELL_PENDING_CMD"
        LACY_SHELL_PENDING_CMD=""
        case "$_cmd" in
            quit)
                lacy_shell_quit
                return
                ;;
            session_new)    lacy_session_new ;;
            session_resume) lacy_session_resume ;;
        esac
    fi

    # Handle pending agent query (deferred from ZLE widget for clean cursor tracking)
    if [[ -n "$LACY_SHELL_PENDING_QUERY" ]]; then
        local pending="$LACY_SHELL_PENDING_QUERY"
        LACY_SHELL_PENDING_QUERY=""
        {
            lacy_shell_execute_agent "$pending"
        } always {
            _lacy_query_interrupt_cleanup
        }
    fi

    # First-run hint, checked on the first prompt after load only
    if [[ -z "$_LACY_HINT_CHECKED" ]]; then
        _LACY_HINT_CHECKED=1
        _lacy_arm_first_run_hint
    fi

    # Update mode badge in the right prompt
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

    # Disable input interception
    if [[ -o zle ]]; then
        zle -A .accept-line accept-line 2>/dev/null
    fi

    # Reset attributes, line wrapping and cursor visibility left by an agent
    # tool. No cursor moves or screen clears: the user's scrollback stays put.
    printf '\e[0m\e[?7h\e[?25h'

    # Stop servers, restore bindings, hooks and RPS1
    lacy_shell_cleanup

    # Unset aliases and function overrides
    unalias mode tool quit 2>/dev/null
    unfunction ask lacy 2>/dev/null

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

    echo ""
    zle && zle reset-prompt 2>/dev/null
    return 0
}

# lacy_shell_mode, lacy_shell_tool, lacy_shell_clear_conversation,
# lacy_shell_show_conversation, and lacy() are in lib/core/commands.sh

# `ask` sends every argument as one query (an alias would pass only $1)
unalias ask 2>/dev/null
function ask {
    {
        lacy_shell_query_agent "$*"
    } always {
        _lacy_query_interrupt_cleanup
    }
}

alias mode="lacy_shell_mode"
alias tool="lacy_shell_tool"
alias quit="lacy_shell_quit"
