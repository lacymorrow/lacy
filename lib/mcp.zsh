#!/usr/bin/env zsh

# Agent query functions for Lacy Shell
# Routes queries to configured AI CLI tools

# Tool registry with command patterns
# Format: tool_name -> "command args" where query is appended or uses quoting
typeset -gA LACY_TOOL_CMD=(
    [lash]="lash run -c"
    [claude]="claude -p"
    [opencode]="opencode run"
    [gemini]="gemini -p"
    [codex]="codex exec"
)

# Active tool (set during install or via config)
: ${LACY_ACTIVE_TOOL:=""}

# Send query to AI agent (configurable tool or fallback)
lacy_shell_query_agent() {
    local query="$1"
    local tool="${LACY_ACTIVE_TOOL}"

    # Auto-detect if not set
    if [[ -z "$tool" ]]; then
        for t in lash claude opencode gemini codex; do
            if command -v "$t" >/dev/null 2>&1; then
                tool="$t"
                break
            fi
        done
    fi

    # If still no tool, try API fallback
    if [[ -z "$tool" ]]; then
        if lacy_shell_check_api_keys; then
            echo ""
            local temp_file=$(mktemp)
            cat > "$temp_file" << EOF
Current Directory: $(pwd)
Query: $query
EOF
            lacy_start_spinner
            lacy_shell_send_to_ai_streaming "$temp_file" "$query"
            local exit_code=$?
            lacy_stop_spinner
            rm -f "$temp_file"
            echo ""
            return $exit_code
        fi

        echo "No AI CLI tool found. Install one of: lash, claude, opencode, gemini, codex"
        echo ""
        echo "Install options:"
        echo "  lash:     npm install -g lash-cli"
        echo "  claude:   brew install claude"
        echo "  opencode: brew install opencode"
        echo "  gemini:   brew install gemini"
        echo "  codex:    npm install -g @openai/codex"
        return 1
    fi

    local cmd="${LACY_TOOL_CMD[$tool]}"
    echo ""
    lacy_start_spinner
    eval "$cmd \"\$query\"" </dev/tty
    local exit_code=$?
    lacy_stop_spinner
    echo ""
    return $exit_code
}

# Check if API keys are configured
lacy_shell_check_api_keys() {
    [[ -n "$LACY_SHELL_API_OPENAI" || -n "$LACY_SHELL_API_ANTHROPIC" || -n "$OPENAI_API_KEY" || -n "$ANTHROPIC_API_KEY" ]]
}

# ============================================================================
# Direct API Fallback (when no CLI tool installed)
# ============================================================================

lacy_shell_send_to_ai_streaming() {
    local input_file="$1"
    local query="$2"

    local provider="${LACY_SHELL_PROVIDER:-$LACY_SHELL_DEFAULT_PROVIDER}"
    local api_key_openai="${LACY_SHELL_API_OPENAI:-$OPENAI_API_KEY}"
    local api_key_anthropic="${LACY_SHELL_API_ANTHROPIC:-$ANTHROPIC_API_KEY}"

    if [[ "$provider" == "anthropic" && -n "$api_key_anthropic" ]]; then
        lacy_shell_query_anthropic "$input_file" "$api_key_anthropic"
    elif [[ -n "$api_key_openai" ]]; then
        lacy_shell_query_openai "$input_file" "$api_key_openai"
    elif [[ -n "$api_key_anthropic" ]]; then
        lacy_shell_query_anthropic "$input_file" "$api_key_anthropic"
    else
        echo "Error: No API keys configured"
        return 1
    fi
}

lacy_shell_query_openai() {
    local input_file="$1"
    local api_key="$2"
    local content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

    local response=$(curl -s -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{\"model\":\"gpt-4o-mini\",\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}],\"max_tokens\":1500}" \
        "https://api.openai.com/v1/chat/completions")

    echo "$response" | grep -o '"content":"[^"]*' | sed 's/"content":"//' | head -1
}

lacy_shell_query_anthropic() {
    local input_file="$1"
    local api_key="$2"
    local content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

    local response=$(curl -s -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -d "{\"model\":\"claude-3-5-sonnet-20241022\",\"max_tokens\":1500,\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}]}" \
        "https://api.anthropic.com/v1/messages")

    echo "$response" | grep -o '"text":"[^"]*' | sed 's/"text":"//' | head -1
}

# Stub for MCP init (no-op, lash handles MCP)
lacy_shell_init_mcp() { :; }
lacy_shell_cleanup_mcp() { :; }
