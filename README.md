# Lacy Shell

Talk directly to your shell. Natural language goes to AI. Commands execute normally. No mode switching required.

```
❯ ls -la                    → runs in shell
❯ what files are here       → AI answers
❯ git status                → runs in shell
❯ fix the build error       → AI answers
```

## Install

### Quick Install (Recommended)

```bash
curl -fsSL https://lacy.sh/install | bash
```

Or with npm (interactive arrow-key selection):

```bash
npx lacy-sh
```

### Other Methods

**Homebrew:**
```bash
brew tap lacymorrow/tap
brew install lacy
source ~/.zshrc
```

**Manual:**
```bash
git clone https://github.com/lacymorrow/lacy-shell.git ~/.lacy
echo 'source ~/.lacy/lacy-shell.plugin.zsh' >> ~/.zshrc
source ~/.zshrc
```

## Uninstall

```bash
# Interactive
npx lacy-sh --uninstall

# Or via curl
curl -fsSL https://lacy.sh/install | bash -s -- --uninstall

# Or manual
bash ~/.lacy/uninstall.sh
```

## How It Works

**Real-time visual feedback** shows what will happen as you type:

- **Green indicator** `▌` = will execute in shell
- **Magenta indicator** `▌` = will go to AI agent

**Auto mode logic:**

| Input | Result | Why |
|-------|--------|-----|
| `ls -la` | Shell | First word is valid command |
| `what files are here` | AI | "what" triggers agent |
| `git status` | Shell | Valid command |
| `fix the bug` | AI | Multi-word, not a command |
| `cd..` | Shell | Single word typo, let it error |
| `!rm -rf *` | Shell | `!` prefix forces shell |

## Commands

| Command | Description |
|---------|-------------|
| `mode` | Show current mode and color legend |
| `mode shell` | All input goes to shell |
| `mode agent` | All input goes to AI |
| `mode auto` | Smart detection (default) |
| `tool` | Show/change active AI tool |
| `tool set <name>` | Set AI tool (lash, claude, opencode, gemini, codex) |
| `ask "query"` | Direct query to AI |
| `Ctrl+Space` | Toggle between modes |
| `quit_lacy` | Exit Lacy Shell |

## Supported AI CLI Tools

Lacy works with any of these AI CLI tools (auto-detects if not configured):

| Tool | Command | Install |
|------|---------|---------|
| lash | `lash run -c "query"` | `npm i -g lash-cli` |
| claude | `claude -p "query"` | `brew install claude` |
| opencode | `opencode run "query"` | `brew install opencode` |
| gemini | `gemini -p "query"` | `brew install gemini` |
| codex | `codex exec "query"` | `npm i -g @openai/codex` |

All tools handle their own authentication — no API keys needed from Lacy.

### Selecting a Tool

During installation, you'll be asked which tool to use. You can change it anytime:

```bash
tool set claude    # Use Claude Code
tool set lash      # Use Lash
tool set auto      # Auto-detect (first available)
```

Or edit `~/.lacy/config.yaml`:

```yaml
agent_tools:
  active: claude   # or lash, opencode, gemini, codex, or empty for auto
```

## Configuration

Config file: `~/.lacy/config.yaml`

```yaml
# AI CLI tool selection
agent_tools:
  active: claude   # lash, claude, opencode, gemini, codex, or empty for auto-detect

# API Keys (only needed if no CLI tool is installed)
api_keys:
  openai: "sk-..."
  anthropic: "sk-ant-..."

# Default mode
modes:
  default: auto    # shell, agent, auto

# Auto-detection settings
auto_detection:
  enabled: true
  confidence_threshold: 0.7
```

## Architecture

```
~/.lacy/
├── lacy-shell.plugin.zsh   # Entry point
├── config.yaml             # User configuration
├── lib/
│   ├── constants.zsh       # Colors, paths, defaults
│   ├── config.zsh          # Config parsing
│   ├── modes.zsh           # Mode state management
│   ├── mcp.zsh             # AI tool routing
│   ├── detection.zsh       # Input type detection
│   ├── keybindings.zsh     # Ctrl+Space, real-time indicator
│   ├── prompt.zsh          # Prompt with mode indicator
│   └── execute.zsh         # Command execution routing
├── install.sh              # Installer
└── uninstall.sh            # Uninstaller
```

## Installation Options

### Installer Flags

```bash
# Show help
bash install.sh --help

# Force bash installer (skip Node)
bash install.sh --bash

# Pre-select tool (non-interactive)
bash install.sh --tool claude

# Uninstall
bash install.sh --uninstall
```

### npx Options

```bash
# Install (interactive)
npx lacy-sh

# Uninstall
npx lacy-sh --uninstall

# Help
npx lacy-sh --help
```

## Troubleshooting

### No AI response

1. Check if an AI tool is installed: `tool`
2. Install one: `npm i -g lash-cli` or `brew install claude`
3. Or configure API keys in `~/.lacy/config.yaml`

### Colors not showing

Ensure your terminal supports 256 colors. The indicator uses:
- Green: color 34
- Magenta: color 200
- Blue: color 75

### Mode not switching

Try `Ctrl+Space` or run `mode auto` to reset.

### Emergency bypass

Prefix any command with `!` to force shell execution:
```bash
!rm -rf node_modules
```

### Disable temporarily

```bash
disable_lacy   # Disable input interception
enable_lacy    # Re-enable
```

## Development

```bash
# Clone
git clone https://github.com/lacymorrow/lacy-shell.git
cd lacy-shell

# Source directly for testing
source lacy-shell.plugin.zsh

# Test installer
bash install.sh --bash
```

## License

MIT — see [LICENSE](LICENSE).
