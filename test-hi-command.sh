#!/usr/bin/env zsh

echo "Testing 'hi' command execution"
echo "=============================="
echo ""

# Set up environment
export LACY_SHELL_API_OPENAI="${OPENAI_API_KEY:-test-key}"
export LACY_SHELL_API_ANTHROPIC="${ANTHROPIC_API_KEY:-}"

# Source the plugin
echo "Loading plugin..."
source lacy-shell.plugin.zsh 2>/dev/null

# Set to auto mode
lacy_shell_set_mode "auto"
echo "Mode: $LACY_SHELL_CURRENT_MODE"
echo ""

# Create a test input file
echo "System Context:
- Current Directory: $(pwd)
- Current Date: $(date)
- Shell: $SHELL
- User: $USER

Current Query: hi" > /tmp/test-hi-input.txt

echo "Testing the AI query function directly:"
echo "----------------------------------------"

# Test if the streaming function works
echo "Testing OpenAI streaming function..."
if declare -f lacy_shell_query_openai_streaming > /dev/null; then
    echo "Function exists. Testing with mock input..."
    
    # Show what the function would do
    echo ""
    echo "The function will:"
    echo "1. Read content from /tmp/test-hi-input.txt"
    echo "2. Escape it for JSON"
    echo "3. Send to OpenAI API via curl"
    echo ""
    
    # Try to run it (will fail with test key but shows if Python is called)
    lacy_shell_query_openai_streaming /tmp/test-hi-input.txt "hi" 2>&1 | head -5
else
    echo "Function not found!"
fi

# Clean up
rm -f /tmp/test-hi-input.txt