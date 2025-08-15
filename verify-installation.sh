#!/usr/bin/env zsh

echo "🔍 Verifying Lacy Shell Installation"
echo "===================================="
echo ""

# 1. Check plugin loads
echo "1. Plugin Loading:"
if zsh -c 'source lacy-shell.plugin.zsh 2>/dev/null; exit 0'; then
    echo "   ✅ Plugin loads successfully"
else
    echo "   ❌ Plugin failed to load"
    exit 1
fi

# 2. Check configuration
echo "2. Configuration:"
if [[ -f "$HOME/.lacy-shell/config.yaml" ]]; then
    echo "   ✅ Config file exists"
else
    echo "   ⚠️  No config file (will be created on first run)"
fi

# 3. Check TypeScript agent
echo "3. TypeScript Agent:"
if [[ -f "agent/lacy-agent" ]]; then
    echo "   ✅ Agent binary found"
else
    echo "   ⚠️  Agent not built (optional - requires bun)"
fi

# 4. Check API configuration
echo "4. API Configuration:"
if [[ -n "$OPENAI_API_KEY" ]] || [[ -n "$ANTHROPIC_API_KEY" ]]; then
    echo "   ✅ API keys in environment"
elif grep -q "openai:\|anthropic:" "$HOME/.lacy-shell/config.yaml" 2>/dev/null; then
    echo "   ✅ API keys in config file"
else
    echo "   ⚠️  No API keys configured"
fi

# 5. Check dependencies
echo "5. Dependencies:"
echo -n "   zsh: "
command -v zsh >/dev/null && echo "✅" || echo "❌"
echo -n "   curl: "
command -v curl >/dev/null && echo "✅" || echo "❌"
echo -n "   git: "
command -v git >/dev/null && echo "✅" || echo "❌"
echo -n "   bun: "
command -v bun >/dev/null && echo "✅ (agent features enabled)" || echo "⚠️  (agent features disabled)"

echo ""
echo "===================================="
echo ""

# Instructions
echo "📚 Quick Start:"
echo "1. Add API key to ~/.lacy-shell/config.yaml"
echo "2. Add to ~/.zshrc: source $PWD/lacy-shell.plugin.zsh"
echo "3. Reload shell: source ~/.zshrc"
echo ""
echo "🎮 Usage:"
echo "• Press Ctrl+Space to switch modes"
echo "• Use '?' prefix for agent mode"
echo "• Use '~' prefix for auto mode"
echo "• Use '$' prefix for shell mode"
echo ""
echo "💡 Examples:"
echo "? help me write a function"
echo "~ what files are here"
echo "$ ls -la"