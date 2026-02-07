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
LACY_PREHEAT_CLAUDE_SESSION_ID=""
LACY_PREHEAT_SESSION_FILE="$LACY_SHELL_HOME/.claude_session_id"

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

        if curl -sf --max-time 0.5 "http://localhost:${LACY_PREHEAT_SERVER_PORT}/global/health" >/dev/null 2>&1; then
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

    curl -sf --max-time 0.3 "http://localhost:${LACY_PREHEAT_SERVER_PORT}/global/health" >/dev/null 2>&1
}

# Send query to background server via REST API
lacy_preheat_server_query() {
    local query="$1"

    if [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" ]]; then
        local session_json
        session_json=$(curl -sf --max-time "$LACY_SESSION_CREATE_TIMEOUT" \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{}' \
            "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session" 2>/dev/null)
        [[ $? -ne 0 ]] && return 1

        if command -v jq >/dev/null 2>&1; then
            LACY_PREHEAT_SERVER_SESSION_ID=$(printf '%s\n' "$session_json" | jq -r '.id // empty' 2>/dev/null)
        elif command -v python3 >/dev/null 2>&1; then
            LACY_PREHEAT_SERVER_SESSION_ID=$(printf '%s\n' "$session_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('id',''))" 2>/dev/null)
        else
            LACY_PREHEAT_SERVER_SESSION_ID=$(printf '%s' "$session_json" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"//' | sed 's/"//')
        fi
        [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" ]] && return 1
    fi

    local escaped_query
    escaped_query=$(printf '%s' "$query" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

    local response
    response=$(curl -sf --max-time "$LACY_SESSION_MESSAGE_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"parts\": [{\"type\": \"text\", \"text\": \"${escaped_query}\"}]}" \
        "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session/${LACY_PREHEAT_SERVER_SESSION_ID}/message" 2>/dev/null)

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        LACY_PREHEAT_SERVER_SESSION_ID=""
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
}

# ============================================================================
# Claude Session Reuse
# ============================================================================

lacy_preheat_claude_restore_session() {
    if [[ -f "$LACY_PREHEAT_SESSION_FILE" ]]; then
        LACY_PREHEAT_CLAUDE_SESSION_ID=$(cat "$LACY_PREHEAT_SESSION_FILE" 2>/dev/null)
    fi
}

lacy_preheat_claude_build_cmd() {
    if [[ -n "$LACY_PREHEAT_CLAUDE_SESSION_ID" ]]; then
        echo "claude --resume ${LACY_PREHEAT_CLAUDE_SESSION_ID} --output-format json -p"
    else
        echo "claude --output-format json -p"
    fi
}

lacy_preheat_claude_capture_session() {
    local json="$1"
    local session_id=""

    if command -v jq >/dev/null 2>&1; then
        session_id=$(printf '%s\n' "$json" | jq -r '.session_id // empty' 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
        session_id=$(printf '%s\n' "$json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('session_id',''))" 2>/dev/null)
    else
        session_id=$(printf '%s' "$json" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//' | sed 's/"//')
    fi

    if [[ -n "$session_id" ]]; then
        LACY_PREHEAT_CLAUDE_SESSION_ID="$session_id"
        echo "$session_id" > "$LACY_PREHEAT_SESSION_FILE"
    fi
}

lacy_preheat_claude_extract_result() {
    local json="$1"

    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$json" | jq -r '.result // empty' 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('result',''))" 2>/dev/null
    else
        printf '%s' "$json" | sed 's/.*"result"[[:space:]]*:[[:space:]]*"//' | sed 's/","[a-z_]*":.*//' | sed 's/\\n/\'$'\n''/g; s/\\"/"/g; s/\\\\/\\/g'
    fi
}

lacy_preheat_claude_reset_session() {
    LACY_PREHEAT_CLAUDE_SESSION_ID=""
    rm -f "$LACY_PREHEAT_SESSION_FILE"
}

# ============================================================================
# Lifecycle
# ============================================================================

lacy_preheat_init() {
    lacy_preheat_claude_restore_session

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
