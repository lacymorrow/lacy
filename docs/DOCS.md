# Lacy Shell - Technical Documentation

Supplement to [CLAUDE.md](../CLAUDE.md) (canonical reference) and [README.md](../README.md) (user-facing docs). This file covers hooks, safety, and shell-specific details not in those files.

---

## Supported Shells

| Shell | Version | Real-time indicator | First-word highlight | Mode badge |
|-------|---------|--------------------|--------------------|------------|
| ZSH   | any     | Yes (per-keystroke) | Yes (`region_highlight`) | RPS1 (right prompt) |
| Bash  | 4+      | No (per-prompt only) | No | PS1 badge |

**Not yet supported:** Fish (no adapter exists)

---

## Hooks & Keybindings

| Binding       | Action                             |
| ------------- | ---------------------------------- |
| `Ctrl+Space`  | Toggle mode                        |
| `Ctrl+D`      | Delete char or quit (empty buffer) |
| `Ctrl+C` (2x) | Emergency quit                     |

### ZSH Hooks

- `accept-line` — Routes input based on mode; flags NL reroute candidates; records shell commands for terminal context
- `zle-line-pre-redraw` — Updates indicator color and first-word syntax highlighting
- `precmd` — Captures `$?` for terminal context, checks reroute candidates, dispatches deferred agent queries, updates prompt

### Bash Hooks

- `\C-m` macro — `\C-x\C-l` (classification via `bind -x`) then `\C-j` (accept-line)
- `PROMPT_COMMAND` — Captures `$?` for terminal context, checks reroute candidates, dispatches deferred agent queries, updates PS1
- `trap INT` — Double Ctrl+C detection

---

## Terminal Context

Agent queries include delta-based terminal context (cwd, git branch, exit code, recent commands). Only changed state is sent — zero overhead when nothing changed between queries.

| Context | Included when |
|---------|--------------|
| `[cwd: /path]` | Directory changed since last query |
| `[git: branch]` | Git branch changed since last query |
| `[exit: N]` | Last command exited non-zero AND a command ran since last query |
| `[recent: cmd1 \| cmd2]` | Shell commands were run between queries (max 10, truncated at 80 chars) |
| `[terminal-output]...[/terminal-output]` | Terminal screen capture (tmux, screen, Kitty, WezTerm, iTerm2, Terminal.app, max 50 lines, ANSI stripped) |

Recent commands use an explicit buffer (not shell history) to avoid agent queries appearing in the context. Terminal output is captured lazily at query time via multiplexer or terminal emulator APIs (no execution overhead). tmux and screen are detected first since terminal emulator APIs return wrong content inside multiplexers. On macOS, iTerm2 and Terminal.app are supported via AppleScript. Counters reset after each agent query. `/new` resets all context state.

Configure via `~/.lacy/config.yaml`:
```yaml
context:
  output: true          # Enable terminal screen capture (default: true)
  output_lines: 50      # Max lines to include (default: 50)
```

---

## Safety Features

- **Dangerous command detection**: Warns for `rm -rf`, `sudo rm`, `mkfs`, `dd if=`
- **Prefix bypass**: `!command` forces shell execution
- **Double Ctrl+C quit**: Prevents accidental exits
- **Signal-aware rerouting**: Only reroutes on exit codes < 128 (not signal-killed processes)
