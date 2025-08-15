#!/usr/bin/env zsh

echo "Testing ping command routing"
echo "============================"
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Check if 'ping' triggers the coding agent
echo "Query: 'can you ping google.com'"
echo ""

# Test the full flow with debugging
set -x
response=$(lacy_shell_query_agent "can you ping google.com" 2>&1)
set +x

echo ""
echo "Response:"
echo "$response"