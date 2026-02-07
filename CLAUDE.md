# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mission

Enable developers to talk directly to their shell.

## Project Overview

Lacy Shell is a ZSH plugin that detects natural language and routes it to an AI coding agent. Commands execute normally. Natural language goes to the AI. No context switching required.

**Install location:** `~/.lacy`
**Package name:** `lacy` (npm)

## Installation Methods

| Method   | Command                                      |
| -------- | -------------------------------------------- |
| curl     | `curl -fsSL https://lacy.sh/install \| bash` |
| npx      | `npx lacy`                                   |
| Homebrew | `brew install lacymorrow/tap/lacy`           |

## Visual Feedback

**Real-time indicator** (left of prompt) changes color as you type:

- **Green (34)** = will execute in shell
- **Magenta (200)** = will go to AI agent

**First-word syntax highlighting** via ZSH `region_highlight`:

- First word is highlighted **green bold** for shell commands, **magenta bold** for agent queries
- Updates on every `zle-line-pre-redraw` (accounts for leading whitespace)

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
5. Valid command + 3+ bare words + NL marker → Shell first, then agent on failure (post-execution reroute)

Rule 5 detail: `lacy_shell_has_nl_markers()` counts bare words after the first word (excluding flags, paths, numbers, variables). If there are 3+ bare words and at least one is a strong NL marker (articles, pronouns, question words, "please"), the command is flagged via `LACY_SHELL_REROUTE_CANDIDATE`. In `precmd`, if the command exited non-zero with code < 128 (not signal-based), it reroutes to the agent. Only active in auto mode.

Examples:

- `ls -la` → Shell (valid command)
- `what files are here` → Agent ("what" override)
- `cd..` → Shell (single word typo)
- `fix the bug` → Agent (multi-word natural language)
- `kill the process on localhost:3000` → Shell → Agent (4 bare words, "the" marker, fails)
- `kill -9 my baby` → Shell only (2 bare words, below threshold)
- `echo the quick brown fox` → Shell only (succeeds, no reroute)
- `!rm -rf` → Shell (emergency bypass with `!` prefix)

## Canonical Functions

### `lacy_shell_classify_input(input)` — The Single Source of Truth

**File:** `lib/detection.zsh`

All input classification MUST go through this function. It returns one of three strings:

- `"shell"` → route to shell (indicator: green)
- `"agent"` → route to AI agent (indicator: magenta)
- `"neutral"` → no routing decision yet (indicator: gray)

**Mode-aware behavior:**

1. **Empty input** → returns mode color (`shell`/`agent`) in locked modes, `neutral` in auto
2. **Shell mode** → always returns `shell` (after empty check)
3. **Agent mode** → always returns `agent` (after empty check)
4. **Auto mode** → applies detection heuristics

**Why this matters:**

- The indicator, execution, and highlighting ALL call this function
- Never create parallel detection logic — always extend this function
- The empty-input behavior ensures the indicator shows the correct mode color when idle

**Consumers:**

- `keybindings.zsh:lacy_shell_update_input_indicator()` — real-time indicator color
- `execute.zsh:lacy_shell_smart_accept_line()` — execution routing
- `keybindings.zsh:lacy_shell_update_first_word_highlight()` — syntax highlighting

## Supported AI CLI Tools

| Tool     | Command                | Prompt Flag  |
| -------- | ---------------------- | ------------ |
| lash     | `lash run -c "query"`  | `-c`         |
| claude   | `claude -p "query"`    | `-p`         |
| opencode | `opencode run "query"` | positional   |
| gemini   | `gemini -p "query"`    | `-p`         |
| codex    | `codex exec "query"`   | positional   |
| custom   | user-defined command   | user-defined |

All tools handle their own authentication - no API keys needed from lacy.

## Architecture

```
~/.lacy/
├── lacy.plugin.zsh          # Entry point
├── config.yaml              # User configuration
├── install.sh               # Installer (bash + npx fallback)
├── uninstall.sh             # Uninstaller
├── bin/
│   └── lacy                 # Standalone CLI (no Node required)
└── lib/
    ├── constants.zsh        # Colors, timeouts, paths (LACY_SHELL_HOME=~/.lacy)
    ├── config.zsh           # YAML config, API key management, agent_tools parsing
    ├── modes.zsh            # Mode state (shell/agent/auto)
    ├── spinner.zsh          # Loading spinner with shimmer text effect
    ├── mcp.zsh              # Multi-tool routing (LACY_TOOL_CMD registry)
    ├── preheat.zsh          # Agent preheating (background server, session reuse)
    ├── detection.zsh        # Mode detection, lacy_shell_has_nl_markers() NL analysis
    ├── keybindings.zsh      # Ctrl+Space toggle, indicator, first-word region_highlight
    ├── prompt.zsh           # Prompt with indicator, mode in right prompt
    └── execute.zsh          # Execution routing, LACY_SHELL_REROUTE_CANDIDATE logic

packages/lacy/               # npm package for interactive installer
├── package.json
├── index.mjs                # @clack/prompts based installer
└── README.md
```

## CLI (standalone, no Node required)

After installation, `~/.lacy/bin` is added to `$PATH`, making the `lacy` command available:

```bash
lacy setup           # Interactive settings (tool, mode, config) — fancy Node UI if available
lacy status          # Show installation status
lacy doctor          # Diagnose common issues
lacy update          # Pull latest changes
lacy uninstall       # Remove Lacy Shell — fancy Node UI if available
lacy reinstall       # Fresh installation
lacy config          # Show config
lacy config edit     # Open config in $EDITOR
lacy install         # Install (delegates to npx or curl installer)
lacy version         # Show version
lacy help            # Show all commands
```

Source: `bin/lacy` (pure bash, zero dependencies)

**Hybrid Node delegation:** `setup`, `install`, and `uninstall` try `npx lacy@latest` first for the rich @clack/prompts UI, then fall back to bash if Node is unavailable. Set `LACY_NO_NODE=1` to force bash-only mode.

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
- `lib/detection.zsh` - **`lacy_shell_classify_input()`** (canonical classifier), `lacy_shell_has_nl_markers()` for NL detection
- `lib/keybindings.zsh` - Real-time indicator logic, first-word `region_highlight`
- `install.sh` - Bash installer with npx fallback, interactive menu
- `packages/lacy/index.mjs` - Node installer with @clack/prompts

## Configuration

Config file: `~/.lacy/config.yaml`

```yaml
agent_tools:
  active: claude # or lash, opencode, gemini, codex, custom, empty for auto
  # custom_command: "your-command -flags"  # used when active: custom

api_keys:
  openai: "sk-..." # Only needed if no CLI tool
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
