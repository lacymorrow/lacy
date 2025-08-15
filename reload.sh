#!/usr/bin/env zsh

echo "🔄 Reloading Lacy Shell Plugin"
echo "=============================="
echo ""

# First, clean up any existing functions and variables
echo "Cleaning up old version..."
unfunction lacy_shell_query_openai_streaming 2>/dev/null
unfunction lacy_shell_query_anthropic_streaming 2>/dev/null
unfunction lacy_shell_query_agent 2>/dev/null
unset LACY_SHELL_DIR 2>/dev/null

# Stop any running MCP servers
if declare -f lacy_shell_stop_mcp_servers > /dev/null; then
    lacy_shell_stop_mcp_servers 2>/dev/null
fi

echo "✅ Cleanup complete"
echo ""

# Now source the plugin fresh
echo "Loading fresh plugin..."
source lacy-shell.plugin.zsh

echo "✅ Plugin reloaded"
echo ""

# Show current configuration
echo "Current configuration:"
echo "- Mode: $LACY_SHELL_CURRENT_MODE"
echo -n "- API Keys: "
if lacy_shell_check_api_keys; then
    echo "Configured ✅"
else
    echo "Not configured ⚠️"
fi

echo -n "- TypeScript Agent: "
if [[ -f "$LACY_SHELL_DIR/agent/lacy-agent" ]]; then
    echo "Available ✅"
else
    echo "Not built ⚠️"
fi

echo ""
echo "Ready to use! Try typing:"
echo "  hi          (in auto mode, will be sent to AI)"
echo "  ? hi        (force agent mode)"
echo "  $ ls        (force shell mode)"