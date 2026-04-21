---
title: How I Made My Terminal Understand English
published: false
tags: terminal, ai, devtools, opensource
canonical_url: https://lacy.sh
cover_image: https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-full.gif
---

Every time I need AI help while coding, I do the same thing:

1. Copy terminal output
2. Switch to Claude or ChatGPT
3. Paste and ask my question
4. Wait for the response
5. Copy the answer
6. Switch back to terminal
7. Paste and run

That loop happens 20+ times a day.

AI coding tools like Claude Code and Gemini CLI already live in the terminal. But you still switch into them, type `claude`, ask your thing, then switch back to your regular shell. Two workflows, one terminal.

I built [Lacy Shell](https://lacy.sh) to fix that. It's a ZSH/Bash plugin that figures out whether you're typing a command or a question and routes it to the right place. Commands run in your shell. Questions go to your AI agent. You just type.

![Demo of Lacy Shell showing real-time color indicator](https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-full.gif)

## The color indicator

The thing that made it click for me was the color indicator. As you type, a dot next to your prompt changes color:

- Green = shell command
- Magenta = AI agent

The first word gets syntax-highlighted too. Both update on every keystroke, so you know what's going to happen before you press Enter.

ZSH also gets a mode badge in the right prompt: `SHELL`, `AGENT`, or `AUTO`. `Ctrl+Space` toggles between them.

## How detection works

The part that surprised me: you don't need AI to classify input. Lacy uses lexical analysis — no network call, no API key. Under a millisecond.

The rules, in priority order:

First, about 150 conversational words ("explain", "why", "thanks", "perfect") always route to AI. `explain this error` has no ambiguity. It's a lookup table, not a model.

Second, shell reserved words. This one tripped me up for a while. Words like `do`, `then`, `in`, and `select` pass `command -v` (they're valid shell syntax), but nobody types `do` and means a `do` loop. "Do we have a way to deploy?" is a question. "In the codebase, where is auth?" is a question. I maintain a list of these and route them straight to AI.

Third, if the first word is a valid command, shell gets it. `git status`, `ls -la`, `docker ps` — straightforward.

Fourth, single non-command words go to shell too. If you type `gti` (a typo for `git`), you probably want to see the shell's error, not have AI interpret it.

Fifth, multiple words where the first isn't a command go to AI. "Fix the bug in auth" starts with "fix" — not a command on most systems. Multiple words, first word isn't a command. That's natural language.

The last rule is my favorite. Sometimes a valid command gets natural language arguments: `kill the process on localhost:3000`. `kill` is a real command, so Lacy sends it to the shell. It fails. Lacy then checks: did the error match a known pattern ("No such process")? Did the input have natural language markers (articles, pronouns, 3+ bare words)? If both, it silently reroutes to the AI agent. You never see the failed attempt.

## Routing table

In practice:

| You type | Routes to | Why |
|----------|-----------|-----|
| `ls -la` | Shell | Valid command |
| `what files are here` | AI | Agent word "what" |
| `git status` | Shell | Valid command |
| `do we have auth?` | AI | Reserved word "do" |
| `cd..` | Shell | Single word (typo) |
| `fix the bug` | AI | Multi-word, not a command |
| `kill the process on 3000` | Shell, then AI | Valid command fails with NL patterns |
| `make sure the tests pass` | Shell, then AI | "sure" is an NL marker, make fails |

## It's a routing layer, not another AI tool

Lacy calls whatever CLI you already have installed:

| Tool | How Lacy calls it |
|------|------------------|
| Claude Code | `claude -p "query"` |
| Gemini CLI | `gemini --resume -p "query"` |
| OpenCode | `opencode run -c "query"` |
| Codex | `codex exec resume --last "query"` |
| Lash | `lash run -c "query"` |

It auto-detects what's on your system, or you can point it at a custom command.

## What I didn't expect

I built this to stop context-switching. The thing that actually changed my workflow was different — I started asking my terminal stuff I'd never have bothered looking up.

What's the flag for recursive grep again? How do I find processes on port 8080? What's the git command to undo the last commit without losing changes?

Before, I'd Google these or fumble through `man` pages. Now I just type the question where I'm already working. The friction was low enough that it changed the habit.

## Install

One line:

```bash
curl -fsSL https://lacy.sh/install | bash
```

Or Homebrew:

```bash
brew install lacymorrow/tap/lacy
```

Or npx:

```bash
npx lacy
```

macOS, Linux, WSL. ZSH and Bash 4+. MIT licensed.

[GitHub](https://github.com/lacymorrow/lacy) / [lacy.sh](https://lacy.sh)

If you try it, I want to hear about the edge cases. The boundary between "command" and "question" is fuzzy by nature, and real usage is how I tune it. File an issue or just yell at me on Twitter.
