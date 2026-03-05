#!/usr/bin/env bash

# Shell execution history capture for Lacy Shell
# Logs commands + exit codes to conversation.log.
# Shared across Bash 4+ and ZSH.

# Last command captured by preexec (ZSH) or precmd (Bash)
LACY_LAST_CMD=""

# Append a completed command + exit code to conversation.log.
# Usage: lacy_history_log "command text" exit_code
lacy_history_log() {
    local cmd="$1"
    local exit_code="${2:-0}"

    [[ -z "$cmd" ]] && return
    [[ -z "$LACY_SHELL_CONVERSATION_FILE" ]] && return

    # Skip internal lacy function calls
    [[ "$cmd" == lacy_* || "$cmd" == _lacy_* ]] && return

    local timestamp
    timestamp=$(date +%H:%M:%S 2>/dev/null) || timestamp=""

    {
        printf 'CMD: %s\n' "$cmd"
        printf 'EXIT: %s\n' "$exit_code"
        [[ -n "$timestamp" ]] && printf 'TS: %s\n' "$timestamp"
        printf -- '---\n'
    } >> "$LACY_SHELL_CONVERSATION_FILE"
}

# Return a query enriched with recent command history as context.
# Reads the last few entries from conversation.log.
# Usage: enriched=$(lacy_build_context_query "user query")
lacy_build_context_query() {
    local query="$1"
    local max_entries=5

    if [[ ! -f "$LACY_SHELL_CONVERSATION_FILE" ]]; then
        printf '%s' "$query"
        return
    fi

    local raw
    raw=$(tail -n $(( max_entries * 4 )) "$LACY_SHELL_CONVERSATION_FILE" 2>/dev/null)

    if [[ -z "$raw" ]]; then
        printf '%s' "$query"
        return
    fi

    # Parse log entries into readable context
    local context="Recent shell commands:"$'\n'
    local line cmd="" exit_code=""
    while IFS= read -r line; do
        case "$line" in
            "CMD: "*) cmd="${line#CMD: }" ;;
            "EXIT: "*) exit_code="${line#EXIT: }" ;;
            ---)
                if [[ -n "$cmd" ]]; then
                    context+="  \$ ${cmd}"
                    [[ -n "$exit_code" && "$exit_code" != "0" ]] && context+="  (exit ${exit_code})"
                    context+=$'\n'
                fi
                cmd="" exit_code=""
                ;;
        esac
    done <<< "$raw"

    printf '%s\n\n%s' "$context" "$query"
}
