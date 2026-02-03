# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mission

Enable developers to talk directly to their shell.

## Project Overview

Lacy Shell is a ZSH plugin that detects natural language and routes it to an AI coding agent (lash). Commands execute normally. Natural language goes to the AI. No mode switching required.

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

## Architecture

```
lacy-shell.plugin.zsh    # Entry point
lib/
  constants.zsh          # Colors, timeouts, paths
  config.zsh             # YAML config, API key management
  modes.zsh              # Mode state (shell/agent/auto)
  mcp.zsh                # Agent query routing (lash/opencode/API fallback)
  detection.zsh          # Mode detection helpers
  keybindings.zsh        # Ctrl+Space toggle, real-time indicator
  prompt.zsh             # Prompt with indicator, mode in right prompt
  execute.zsh            # Command execution routing
```

## Agent Integration

When `lash` is installed: `lash run -c "<query>"`
Fallback: `opencode run -c "<query>"`
Last resort: Direct OpenAI/Anthropic API calls

## Key Commands

- `mode [shell|agent|auto]` - Switch modes
- `mode` - Show current mode and color legend
- `ask "question"` - Direct query to agent
- `quit_lacy` - Exit lacy shell
- `Ctrl+Space` - Toggle between modes
- `Ctrl+C` (2x) - Quit

## Key Files

- `keybindings.zsh:lacy_shell_detect_input_type()` - Real-time indicator logic
- `execute.zsh:lacy_shell_smart_accept_line()` - Routing logic (must match indicator)
- `prompt.zsh` - Prompt initialization (deferred to first precmd)
- `mcp.zsh:lacy_shell_query_agent()` - Routes to lash/opencode

## Development Notes

- Prompt capture is deferred to first `precmd` so user's shell profile loads first
- Indicator only updates when type changes (avoids flickering)
- Colors: Green=34, Magenta=200, Blue=75, Gray=238
