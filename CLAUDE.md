# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mission

Enable developers to talk directly to their shell.

## Project Overview

Lacy Shell is a shell plugin (ZSH and Bash 4+) that detects natural language and routes it to an AI coding agent. Commands execute normally. Natural language goes to the AI. No context switching required.

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

**First-word syntax highlighting** (ZSH only, via `region_highlight`):

- First word is highlighted **green bold** for shell commands, **magenta bold** for agent queries
- Updates on every `zle-line-pre-redraw` (accounts for leading whitespace)

**Mode indicator** shows current mode:

- ZSH: right prompt (`RPS1`) — `SHELL` (green) / `AGENT` (magenta) / `AUTO` (blue)
- Bash: PS1 badge — `SHELL` / `AGENT` / `AUTO` with matching colors

## Auto Mode Logic

In AUTO mode, routing is determined by:

1. **Agent words** (~150 common conversational words like `perfect`, `thanks`, `yes`, `no`, `explain`, `help`) → Agent (always, even single-word). Defined in `LACY_AGENT_WORDS` in `lib/core/constants.sh`.
2. **Shell reserved words** (`do`, `done`, `then`, `else`, `elif`, `fi`, `esac`, `in`, `select`, `function`, `coproc`, `{`, `}`, `!`, `[[`) → Agent (Layer 1 — these pass `command -v` but are never standalone commands)
3. First word is valid command → Shell
4. Single word, not a command → Shell (typo, let it error)
5. Multiple words, first not a command → Agent (natural language)
6. Valid command + NL arguments → Shell first, then agent on failure (post-execution reroute, silent)

Rule 2 detail: Shell reserved words pass `command -v` but are never valid as the first token of a standalone invocation. When a user types "do we have X" or "in the codebase", they mean natural language. List defined in `LACY_SHELL_RESERVED_WORDS` in `lib/core/constants.sh`. See `docs/NATURAL_LANGUAGE_DETECTION.md` for full spec.

Rule 6 detail: When a valid command receives NL arguments and fails (exit non-zero, code < 128), the error output is analyzed. If it matches a known error pattern AND has NL markers in the input, the command silently reroutes to the agent. No user-facing hint — just auto-reroute. Only active in auto mode.

Examples:

- `ls -la` → Shell (valid command)
- `what files are here` → Agent (agent word "what")
- `do we have a way to uninstall?` → Agent (reserved word "do")
- `in the codebase where is auth?` → Agent (reserved word "in")
- `cd..` → Shell (single word typo)
- `fix the bug` → Agent (multi-word natural language)
- `kill the process on localhost:3000` → Shell → Agent (4 bare words, "the" marker, fails)
- `go ahead and fix the tests` → Shell → Agent ("ahead" marker, "unknown command" error)
- `make sure the tests pass` → Shell → Agent ("sure" marker, "No rule to make target" error)
- `kill -9 my baby` → Shell only (2 bare words, below threshold)
- `echo the quick brown fox` → Shell only (succeeds, no reroute)
- `!rm -rf` → Shell (emergency bypass with `!` prefix)

## Canonical Functions

### `lacy_shell_classify_input(input)` — The Single Source of Truth

**File:** `lib/core/detection.sh`

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

- ZSH: `keybindings.zsh:lacy_shell_update_input_indicator()` — real-time indicator color
- ZSH: `execute.zsh:lacy_shell_smart_accept_line()` — execution routing
- ZSH: `keybindings.zsh:lacy_shell_update_first_word_highlight()` — syntax highlighting
- Bash: `execute.bash:lacy_shell_smart_accept_line_bash()` — execution routing

### `lacy_shell_detect_natural_language(input, output, exit_code)` — Layer 2 Post-Execution

**File:** `lib/core/detection.sh`

Analyzes a failed shell command's output to detect natural language. Returns 0 if NL detected, 1 otherwise. Both criteria must match:

1. **Error pattern** — output contains a known shell error from `LACY_SHELL_ERROR_PATTERNS`
2. **NL signal** — second word is in `LACY_NL_MARKERS`, OR 5+ words with parse/syntax error

Minimum 2 words required. See `docs/NATURAL_LANGUAGE_DETECTION.md` for full algorithm.

## Supported AI CLI Tools

| Tool     | Command                | Prompt Flag  |
| -------- | ---------------------- | ------------ |
| lash     | `lash run -c "query"`  | `-c`         |
| claude   | `claude -p "query"`    | `-p`         |
| opencode | `opencode run -c "query"` | `-c`         |
| gemini   | `gemini --resume -p "query"` | `-p`         |
| codex    | `codex exec resume --last "query"` | positional   |
| custom   | user-defined command   | user-defined |

All tools handle their own authentication - no API keys needed from lacy.

## Architecture

```
~/.lacy/
├── lacy.plugin.zsh          # Entry point (ZSH)
├── lacy.plugin.bash         # Entry point (Bash 4+)
├── config.yaml              # User configuration
├── install.sh               # Installer (bash + npx fallback)
├── uninstall.sh             # Uninstaller
├── bin/
│   └── lacy                 # Standalone CLI (no Node required)
└── lib/
    ├── core/                    # Shared modules (Bash 4+ and ZSH)
    │   ├── constants.sh         # Colors, timeouts, paths, detection arrays
    │   ├── config.sh            # YAML config, API key management
    │   ├── modes.sh             # Mode state (shell/agent/auto)
    │   ├── spinner.sh           # Loading spinner with shimmer text effect
    │   ├── mcp.sh               # Multi-tool routing (LACY_TOOL_CMD registry)
    │   ├── preheat.sh           # Agent preheating (background server, session reuse)
    │   └── detection.sh         # classify_input(), has_nl_markers(), detect_natural_language()
    ├── zsh/
    │   ├── keybindings.zsh      # Ctrl+Space toggle, indicator, first-word region_highlight
    │   ├── prompt.zsh           # Prompt with indicator, mode in right prompt
    │   └── execute.zsh          # Execution routing, reroute candidate logic
    ├── bash/
    │   ├── init.bash            # Bash adapter init (sources core + bash modules)
    │   ├── keybindings.bash     # Macro-based Enter override, Ctrl+Space toggle
    │   ├── prompt.bash          # Mode badge in PS1
    │   └── execute.bash         # Execution routing, reroute candidate logic
    └── *.zsh                    # Backward-compat wrappers → lib/core/ or lib/zsh/

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

### Testing locally

`bin/lacy` delegates to `npx lacy@latest` which downloads the **published** npm package, not the local code. To test local changes to `packages/lacy/index.mjs`:

```bash
# Run the local Node installer/menu directly
node packages/lacy/index.mjs          # already-installed dashboard
node packages/lacy/index.mjs setup    # same dashboard
node packages/lacy/index.mjs --help   # help text

# Or force the bash fallback (skips npx entirely)
LACY_NO_NODE=1 bin/lacy setup
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

- `lib/core/constants.sh` - Colors, paths, `LACY_AGENT_WORDS`, `LACY_SHELL_RESERVED_WORDS`, `LACY_NL_MARKERS`, `LACY_SHELL_ERROR_PATTERNS`
- `lib/core/detection.sh` - **`lacy_shell_classify_input()`** (canonical), `lacy_shell_has_nl_markers()`, `lacy_shell_detect_natural_language()`
- `lib/core/mcp.sh` - `_lacy_run_tool_cmd()` safe executor, `lacy_tool_cmd()` registry, `lacy_shell_query_agent()` routing
- `lib/core/config.sh` - `agent_tools.active` parsing → `LACY_ACTIVE_TOOL`
- `lib/core/spinner.sh` - Braille spinner + shimmer "Thinking" animation during AI queries
- `lib/core/preheat.sh` - Background server (lash/opencode) + session reuse (claude)
- `lib/zsh/execute.zsh` - `lacy_shell_tool()` command, routing logic, reroute candidates
- `lib/zsh/keybindings.zsh` - Real-time indicator logic, first-word `region_highlight`
- `install.sh` - Bash installer with npx fallback, interactive menu
- `packages/lacy/index.mjs` - Node installer with @clack/prompts
- `docs/NATURAL_LANGUAGE_DETECTION.md` - Shared spec for NL detection (synced with lash)

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
- Prompt capture is deferred to first `precmd`/`PROMPT_COMMAND` so user's shell profile loads first
- Indicator only updates when type changes (avoids flickering)
- Colors: Green=34, Magenta=200, Blue=75, Gray=238
- Use `print -P` (not `echo`) for colored output in ZSH — `%F{...}%f` escapes need `print -P`
- Use `printf '\e[38;5;Nm...\e[0m'` for colored output in Bash
- Installer uses `printf` instead of `echo -e` for portability
- Node installer falls back to bash if npm package not available

### Bash adapter notes

- **Enter key**: Can't use `bind -x` directly on `\C-m` — it replaces accept-line entirely, so shell commands never submit. Instead, bind classification to a hidden key (`\C-x\C-l`) and make `\C-m` a macro: `"\C-x\C-l\C-j"` (classify, then accept-line)
- **Spinner**: Background `{ ... } &` jobs dump their source on exit via bash's `[N] Done ...` notification. Fix: `disown` the PID immediately after starting; use `kill` + `sleep` instead of `wait` for cleanup
- **No real-time indicator**: Bash can't redraw PS1 on keystroke (no `zle-line-pre-redraw` equivalent). Mode badge in PS1 updates on each prompt cycle only
- **Ctrl+Space**: Uses macro `"\C-a\C-k _lacy_mode_toggle_\C-j"` — types hidden command and submits, so PROMPT_COMMAND can update PS1
- **macOS default bash is 3.2** — adapter requires 4+ and shows a clear error if version is too old. Users install modern bash via `brew install bash`
