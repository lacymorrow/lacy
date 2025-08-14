# Lacy Shell

A smart shell enhancement that brings AI assistance directly to your terminal with three intelligent modes of operation.

## 🌟 Overview

Lacy Shell is a **production-ready** zsh plugin that seamlessly integrates AI capabilities into your command-line workflow. It provides three distinct modes that adapt to how you work:

- **🐚 Shell Mode** (`$`): Pure shell execution - all commands run normally
- **🤖 Agent Mode** (`?`): AI-powered assistance - all input goes to AI with context
- **⚡ Auto Mode** (`~`): Smart execution - tries real commands first, falls back to AI

**✅ PRODUCTION READY** with complete MCP integration, robust error handling, and bulletproof architecture!

## ✨ Key Features

- 🔄 **Instant Mode Switching** - `Ctrl+Space` to toggle between modes
- 💾 **Mode Persistence** - Your preferred mode is remembered across shell sessions
- 🤖 **MCP Integration** - Model Context Protocol support for advanced AI capabilities  
- 🧠 **Smart Execution** - Executes real commands first, then falls back to AI for assistance
- 💬 **Persistent Conversations** - AI remembers context across interactions
- 📺 **Streaming Responses** - Real-time typewriter effect for AI responses
- ⚡ **Zero Configuration** - Works with existing zsh/starship/oh-my-zsh setups
- 🔐 **Secure** - API keys stored locally, never transmitted unnecessarily

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/lacy-shell.git ~/.lacy-shell

# Install dependencies  
cd ~/.lacy-shell && ./install.sh

# Or manual installation:
echo 'source ~/.lacy-shell/lacy-shell.plugin.zsh' >> ~/.zshrc
source ~/.zshrc
```

### Configuration

Edit `~/.lacy-shell/config.yaml` to add your API keys:

```yaml
api_keys:
  openai: "sk-your-openai-key-here"
  # OR
  anthropic: "your-anthropic-key-here"

modes:
  default: "auto"  # Start in auto mode

mcp:
  servers:
    - name: "filesystem"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/Users/yourname"]
```

## 🎮 Usage Guide

### Mode Switching

**Primary Method:**
- **`Ctrl+Space`** - Toggle through modes (auto → shell → agent → auto...)

**Command Method:**
```bash
mode shell    # Switch to shell mode
mode agent    # Switch to agent mode  
mode auto     # Switch to auto mode
mode toggle   # Toggle to next mode
mode status   # Show current mode and persistence info
```

**Mode Persistence:**
Your selected mode is automatically saved and restored across shell sessions. If you prefer agent mode, it will remain in agent mode when you start new shells, until you explicitly change it.

**Alternative Keybindings:**
- `Ctrl+T` - Toggle mode (backup)
- `Ctrl+X Ctrl+A` - Direct to agent mode
- `Ctrl+X Ctrl+S` - Direct to shell mode
- `Ctrl+X Ctrl+U` - Direct to auto mode
- `Ctrl+X Ctrl+H` - Show help

### Mode Indicators

Watch the right side of your prompt:
- **`~`** = Auto mode (smart detection)
- **`$`** = Shell mode (normal execution)  
- **`?`** = Agent mode (AI assistance)

### Smart Auto Mode Behavior

Auto mode now features **intelligent command execution** that maximizes efficiency:

#### 🎯 How It Works

1. **Natural Language Detection**: Obvious questions and requests go directly to AI
   ```bash
   ~ ❯ what files were changed today?    # → Direct to AI (no shell attempt)
   ~ ❯ how do I install docker?          # → Direct to AI (no shell attempt)
   ~ ❯ please help me with git           # → Direct to AI (no shell attempt)
   ```

2. **Command Execution First**: Real commands are executed immediately
   ```bash
   ~ ❯ ls -la          # → Shell execution (command exists)
   ~ ❯ git status      # → Shell execution (command exists)  
   ~ ❯ npm install     # → Shell execution (command exists)
   ```

3. **Smart Fallback**: Unknown commands try shell first, then fall back to AI
   ```bash
   ~ ❯ invalidcmd --help     # → Try shell first → Command not found → Ask AI
   ~ ❯ unknowntool --version # → Try shell first → Command not found → Ask AI
   ```

#### 💡 Benefits

- **⚡ Faster**: Real commands execute immediately without AI overhead
- **🧠 Smarter**: Natural language goes directly to AI without failed shell attempts  
- **🔄 Resilient**: Unknown commands get AI assistance automatically
- **📚 Educational**: Learn about new tools when commands don't exist

### Example Workflows

**Auto Mode** (Recommended):
```bash
~ ❯ ls -la                          # → Executes shell command directly
~ ❯ what files were changed today?  # → Natural language → AI analysis  
~ ❯ git status                      # → Executes shell command directly
~ ❯ invalidcmd --help              # → Tries shell first, then → AI assistance
~ ❯ help me fix this merge conflict # → Natural language → AI assistance
```

**Agent Mode** (AI Assistance):
```bash
? ❯ explain this error message
? ❯ write a bash script to backup files
? ❯ what's the best way to optimize this code?
? ❯ help me understand this git workflow
```

**Shell Mode** (Pure Shell):
```bash
$ ❯ npm install express
$ ❯ docker build -t myapp .
$ ❯ ssh user@server
$ ❯ git commit -m "feature complete"
```

## 🔧 Advanced Features

### Direct Commands

```bash
ask "how do I use grep effectively?"    # Direct AI query
clear_chat                              # Clear conversation history
show_chat                               # View conversation history
mode help                               # Show help information
```

### Conversation Memory

The AI maintains context across your session:
```bash
? ❯ I'm working on a Python project
AI: Great! What kind of Python project are you working on?

? ❯ it's a web scraper
AI: Excellent! For web scraping in Python, I'd recommend... 

? ❯ what libraries did you just mention?
AI: I mentioned requests, BeautifulSoup, and Scrapy for web scraping...
```

### MCP Integration

Lacy Shell includes full Model Context Protocol (MCP) support with real server management:

**Capabilities:**
- 📁 **Filesystem Operations** - Read, write, and list files through MCP filesystem server
- 🌐 **Web Integration** - Search the web and fetch content via MCP web server
- 📊 **System Analysis** - Execute commands and gather system info safely
- 📈 **Git Operations** - Repository analysis and git operations
- 🔧 **Tool Orchestration** - AI can call multiple tools in sequence

**MCP Commands:**
```bash
mcp_test        # Test MCP server status and configuration
mcp_start       # Start all configured MCP servers
mcp_stop        # Stop all MCP servers
mcp_restart     # Restart a specific server
mcp_debug       # Debug server communication
mcp_logs        # View server logs
```

**How it Works:**
The AI can automatically call MCP tools when you ask questions like:
- "What files are in this directory?" → Uses filesystem server
- "Search for information about X" → Uses web server  
- "What's my system memory usage?" → Uses system server

## 📚 Configuration Reference

### Complete Config Example

```yaml
# ~/.lacy-shell/config.yaml

api_keys:
  openai: "sk-your-openai-key"
  anthropic: "your-anthropic-key"

mcp:
  servers:
    - name: "filesystem"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/Users/yourname/projects"]
    - name: "web"
      command: "npx"
      args: ["@modelcontextprotocol/server-web"]
    - name: "git"
      command: "npx"
      args: ["@modelcontextprotocol/server-git", "--repository", "."]

modes:
  default: "auto"

detection:
  agent_keywords:
    - "help"
    - "how"
    - "what"
    - "why" 
    - "explain"
    - "show me"
    - "find"
    - "search"
    - "analyze"
    - "debug"
  
  shell_commands:
    - "ls"
    - "cd"
    - "git"
    - "npm"
    - "docker"
    - "ssh"
    - "vim"
    - "code"
```

### Environment Variables

Lacy Shell uses these environment variables (set automatically from config):
- `LACY_SHELL_API_OPENAI` - OpenAI API key
- `LACY_SHELL_API_ANTHROPIC` - Anthropic API key  
- `LACY_SHELL_CURRENT_MODE` - Current mode (shell/agent/auto)
- `LACY_SHELL_MCP_SERVERS` - MCP server configuration

## 🧪 Testing Smart Auto Mode

Test the new intelligent command execution:

```bash
# Run the comprehensive test suite
./test-smart-auto.sh

# Or test individual functions
source lib/execute.zsh && test_smart_auto
```

The test will show you:
- ✅ Which commands exist vs don't exist
- 🤖 Natural language detection accuracy  
- 💻 Smart routing decisions
- 🔄 Fallback behavior

Try these examples in auto mode (`mode auto`):
```bash
ls -la                              # Should execute immediately
what files are in this directory?   # Should go to AI directly  
invalidcommand123                   # Should try shell, then AI
git status                          # Should execute immediately
please help me with docker          # Should go to AI directly
```

## 🔍 Troubleshooting

### Common Issues

**MCP Server fails to start:**
```bash
# Check if MCP packages are installed
mcp_check

# Install missing packages
npm install -g @modelcontextprotocol/server-filesystem

# Check server logs
mcp_logs filesystem

# Restart servers
mcp_restart
```

**Plugin not loading:**
```bash
# Check if plugin is sourced
echo $LACY_SHELL_CURRENT_MODE

# Reload plugin
source ~/.lacy-shell/lacy-shell.plugin.zsh
```

**API not responding:**
```bash
# Test configuration
lacy_shell_test_mcp

# Check API keys
env | grep LACY_SHELL_API
```

**Commands not executing / Output "swallowed":**
```bash
# Emergency bypass: prefix command with !
!ls -la

# Or disable input interception temporarily
disable_lacy

# Re-enable when ready
enable_lacy

# Force shell mode
mode shell
```

**Mode switching not working:**
```bash
# Try command method
mode auto

# Check keybindings
bindkey | grep lacy_shell
```

### Debug Mode

```bash
# Test auto-detection logic
lacy_shell_test_detection

# View conversation history
cat ~/.lacy-shell/conversation.log

# Check configuration loading
lacy_shell_load_config
```

## 🏗️ Architecture

### Project Structure

```
~/.lacy-shell/
├── lacy-shell.plugin.zsh    # Main plugin entry point
├── lib/
│   ├── config.zsh          # Configuration management
│   ├── modes.zsh           # Mode switching logic
│   ├── mcp.zsh             # MCP client & AI integration
│   ├── detection.zsh       # Auto-detection algorithms
│   ├── keybindings.zsh     # Keyboard shortcuts
│   ├── prompt.zsh          # Visual indicators
│   └── execute.zsh         # Command execution logic
├── install.sh              # Installation script
├── config.yaml             # User configuration
└── conversation.log        # Chat history
```

### How It Works

1. **Hook Integration**: Uses zsh's `accept-line` widget to intercept commands
2. **Smart Detection**: Analyzes input using keyword matching and patterns
3. **Mode Routing**: Routes to shell execution or AI processing based on mode
4. **AI Integration**: Streams responses from OpenAI/Anthropic APIs
5. **Context Management**: Maintains conversation history and system context

## 🤝 Contributing

We welcome contributions! Please see:
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [EXAMPLES.md](EXAMPLES.md) - Usage examples and recipes
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical deep dive

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for the modern command-line experience
- Inspired by Warp Terminal's AI features
- Uses the Model Context Protocol (MCP) for extensibility
- Compatible with zsh, starship, oh-my-zsh, and other shell enhancements
