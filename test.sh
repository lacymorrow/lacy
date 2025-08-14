#!/usr/bin/env bash

# Test script for Lacy Shell

set -e

echo "🧪 Testing Lacy Shell Installation"
echo "=================================="

# Test zsh plugin loading
echo "📋 Testing plugin loading..."
if zsh -c "source lacy-shell.plugin.zsh && echo 'Plugin loaded successfully'" 2>/dev/null; then
    echo "✅ Plugin loads without errors"
else
    echo "❌ Plugin loading failed"
    exit 1
fi

# Test configuration
echo "📋 Testing configuration..."
zsh -c "
source lacy-shell.plugin.zsh
if [[ -n \"\$LACY_SHELL_CURRENT_MODE\" ]]; then
    echo '✅ Configuration loaded successfully'
    echo 'Current mode:' \$LACY_SHELL_CURRENT_MODE
else
    echo '❌ Configuration loading failed'
    exit 1
fi
"

# Test mode switching
echo "📋 Testing mode switching..."
zsh -c "
source lacy-shell.plugin.zsh
lacy_shell_set_mode 'agent'
if [[ \"\$LACY_SHELL_CURRENT_MODE\" == 'agent' ]]; then
    echo '✅ Mode switching works'
else
    echo '❌ Mode switching failed'
    exit 1
fi
"

# Test detection logic
echo "📋 Testing auto-detection..."
zsh -c "
source lacy-shell.plugin.zsh
lacy_shell_test_detection
echo '✅ Detection logic tested'
"

# Test MCP configuration
echo "📋 Testing MCP setup..."
zsh -c "
source lacy-shell.plugin.zsh
lacy_shell_test_mcp
"

# Test mode persistence
echo "📋 Testing mode persistence..."
zsh -c "
source lacy-shell.plugin.zsh
echo 'Testing mode persistence...'
lacy_shell_set_mode 'shell'
echo 'Set to shell mode, checking persistence...'
"

zsh -c "
source lacy-shell.plugin.zsh
echo 'Mode in fresh shell:' \$LACY_SHELL_CURRENT_MODE
if [[ \"\$LACY_SHELL_CURRENT_MODE\" == \"shell\" ]]; then
    echo '✅ Mode persistence working'
else
    echo '❌ Mode persistence failed'
fi
"

echo ""
echo "🎉 All tests completed!"
echo ""
echo "Next steps:"
echo "1. Run: ./install.sh"
echo "2. Add API keys to ~/.lacy-shell/config.yaml"
echo "3. Restart your shell"
