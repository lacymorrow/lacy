# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lacy Shell is a zsh plugin that adds an AI agent to the terminal. When `lash` (the recommended CLI tool) is installed, this plugin becomes a thin wrapper delegating model and MCP work to Lash. Without Lash, it falls back to direct OpenAI/Anthropic HTTP calls.

## Architecture

The plugin is structured as modular zsh scripts loaded in a specific order:

```
lacy-shell.plugin.zsh    # Entry point - loads modules and initializes
lib/
  constants.zsh          # Global constants, paths, defaults, timeouts
  config.zsh             # YAML config parsing, API key management
  modes.zsh              # Mode state (shell/agent/auto) and persistence
  mcp.zsh                # MCP protocol, AI API calls (OpenAI/Anthropic)
  detection.zsh          # Auto-detection logic for shell vs agent routing
  keybindings.zsh        # Keyboard shortcuts, interrupt handlers
  prompt.zsh             # Prompt/status bar rendering, terminal manipulation
  execute.zsh            # Command execution, smart routing, loader animation
```

### Key Concepts

- **Three modes**: `shell` (normal execution), `agent` (AI-powered), `auto` (smart detection)
- **Smart auto mode**: In auto mode, valid shell commands execute normally; unrecognized input routes to AI
- **Agent CLI abstraction**: Configurable `agent.command` in config.yaml allows using any CLI tool (default: `lash run {query}`)
- **MCP servers**: When Lash is absent, the plugin can manage MCP servers directly via named pipes

### Configuration

Config file: `~/.lacy-shell/config.yaml`

Key sections:
- `api_keys`: OpenAI/Anthropic keys (also reads from `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` env vars)
- `model`: provider and model name for fallback mode
- `agent`: command template, context mode (stdin/file), needs_api_keys flag
- `mcp`: server definitions for direct MCP management

### Terminal UI

The plugin uses terminal escape sequences for:
- Top status bar (redrawn before each prompt, preserves terminal scrollback)
- Animated loader (pink sparkle frames)
- Mode indicator display (top bar, right prompt, or left prompt styles)

The top bar is drawn at line 1 of the visible terminal window using cursor positioning, without scroll regions. This allows agent responses to scroll into terminal scrollback for later review.

## Development

This is a pure zsh plugin with no build step. To test changes:

```bash
# Source the plugin directly
source lacy-shell.plugin.zsh

# Test mode detection
lacy_shell_test_detection

# Test smart auto behavior
test_smart_auto

# Check MCP configuration
mcp_test
```

### Key Functions

- `lacy_shell_smart_accept_line`: Main input router (ZLE widget)
- `lacy_shell_query_agent`: Sends queries to AI (via Lash or direct API)
- `lacy_shell_detect_mode`: Determines execution path for input
- `lacy_shell_draw_top_bar`: Renders the status bar

### Aliases Defined

User-facing commands: `ask`, `mode`, `quit_lacy`, `mcp_test`, `mcp_debug`, `disable_lacy`, `enable_lacy`
