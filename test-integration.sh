#!/bin/bash

# Test script for Lacy Shell integration

set -e

echo "🧪 Testing Lacy Shell Integration"
echo "================================="
echo ""

# Test 1: Plugin loads without errors
echo "Test 1: Plugin Loading"
if zsh -c 'source lacy-shell.plugin.zsh; exit 0' 2>/dev/null; then
    echo "✅ Plugin loads successfully"
else
    echo "❌ Plugin failed to load"
    exit 1
fi
echo ""

# Test 2: Config file exists or can be created
echo "Test 2: Configuration"
if [[ -f "$HOME/.lacy-shell/config.yaml" ]] || zsh -c 'source lib/config.zsh; lacy_shell_create_default_config' 2>/dev/null; then
    echo "✅ Configuration system working"
else
    echo "❌ Configuration system failed"
    exit 1
fi
echo ""

# Test 3: Mode switching works
echo "Test 3: Mode Switching"
zsh_test='
source lacy-shell.plugin.zsh
lacy_shell_set_mode "agent"
if [[ "$LACY_SHELL_CURRENT_MODE" == "agent" ]]; then
    echo "✅ Mode switching works"
else
    echo "❌ Mode switching failed"
    exit 1
fi
'
zsh -c "$zsh_test"
echo ""

# Test 4: Detection logic works
echo "Test 4: Smart Detection"
zsh_test='
source lacy-shell.plugin.zsh
if lacy_shell_is_shell_command "ls -la"; then
    echo "✅ Shell command detection works"
else
    echo "❌ Shell command detection failed"
    exit 1
fi
'
zsh -c "$zsh_test" 2>/dev/null
echo ""

# Test 5: Agent binary exists
echo "Test 5: TypeScript Agent"
if [[ -f "agent/lacy-agent" ]]; then
    echo "✅ Agent binary exists"
    if ./agent/lacy-agent --help >/dev/null 2>&1; then
        echo "✅ Agent binary is executable"
    else
        echo "⚠️  Agent exists but may not be executable"
    fi
else
    echo "⚠️  Agent binary not built (bun required)"
    echo "   Run: cd agent && bun install && bun run build"
fi
echo ""

# Test 6: API key configuration
echo "Test 6: API Configuration"
if [[ -n "$OPENAI_API_KEY" ]] || [[ -n "$ANTHROPIC_API_KEY" ]]; then
    echo "✅ API keys found in environment"
elif grep -q "openai:\|anthropic:" "$HOME/.lacy-shell/config.yaml" 2>/dev/null; then
    echo "⚠️  API keys configured in config.yaml (not validated)"
else
    echo "⚠️  No API keys configured"
    echo "   Set OPENAI_API_KEY or ANTHROPIC_API_KEY environment variable"
    echo "   Or add to ~/.lacy-shell/config.yaml"
fi
echo ""

echo "================================="
echo "🎉 Integration tests complete!"
echo ""
echo "To start using Lacy Shell:"
echo "1. Add to ~/.zshrc: source $PWD/lacy-shell.plugin.zsh"
echo "2. Reload shell: source ~/.zshrc"
echo "3. Toggle modes with Ctrl+Space"
echo "4. Use ? prefix for agent mode, ~ for auto mode"