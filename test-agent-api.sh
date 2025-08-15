#!/usr/bin/env zsh

echo "Testing agent API key passing"
echo "=============================="
echo ""

# Source the plugin
source lacy-shell.plugin.zsh 2>/dev/null

# Check if API keys are set
echo "API Keys in shell:"
echo "  LACY_SHELL_API_OPENAI: ${LACY_SHELL_API_OPENAI:+SET (${#LACY_SHELL_API_OPENAI} chars)}"
echo "  LACY_SHELL_API_ANTHROPIC: ${LACY_SHELL_API_ANTHROPIC:+SET (${#LACY_SHELL_API_ANTHROPIC} chars)}"
echo ""

# Test direct agent call with environment variable
echo "Testing direct agent call with environment variable:"
if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
    echo "  Setting OPENAI_API_KEY and calling agent..."
    OPENAI_API_KEY="$LACY_SHELL_API_OPENAI" /Users/lacy/repo/lacy-shell/agent/lacy-agent --provider openai --model gpt-4 "Say 'test successful'" 2>&1 | head -5
elif [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
    echo "  Setting ANTHROPIC_API_KEY and calling agent..."
    ANTHROPIC_API_KEY="$LACY_SHELL_API_ANTHROPIC" /Users/lacy/repo/lacy-shell/agent/lacy-agent --provider anthropic --model claude-3-5-sonnet-20241022 "Say 'test successful'" 2>&1 | head -5
fi

echo ""
echo "Testing through lacy_shell_query_agent function:"
lacy_shell_query_agent "Say 'function test successful'" 2>&1 | head -5