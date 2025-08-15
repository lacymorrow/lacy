#!/usr/bin/env zsh

echo "Testing curl command through AI agent"
echo "======================================"
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Set to auto mode
lacy_shell_set_mode "auto"

# Test the query
echo "Query: 'curl https://api.github.com/zen'"
echo ""

response=$(lacy_shell_query_agent "curl https://api.github.com/zen" 2>&1)

if [[ -n "$response" ]] && [[ "$response" != *"Error"* ]]; then
    echo "✅ Response received:"
    echo "$response"
else
    echo "❌ Error in response:"
    echo "$response"
fi