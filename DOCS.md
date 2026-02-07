# Lacy Shell - Technical Documentation

> A Zsh shell wrapper enabling natural language AI queries alongside standard shell commands.

## Architecture Overview

```
lacy.plugin.zsh (entry point)
├── lib/core/
│   ├── constants.sh    - Paths, defaults, detection arrays (reserved words, NL markers, error patterns)
│   ├── config.sh       - YAML parsing, API key management
│   ├── modes.sh        - Mode state management
│   ├── detection.sh    - classify_input(), has_nl_markers(), detect_natural_language()
│   ├── mcp.sh          - Model Context Protocol integration
│   ├── preheat.sh      - Background server lifecycle, session reuse
│   └── spinner.sh      - Braille spinner with shimmer effect
├── lib/zsh/
│   ├── keybindings.zsh - Ctrl+Space toggle, Ctrl+D, real-time indicator
│   ├── prompt.zsh      - Mode indicators (top/right/prompt)
│   └── execute.zsh     - Execution routing, reroute candidate logic
├── lib/bash/
│   ├── keybindings.bash - bind -x Enter override, Ctrl+Space toggle
│   ├── prompt.bash     - Mode badge in PS1
│   └── execute.bash    - Execution routing, reroute candidate logic
└── lib/*.zsh           - Backward-compat wrappers → lib/core/ or lib/zsh/
```

**Config/State Files** (`~/.lacy/`):

- `config.yaml` - API keys, modes, MCP servers, appearance
- `current_mode` - Persisted mode state
- `conversation.log` - Chat history (auto-trimmed to 200 lines)

---

## Operating Modes

| Mode    | Indicator       | Behavior                                         |
| ------- | --------------- | ------------------------------------------------ |
| `shell` | ▌SHELL (pink)   | All input → shell execution                      |
| `agent` | ▌AGENT (orange) | All input → AI query                             |
| `auto`  | ▌AUTO (purple)  | Smart routing: known commands → shell, else → AI |

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
- Shell executes first; if the command fails (non-zero exit, excluding signals ≥ 128), a hint is shown and the input is automatically re-sent to the AI agent
- Only active in auto mode — explicit `mode shell` never reroutes
- Examples: `kill the process on localhost:3000` (reroutes), `go ahead and fix it` (reroutes — "ahead" is NL marker, "unknown command" error), `make sure the tests pass` (reroutes), `kill -9 my baby` (stays in shell — only 2 bare words), `git push origin main` (stays in shell — no NL markers)

**→ Agent** (fallback):

- First word is not a recognized command

See `NATURAL_LANGUAGE_DETECTION.md` for the full detection spec shared with lash.

### First-word highlighting

The first word in the input buffer is syntax-highlighted in real-time via ZSH `region_highlight`:

- **Green (34, bold)** — shell command
- **Magenta (200, bold)** — agent query

---

## AI Integration

**Providers**: OpenAI (`gpt-4o-mini`), Anthropic (`claude-3-5-sonnet`)

**Primary Path**: If `lash` CLI installed → `lash run {query}` (recommended)

**Fallback**: Direct curl to APIs with streaming response parsing

**Context Passed to AI**:

- Current directory + datetime
- Last 20 conversation exchanges
- Available MCP tools (if configured)

**API Keys** (precedence):

1. `~/.lacy/config.yaml` → `api_keys.openai/anthropic`
2. Environment: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`

---

## Key Commands

| Command                        | Description                              |
| ------------------------------ | ---------------------------------------- |
| `ask "query"`                  | Direct AI query                          |
| `suggest`                      | AI suggestion for failed commands        |
| `aihelp "topic"`               | Context-aware help                       |
| `aicomplete "cmd"`             | AI command completion                    |
| `clear_chat` / `show_chat`     | Manage conversation history              |
| `!command`                     | Force shell execution (bypass detection) |
| `disable_lacy` / `enable_lacy` | Emergency toggle                         |

---

## MCP (Model Context Protocol)

Configured in `config.yaml`:

```yaml
mcp:
  enabled: true
  servers:
    - name: filesystem
      command: npx
      args: ["@modelcontextprotocol/server-filesystem", "/"]
```

**Commands**: `mcp_test`, `mcp_check`, `mcp_debug`, `mcp_restart`, `mcp_logs`

**Implementation**: JSON-RPC 2.0 over stdio via named pipes (FIFOs)

---

## Hooks & Keybindings

| Binding       | Action                             |
| ------------- | ---------------------------------- |
| `Ctrl+Space`  | Toggle mode                        |
| `Ctrl+D`      | Delete char or quit (empty buffer) |
| `Ctrl+C` (2x) | Emergency quit                     |

**Zsh Hooks**:

- `accept-line` → Routes input based on mode; flags NL reroute candidates
- `zle-line-pre-redraw` → Updates indicator color and first-word syntax highlighting
- `precmd` → Captures `$?` (must be first operation), checks reroute candidates, updates prompt
- `TRAPINT` → Double Ctrl+C detection
- `WINCH` → Terminal resize handling

---

## Safety Features

- **Dangerous command detection**: Warns for `rm -rf`, `sudo rm`, `mkfs`, `dd if=`
- **Prefix bypass**: `!command` forces shell execution
- **Emergency disable**: `disable_lacy` stops all interception
- **Double Ctrl+C quit**: Prevents accidental exits

---

## Config Reference

```yaml
api_keys:
  openai: "sk-..."
  anthropic: "..."

modes:
  default: auto # shell | agent | auto

model:
  provider: openai
  name: gpt-4o-mini

agent:
  command: "lash run {query}"
  context_mode: stdin # stdin | file

mcp:
  enabled: false
  servers: []

appearance:
  show_mode_indicator: true
  mode_colors:
    shell: green
    agent: blue
    auto: yellow
```

---

## Tech Stack

- **Language**: Pure Zsh (no external deps except curl)
- **Terminal**: Direct ANSI escape sequences (256-color)
- **APIs**: Streaming curl requests with JSON parsing
- **State**: File-based persistence + environment variables
