#!/usr/bin/env zsh

# MCP (Model Context Protocol) integration for Lacy Shell

# ============================================================================
# Shared Helper Functions (reduces code duplication across API implementations)
# ============================================================================

# Escape content for JSON embedding
lacy_shell_escape_json() {
    local content="$1"
    echo "$content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/	/\\t/g' | tr '\n' ' '
}

# Unescape JSON string sequences
lacy_shell_unescape_json() {
    local content="$1"
    echo "$content" | sed 's/\\n/\
/g' | sed 's/\\t/	/g' | sed 's/\\"/"/g' | sed 's/\\\\/\\/g'
}

# Handle API error responses - returns 0 if error found, 1 if no error
lacy_shell_handle_api_error() {
    local response="$1"
    if echo "$response" | grep -q '"error"'; then
        echo "❌ API Error:"
        echo "$response" | grep -o '"message":"[^"]*' | sed 's/"message":"/  /' | head -1
        return 0  # Error found
    fi
    return 1  # No error
}

# Make an API request with curl
# Usage: lacy_shell_api_request <url> <json_payload> <auth_header> [extra_headers...]
lacy_shell_api_request() {
    local url="$1"
    local payload="$2"
    local auth_header="$3"
    shift 3
    local extra_headers=("$@")

    local curl_args=(-s -H "Content-Type: application/json" -H "$auth_header" -d "$payload")
    for header in "${extra_headers[@]}"; do
        curl_args+=(-H "$header")
    done
    curl_args+=("$url")

    curl "${curl_args[@]}" 2>&1
}

# Extract content from API response
# Usage: lacy_shell_extract_response <response> <content_key>
lacy_shell_extract_response() {
    local response="$1"
    local key="$2"
    echo "$response" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/"
}

# ============================================================================
# MCP Server Management
# ============================================================================

# MCP server management
typeset -A LACY_SHELL_MCP_PIDS
typeset -A LACY_SHELL_MCP_PIPES_IN
typeset -A LACY_SHELL_MCP_PIPES_OUT
typeset -A LACY_SHELL_MCP_TOOLS

# MCP configuration (initialized in config.zsh)
# Don't initialize here to avoid conflicts

# MCP communication directory is defined in constants.zsh

# Initialize MCP connections
lacy_shell_init_mcp() {
    # Create MCP directory
    mkdir -p "$LACY_SHELL_MCP_DIR"

    # If a configured agent CLI is available, let it manage MCP. Nothing to start here.
    local agent_cmd="${LACY_SHELL_AGENT_COMMAND:-$LACY_SHELL_DEFAULT_AGENT_COMMAND}"
    local base_cmd="${agent_cmd%% *}"
    if command -v "$base_cmd" >/dev/null 2>&1; then
        return 0
    fi

    # Only initialize if we have servers configured
    if [[ "$LACY_SHELL_MCP_SERVERS" == "configured" && -n "$LACY_SHELL_MCP_SERVERS_JSON" ]]; then
        lacy_shell_start_mcp_servers
    fi
}

# Parse MCP server configuration and start servers
lacy_shell_start_mcp_servers() {
    if [[ -z "$LACY_SHELL_MCP_SERVERS_JSON" ]]; then
        return 0
    fi
    
    # Parse server configurations using Python
    local server_configs=$(python3 -c "
import json
import sys

try:
    servers = json.loads('$LACY_SHELL_MCP_SERVERS_JSON')
    for i, server in enumerate(servers):
        name = server.get('name', f'server_{i}')
        command = server.get('command', '')
        args = server.get('args', [])
        
        if command:
            print(f'{name}|{command}|{\" \".join(args)}')
except Exception as e:
    print(f'Error parsing MCP config: {e}', file=sys.stderr)
" 2>/dev/null)

    # Start each configured server
    echo "$server_configs" | while IFS='|' read -r name command args; do
        if [[ -n "$name" && -n "$command" ]]; then
            lacy_shell_start_mcp_server "$name" "$command" "$args"
        fi
    done
}

# Start a single MCP server with stdio communication
lacy_shell_start_mcp_server() {
    local server_name="$1"
    local command="$2"
    local args="$3"
    
    # Check if server is already running
    if [[ -n "${LACY_SHELL_MCP_PIDS[$server_name]}" ]]; then
        local pid="${LACY_SHELL_MCP_PIDS[$server_name]}"
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Already running
        fi
    fi
    
    # Create named pipes for communication
    local pipe_dir="$LACY_SHELL_MCP_DIR/$server_name"
    mkdir -p "$pipe_dir"
    
    local pipe_in="$pipe_dir/stdin"
    local pipe_out="$pipe_dir/stdout"
    local pipe_err="$pipe_dir/stderr"
    
    # Remove existing pipes
    rm -f "$pipe_in" "$pipe_out" "$pipe_err"
    
    # Create named pipes
    mkfifo "$pipe_in" "$pipe_out" "$pipe_err" 2>/dev/null
    
    # Start the MCP server process
    (
        cd "$LACY_SHELL_MCP_DIR"
        # Check if command exists before starting
        if ! command -v "$command" >/dev/null 2>&1; then
            echo "Error: Command '$command' not found" > "$pipe_err"
            exit 1
        fi
        $command $args < "$pipe_in" > "$pipe_out" 2> "$pipe_err" &
        echo $! > "$pipe_dir/pid"
    ) &!
    
    # Wait a moment for the process to start
    sleep 0.5
    
    # Get the PID
    local pid
    if [[ -f "$pipe_dir/pid" ]]; then
        pid=$(cat "$pipe_dir/pid")
        
        # Check if the process is actually running
        if ps -p "$pid" > /dev/null 2>&1; then
            LACY_SHELL_MCP_PIDS[$server_name]="$pid"
            LACY_SHELL_MCP_PIPES_IN[$server_name]="$pipe_in"
            LACY_SHELL_MCP_PIPES_OUT[$server_name]="$pipe_out"
            
            echo "Started MCP server '$server_name' (PID: $pid)"
            
            # Initialize the server with a handshake
            lacy_shell_mcp_initialize "$server_name"
            
            # Get available tools
            lacy_shell_mcp_list_tools "$server_name"
        else
            echo "Error: MCP server '$server_name' failed to start - process died immediately"
            if [[ -f "$pipe_err" ]]; then
                echo "Error details:"
                cat "$pipe_err"
            fi
            return 1
        fi
    else
        echo "Error: Failed to create PID file for MCP server '$server_name'"
        return 1
    fi
}

# Stop MCP servers
lacy_shell_stop_mcp_servers() {
    for server_name in "${(@k)LACY_SHELL_MCP_PIDS}"; do
        lacy_shell_stop_mcp_server "$server_name"
    done
}

# Stop a single MCP server
lacy_shell_stop_mcp_server() {
    local server_name="$1"
    local pid="${LACY_SHELL_MCP_PIDS[$server_name]}"
    
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        
        # Clean up pipes
        local pipe_dir="$LACY_SHELL_MCP_DIR/$server_name"
        rm -rf "$pipe_dir"
    fi
    
    # Remove from tracking
    unset "LACY_SHELL_MCP_PIDS[$server_name]"
    unset "LACY_SHELL_MCP_PIPES_IN[$server_name]"
    unset "LACY_SHELL_MCP_PIPES_OUT[$server_name]"
}

# MCP Protocol Implementation

# Send MCP message to server
lacy_shell_mcp_send() {
    local server_name="$1"
    local message="$2"
    local pipe_in="${LACY_SHELL_MCP_PIPES_IN[$server_name]}"
    
    if [[ -n "$pipe_in" && -p "$pipe_in" ]]; then
        echo "$message" > "$pipe_in"
        return 0
    else
        return 1
    fi
}

# Read MCP response from server
lacy_shell_mcp_read() {
    local server_name="$1"
    local timeout="${2:-$LACY_SHELL_MCP_TIMEOUT_SEC}"
    local pipe_out="${LACY_SHELL_MCP_PIPES_OUT[$server_name]}"
    
    if [[ -n "$pipe_out" && -p "$pipe_out" ]]; then
        # Cross-platform timeout: prefer timeout/gtimeout, otherwise fallback
        if command -v timeout >/dev/null 2>&1; then
            timeout "$timeout" cat "$pipe_out" 2>/dev/null
            return $?
        elif command -v gtimeout >/dev/null 2>&1; then
            gtimeout "$timeout" cat "$pipe_out" 2>/dev/null
            return $?
        else
            # Fallback: run cat in background and kill after timeout
            (
                cat "$pipe_out" &
                local cat_pid=$!
                sleep "$timeout" 2>/dev/null || true
                if kill -0 "$cat_pid" 2>/dev/null; then
                    kill "$cat_pid" 2>/dev/null || true
                fi
                wait "$cat_pid" 2>/dev/null || true
            ) 2>/dev/null
            return 0
        fi
    else
        return 1
    fi
}

# Initialize MCP server with handshake
lacy_shell_mcp_initialize() {
    local server_name="$1"
    
    local init_message=$(python3 -c "
import json
import uuid

message = {
    'jsonrpc': '2.0',
    'id': str(uuid.uuid4()),
    'method': 'initialize',
    'params': {
        'protocolVersion': '2024-11-05',
        'capabilities': {
            'tools': {},
            'resources': {}
        },
        'clientInfo': {
            'name': 'lacy-shell',
            'version': '1.0.0'
        }
    }
}

print(json.dumps(message))
")
    
    if lacy_shell_mcp_send "$server_name" "$init_message"; then
        local response=$(lacy_shell_mcp_read "$server_name" 3)
        if [[ -n "$response" ]]; then
            # Send initialized notification
            local initialized_message=$(python3 -c "
import json
import uuid

message = {
    'jsonrpc': '2.0',
    'method': 'notifications/initialized'
}

print(json.dumps(message))
")
            lacy_shell_mcp_send "$server_name" "$initialized_message"
            return 0
        fi
    fi
    
    return 1
}

# List available tools from MCP server
lacy_shell_mcp_list_tools() {
    local server_name="$1"
    
    local list_tools_message=$(python3 -c "
import json
import uuid

message = {
    'jsonrpc': '2.0',
    'id': str(uuid.uuid4()),
    'method': 'tools/list'
}

print(json.dumps(message))
")
    
    if lacy_shell_mcp_send "$server_name" "$list_tools_message"; then
        local response=$(lacy_shell_mcp_read "$server_name" 3)
        if [[ -n "$response" ]]; then
            # Parse and store available tools
            local tools=$(echo "$response" | python3 -c "
import json
import sys

try:
    response = json.load(sys.stdin)
    if 'result' in response and 'tools' in response['result']:
        tools = []
        for tool in response['result']['tools']:
            name = tool.get('name', '')
            description = tool.get('description', '')
            if name:
                tools.append(f'{name}:{description}')
        print('|'.join(tools))
except:
    pass
" 2>/dev/null)
            
            if [[ -n "$tools" ]]; then
                LACY_SHELL_MCP_TOOLS[$server_name]="$tools"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Call an MCP tool
lacy_shell_mcp_call_tool() {
    local server_name="$1"
    local tool_name="$2"
    local arguments="$3"  # JSON string
    
    local call_message=$(python3 -c "
import json
import uuid

message = {
    'jsonrpc': '2.0',
    'id': str(uuid.uuid4()),
    'method': 'tools/call',
    'params': {
        'name': '$tool_name',
        'arguments': $arguments
    }
}

print(json.dumps(message))
")
    
    if lacy_shell_mcp_send "$server_name" "$call_message"; then
        lacy_shell_mcp_read "$server_name" 10
        return $?
    fi
    
    return 1
}

# Conversation history file is defined in constants.zsh

# Send query to AI with MCP context and conversation history
lacy_shell_query_agent() {
    local query="$1"
    local use_mcp="${2:-true}"
    
    # Check if API keys are available
    if ! lacy_shell_check_api_keys; then
        echo "Error: No API keys configured. Cannot query agent."
        return 1
    fi
    
    # Use configured agent CLI (defaults from constants.zsh)
    local agent_cmd="${LACY_SHELL_AGENT_COMMAND:-$LACY_SHELL_DEFAULT_AGENT_COMMAND}"
    local context_mode="${LACY_SHELL_AGENT_CONTEXT_MODE:-$LACY_SHELL_DEFAULT_AGENT_CONTEXT_MODE}"
    local needs_api_keys="${LACY_SHELL_AGENT_NEEDS_API_KEYS:-$LACY_SHELL_DEFAULT_AGENT_NEEDS_API_KEYS}"

    # Extract the base command (first word) to check if it exists
    local base_cmd="${agent_cmd%% *}"
    if command -v "$base_cmd" >/dev/null 2>&1; then
        # Ensure conversation directory exists
        mkdir -p "$(dirname "$LACY_SHELL_CONVERSATION_FILE")"

        # Prepare minimal context and recent conversation
        local temp_file=$(mktemp)
        local response_file=$(mktemp)

        cat > "$temp_file" << EOF
System Context:
- Current Directory: $(pwd)
- Current Date: $(date)
- Shell: $SHELL
- User: $USER

EOF

        if [[ -f "$LACY_SHELL_CONVERSATION_FILE" ]]; then
            echo "Recent Conversation:" >> "$temp_file"
            tail -20 "$LACY_SHELL_CONVERSATION_FILE" >> "$temp_file"
            echo "" >> "$temp_file"
        fi

        # Build the command with query and context_file substitution
        # Use printf %q to properly shell-escape the query
        local escaped_query=$(printf '%q' "$query")
        local final_cmd="${agent_cmd//\{query\}/$escaped_query}"
        final_cmd="${final_cmd//\{context_file\}/$temp_file}"

        # Execute command and capture response (loader runs on stderr, output on stdout)
        local captured_response=""
        if [[ "$context_mode" == "stdin" ]]; then
            captured_response=$(cat "$temp_file" | eval "$final_cmd" | tee /dev/tty)
        else
            # File mode - context is already in temp_file referenced by {context_file}
            captured_response=$(eval "$final_cmd" | tee /dev/tty)
        fi

        # Stop the loader after command finishes
        lacy_shell_stop_loader

        # Truncate response for history (keep first 500 chars to avoid bloat)
        local truncated_response="${captured_response:0:500}"
        [[ ${#captured_response} -gt 500 ]] && truncated_response="${truncated_response}..."

        # Save to conversation history with actual response
        echo "User: $query" >> "$LACY_SHELL_CONVERSATION_FILE"
        echo "Assistant: $truncated_response" >> "$LACY_SHELL_CONVERSATION_FILE"
        echo "---" >> "$LACY_SHELL_CONVERSATION_FILE"

        # Cleanup
        rm -f "$temp_file" "$response_file"

        # Maintain history size
        if [[ $(wc -l < "$LACY_SHELL_CONVERSATION_FILE") -gt 300 ]]; then
            tail -200 "$LACY_SHELL_CONVERSATION_FILE" > "${LACY_SHELL_CONVERSATION_FILE}.tmp"
            mv "${LACY_SHELL_CONVERSATION_FILE}.tmp" "$LACY_SHELL_CONVERSATION_FILE"
        fi

        return 0
    fi

    # Use original agent flow (fallback when Lash is not installed)
    # Create temporary file for the query
    local temp_file=$(mktemp)
    local response_file=$(mktemp)
    
    # Prepare the query with context and conversation history
    cat > "$temp_file" << EOF
System Context:
- Current Directory: $(pwd)
- Current Date: $(date)
- Shell: $SHELL
- User: $USER

EOF

    # Add recent conversation history (last 10 exchanges)
    if [[ -f "$LACY_SHELL_CONVERSATION_FILE" ]]; then
        echo "Recent Conversation:" >> "$temp_file"
        tail -20 "$LACY_SHELL_CONVERSATION_FILE" >> "$temp_file"
        echo "" >> "$temp_file"
    fi

    # Add MCP context if available
    if [[ "$use_mcp" == "true" ]] && [[ -n "$LACY_SHELL_MCP_SERVERS" ]]; then
        echo "Available MCP Tools:" >> "$temp_file"
        lacy_shell_list_mcp_tools >> "$temp_file"
        echo "" >> "$temp_file"
    fi
    
    echo "Current Query: $query" >> "$temp_file"

    # Send to AI service and capture response (loader runs on stderr, output on stdout)
    local captured_response=""
    captured_response=$(lacy_shell_send_to_ai_streaming "$temp_file" "$query" | tee /dev/tty)

    # Stop the loader after response finishes
    lacy_shell_stop_loader

    # Truncate response for history (keep first 500 chars to avoid bloat)
    local truncated_response="${captured_response:0:500}"
    [[ ${#captured_response} -gt 500 ]] && truncated_response="${truncated_response}..."

    # Save to conversation history with actual response
    echo "User: $query" >> "$LACY_SHELL_CONVERSATION_FILE"
    echo "Assistant: $truncated_response" >> "$LACY_SHELL_CONVERSATION_FILE"
    echo "---" >> "$LACY_SHELL_CONVERSATION_FILE"
    
    # Cleanup
    rm -f "$temp_file" "$response_file"
    
    # Keep conversation history manageable (last 100 exchanges)
    if [[ $(wc -l < "$LACY_SHELL_CONVERSATION_FILE") -gt 300 ]]; then
        tail -200 "$LACY_SHELL_CONVERSATION_FILE" > "${LACY_SHELL_CONVERSATION_FILE}.tmp"
        mv "${LACY_SHELL_CONVERSATION_FILE}.tmp" "$LACY_SHELL_CONVERSATION_FILE"
    fi
}

# Send query to AI service with streaming (OpenAI/Anthropic)
lacy_shell_send_to_ai_streaming() {
    local input_file="$1"
    local query="$2"
    
    # Prefer configured provider/model, fallback by available keys
    local provider="${LACY_SHELL_PROVIDER:-$LACY_SHELL_DEFAULT_PROVIDER}"
    if [[ "$provider" == "anthropic" && -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
        lacy_shell_query_anthropic_streaming "$input_file" "$query"
    elif [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
        lacy_shell_query_openai_streaming "$input_file" "$query"
    elif [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
        lacy_shell_query_anthropic_streaming "$input_file" "$query"
    else
        echo "Error: No API keys configured"
        return 1
    fi
}

# Fallback streaming query without Python or TypeScript
lacy_shell_send_to_ai_streaming_fallback() {
    local query="$1"
    
    if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
        # Use curl directly for OpenAI
        local json_payload=$(cat <<EOF
{
  "model": "${LACY_SHELL_MODEL_NAME:-$LACY_SHELL_DEFAULT_MODEL}",
  "messages": [
    {"role": "system", "content": "You are a helpful coding assistant. Be concise and practical."},
    {"role": "user", "content": "$query"}
  ],
  "temperature": 0.3,
  "max_tokens": 1500
}
EOF
)
        curl -s -H "Content-Type: application/json" \
             -H "Authorization: Bearer $LACY_SHELL_API_OPENAI" \
             -d "$json_payload" \
             "https://api.openai.com/v1/chat/completions" | \
        grep -o '"content":"[^"]*' | sed 's/"content":"//' | head -1
        
    elif [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
        # Use curl directly for Anthropic
        local json_payload=$(cat <<EOF
{
  "model": "${LACY_SHELL_MODEL_NAME:-claude-3-5-sonnet-20241022}",
  "max_tokens": 1500,
  "messages": [
    {"role": "user", "content": "$query"}
  ]
}
EOF
)
        curl -s -H "Content-Type: application/json" \
             -H "x-api-key: $LACY_SHELL_API_ANTHROPIC" \
             -H "anthropic-version: 2023-06-01" \
             -d "$json_payload" \
             "https://api.anthropic.com/v1/messages" | \
        grep -o '"text":"[^"]*' | sed 's/"text":"//' | head -1
    else
        echo "Error: No API keys configured"
        return 1
    fi
}


# Query OpenAI API with streaming
lacy_shell_query_openai_streaming() {
    local input_file="$1"
    local query="$2"

    # Read and escape the input properly for JSON
    local content=$(lacy_shell_escape_json "$(cat "$input_file")")

    # Create JSON payload
    local json_payload="{
  \"model\": \"${LACY_SHELL_MODEL_NAME:-$LACY_SHELL_DEFAULT_MODEL}\",
  \"messages\": [
    {
      \"role\": \"system\",
      \"content\": \"You are a helpful assistant. Provide concise, practical responses.\"
    },
    {
      \"role\": \"user\",
      \"content\": \"$content\"
    }
  ],
  \"temperature\": 0.3,
  \"max_tokens\": 1500
}"

    # Send request
    local response=$(lacy_shell_api_request \
        "https://api.openai.com/v1/chat/completions" \
        "$json_payload" \
        "Authorization: Bearer $LACY_SHELL_API_OPENAI")

    # Check for errors
    if lacy_shell_handle_api_error "$response"; then
        return 1
    fi

    # Extract and unescape content
    local extracted=$(lacy_shell_extract_response "$response" "content")

    if [[ -n "$extracted" ]]; then
        lacy_shell_unescape_json "$extracted"
    else
        echo "❌ No response from API. Raw response:"
        echo "$response" | head -3
        return 1
    fi
}


# Query Anthropic API with streaming
lacy_shell_query_anthropic_streaming() {
    local input_file="$1"
    local query="$2"

    # Read and escape the input properly for JSON
    local content=$(lacy_shell_escape_json "$(cat "$input_file")")

    # Create JSON payload
    local json_payload="{
  \"model\": \"${LACY_SHELL_MODEL_NAME:-claude-3-5-sonnet-20241022}\",
  \"max_tokens\": 1500,
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": \"$content\"
    }
  ]
}"

    # Send request
    local response=$(lacy_shell_api_request \
        "https://api.anthropic.com/v1/messages" \
        "$json_payload" \
        "x-api-key: $LACY_SHELL_API_ANTHROPIC" \
        "anthropic-version: 2023-06-01")

    # Check for errors
    if lacy_shell_handle_api_error "$response"; then
        return 1
    fi

    # Extract and unescape content (Anthropic uses "text" key)
    local extracted=$(lacy_shell_extract_response "$response" "text")

    if [[ -n "$extracted" ]]; then
        lacy_shell_unescape_json "$extracted"
    else
        echo "❌ No response from API. Raw response:"
        echo "$response" | head -3
        return 1
    fi
}

# List available MCP tools for AI context
lacy_shell_list_mcp_tools() {
    if [[ "$LACY_SHELL_MCP_SERVERS" == "configured" ]]; then
        echo "Available MCP Tools:"
        
        for server_name in "${(@k)LACY_SHELL_MCP_TOOLS}"; do
            local tools="${LACY_SHELL_MCP_TOOLS[$server_name]}"
            if [[ -n "$tools" ]]; then
                echo "Server: $server_name"
                echo "$tools" | tr '|' '\n' | while IFS=':' read -r tool_name tool_desc; do
                    echo "  - $tool_name: $tool_desc"
                done
            fi
        done
        
        # If no tools loaded yet, show generic capabilities
        if [[ ${#LACY_SHELL_MCP_TOOLS} -eq 0 ]]; then
            echo "  - Filesystem tools (read_file, write_file, list_directory)"
            echo "  - Web tools (search, fetch_content)"
            echo "  - System tools (run_command, get_system_info)"
        fi
    else
        echo "No MCP servers configured"
    fi
}

# Get available tools as JSON for AI
lacy_shell_get_mcp_tools_json() {
    local tools_json="[]"
    
    if [[ "$LACY_SHELL_MCP_SERVERS" == "configured" ]]; then
        tools_json=$(python3 -c "
import json

tools = []
for server_name in ['filesystem', 'web', 'system']:
    if server_name == 'filesystem':
        tools.extend([
            {'name': 'read_file', 'description': 'Read contents of a file', 'server': server_name},
            {'name': 'write_file', 'description': 'Write content to a file', 'server': server_name},
            {'name': 'list_directory', 'description': 'List files in a directory', 'server': server_name}
        ])
    elif server_name == 'web':
        tools.extend([
            {'name': 'search_web', 'description': 'Search the web for information', 'server': server_name},
            {'name': 'fetch_url', 'description': 'Fetch content from a URL', 'server': server_name}
        ])
    elif server_name == 'system':
        tools.extend([
            {'name': 'run_command', 'description': 'Execute a system command', 'server': server_name},
            {'name': 'get_system_info', 'description': 'Get system information', 'server': server_name}
        ])

print(json.dumps(tools, indent=2))
" 2>/dev/null)
    fi
    
    echo "$tools_json"
}

# Cleanup MCP connections
lacy_shell_cleanup_mcp() {
    lacy_shell_stop_mcp_servers
}

# Check if MCP packages are installed
lacy_shell_check_mcp_packages() {
    echo "🔍 Checking MCP package dependencies..."
    echo ""
    
    local missing_packages=()
    
    # Check for npx
    if ! command -v npx >/dev/null 2>&1; then
        echo "❌ npx not found - please install Node.js and npm"
        return 1
    fi
    
    # Check for MCP filesystem server
    if ! npx @modelcontextprotocol/server-filesystem --help >/dev/null 2>&1; then
        echo "❌ @modelcontextprotocol/server-filesystem not installed"
        missing_packages+=("@modelcontextprotocol/server-filesystem")
    else
        echo "✅ @modelcontextprotocol/server-filesystem installed"
    fi
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        echo ""
        echo "📦 To install missing packages, run:"
        for package in "${missing_packages[@]}"; do
            echo "   npm install -g $package"
        done
        return 1
    fi
    
    echo "✅ All required MCP packages are installed"
    return 0
}

# Test MCP connection
lacy_shell_test_mcp() {
    echo "Testing MCP configuration..."
    
    # Check package dependencies first
    echo ""
    if ! lacy_shell_check_mcp_packages; then
        echo ""
        echo "❌ MCP package dependencies not met"
        return 1
    fi
    echo ""
    
    # First load the config to make sure variables are set
    lacy_shell_load_config >/dev/null 2>&1
    
    if [[ "$LACY_SHELL_MCP_SERVERS" == "configured" ]]; then
        echo "✅ MCP framework ready"
        
        # Test server status
        echo ""
        echo "Server Status:"
        for server_name in "${(@k)LACY_SHELL_MCP_PIDS}"; do
            local pid="${LACY_SHELL_MCP_PIDS[$server_name]}"
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                echo "  ✅ $server_name (PID: $pid)"
                
                # Test tool listing
                local tools="${LACY_SHELL_MCP_TOOLS[$server_name]}"
                if [[ -n "$tools" ]]; then
                    echo "    Tools: $(echo "$tools" | tr '|' ', ')"
                fi
            else
                echo "  ❌ $server_name (not running)"
            fi
        done
        
        if [[ ${#LACY_SHELL_MCP_PIDS} -eq 0 ]]; then
            echo "  ⚠️  No servers currently running"
            echo "  Run 'lacy_shell_start_mcp_servers' to start them"
        fi
    else
        echo "❌ No MCP servers configured"
        return 1
    fi
    
    # Test API keys
    echo ""
    if lacy_shell_check_api_keys; then
        echo "✅ API keys configured"
    else
        echo "❌ No API keys configured"
    fi
    
    # Test MCP directory
    echo ""
    if [[ -d "$LACY_SHELL_MCP_DIR" ]]; then
        echo "✅ MCP directory: $LACY_SHELL_MCP_DIR"
        # Count named pipes (FIFOs) for an accurate view of active IPC files
        local pipe_count=$(find "$LACY_SHELL_MCP_DIR" -type p 2>/dev/null | wc -l | tr -d ' ')
        echo "   Named pipes: $pipe_count"
    else
        echo "❌ MCP directory not found"
    fi
}

# Debug MCP server communication
lacy_shell_debug_mcp() {
    local server_name="$1"
    
    if [[ -z "$server_name" ]]; then
        echo "Usage: lacy_shell_debug_mcp <server_name>"
        echo "Available servers: ${(k)LACY_SHELL_MCP_PIDS}"
        return 1
    fi
    
    local pid="${LACY_SHELL_MCP_PIDS[$server_name]}"
    local pipe_dir="$LACY_SHELL_MCP_DIR/$server_name"
    
    echo "Debug info for server: $server_name"
    echo "=================================="
    echo "PID: $pid"
    echo "Pipe directory: $pipe_dir"
    echo "Process status: $(kill -0 "$pid" 2>/dev/null && echo "running" || echo "stopped")"
    
    if [[ -d "$pipe_dir" ]]; then
        echo "Pipe files:"
        ls -la "$pipe_dir/"
        
        # Show recent stderr output
        if [[ -f "$pipe_dir/stderr" ]]; then
            echo ""
            echo "Recent stderr:"
            tail -10 "$pipe_dir/stderr" 2>/dev/null
        fi
    fi
    
    echo ""
    echo "Available tools:"
    local tools="${LACY_SHELL_MCP_TOOLS[$server_name]}"
    if [[ -n "$tools" ]]; then
        echo "$tools" | tr '|' '\n'
    else
        echo "No tools loaded"
    fi
}

# Restart a specific MCP server
lacy_shell_restart_mcp_server() {
    local server_name="$1"
    
    if [[ -z "$server_name" ]]; then
        echo "Usage: lacy_shell_restart_mcp_server <server_name>"
        return 1
    fi
    
    echo "Restarting MCP server: $server_name"
    lacy_shell_stop_mcp_server "$server_name"
    sleep 1
    
    # Get server config and restart
    if [[ -n "$LACY_SHELL_MCP_SERVERS_JSON" ]]; then
        local server_config=$(python3 -c "
import json
servers = json.loads('$LACY_SHELL_MCP_SERVERS_JSON')
for server in servers:
    if server.get('name') == '$server_name':
        command = server.get('command', '')
        args = server.get('args', [])
        print(f'{command}|{\" \".join(args)}')
        break
" 2>/dev/null)
        
        if [[ -n "$server_config" ]]; then
            local command=$(echo "$server_config" | cut -d'|' -f1)
            local args=$(echo "$server_config" | cut -d'|' -f2)
            lacy_shell_start_mcp_server "$server_name" "$command" "$args"
            
            if [[ -n "${LACY_SHELL_MCP_PIDS[$server_name]}" ]]; then
                echo "✅ Server restarted successfully"
            else
                echo "❌ Failed to restart server"
            fi
        else
            echo "❌ Server configuration not found"
        fi
    fi
}

# Show MCP server logs
lacy_shell_mcp_logs() {
    local server_name="$1"
    
    if [[ -z "$server_name" ]]; then
        echo "Available servers:"
        for name in "${(@k)LACY_SHELL_MCP_PIDS}"; do
            echo "  - $name"
        done
        return 1
    fi
    
    local pipe_dir="$LACY_SHELL_MCP_DIR/$server_name"
    
    if [[ -f "$pipe_dir/stderr" ]]; then
        echo "=== MCP Server Logs: $server_name ==="
        tail -50 "$pipe_dir/stderr"
    else
        echo "No logs found for server: $server_name"
    fi
}
