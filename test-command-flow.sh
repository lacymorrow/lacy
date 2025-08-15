#!/usr/bin/env zsh

echo "Testing command flow in auto mode"
echo "================================="

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Set to auto mode
lacy_shell_set_mode "auto"
echo "Mode set to: $LACY_SHELL_CURRENT_MODE"
echo ""

# Test if "hi" is recognized as a command
echo "Testing: 'hi'"
if lacy_shell_command_exists "hi"; then
    echo "  'hi' is recognized as a command"
else
    echo "  'hi' is NOT a command"
fi
echo ""

# Test what happens with unrecognized command
echo "Simulating what happens when 'hi' is typed:"
echo "-------------------------------------------"

# Check if it's obvious natural language
if lacy_shell_is_obvious_natural_language "hi"; then
    echo "  1. Detected as natural language -> would go directly to agent"
else
    echo "  1. NOT detected as natural language"
    echo "  2. Will try to execute as shell command"
    echo "  3. When that fails, will fall back to agent"
fi

# Show what function would be called
echo ""
echo "In auto mode, typing 'hi' would:"
echo "  - First check if 'hi' is a command: NO"
echo "  - Since API keys are configured: Call lacy_shell_execute_agent"
echo "  - Which calls lacy_shell_query_agent"
echo "  - Which should use the TypeScript agent or curl fallback"