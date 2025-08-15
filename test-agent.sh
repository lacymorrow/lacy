#!/usr/bin/env zsh

# Test the agent functionality

echo "🧪 Testing Lacy Shell Agent"
echo "=========================="
echo ""

# Source the plugin
export LACY_SHELL_API_OPENAI="${OPENAI_API_KEY:-}"
export LACY_SHELL_API_ANTHROPIC="${ANTHROPIC_API_KEY:-}"
source lacy-shell.plugin.zsh 2>/dev/null

# Check if API keys are configured
if lacy_shell_check_api_keys; then
    echo "✅ API keys configured"
    provider=$(lacy_shell_get_api_provider)
    echo "   Using provider: $provider"
else
    echo "❌ No API keys configured"
    echo "   Set OPENAI_API_KEY or ANTHROPIC_API_KEY environment variable"
    exit 1
fi
echo ""

# Test mode switching
echo "Testing mode switching:"
lacy_shell_set_mode "agent"
echo "✅ Switched to agent mode"
echo ""

# Test simple query (non-interactive)
echo "Testing simple query:"
echo "Query: 'What is 2+2?'"

# Create a simple test query
test_query() {
    local query="What is 2+2?"
    local temp_file=$(mktemp)
    
    echo "System Context:" > "$temp_file"
    echo "- Current Directory: $(pwd)" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "Current Query: $query" >> "$temp_file"
    
    # Try to send query
    if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
        echo "Using OpenAI API..."
        lacy_shell_query_openai_streaming "$temp_file" "$query"
    elif [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
        echo "Using Anthropic API..."
        lacy_shell_query_anthropic_streaming "$temp_file" "$query"
    fi
    
    rm -f "$temp_file"
}

# Run the test
test_query
echo ""

# Test TypeScript agent if available
echo "Testing TypeScript agent:"
if [[ -f "agent/lacy-agent" ]]; then
    echo "✅ TypeScript agent found"
    ./agent/lacy-agent --help | head -3
else
    echo "⚠️  TypeScript agent not built"
    echo "   Run: cd agent && bun install && bun run build"
fi
echo ""

echo "=========================="
echo "✅ Agent test complete!"