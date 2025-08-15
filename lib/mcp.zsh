#!/usr/bin/env zsh

# MCP (Model Context Protocol) integration for Lacy Shell

# MCP server management
typeset -A LACY_SHELL_MCP_PIDS
typeset -A LACY_SHELL_MCP_PIPES_IN
typeset -A LACY_SHELL_MCP_PIPES_OUT
typeset -A LACY_SHELL_MCP_TOOLS

# MCP configuration (initialized in config.zsh)
# Don't initialize here to avoid conflicts

# MCP communication directory
LACY_SHELL_MCP_DIR="${HOME}/.lacy-shell/mcp"

# Initialize MCP connections
lacy_shell_init_mcp() {
    # Create MCP directory
    mkdir -p "$LACY_SHELL_MCP_DIR"
    
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
    ) &
    
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
    local timeout="${2:-5}"
    local pipe_out="${LACY_SHELL_MCP_PIPES_OUT[$server_name]}"
    
    if [[ -n "$pipe_out" && -p "$pipe_out" ]]; then
        timeout "$timeout" cat "$pipe_out" 2>/dev/null
        return $?
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

# Conversation history
LACY_SHELL_CONVERSATION_FILE="${HOME}/.lacy-shell/conversation.log"

# Send query to AI with MCP context and conversation history
lacy_shell_query_agent() {
    local query="$1"
    local use_mcp="${2:-true}"
    
    # Check if API keys are available
    if ! lacy_shell_check_api_keys; then
        echo "Error: No API keys configured. Cannot query agent."
        return 1
    fi
    
    # Ensure conversation directory exists
    mkdir -p "$(dirname "$LACY_SHELL_CONVERSATION_FILE")"
    
    # Check if we should use the enhanced coding agent
    local use_coding_agent=false
    local coding_keywords=("read" "write" "edit" "file" "code" "function" "class" "refactor" "analyze" "git" "implement" "fix" "bug" "create" "modify" "search")
    
    for keyword in "${coding_keywords[@]}"; do
        if [[ "$query" == *"$keyword"* ]]; then
            use_coding_agent=true
            break
        fi
    done
    
    if [[ "$use_coding_agent" == "true" ]]; then
        # Use enhanced TypeScript coding agent
        local provider="openai"
        local api_key="$LACY_SHELL_API_OPENAI"
        local model="gpt-4"
        
        if [[ -z "$api_key" ]] && [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
            provider="anthropic"
            api_key="$LACY_SHELL_API_ANTHROPIC"
            model="claude-3-5-sonnet-20241022"
        fi
        
        # Use the compiled TypeScript agent
        local agent_path="$LACY_SHELL_DIR/agent/lacy-agent"
        
        # Check if agent exists and is executable
        if [[ ! -f "$agent_path" ]]; then
            # Try to build it if bun is available
            if command -v bun >/dev/null 2>&1 && [[ -d "$LACY_SHELL_DIR/agent" ]]; then
                echo "🔧 Building coding agent..."
                (cd "$LACY_SHELL_DIR/agent" && bun install --silent && bun run build) >/dev/null 2>&1
            fi
        fi
        
        if [[ -f "$agent_path" ]]; then
            # Make sure it's executable
            chmod +x "$agent_path" 2>/dev/null
            
            # Execute the TypeScript agent with API key in environment
            if [[ "$provider" == "openai" ]]; then
                OPENAI_API_KEY="$api_key" "$agent_path" --provider "$provider" --model "$model" "$query"
            else
                ANTHROPIC_API_KEY="$api_key" "$agent_path" --provider "$provider" --model "$model" "$query"
            fi
        else
            # Fallback to simple AI query if agent not available
            echo "⚠️  Coding agent not available. Using simple AI mode."
            echo "   To enable full coding features, install bun from https://bun.sh"
            
            # Use the fallback streaming query
            lacy_shell_send_to_ai_streaming_fallback "$query"
        fi
        
        # Save to conversation history
        echo "User: $query" >> "$LACY_SHELL_CONVERSATION_FILE"
        echo "Assistant: [Coding Agent Response]" >> "$LACY_SHELL_CONVERSATION_FILE"
        echo "---" >> "$LACY_SHELL_CONVERSATION_FILE"
    else
        # Use original agent for general queries
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
        
        # Send to AI service and stream response directly to stdout
        lacy_shell_send_to_ai_streaming "$temp_file" "$query"
        
        # Save to conversation history
        echo "User: $query" >> "$LACY_SHELL_CONVERSATION_FILE"
        echo "Assistant: [AI Response]" >> "$LACY_SHELL_CONVERSATION_FILE"
        echo "---" >> "$LACY_SHELL_CONVERSATION_FILE"
        
        # Cleanup
        rm -f "$temp_file" "$response_file"
    fi
    
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
    
    # Try OpenAI first, then Anthropic
    if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
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
  "model": "gpt-4",
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
  "model": "claude-3-5-sonnet-20241022",
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
    local content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
    
    # Create JSON payload - simpler version
    local json_payload="{
  \"model\": \"gpt-4\",
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
    
    # Send request and get response
    local response=$(curl -s -H "Content-Type: application/json" \
         -H "Authorization: Bearer $LACY_SHELL_API_OPENAI" \
         -d "$json_payload" \
         "https://api.openai.com/v1/chat/completions" 2>&1)
    
    # Check if response contains an error
    if echo "$response" | grep -q '"error"'; then
        echo "❌ API Error:"
        echo "$response" | grep -o '"message":"[^"]*' | sed 's/"message":"/  /' | head -1
        return 1
    fi
    
    # Parse the JSON response to extract content
    if command -v python3 >/dev/null 2>&1; then
        # Use Python for robust JSON parsing
        local content=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'choices' in data and len(data['choices']) > 0:
        content = data['choices'][0]['message']['content']
        print(content)
    else:
        print('No content in response', file=sys.stderr)
except json.JSONDecodeError as e:
    # If JSON is invalid, try to extract content with regex
    import re
    text = sys.stdin.read()
    match = re.search(r'\"content\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"', text)
    if match:
        content = match.group(1)
        # Unescape common sequences
        content = content.replace('\\\\n', '\\n').replace('\\\\t', '\\t')
        content = content.replace('\\\\\"', '\"').replace('\\\\\\\\', '\\\\')
        print(content)
    else:
        print(f'Error parsing JSON: {e}', file=sys.stderr)
except Exception as e:
    print(f'Unexpected error: {e}', file=sys.stderr)
" 2>&1)
        
        if [[ -n "$content" ]]; then
            echo "$content"
        else
            # If we didn't get content, try a simpler extraction
            echo "$response" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
        fi
    else
        # Fallback to sed/grep if Python isn't available
        echo "$response" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
    fi
}


# Query Anthropic API with streaming
lacy_shell_query_anthropic_streaming() {
    local input_file="$1"
    local query="$2"
    
    # Read and escape the input properly for JSON
    local content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
    
    # Create JSON payload - simpler version
    local json_payload="{
  \"model\": \"claude-3-5-sonnet-20241022\",
  \"max_tokens\": 1500,
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": \"$content\"
    }
  ]
}"
    
    # Send request and extract response
    local response=$(curl -s -H "Content-Type: application/json" \
         -H "x-api-key: $LACY_SHELL_API_ANTHROPIC" \
         -H "anthropic-version: 2023-06-01" \
         -d "$json_payload" \
         "https://api.anthropic.com/v1/messages" 2>&1)
    
    # Check if response contains an error
    if echo "$response" | grep -q '"error"'; then
        echo "❌ API Error:"
        echo "$response" | grep -o '"message":"[^"]*' | sed 's/"message":"/  /' | head -1
        return 1
    fi
    
    # Parse the JSON response to extract content
    if command -v python3 >/dev/null 2>&1; then
        # Use Python for robust JSON parsing
        local content=$(echo "$response" | python3 -c "
import sys, json, re
try:
    data = json.load(sys.stdin)
    if 'content' in data and len(data['content']) > 0:
        # Anthropic returns content as an array of blocks
        for block in data['content']:
            if block.get('type') == 'text':
                print(block.get('text', ''))
except json.JSONDecodeError as e:
    # If JSON is invalid, try to extract content with regex
    text = sys.stdin.read()
    match = re.search(r'\"text\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"', text)
    if match:
        text = match.group(1)
        # Unescape common sequences
        text = text.replace('\\\\n', '\\n').replace('\\\\t', '\\t')
        text = text.replace('\\\\\"', '\"').replace('\\\\\\\\', '\\\\')
        print(text)
except Exception as e:
    pass
" 2>/dev/null)
        
        if [[ -n "$content" ]]; then
            echo "$content"
        else
            # Fallback to simple extraction
            echo "$response" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
        fi
    else
        # Fallback extraction without Python
        local content=$(echo "$response" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        if [[ -n "$content" ]]; then
            # Basic unescaping
            echo "$content" | sed 's/\\n/\
/g' | sed 's/\\"/"/g' | sed 's/\\\\/\\/g'
        else
            echo "❌ No response from API. Raw response:"
            echo "$response" | head -3
            return 1
        fi
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
        local pipe_count=$(find "$LACY_SHELL_MCP_DIR" -name "*.pipe" 2>/dev/null | wc -l)
        echo "   Active pipes: $pipe_count"
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
