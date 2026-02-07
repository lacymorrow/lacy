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

- `accept-line` — Routes input based on mode; flags NL reroute candidates
- `zle-line-pre-redraw` — Updates indicator color and first-word syntax highlighting
- `precmd` — Captures `$?`, checks reroute candidates, dispatches deferred agent queries, updates prompt

### Bash Hooks

- `\C-m` macro — `\C-x\C-l` (classification via `bind -x`) then `\C-j` (accept-line)
- `PROMPT_COMMAND` — Captures `$?`, checks reroute candidates, dispatches deferred agent queries, updates PS1
- `trap INT` — Double Ctrl+C detection

---

## Safety Features

- **Dangerous command detection**: Warns for `rm -rf`, `sudo rm`, `mkfs`, `dd if=`
- **Prefix bypass**: `!command` forces shell execution
- **Double Ctrl+C quit**: Prevents accidental exits
- **Signal-aware rerouting**: Only reroutes on exit codes < 128 (not signal-killed processes)
