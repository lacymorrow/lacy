#!/usr/bin/env bash

# Shell execution history capture + query enrichment for Lacy Shell
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

# ============================================================================
# Feature 2: @file reference expansion
#
# Scans a query string for @path tokens. For each token that resolves to a
# readable file, the file's contents are appended to the query so the agent
# can read them directly.
#
# Rules:
#   - Token must start with @ and contain at least one non-@ character
#   - Trailing punctuation (,.;:!?) is stripped before resolving
#   - Files larger than 8 KB are truncated
#   - Each file is included at most once (deduplication)
#
# Usage: expanded=$(lacy_expand_file_refs "fix the bug in @src/main.go")
# ============================================================================
LACY_EXPANDED_FILES=()   # populated by lacy_expand_file_refs, read by mcp.sh

lacy_expand_file_refs() {
    local query="$1"
    local result="$query"
    local seen=":"   # colon-delimited list of already-expanded paths
    LACY_EXPANDED_FILES=()

    local tmp="$query"
    while [[ "$tmp" == *"@"* ]]; do
        tmp="${tmp#*@}"                         # advance past the next @
        local token="${tmp%%[[:space:]]*}"       # grab word up to whitespace
        tmp="${tmp#"$token"}"                   # advance past the token

        [[ -z "$token" ]] && continue

        # Strip trailing punctuation characters
        local path="$token"
        while [[ -n "$path" && "${path: -1}" == [,.:;!?] ]]; do
            path="${path%?}"
        done

        [[ -z "$path" ]] && continue

        # Expand readable files not yet seen
        if [[ -f "$path" && -r "$path" && "$seen" != *":${path}:"* ]]; then
            seen+=":${path}:"
            LACY_EXPANDED_FILES+=("$path")
            local contents
            contents=$(head -c 8192 "$path" 2>/dev/null)
            result+=$'\n\n'"--- @${path} ---"$'\n'"${contents}"$'\n'"---"
        fi
    done

    printf '%s' "$result"
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
