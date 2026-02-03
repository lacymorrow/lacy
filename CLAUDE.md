# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mission

Enable developers to talk directly to their shell.

## Project Overview

Lacy Shell is a ZSH plugin that detects natural language and routes it to an AI coding agent. Commands execute normally. Natural language goes to the AI. No mode switching required.

**Install location:** `~/.lacy`
**Package name:** `lacy-sh` (npm)

## Installation Methods

| Method | Command |
|--------|---------|
| curl | `curl -fsSL https://lacy.sh/install \| bash` |
| npx | `npx lacy-sh` |
| Homebrew | `brew install lacymorrow/tap/lacy` |

## Visual Feedback

**Real-time indicator** (left of prompt) changes color as you type:
- **Green (34)** = will execute in shell
- **Magenta (200)** = will go to AI agent

**Mode indicator** (right prompt) shows current mode:
- `SHELL` (green) = all input goes to shell
- `AGENT` (magenta) = all input goes to AI
- `AUTO` (blue) = smart detection (default)

## Auto Mode Logic

In AUTO mode, routing is determined by:

1. `what ...` → Agent (hardcoded override)
2. First word is valid command → Shell
3. Single word, not a command → Shell (typo, let it error)
4. Multiple words, first not a command → Agent (natural language)

Examples:
- `ls -la` → Shell (valid command)
- `what files are here` → Agent ("what" override)
- `cd..` → Shell (single word typo)
- `fix the bug` → Agent (multi-word natural language)
- `!rm -rf` → Shell (emergency bypass with `!` prefix)

## Supported AI CLI Tools

| Tool | Command | Prompt Flag |
|------|---------|-------------|
| lash | `lash run -c "query"` | `-c` |
| claude | `claude -p "query"` | `-p` |
| opencode | `opencode run "query"` | positional |
| gemini | `gemini -p "query"` | `-p` |
| codex | `codex exec "query"` | positional |
| custom | user-defined command | user-defined |

All tools handle their own authentication - no API keys needed from lacy.

## Architecture

```
~/.lacy/
├── lacy-shell.plugin.zsh    # Entry point
├── config.yaml              # User configuration
├── install.sh               # Installer (bash + npx fallback)
├── uninstall.sh             # Uninstaller
└── lib/
    ├── constants.zsh        # Colors, timeouts, paths (LACY_SHELL_HOME=~/.lacy)
    ├── config.zsh           # YAML config, API key management, agent_tools parsing
    ├── modes.zsh            # Mode state (shell/agent/auto)
    ├── spinner.zsh          # Loading spinner with shimmer text effect
    ├── mcp.zsh              # Multi-tool routing (LACY_TOOL_CMD registry)
    ├── preheat.zsh          # Agent preheating (background server, session reuse)
    ├── detection.zsh        # Mode detection helpers
    ├── keybindings.zsh      # Ctrl+Space toggle, real-time indicator
    ├── prompt.zsh           # Prompt with indicator, mode in right prompt
    └── execute.zsh          # Command execution routing, tool command

packages/lacy-sh/            # npm package for interactive installer
├── package.json
├── index.mjs                # @clack/prompts based installer
└── README.md
```

## Key Commands

- `mode [shell|agent|auto]` - Switch modes
- `mode` - Show current mode and color legend
- `tool` - Show active AI tool and available tools
- `tool set <name>` - Set AI tool (lash, claude, opencode, gemini, codex, custom, auto)
- `tool set custom "cmd"` - Set a custom command as the AI tool
- `ask "question"` - Direct query to agent
- `quit` / `stop` / `exit` - Exit lacy shell
- `Ctrl+Space` - Toggle between modes
- `Ctrl+C` (2x) - Quit

## Key Files

- `lib/constants.zsh` - `LACY_SHELL_HOME` path definition (~/.lacy)
- `lib/mcp.zsh` - `LACY_TOOL_CMD` registry, `lacy_shell_query_agent()` routing
- `lib/config.zsh` - `agent_tools.active` parsing → `LACY_ACTIVE_TOOL`
- `lib/execute.zsh` - `lacy_shell_tool()` command, routing logic
- `lib/spinner.zsh` - Braille spinner + shimmer "Thinking" animation during AI queries
- `lib/preheat.zsh` - Background server (lash/opencode) + session reuse (claude)
- `lib/keybindings.zsh` - Real-time indicator logic
- `install.sh` - Bash installer with npx fallback, interactive menu
- `packages/lacy-sh/index.mjs` - Node installer with @clack/prompts

## Configuration

Config file: `~/.lacy/config.yaml`

```yaml
agent_tools:
  active: claude  # or lash, opencode, gemini, codex, custom, empty for auto
  # custom_command: "your-command -flags"  # used when active: custom

api_keys:
  openai: "sk-..."      # Only needed if no CLI tool
  anthropic: "sk-..."

modes:
  default: auto

# Preheat: keep agents warm between queries
# preheat:
#   eager: false          # Start background server on plugin load
#   server_port: 4096     # Port for background server
```

**Preheating:** lash/opencode use a background server (`lash serve`) to eliminate cold-start. Claude uses `--resume SESSION_ID` for conversation continuity. Other tools have no preheating.

## Development Notes

- Install path changed from `~/.lacy-shell` to `~/.lacy`
- Repo (`lib/`) and install dir (`~/.lacy/lib/`) are separate copies — changes must be applied to both
- Prompt capture is deferred to first `precmd` so user's shell profile loads first
- Indicator only updates when type changes (avoids flickering)
- Colors: Green=34, Magenta=200, Blue=75, Gray=238
- Use `print -P` (not `echo`) for colored output outside of prompt strings — `%F{...}%f` escapes are only interpreted by ZSH in prompt context or via `print -P`
- Installer uses `printf` instead of `echo -e` for portability
- Node installer falls back to bash if npm package not available
