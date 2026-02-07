# Lacy Shell - Technical Documentation

> A shell plugin (ZSH and Bash 4+) enabling natural language AI queries alongside standard shell commands.

## Architecture Overview

```
lacy.plugin.zsh  (ZSH entry point)
lacy.plugin.bash (Bash 4+ entry point)
├── lib/core/                  # Shared modules (Bash 4+ and ZSH)
│   ├── constants.sh           # Paths, defaults, detection arrays (reserved words, NL markers, error patterns)
│   ├── config.sh              # YAML parsing, API key management
│   ├── modes.sh               # Mode state management
│   ├── detection.sh           # classify_input(), has_nl_markers(), detect_natural_language()
│   ├── mcp.sh                 # AI tool routing (lash, claude, opencode, gemini, codex, custom)
│   ├── preheat.sh             # Background server lifecycle, session reuse
│   └── spinner.sh             # Braille spinner with shimmer effect
├── lib/zsh/                   # ZSH adapter
│   ├── init.zsh               # Sources core + ZSH modules
│   ├── keybindings.zsh        # Ctrl+Space toggle, Ctrl+D, real-time indicator, region_highlight
│   ├── prompt.zsh             # Deferred prompt init, mode in RPS1
│   └── execute.zsh            # ZLE accept-line override, precmd routing, reroute candidates
├── lib/bash/                  # Bash 4+ adapter
│   ├── init.bash              # Sources core + Bash modules
│   ├── keybindings.bash       # Macro-based Enter, Ctrl+Space toggle, interrupt handler
│   ├── prompt.bash            # Mode badge in PS1, PROMPT_COMMAND integration
│   └── execute.bash           # Readline classification, PROMPT_COMMAND routing, reroute candidates
└── lib/*.zsh                  # Backward-compat wrappers → lib/core/ or lib/zsh/
```

**Config/State Files** (`~/.lacy/`):

- `config.yaml` - Tool selection, API keys, modes
- `bin/lacy` - Standalone CLI (pure bash, zero dependencies)

---

## Supported Shells

| Shell | Version | Real-time indicator | First-word highlight | Mode badge |
|-------|---------|--------------------|--------------------|------------|
| ZSH   | any     | Yes (per-keystroke) | Yes (`region_highlight`) | RPS1 (right prompt) |
| Bash  | 4+      | No (per-prompt only) | No | PS1 badge |

**Not yet supported:** Fish (installer references stripped, no adapter exists)

---

## Operating Modes

| Mode    | Indicator       | Behavior                                         |
| ------- | --------------- | ------------------------------------------------ |
| `shell` | SHELL (green)   | All input → shell execution                      |
| `agent` | AGENT (magenta) | All input → AI query                             |
| `auto`  | AUTO (blue)     | Smart routing: known commands → shell, else → AI |

**Switching**: `Ctrl+Space` or `mode shell|agent|auto|toggle`

---

## Detection Logic (Auto Mode)

**→ Agent** when input:

- Starts with `what`, `yes`, or `no` (hard agent indicators)
- First word is a shell reserved word (`do`, `done`, `then`, `else`, `elif`, `fi`, `esac`, `in`, `select`, `function`, `coproc`, `{`, `}`, `!`, `[[`) — these pass `command -v` but are never standalone commands (Layer 1)

**→ Shell** when input:

- First word is a valid command (checked via `command -v`, excluding reserved words)

**→ Shell → Agent** (post-execution reroute):

- First word is a valid command, but the input has 3+ bare words after it with a strong NL marker from `LACY_NL_MARKERS` (~100 common English words)
- Shell executes first; if the command fails (non-zero exit, excluding signals >= 128), a hint is shown and the input is automatically re-sent to the AI agent
- Only active in auto mode — explicit `mode shell` never reroutes
- Examples: `kill the process on localhost:3000` (reroutes), `go ahead and fix it` (reroutes), `make sure the tests pass` (reroutes), `kill -9 my baby` (stays — only 2 bare words)

**→ Agent** (fallback):

- First word is not a recognized command

See `NATURAL_LANGUAGE_DETECTION.md` for the full detection spec shared with lash.

### First-word highlighting (ZSH only)

The first word in the input buffer is syntax-highlighted in real-time via ZSH `region_highlight`:

- **Green (34, bold)** — shell command
- **Magenta (200, bold)** — agent query

---

## AI CLI Tool Integration

| Tool     | Command                | Prompt Flag  |
| -------- | ---------------------- | ------------ |
| lash     | `lash run -c "query"`  | `-c`         |
| claude   | `claude -p "query"`    | `-p`         |
| opencode | `opencode run "query"` | positional   |
| gemini   | `gemini -p "query"`    | `-p`         |
| codex    | `codex exec "query"`   | positional   |
| custom   | user-defined command   | user-defined |

All tools handle their own authentication — no API keys needed from Lacy.

**Selection priority**: Config `agent_tools.active` → auto-detect (first installed) → direct API fallback (if keys configured)

**Preheating**: lash/opencode use a background server to eliminate cold-start. Claude uses `--resume SESSION_ID` for conversation continuity.

---

## Key Commands

| Command                        | Description                              |
| ------------------------------ | ---------------------------------------- |
| `ask "query"`                  | Direct AI query                          |
| `mode [shell\|agent\|auto]`   | Show/change mode                         |
| `tool`                         | Show active tool and available tools      |
| `tool set <name>`             | Set AI tool                              |
| `tool set custom "cmd"`       | Set custom command as AI tool            |
| `quit` / `stop` / `exit`      | Exit Lacy Shell                          |
| `!command`                     | Force shell execution (bypass detection) |
| `lacy setup`                   | Interactive settings (Node UI or bash)   |
| `lacy status`                  | Show installation status                 |
| `lacy doctor`                  | Diagnose common issues                   |

---

## Hooks & Keybindings

| Binding       | Action                             |
| ------------- | ---------------------------------- |
| `Ctrl+Space`  | Toggle mode                        |
| `Ctrl+D`      | Delete char or quit (empty buffer) |
| `Ctrl+C` (2x) | Emergency quit                     |

### ZSH Hooks

- `accept-line` → Routes input based on mode; flags NL reroute candidates
- `zle-line-pre-redraw` → Updates indicator color and first-word syntax highlighting
- `precmd` → Captures `$?`, checks reroute candidates, dispatches deferred agent queries, updates prompt

### Bash Hooks

- `\C-m` macro → `\C-x\C-l` (classification via `bind -x`) then `\C-j` (accept-line)
- `PROMPT_COMMAND` → Captures `$?`, checks reroute candidates, dispatches deferred agent queries, updates PS1
- `trap INT` → Double Ctrl+C detection

---

## Safety Features

- **Dangerous command detection**: Warns for `rm -rf`, `sudo rm`, `mkfs`, `dd if=`
- **Prefix bypass**: `!command` forces shell execution
- **Double Ctrl+C quit**: Prevents accidental exits
- **Signal-aware rerouting**: Only reroutes on exit codes < 128 (not signal-killed processes)

---

## Config Reference

Config file: `~/.lacy/config.yaml`

```yaml
# AI CLI tool selection
# Options: lash, claude, opencode, gemini, codex, custom, or empty for auto-detect
agent_tools:
  active: claude
  # custom_command: "your-command -flags"  # used when active: custom

# API Keys (optional - only needed if no CLI tool is installed)
api_keys:
  # openai: "sk-..."
  # anthropic: "sk-..."

# Operating modes
modes:
  default: auto  # Options: shell, agent, auto

# Preheat: keep agents warm between queries
# preheat:
#   eager: false          # Start background server on plugin load
#   server_port: 4096     # Port for background server
```

---

## Tech Stack

- **Language**: Portable shell (Bash 4+ / ZSH shared core, shell-specific adapters)
- **Terminal**: Direct ANSI escape sequences (256-color)
- **AI routing**: CLI tool delegation (lash, claude, opencode, gemini, codex) with direct API fallback
- **State**: Environment variables + config.yaml
