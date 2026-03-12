#!/usr/bin/env bash

# Agent preheating for Lacy Shell
# - Background server for lash/opencode (eliminates cold-start)
# - Session reuse for claude (conversation continuity)
# Shared across Bash 4+ and ZSH

# === State ===
LACY_PREHEAT_SERVER_PID=""
LACY_PREHEAT_SERVER_PASSWORD=""
LACY_PREHEAT_SERVER_PID_FILE="$LACY_SHELL_HOME/.server.pid"
LACY_PREHEAT_SERVER_SESSION_ID=""
# Per-shell session files (using PID to ensure fresh session per window/tab)
LACY_PREHEAT_SERVER_SESSION_FILE="$LACY_SHELL_HOME/.server_session_id_$$"
LACY_PREHEAT_CLAUDE_SESSION_ID=""
LACY_PREHEAT_SESSION_FILE="$LACY_SHELL_HOME/.claude_session_id_$$"

# ============================================================================
# Background Server (lash + opencode)
# ============================================================================

# Start background server for lash or opencode
lacy_preheat_server_start() {
    local tool="$1"

    # Already running?
    if lacy_preheat_server_is_healthy; then
        return 0
    fi

    # Clean up stale PID from previous session
    lacy_preheat_server_stop 2>/dev/null

    # Generate random password for this session
    LACY_PREHEAT_SERVER_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 32 || date +%s%N)

    # Start server in background (suppress all job notifications)
    # Redirect stdin from /dev/null so the background server doesn't compete
    # with foreground processes (lash, vim, etc.) for terminal input.
    _lacy_jobctl_off
    "$tool" serve --port "$LACY_PREHEAT_SERVER_PORT" </dev/null >/dev/null 2>&1 &
    LACY_PREHEAT_SERVER_PID=$!
    disown 2>/dev/null
    _lacy_jobctl_on

    # Save PID to file for crash recovery
    echo "$LACY_PREHEAT_SERVER_PID" > "$LACY_PREHEAT_SERVER_PID_FILE"

    # Wait for server to become healthy (up to 3 seconds)
    local attempts=0
    while (( attempts < LACY_HEALTH_CHECK_ATTEMPTS )); do
        if lacy_preheat_server_is_healthy; then
            return 0
        fi
        sleep "$LACY_HEALTH_CHECK_INTERVAL"
        (( attempts++ ))
    done

    # Failed to start — clean up
    lacy_preheat_server_stop 2>/dev/null
    return 1
}

# Start async health check in background
lacy_preheat_server_check_async() {
    # Cancel any existing check
    [[ -n "$LACY_PREHEAT_HEALTH_CHECK_PID" ]] && kill "$LACY_PREHEAT_HEALTH_CHECK_PID" 2>/dev/null

    # Skip if we already have a fresh cache
    if [[ "$LACY_PREHEAT_HEALTH_CACHE" == true ]] && [[ -f "$LACY_SHELL_HEALTH_CACHE_FILE" ]] && \
       [[ $(find "$LACY_SHELL_HEALTH_CACHE_FILE" -mmin -1 2>/dev/null) ]]; then
        return 0
    fi

    {
        local pid="$LACY_PREHEAT_SERVER_PID"
        if [[ -z "$pid" ]]; then
            if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
                pid=$(cat "$LACY_PREHEAT_SERVER_PID_FILE" 2>/dev/null)
            fi
            [[ -z "$pid" ]] && echo "1" > "$LACY_SHELL_HEALTH_CACHE_FILE" && return
        fi

        kill -0 "$pid" 2>/dev/null || { echo "1" > "$LACY_SHELL_HEALTH_CACHE_FILE" && return; }

        if curl -sf --max-time "$LACY_HEALTH_CHECK_TIMEOUT_ASYNC" "http://localhost:${LACY_PREHEAT_SERVER_PORT}/global/health" >/dev/null 2>&1; then
            echo "0" > "$LACY_SHELL_HEALTH_CACHE_FILE"
        else
            echo "1" > "$LACY_SHELL_HEALTH_CACHE_FILE"
        fi
    } &
    LACY_PREHEAT_HEALTH_CHECK_PID=$!
    LACY_PREHEAT_HEALTH_CACHE=true
}

# Check if server is alive and responding
lacy_preheat_server_is_healthy() {
    # First check cache for instant response
    if [[ "$LACY_PREHEAT_HEALTH_CACHE" == true ]] && [[ -f "$LACY_SHELL_HEALTH_CACHE_FILE" ]]; then
        local result
        result=$(cat "$LACY_SHELL_HEALTH_CACHE_FILE" 2>/dev/null || echo "1")
        [[ "$result" == "0" ]] && return 0
    fi

    # Fallback: synchronous check
    if [[ -z "$LACY_PREHEAT_SERVER_PID" ]]; then
        if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
            LACY_PREHEAT_SERVER_PID=$(cat "$LACY_PREHEAT_SERVER_PID_FILE" 2>/dev/null)
        fi
        [[ -z "$LACY_PREHEAT_SERVER_PID" ]] && return 1
    fi

    kill -0 "$LACY_PREHEAT_SERVER_PID" 2>/dev/null || return 1

    curl -sf --max-time "$LACY_HEALTH_CHECK_TIMEOUT_SYNC" "http://localhost:${LACY_PREHEAT_SERVER_PORT}/global/health" >/dev/null 2>&1
}

# Send query to background server via REST API
lacy_preheat_server_query() {
    local query="$1"

    if [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" ]]; then
        # Pass the current working directory via the x-opencode-directory header.
        # The lash/opencode server stores this on the session and uses it for all
        # file operations — the server's own process.cwd() is irrelevant.
        local _session_dir session_json
        _session_dir=$(pwd 2>/dev/null)
        session_json=$(curl -sf --max-time "$LACY_SESSION_CREATE_TIMEOUT" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "x-opencode-directory: ${_session_dir}" \
            -d '{}' \
            "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session" 2>/dev/null)
        [[ $? -ne 0 ]] && return 1

        LACY_PREHEAT_SERVER_SESSION_ID=$(_lacy_json_get "$session_json" "id")
        [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" ]] && return 1
        # Persist to file so parent shell can read it (subshell workaround)
        echo "$LACY_PREHEAT_SERVER_SESSION_ID" > "$LACY_PREHEAT_SERVER_SESSION_FILE"
        # Also persist to a global 'latest' file for resume support
        local latest_file="${LACY_PREHEAT_SERVER_SESSION_FILE%_*}_latest"
        echo "$LACY_PREHEAT_SERVER_SESSION_ID" > "$latest_file"
    fi

    local escaped_query
    escaped_query=$(printf '%s' "$query" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

    # Pass the current working directory on every message request.
    # lash/opencode wraps each request in Instance.provide({ directory }) so
    # per-message directory takes effect even on an existing session — this
    # preserves conversation continuity while keeping CWD always accurate.
    local _msg_dir
    _msg_dir=$(pwd 2>/dev/null)

    local response
    response=$(curl -sf --max-time "$LACY_SESSION_MESSAGE_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "x-opencode-directory: ${_msg_dir}" \
        -d "{\"parts\": [{\"type\": \"text\", \"text\": \"${escaped_query}\"}]}" \
        "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session/${LACY_PREHEAT_SERVER_SESSION_ID}/message" 2>/dev/null)

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        LACY_PREHEAT_SERVER_SESSION_ID=""
        rm -f "$LACY_PREHEAT_SERVER_SESSION_FILE"
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$response" | jq -r '
            if type == "array" then
                [.[] | select(.role == "assistant") | .parts[]? | select(.type == "text") | .text] | last // empty
            elif .parts then
                [.parts[] | select(.type == "text") | .text] | join("\n") // empty
            else
                .result // .content // .text // .response // .message // empty
            end' 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$response" | python3 -c "
import json, sys
data = sys.stdin.read().strip()
for line in reversed(data.split('\n')):
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        if isinstance(obj, list):
            for msg in reversed(obj):
                if msg.get('role') == 'assistant':
                    texts = [p['text'] for p in msg.get('parts', []) if p.get('type') == 'text']
                    if texts: print('\n'.join(texts)); sys.exit(0)
        elif isinstance(obj, dict):
            parts = obj.get('parts', [])
            texts = [p['text'] for p in parts if p.get('type') == 'text']
            if texts: print('\n'.join(texts)); sys.exit(0)
            for key in ('result', 'content', 'text', 'response', 'message'):
                val = obj.get(key)
                if val and isinstance(val, str): print(val); sys.exit(0)
    except (json.JSONDecodeError, KeyError, TypeError): continue
print(data)" 2>/dev/null
    else
        printf '%s' "$response" | sed 's/.*"text"[[:space:]]*:[[:space:]]*"//' | sed 's/"[[:space:]]*[,}\]].*//' | sed 's/\\n/\'$'\n''/g; s/\\"/"/g; s/\\\\/\\/g'
    fi
}

# Stop background server and clean up
lacy_preheat_server_stop() {
    if [[ -n "$LACY_PREHEAT_SERVER_PID" ]]; then
        kill "$LACY_PREHEAT_SERVER_PID" 2>/dev/null
        wait "$LACY_PREHEAT_SERVER_PID" 2>/dev/null
        LACY_PREHEAT_SERVER_PID=""
    fi

    if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
        local file_pid
        file_pid=$(cat "$LACY_PREHEAT_SERVER_PID_FILE" 2>/dev/null)
        if [[ -n "$file_pid" ]]; then
            kill "$file_pid" 2>/dev/null
            wait "$file_pid" 2>/dev/null
        fi
        rm -f "$LACY_PREHEAT_SERVER_PID_FILE"
    fi

    LACY_PREHEAT_SERVER_PASSWORD=""
    LACY_PREHEAT_SERVER_SESSION_ID=""
    rm -f "$LACY_PREHEAT_SERVER_SESSION_FILE"
}

# Restore server session ID from file (survives subshell boundary)
lacy_preheat_server_restore_session() {
    if [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" && -f "$LACY_PREHEAT_SERVER_SESSION_FILE" ]]; then
        LACY_PREHEAT_SERVER_SESSION_ID=$(cat "$LACY_PREHEAT_SERVER_SESSION_FILE" 2>/dev/null)
    fi
}

# ============================================================================
# Generic Session Reuse
# ============================================================================

# Internal helper to restore a session ID from a file
_lacy_session_restore() {
    local file="$1"
    local var_name="$2"
    if [[ -f "$file" ]]; then
        eval "$var_name=\"\$(cat \"\$file\" 2>/dev/null)\""
    fi
}

# Internal helper to build a tool command with optional session resume
_lacy_session_build_cmd() {
    local tool="$1"
    local session_id="$2"
    local file="$3"
    local var_name="$4"

    # Ensure we have the latest session ID from the file (subshell workaround)
    if [[ -z "$session_id" ]]; then
        _lacy_session_restore "$file" "$var_name"
        eval "session_id=\"\$$var_name\""
    fi

    if [[ -n "$session_id" ]]; then
        echo "${tool} --resume ${session_id} --output-format json -p"
    else
        echo "${tool} --output-format json -p"
    fi
}

# Internal helper to capture a session ID from JSON response and persist it
_lacy_session_capture() {
    local json="$1"
    local file="$2"
    local var_name="$3"
    local key_name="${4:-session_id}"
    local session_id
    session_id=$(_lacy_json_get "$json" "$key_name")

    if [[ -n "$session_id" ]]; then
        eval "$var_name=\"\$session_id\""
        echo "$session_id" > "$file"
        
        # Also persist to a global 'latest' file for resume support across shells
        local latest_file="${file%_*}_latest"
        echo "$session_id" > "$latest_file"
    fi
}

# Internal helper to reset a session
_lacy_session_reset() {
    local file="$1"
    local var_name="$2"
    eval "$var_name=\"\""
    rm -f "$file"
}

# ============================================================================
# Claude Session Reuse
# ============================================================================

lacy_preheat_claude_restore_session() {
    _lacy_session_restore "$LACY_PREHEAT_SESSION_FILE" "LACY_PREHEAT_CLAUDE_SESSION_ID"
}

lacy_preheat_claude_build_cmd() {
    _lacy_session_build_cmd "claude" "$LACY_PREHEAT_CLAUDE_SESSION_ID" "$LACY_PREHEAT_SESSION_FILE" "LACY_PREHEAT_CLAUDE_SESSION_ID"
}

lacy_preheat_claude_capture_session() {
    _lacy_session_capture "$1" "$LACY_PREHEAT_SESSION_FILE" "LACY_PREHEAT_CLAUDE_SESSION_ID" "session_id"
}

lacy_preheat_claude_extract_result() {
    _lacy_json_get "$1" "result"
}

lacy_preheat_claude_reset_session() {
    _lacy_session_reset "$LACY_PREHEAT_SESSION_FILE" "LACY_PREHEAT_CLAUDE_SESSION_ID"
}

# ============================================================================
# Gemini Session Reuse
# ============================================================================

LACY_GEMINI_SESSION_ID=""
LACY_GEMINI_SESSION_ID_FILE="$LACY_SHELL_HOME/.gemini_session_id_$$"

lacy_preheat_gemini_restore_session() {
    _lacy_session_restore "$LACY_GEMINI_SESSION_ID_FILE" "LACY_GEMINI_SESSION_ID"
}

lacy_preheat_gemini_build_cmd() {
    _lacy_session_build_cmd "gemini" "$LACY_GEMINI_SESSION_ID" "$LACY_GEMINI_SESSION_ID_FILE" "LACY_GEMINI_SESSION_ID"
}

lacy_preheat_gemini_capture_session() {
    _lacy_session_capture "$1" "$LACY_GEMINI_SESSION_ID_FILE" "LACY_GEMINI_SESSION_ID" "session_id"
}

lacy_preheat_gemini_extract_result() {
    _lacy_json_get "$1" "response"
}

lacy_preheat_gemini_reset_session() {
    _lacy_session_reset "$LACY_GEMINI_SESSION_ID_FILE" "LACY_GEMINI_SESSION_ID"
}

# ============================================================================
# Lifecycle
# ============================================================================

lacy_preheat_init() {
    # Per-shell session files ensure a fresh session on every new shell start.
    # We no longer need to restore here because the PID-specific file won't exist yet.

    if [[ "$LACY_RESUME_SESSION" == "1" ]]; then
        lacy_preheat_resume_latest
    fi

    if [[ "$LACY_PREHEAT_EAGER" == "true" ]]; then
        local tool="${LACY_ACTIVE_TOOL}"

        if [[ "$tool" == "lash" || "$tool" == "opencode" ]]; then
            _lacy_jobctl_off
            lacy_preheat_server_start "$tool" &
            disown 2>/dev/null
            _lacy_jobctl_on
        fi
    fi
}

lacy_preheat_cleanup() {
    lacy_preheat_server_stop
}

# Resume the latest session across all shells for the current tool
lacy_preheat_resume_latest() {
    # Ensure config is loaded to know which tool to use
    [[ -n "$(declare -f lacy_shell_load_config)" ]] && lacy_shell_load_config

    local tool="${LACY_ACTIVE_TOOL}"
    # Auto-detect if not set
    if [[ -z "$tool" ]]; then
        local t
        for t in lash claude opencode gemini; do
            if command -v "$t" >/dev/null 2>&1; then
                tool="$t"
                break
            fi
        done
    fi

    [[ -z "$tool" ]] && return 1

    local latest_file
    case "$tool" in
        lash|opencode)
            latest_file="${LACY_PREHEAT_SERVER_SESSION_FILE%_*}_latest"
            if [[ -f "$latest_file" ]]; then
                LACY_PREHEAT_SERVER_SESSION_ID=$(cat "$latest_file" 2>/dev/null)
                echo "$LACY_PREHEAT_SERVER_SESSION_ID" > "$LACY_PREHEAT_SERVER_SESSION_FILE"
                return 0
            fi
            ;;
        claude)
            latest_file="${LACY_PREHEAT_SESSION_FILE%_*}_latest"
            if [[ -f "$latest_file" ]]; then
                LACY_PREHEAT_CLAUDE_SESSION_ID=$(cat "$latest_file" 2>/dev/null)
                echo "$LACY_PREHEAT_CLAUDE_SESSION_ID" > "$LACY_PREHEAT_SESSION_FILE"
                return 0
            fi
            ;;
        gemini)
            latest_file="${LACY_GEMINI_SESSION_ID_FILE%_*}_latest"
            if [[ -f "$latest_file" ]]; then
                LACY_GEMINI_SESSION_ID=$(cat "$latest_file" 2>/dev/null)
                echo "$LACY_GEMINI_SESSION_ID" > "$LACY_GEMINI_SESSION_ID_FILE"
                return 0
            fi
            ;;
    esac
    return 1
}
