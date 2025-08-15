#!/usr/bin/env zsh

echo "🎯 Final Integration Test: 'hi' Command"
echo "======================================="
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Ensure we're in auto mode
lacy_shell_set_mode "auto"
echo "Mode: $LACY_SHELL_CURRENT_MODE"

# Check API keys
if lacy_shell_check_api_keys; then
    echo "API Keys: ✅ Configured"
else
    echo "API Keys: ❌ Not configured"
    exit 1
fi

echo ""
echo "Testing what happens when user types 'hi':"
echo "------------------------------------------"
echo ""

# This simulates what the command-not-found handler would do
# when the user types "hi" in the terminal

# First, check if "hi" is a command
if ! command -v hi >/dev/null 2>&1; then
    echo "❓ Command not found, trying AI agent: hi"
    echo "🤖 Sending to AI agent: hi"
    
    # Call the query agent directly
    response=$(lacy_shell_query_agent "hi" 2>&1)
    
    if [[ -n "$response" ]] && [[ "$response" != *"Error"* ]] && [[ "$response" != *"No response"* ]]; then
        echo ""
        echo "✅ Success! AI Response:"
        echo "------------------------"
        echo "$response"
    else
        echo ""
        echo "❌ Failed to get AI response"
        echo "Debug info:"
        echo "$response"
    fi
else
    echo "'hi' is somehow a valid command on this system"
fi

echo ""
echo "Test complete!"