#!/usr/bin/env zsh

# Agent query functions for Lacy Shell
# MCP is handled by lash - this file just routes queries

# Send query to AI agent (lash/opencode or fallback)
lacy_shell_query_agent() {
    local query="$1"

    # Check if lash is available
    if command -v lash >/dev/null 2>&1; then
        echo ""
        lash run -c "$query" </dev/tty
        local exit_code=$?
        echo ""
        return $exit_code
    fi

    # Check if opencode is available as fallback
    if command -v opencode >/dev/null 2>&1; then
        echo ""
        opencode run -c "$query" </dev/tty
        local exit_code=$?
        echo ""
        return $exit_code
    fi

    # Fallback to direct API calls if no CLI tool available
    if ! lacy_shell_check_api_keys; then
        echo "Error: No agent CLI (lash/opencode) found and no API keys configured."
        echo "Install lash: npm install -g lash-cli"
        return 1
    fi

    # Fallback: Direct API calls (when lash/opencode not installed)
    echo ""
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
Current Directory: $(pwd)
Query: $query
EOF
    lacy_shell_send_to_ai_streaming "$temp_file" "$query"
    local exit_code=$?
    rm -f "$temp_file"
    echo ""
    return $exit_code
}

# Check if API keys are configured
lacy_shell_check_api_keys() {
    [[ -n "$LACY_SHELL_API_OPENAI" || -n "$LACY_SHELL_API_ANTHROPIC" || -n "$OPENAI_API_KEY" || -n "$ANTHROPIC_API_KEY" ]]
}

# ============================================================================
# Direct API Fallback (when lash not installed)
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
