#!/usr/bin/env zsh

echo "🚀 Testing Real API Integration"
echo "==============================="
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Check API keys
echo "1. Checking API Keys:"
if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
    echo "  ✅ OpenAI API key configured"
    API_AVAILABLE="openai"
elif [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
    echo "  ✅ Anthropic API key configured"
    API_AVAILABLE="anthropic"
else
    echo "  ❌ No API keys configured"
    echo ""
    echo "Please set one of:"
    echo "  export LACY_SHELL_API_OPENAI='your-openai-key'"
    echo "  export LACY_SHELL_API_ANTHROPIC='your-anthropic-key'"
    exit 1
fi

echo ""
echo "2. Testing direct API query:"
echo "----------------------------"

# Test the fallback function
echo "Testing fallback streaming function..."
response=$(lacy_shell_send_to_ai_streaming_fallback "Say 'Hello from Lacy Shell!' in exactly 5 words" 2>&1)

if [[ -n "$response" ]] && [[ "$response" != *"Error"* ]]; then
    echo "  ✅ Got response: $response"
else
    echo "  ❌ Failed to get response"
    echo "  Response: $response"
fi

echo ""
echo "3. Testing full agent query:"
echo "---------------------------"

# Test the full agent query
echo "Testing lacy_shell_query_agent..."
echo "Query: 'Say hello'"
echo ""
response=$(lacy_shell_query_agent "Say hello" 2>&1)

if [[ -n "$response" ]]; then
    echo "Response received:"
    echo "$response" | head -5
else
    echo "  ❌ No response received"
fi

echo ""
echo "4. Testing command interception:"
echo "--------------------------------"

# Set to auto mode
lacy_shell_set_mode "auto"
echo "Mode set to: $LACY_SHELL_CURRENT_MODE"

# Simulate what happens when an unrecognized command is typed
echo ""
echo "Simulating 'hi' command in auto mode..."
echo ""

# Call the execute function directly
if declare -f lacy_shell_execute_smart_auto > /dev/null; then
    # This would normally be triggered by command-not-found
    export BUFFER="hi"
    lacy_shell_execute_smart_auto
else
    echo "Execute function not available"
fi

echo ""
echo "Test complete!"