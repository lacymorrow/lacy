#!/usr/bin/env zsh

# Test script for MCP integration

# set -e # Disable for debugging

echo "🧪 Testing Lacy Shell MCP Integration"
echo "===================================="

# Source the plugin
source "./lacy-shell.plugin.zsh"

echo ""
echo "📋 Configuration Status:"
echo "LACY_SHELL_MCP_SERVERS: $LACY_SHELL_MCP_SERVERS"
echo "LACY_SHELL_MCP_SERVERS_JSON: ${LACY_SHELL_MCP_SERVERS_JSON:0:50}..."

echo ""
echo "🔧 Testing MCP Configuration Loading..."
lacy_shell_load_config

echo ""
echo "🚀 Testing MCP Server Management..."
echo "Starting MCP servers..."
lacy_shell_start_mcp_servers

echo ""
echo "⏱️  Waiting for servers to initialize..."
sleep 2

echo ""
echo "🔍 Testing MCP Status..."
lacy_shell_test_mcp

echo ""
echo "📊 Server Status Summary:"
echo "Active MCP Servers: ${#LACY_SHELL_MCP_PIDS}"
for server_name in "${(@k)LACY_SHELL_MCP_PIDS}"; do
    local pid="${LACY_SHELL_MCP_PIDS[$server_name]}"
    echo "  - $server_name: PID $pid"
done

echo ""
echo "🧰 Available Tools:"
lacy_shell_list_mcp_tools

echo ""
echo "🛑 Cleaning up..."
lacy_shell_stop_mcp_servers

echo ""
echo "✅ MCP Integration Test Complete!"
