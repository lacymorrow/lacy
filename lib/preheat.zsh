#!/usr/bin/env zsh

# Agent preheating for Lacy Shell
# - Background server for lash/opencode (eliminates cold-start)
# - Session reuse for claude (conversation continuity)

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
# Usage: lacy_preheat_server_start <tool>  (tool is "lash" or "opencode")
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

    # Start server in background
    setopt LOCAL_OPTIONS NO_MONITOR
    "$tool" serve --port "$LACY_PREHEAT_SERVER_PORT" >/dev/null 2>&1 &
    LACY_PREHEAT_SERVER_PID=$!
    disown 2>/dev/null

    # Save PID to file for crash recovery
    echo "$LACY_PREHEAT_SERVER_PID" > "$LACY_PREHEAT_SERVER_PID_FILE"

    # Wait for server to become healthy (up to 3 seconds)
    local attempts=0
    while (( attempts < 30 )); do
        if lacy_preheat_server_is_healthy; then
            return 0
        fi
        sleep 0.1
        (( attempts++ ))
    done

    # Failed to start — clean up
    lacy_preheat_server_stop 2>/dev/null
    return 1
}

# Check if server is alive and responding
lacy_preheat_server_is_healthy() {
    # Check PID is set and process exists
    if [[ -z "$LACY_PREHEAT_SERVER_PID" ]]; then
        # Try to recover PID from file
        if [[ -f "$LACY_PREHEAT_SERVER_PID_FILE" ]]; then
            LACY_PREHEAT_SERVER_PID=$(cat "$LACY_PREHEAT_SERVER_PID_FILE" 2>/dev/null)
        fi
        [[ -z "$LACY_PREHEAT_SERVER_PID" ]] && return 1
    fi

    # Process alive?
    kill -0 "$LACY_PREHEAT_SERVER_PID" 2>/dev/null || return 1

    # HTTP health check
    curl -sf --max-time 1 "http://localhost:${LACY_PREHEAT_SERVER_PORT}/global/health" >/dev/null 2>&1
}

# Send query to background server via REST API
# Usage: lacy_preheat_server_query <query>
# Outputs: response text to stdout
#
# The lash/opencode server requires:
#   1. POST /session          → create a session (reused across queries)
#   2. POST /session/{id}/message → send message (blocks until AI responds)
lacy_preheat_server_query() {
    local query="$1"

    # Create session if we don't have one yet
    if [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" ]]; then
        local session_json
        session_json=$(curl -sf --max-time 10 \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{}' \
            "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session" 2>/dev/null)
        [[ $? -ne 0 ]] && return 1

        # Extract session ID
        if command -v jq >/dev/null 2>&1; then
            LACY_PREHEAT_SERVER_SESSION_ID=$(printf '%s\n' "$session_json" | jq -r '.id // empty' 2>/dev/null)
        elif command -v python3 >/dev/null 2>&1; then
            LACY_PREHEAT_SERVER_SESSION_ID=$(printf '%s\n' "$session_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('id',''))" 2>/dev/null)
        else
            LACY_PREHEAT_SERVER_SESSION_ID=$(printf '%s' "$session_json" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"//' | sed 's/"//')
        fi
        [[ -z "$LACY_PREHEAT_SERVER_SESSION_ID" ]] && return 1
    fi

    # JSON-escape the query (handle quotes and backslashes)
    local escaped_query
    escaped_query=$(printf '%s' "$query" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

    # Send message to session (sync — blocks until AI finishes)
    local response
    response=$(curl -sf --max-time 120 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"parts\": [{\"type\": \"text\", \"text\": \"${escaped_query}\"}]}" \
        "http://localhost:${LACY_PREHEAT_SERVER_PORT}/session/${LACY_PREHEAT_SERVER_SESSION_ID}/message" 2>/dev/null)

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        # Session may be stale — reset so next attempt creates a fresh one
        LACY_PREHEAT_SERVER_SESSION_ID=""
        return 1
    fi

    # Extract assistant text from response
    # Use printf '%s\n' (not echo) — zsh echo interprets \n, \t, etc. in strings
    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$response" | jq -r '
            # Handle array of messages — pick last assistant message
            if type == "array" then
                [.[] | select(.role == "assistant") | .parts[]? | select(.type == "text") | .text] | last // empty
            # Handle single message object with parts
            elif .parts then
                [.parts[] | select(.type == "text") | .text] | join("\n") // empty
            # Fallback fields
            else
                .result // .content // .text // .response // .message // empty
            end' 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$response" | python3 -c "
import json, sys
data = sys.stdin.read().strip()
# Handle NDJSON (multiple JSON objects per line)
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
        # Last resort: extract text from parts
        printf '%s' "$response" | sed 's/.*"text"[[:space:]]*:[[:space:]]*"//' | sed 's/"[[:space:]]*[,}\]].*//' | sed 's/\\n/\'$'\n''/g; s/\\"/"/g; s/\\\\/\\/g'
    fi
}

# Stop background server and clean up
lacy_preheat_server_stop() {
    # Kill by in-memory PID
    if [[ -n "$LACY_PREHEAT_SERVER_PID" ]]; then
        kill "$LACY_PREHEAT_SERVER_PID" 2>/dev/null
        wait "$LACY_PREHEAT_SERVER_PID" 2>/dev/null
        LACY_PREHEAT_SERVER_PID=""
    fi

    # Kill by PID file (handles orphans from crashed sessions)
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

# Restore session ID from disk (called at init)
lacy_preheat_claude_restore_session() {
    if [[ -f "$LACY_PREHEAT_SESSION_FILE" ]]; then
        LACY_PREHEAT_CLAUDE_SESSION_ID=$(cat "$LACY_PREHEAT_SESSION_FILE" 2>/dev/null)
    fi
}

# Build claude command with session reuse flags
# Outputs: command string to stdout
lacy_preheat_claude_build_cmd() {
    if [[ -n "$LACY_PREHEAT_CLAUDE_SESSION_ID" ]]; then
        echo "claude --resume ${LACY_PREHEAT_CLAUDE_SESSION_ID} --output-format json -p"
    else
        echo "claude --output-format json -p"
    fi
}

# Capture session ID from claude JSON output and persist to disk
# Usage: lacy_preheat_claude_capture_session <json_output>
lacy_preheat_claude_capture_session() {
    local json="$1"
    local session_id=""

    # Use printf '%s\n' (not echo) — zsh echo interprets \n, \t, etc. in strings
    if command -v jq >/dev/null 2>&1; then
        session_id=$(printf '%s\n' "$json" | jq -r '.session_id // empty' 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
        session_id=$(printf '%s\n' "$json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('session_id',''))" 2>/dev/null)
    else
        # session_id is a UUID — no escaped quotes, safe for simple grep
        session_id=$(printf '%s' "$json" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//' | sed 's/"//')
    fi

    if [[ -n "$session_id" ]]; then
        LACY_PREHEAT_CLAUDE_SESSION_ID="$session_id"
        echo "$session_id" > "$LACY_PREHEAT_SESSION_FILE"
    fi
}

# Extract result text from claude JSON output
# Usage: lacy_preheat_claude_extract_result <json_output>
# Outputs: result text to stdout
lacy_preheat_claude_extract_result() {
    local json="$1"

    # Use printf '%s\n' (not echo) — zsh echo interprets \n, \t, etc. in strings,
    # which mangles JSON before it reaches jq/python/grep
    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$json" | jq -r '.result // empty' 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('result',''))" 2>/dev/null
    else
        # Last resort: sed extraction (handles escaped quotes in result value)
        # Match from "result":" to the next ","<key>": pattern
        printf '%s' "$json" | sed 's/.*"result"[[:space:]]*:[[:space:]]*"//' | sed 's/","[a-z_]*":.*//' | sed 's/\\n/\'$'\n''/g; s/\\"/"/g; s/\\\\/\\/g'
    fi
}

# Reset stale session (called on --resume failure)
lacy_preheat_claude_reset_session() {
    LACY_PREHEAT_CLAUDE_SESSION_ID=""
    rm -f "$LACY_PREHEAT_SESSION_FILE"
}

# ============================================================================
# Lifecycle
# ============================================================================

# Initialize preheating (called at plugin load)
lacy_preheat_init() {
    # Restore claude session from disk
    lacy_preheat_claude_restore_session

    # Eager server start if configured
    if [[ "$LACY_PREHEAT_EAGER" == "true" ]]; then
        local tool="${LACY_ACTIVE_TOOL}"

        # Only start for tools that support serve
        if [[ "$tool" == "lash" || "$tool" == "opencode" ]]; then
            lacy_preheat_server_start "$tool" &
            # Don't wait — let it start in background
            disown 2>/dev/null
        fi
    fi
}

# Cleanup preheating (called on quit/exit)
lacy_preheat_cleanup() {
    lacy_preheat_server_stop
    # Note: do NOT delete claude session file — it's intentionally persistent
}
