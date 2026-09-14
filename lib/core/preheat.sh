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
# Global last-session file (not PID-specific) — enables cross-shell resume
LACY_LAST_SESSION_FILE="$LACY_SHELL_HOME/.last_session"

# ============================================================================
# Background Server (lash + opencode)
# ============================================================================

# --- Port and process helpers -------------------------------------------------
#
# The npm `lash` command is a Node wrapper that spawns the Bun binary and
# forwards no signals. Killing the wrapper PID leaves the real server (the
# process that holds the port) alive, reparented to PID 1. So every lookup
# here goes by port, and every kill is verified against the command line.

# Print PIDs listening on a TCP port, one per line. lsof first, fuser second.
# Returns 1 when neither tool exists (caller falls back to the PID file).
_lacy_port_listeners() {
    local port="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null
        return 0
    fi
    if command -v fuser >/dev/null 2>&1; then
        fuser -n tcp "$port" 2>/dev/null | tr -s ' \t' '\n' | grep -E '^[0-9]+$'
        return 0
    fi
    return 1
}

# True when PID is alive and its command line is a server on our port.
# Guards every kill: a recycled PID from a stale file must never be signalled.
_lacy_is_server_pid() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    local cmdline
    cmdline=$(ps -o command= -p "$pid" 2>/dev/null)
    [[ "$cmdline" == *"serve --port ${LACY_PREHEAT_SERVER_PORT}" || \
       "$cmdline" == *"serve --port ${LACY_PREHEAT_SERVER_PORT} "* ]]
}

# Print the PID that actually holds the server port (the Bun binary, not the
# npm wrapper). Empty and return 1 when no verified server is listening.
_lacy_preheat_server_listener_pid() {
    local listeners pid
    listeners=$(_lacy_port_listeners "$LACY_PREHEAT_SERVER_PORT") || return 1
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        if _lacy_is_server_pid "$pid"; then
            echo "$pid"
            return 0
        fi
    done <<< "$listeners"
    return 1
}

# Record the server PID in memory and on disk (shared by every lacy shell).
_lacy_preheat_server_record_pid() {
    LACY_PREHEAT_SERVER_PID="$1"
    echo "$1" > "$LACY_PREHEAT_SERVER_PID_FILE"
}

# Start background server for lash or opencode
lacy_preheat_server_start() {
    local tool="$1"

    # Already running?
    if lacy_preheat_server_is_healthy; then
        return 0
    fi

    local listener
    listener=$(_lacy_preheat_server_listener_pid)
    if [[ -n "$listener" ]]; then
        # A server already holds the port (another tab, or a survivor from an
        # earlier shell). Adopt it and wait for it to answer.
        _lacy_preheat_server_record_pid "$listener"
    else
        # Clean up stale PID from previous session
        lacy_preheat_server_stop 2>/dev/null

        # Generate random password for this session
        LACY_PREHEAT_SERVER_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 32 || date +%s%N)

        # Start server in background (suppress all job notifications)
        # Redirect stdin from /dev/null so the background server doesn't compete
        # with foreground processes (lash, vim, etc.) for terminal input.
        _lacy_jobctl_off
        "$tool" serve --port "$LACY_PREHEAT_SERVER_PORT" </dev/null >/dev/null 2>&1 &
        _lacy_preheat_server_record_pid "$!"
        disown 2>/dev/null
        _lacy_jobctl_on
    fi

    # Wait for the server to answer (LACY_HEALTH_CHECK_ATTEMPTS x INTERVAL)
    local attempts=0
    while (( attempts < LACY_HEALTH_CHECK_ATTEMPTS )); do
        if lacy_preheat_server_is_healthy; then
            # Swap the wrapper PID for the PID that holds the port
            listener=$(_lacy_preheat_server_listener_pid)
            [[ -n "$listener" ]] && _lacy_preheat_server_record_pid "$listener"
            return 0
        fi
        sleep "$LACY_HEALTH_CHECK_INTERVAL"
        (( attempts++ ))
    done

    # Budget exhausted. A slow server that holds the port is left alone so the
    # next query can use it. Only a dead one gets cleaned up.
    listener=$(_lacy_preheat_server_listener_pid)
    if [[ -n "$listener" ]]; then
        _lacy_preheat_server_record_pid "$listener"
        return 1
    fi
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

# Internal helper to create a new server session (lash/opencode)
_lacy_preheat_server_create_session() {
    if ! lacy_preheat_server_is_healthy; then
        return 1
    fi

    local _session_dir session_json
    _session_dir=$(pwd 2>/dev/null)
    if session_json=$(curl -sf --max-time "$LACY_SESSION_CREATE_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "x-opencode-directory: ${_session_dir}" \
        -d '{}' \
        "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session" 2>/dev/null); then
        LACY_PREHEAT_SERVER_SESSION_ID=$(_lacy_json_get "$session_json" "id")
        if [[ -n "$LACY_PREHEAT_SERVER_SESSION_ID" ]]; then
            echo "$LACY_PREHEAT_SERVER_SESSION_ID" > "$LACY_PREHEAT_SERVER_SESSION_FILE"
            return 0
        fi
    fi
    return 1
}

# Return codes from lacy_preheat_server_query. Only UNREACHABLE means the
# prompt never left this machine; every other failure must not be re-sent.
LACY_SERVER_QUERY_OK=0
LACY_SERVER_QUERY_UNREACHABLE=1   # curl 7 or no session: safe to retry single-shot
LACY_SERVER_QUERY_HTTP_ERROR=2    # server answered with an error; body on stdout
LACY_SERVER_QUERY_TIMEOUT=3       # curl 28: request still running on the server
LACY_SERVER_QUERY_LOST=4          # other curl failure mid-request
LACY_SERVER_QUERY_SESSION_GONE=5  # HTTP 404: the session no longer exists

# Send query to background server via REST API.
# Prints the assistant text on success. See the return codes above; the caller
# (usually inside $(...)) resets the session on codes that invalidate it.
lacy_preheat_server_query() {
    local query="$1"

    if [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" ]]; then
        _lacy_preheat_server_create_session || return "$LACY_SERVER_QUERY_UNREACHABLE"
    fi

    local escaped_query
    escaped_query=$(_lacy_json_escape_str "$query")

    # Pass the current working directory on every message request.
    # lash/opencode wraps each request in Instance.provide({ directory }) so
    # per-message directory takes effect even on an existing session, which
    # preserves conversation continuity while keeping CWD always accurate.
    local _msg_dir
    _msg_dir=$(pwd 2>/dev/null)

    local body_file http_code curl_rc response
    body_file=$(mktemp 2>/dev/null) || body_file="${LACY_SHELL_HOME}/.server_body_$$"
    http_code=$(curl -s --max-time "$LACY_SESSION_MESSAGE_TIMEOUT" \
        -o "$body_file" -w '%{http_code}' \
        -X POST \
        -H "Content-Type: application/json" \
        -H "x-opencode-directory: ${_msg_dir}" \
        -d "{\"parts\": [{\"type\": \"text\", \"text\": \"${escaped_query}\"}]}" \
        "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session/${LACY_PREHEAT_SERVER_SESSION_ID}/message" 2>/dev/null)
    curl_rc=$?
    response=$(cat "$body_file" 2>/dev/null)
    command rm -f "$body_file"

    case "$curl_rc" in
        0) ;;
        7)  return "$LACY_SERVER_QUERY_UNREACHABLE" ;;
        28) return "$LACY_SERVER_QUERY_TIMEOUT" ;;
        *)  return "$LACY_SERVER_QUERY_LOST" ;;
    esac

    if [[ ! "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        printf '%s' "$response"
        # 404 means the session is gone: drop it so the next query starts fresh.
        # This reset is visible only when called directly; a $(...) caller
        # must mirror it from the return code.
        if [[ "$http_code" == "404" ]]; then
            LACY_PREHEAT_SERVER_SESSION_ID=""
            : > "$LACY_PREHEAT_SERVER_SESSION_FILE"
            return "$LACY_SERVER_QUERY_SESSION_GONE"
        fi
        return "$LACY_SERVER_QUERY_HTTP_ERROR"
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

# Stop background server and clean up.
# Kills by port, not by remembered PID: the npm wrapper dies on its own signal
# but the Bun process it spawned keeps the port. Every candidate is verified
# against its command line first, so a recycled PID is never touched.
lacy_preheat_server_stop() {
    local pid file_pid="" listeners
    local -a victims
    victims=()

    if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
        file_pid=$(cat "$LACY_PREHEAT_SERVER_PID_FILE" 2>/dev/null)
    fi

    # 1. Whatever holds the port
    listeners=$(_lacy_port_listeners "$LACY_PREHEAT_SERVER_PORT")
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        _lacy_is_server_pid "$pid" && victims+=("$pid")
    done <<< "$listeners"

    # 2. Remembered PIDs (wrapper or listener) and the wrapper's children
    for pid in "$LACY_PREHEAT_SERVER_PID" "$file_pid"; do
        [[ -n "$pid" ]] || continue
        _lacy_is_server_pid "$pid" || continue
        victims+=("$pid")
        pkill -TERM -P "$pid" -f "serve --port ${LACY_PREHEAT_SERVER_PORT}" 2>/dev/null
    done

    if (( ${#victims[@]} > 0 )); then
        for pid in "${victims[@]}"; do
            kill -TERM "$pid" 2>/dev/null
        done
        # Give them a moment, then force anything still alive
        local tries=0 alive
        while (( tries < 10 )); do
            alive=""
            for pid in "${victims[@]}"; do
                kill -0 "$pid" 2>/dev/null && alive="1"
            done
            [[ -z "$alive" ]] && break
            sleep 0.1
            (( tries++ ))
        done
        for pid in "${victims[@]}"; do
            kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
        done
    fi

    LACY_PREHEAT_SERVER_PID=""
    command rm -f "$LACY_PREHEAT_SERVER_PID_FILE"
    command rm -f "$LACY_SHELL_HEALTH_CACHE_FILE"

    LACY_PREHEAT_SERVER_PASSWORD=""
    LACY_PREHEAT_SERVER_SESSION_ID=""
    # Keep the marker file (other shells use it to see we are alive), drop its contents
    [[ -f "$LACY_PREHEAT_SERVER_SESSION_FILE" ]] && : > "$LACY_PREHEAT_SERVER_SESSION_FILE" 2>/dev/null
    return 0
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
        local _val
        _val=$(cat "$file" 2>/dev/null)
        printf -v "$var_name" '%s' "$_val"
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
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            session_id="${(P)var_name}"
        else
            session_id="${!var_name}"
        fi
    fi

    local parts="${tool}"
    [[ -n "$session_id" ]] && parts+=" --resume ${session_id}"
    if [[ "$tool" == "claude" ]]; then
        parts+=" --output-format json"
    fi
    parts+=" -p"
    echo "$parts"
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
        printf -v "$var_name" '%s' "$session_id"
        echo "$session_id" > "$file"
    fi
}

# Internal helper to reset a session
_lacy_session_reset() {
    local file="$1"
    local var_name="$2"
    printf -v "$var_name" '%s' ""
    command rm -f "$file"
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
# Session Commands (new / resume)
# ============================================================================

# Return the active tool name: LACY_ACTIVE_TOOL if set, else first installed tool found.
_lacy_get_current_tool() {
    if [[ -n "${LACY_ACTIVE_TOOL:-}" ]]; then
        echo "$LACY_ACTIVE_TOOL"
        return
    fi
    local t
    for t in "${LACY_TOOL_LIST[@]}"; do
        command -v "$t" >/dev/null 2>&1 && { echo "$t"; return; }
    done
}

# Persist current session state to global file for cross-shell resume.
# Called after each successful agent query via _lacy_print_resume_hint.
_lacy_save_last_session() {
    local tool
    tool=$(_lacy_get_current_tool)

    local session_id=""
    case "$tool" in
        lash|opencode)   session_id="$LACY_PREHEAT_SERVER_SESSION_ID" ;;
        claude)          session_id="$LACY_PREHEAT_CLAUDE_SESSION_ID" ;;
        gemini)          session_id="$LACY_GEMINI_SESSION_ID" ;;
        codex|hermes|copilot|goose|amp) session_id="default" ;;
    esac

    [[ -n "$session_id" && -n "$tool" ]] || return 0
    printf '%s\n%s\n' "$tool" "$session_id" > "$LACY_LAST_SESSION_FILE"
}

# Clear all session state and start a fresh context.
# For server-based tools (lash/opencode), eagerly creates a new session (blocking).
lacy_session_new() {
    # Persist current session before clearing (enables cross-shell resume)
    _lacy_save_last_session

    # Reset all per-session state
    lacy_preheat_claude_reset_session
    lacy_preheat_gemini_reset_session
    LACY_PREHEAT_SERVER_SESSION_ID=""
    : > "$LACY_PREHEAT_SERVER_SESSION_FILE"

    # Reset terminal context so the next query sends full context
    _lacy_ctx_reset

    # For server-based tools, pre-create a new session now (blocking)
    local tool
    tool=$(_lacy_get_current_tool)

    if [[ "$tool" == "lash" || "$tool" == "opencode" ]]; then
        lacy_start_spinner
        _lacy_preheat_server_create_session
        lacy_stop_spinner
    fi

    echo ""
    lacy_print_color 34 "  New session started"
    echo ""
}

# Resume the last saved session in the current shell.
# Reads from LACY_LAST_SESSION_FILE — written after every successful query.
lacy_session_resume() {
    local saved_tool="" saved_id=""
    if [[ -f "$LACY_LAST_SESSION_FILE" ]]; then
        { read -r saved_tool; read -r saved_id; } < "$LACY_LAST_SESSION_FILE"
    fi

    if [[ -z "$saved_tool" || -z "$saved_id" ]]; then
        echo ""
        lacy_print_color 238 "  No previous session to resume"
        echo ""
        return 1
    fi

    # Swap: save current session before overwriting (so it's resumable in turn)
    _lacy_save_last_session

    # Switch active tool to match the saved session
    local current_tool
    current_tool=$(_lacy_get_current_tool)
    if [[ -n "$current_tool" && "$current_tool" != "$saved_tool" ]]; then
        LACY_ACTIVE_TOOL="$saved_tool"
        export LACY_ACTIVE_TOOL
    fi

    # Load saved session into current shell state
    case "$saved_tool" in
        lash|opencode)
            LACY_PREHEAT_SERVER_SESSION_ID="$saved_id"
            echo "$saved_id" > "$LACY_PREHEAT_SERVER_SESSION_FILE"
            ;;
        claude)
            LACY_PREHEAT_CLAUDE_SESSION_ID="$saved_id"
            echo "$saved_id" > "$LACY_PREHEAT_SESSION_FILE"
            ;;
        gemini)
            LACY_GEMINI_SESSION_ID="$saved_id"
            echo "$saved_id" > "$LACY_GEMINI_SESSION_ID_FILE"
            ;;
        codex|hermes|copilot|goose|amp)
            ;;
    esac

    echo ""
    lacy_print_color 34 "  Resumed $saved_tool session"
    lacy_print_color 238 "  $saved_id"
    echo ""
}

# ============================================================================
# Lifecycle
# ============================================================================

lacy_preheat_init() {
    # Per-shell session files ensure a fresh session on every new shell start.
    # Touch ours now so other shells can tell we are alive (see cleanup).
    mkdir -p "$LACY_SHELL_HOME" 2>/dev/null
    [[ -f "$LACY_PREHEAT_SERVER_SESSION_FILE" ]] || : > "$LACY_PREHEAT_SERVER_SESSION_FILE" 2>/dev/null

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

# Count other lacy shells that are still alive, judged by their per-shell
# session marker files. Dead shells' leftovers are removed on the way.
_lacy_preheat_other_shells() {
    local count=0 f pid
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        pid="${f##*_}"
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [[ "$pid" == "$$" ]] && continue
        if kill -0 "$pid" 2>/dev/null; then
            (( count++ ))
        else
            command rm -f "$f"
        fi
    done < <(find "$LACY_SHELL_HOME" -maxdepth 1 -name '.server_session_id_*' 2>/dev/null)
    echo "$count"
}

# Release this shell's server state. The server itself is shared by every
# lacy shell on this machine, so it is only stopped by the last one out.
lacy_preheat_cleanup() {
    command rm -f "$LACY_PREHEAT_SERVER_SESSION_FILE" \
                  "$LACY_PREHEAT_SESSION_FILE" \
                  "$LACY_GEMINI_SESSION_ID_FILE"
    LACY_PREHEAT_SERVER_SESSION_ID=""

    if [[ "$(_lacy_preheat_other_shells)" == "0" ]]; then
        lacy_preheat_server_stop
    else
        LACY_PREHEAT_SERVER_PID=""
    fi
}
