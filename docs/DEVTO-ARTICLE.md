---
title: How I Made My Terminal Understand English
published: false
tags: terminal, ai, devtools, opensource
cover_image: https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-full.gif
---

Every time I need AI help while coding, I do the same thing:

1. Copy terminal output
2. Switch to Claude/ChatGPT
3. Paste and ask my question
4. Wait for the response
5. Copy the answer
6. Switch back to terminal
7. Paste and run

That loop happens 20+ times a day. It's death by a thousand context switches.

So I built [Lacy Shell](https://lacy.sh), a ZSH/Bash plugin that detects whether you're typing a command or natural language, then routes accordingly. Commands execute in your shell. Questions go to your AI agent. No prefix, no hotkey, no new terminal.

## The real-time indicator

As you type, a colored indicator shows what will happen when you press enter:

- **Green** = shell command (will execute normally)
- **Magenta** = natural language (will go to AI agent)

The first word also gets syntax-highlighted in real-time. It updates on every keystroke.

![Demo showing color indicator transition](https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-color-transition.gif)

## How detection works

Here's the part I found most interesting to build. Lacy doesn't use AI to classify your input. It's pure lexical analysis:

1. **Agent words** (~150 common conversational words like "explain", "why", "thanks", "perfect") always route to AI
2. **Shell reserved words** (`do`, `then`, `in`, `fi`) pass `command -v` but are never standalone commands. "Do we have auth?" is natural language, not a `do` loop.
3. **Command validity** (if the first word is a valid command, it goes to shell)
4. **Word count heuristic** (single non-command words go to shell because they're probably typos. Multiple words starting with a non-command go to AI.)
5. **Post-execution reroute** (if a valid command fails with natural language patterns like 3+ bare words or articles/pronouns, it silently reroutes to AI)

This makes it sub-millisecond. No network call, no API key needed for classification.

## Tool agnostic

Lacy doesn't replace your AI tool. It makes it accessible:

| Tool | How Lacy calls it |
|------|------------------|
| Claude Code | `claude -p "query"` |
| Gemini CLI | `gemini --resume -p "query"` |
| OpenCode | `opencode run -c "query"` |
| Codex | `codex exec resume --last "query"` |
| Lash | `lash run -c "query"` |

It auto-detects whatever you have installed. Or set a custom command.

## Examples

| You type | Routes to | Why |
|----------|-----------|-----|
| `ls -la` | Shell | Valid command |
| `what files are here` | AI | Natural language |
| `git status` | Shell | Valid command |
| `do we have auth?` | AI | Reserved word "do" |
| `fix the bug` | AI | Multi-word, not a command |
| `kill the process on 3000` | Shell, then AI | Valid command fails with NL patterns |

## The trickiest part: coexisting with zsh-autosuggestions

Both Lacy and zsh-autosuggestions write to `POSTDISPLAY` and `region_highlight`. Getting them to share nicely took more time than the actual detection logic.

The solution: Lacy tags all its highlight entries with `memo=lacy` (a ZSH 5.8+ feature) so it can remove only its own entries on each redraw. For `POSTDISPLAY`, Lacy calls `_zsh_autosuggest_clear` before writing its ghost text, and autosuggestions picks back up once you start typing.

Small detail, but if you've ever had two ZSH plugins fighting over the same resources, you know how annoying it is.

## Install

One line:

```bash
curl -fsSL https://lacy.sh/install | bash
```

Also: `brew install lacymorrow/tap/lacy` or `npx lacy`

Works on macOS, Linux, WSL. ZSH and Bash 4+. MIT licensed. Currently on v1.8.11.

[GitHub](https://github.com/lacymorrow/lacy) | [Website](https://lacy.sh)

---

If you have questions or want to see something specific, the [GitHub Discussions](https://github.com/lacymorrow/lacy/discussions) are open. I read everything.
