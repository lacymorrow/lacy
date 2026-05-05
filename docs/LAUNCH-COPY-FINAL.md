# Launch Copy - Final (Humanized, ready to submit)

## Show HN

**Title:** Show HN: Lacy Shell - Talk to your terminal. Commands run, questions go to AI

**Body:**

Hi HN,

I built Lacy, a ZSH/Bash plugin that figures out whether you're typing a command or asking a question, then sends it to the right place. Commands run in your shell. Questions go to your AI agent. No prefix, no hotkey. You just type.

A color indicator next to your prompt changes as you type. Green means it'll run in the shell, magenta means it's going to AI. First word gets syntax-highlighted too. Updates every keystroke.

How it decides:

- `ls -la` -> Shell (valid command, green)
- `what files are here` -> AI (natural language, magenta)
- `do we have auth?` -> AI (shell reserved words like "do", "in", "then" are never standalone commands)
- `kill the process on 3000` -> Shell first, then AI (valid command fails with NL patterns, silent reroute)

No AI call to classify your input. Pure lexical analysis: checks command validity, word counts, article/pronoun markers, known error patterns. Sub-millisecond.

Works with whatever AI CLI you already have: Claude Code, Gemini CLI, OpenCode, Codex, or Lash (my OpenCode fork). Lacy doesn't replace any of them, it just makes them easier to reach.

Install:

    curl -fsSL https://lacy.sh/install | bash

Or: `brew install lacymorrow/tap/lacy` | `npx lacy`

macOS, Linux, WSL. ZSH and Bash 4+.

Site: https://lacy.sh
Source: https://github.com/lacymorrow/lacy

---

## Twitter Thread (5 tweets)

**Tweet 1:**
I made my terminal understand English.

Type a command, it runs in your shell.
Type a question, it goes to your AI agent.

No prefix. No hotkey. Just type.

It's called Lacy Shell. Free and open source.

[attach demo-full.gif]

**Tweet 2:**
The problem: every time you need AI help, you leave your terminal.

Copy output. Switch to Claude/ChatGPT. Paste. Wait. Copy answer. Switch back. Paste.

I was doing that 20+ times a day. So I fixed it.

**Tweet 3:**
How it works:

A color indicator next to your prompt updates as you type:

Green = shell command (runs normally)
Magenta = natural language (goes to AI)

No AI call to classify. Pure lexical analysis. Sub-millisecond.

If a command fails with NL patterns, it silently reroutes to AI.

**Tweet 4:**
Lacy works with whatever AI tool you already have.

- Claude Code
- Gemini CLI
- OpenCode
- Codex CLI
- Lash
- Any custom command

It auto-detects what's installed. You don't configure anything.

**Tweet 5:**
One line to install:

curl -fsSL https://lacy.sh/install | bash

Also: brew install lacymorrow/tap/lacy

ZSH + Bash 4+. macOS, Linux, WSL.

github.com/lacymorrow/lacy
lacy.sh

Tags: @AnthropicAI @GoogleDeepMind

---

## Schedule

- Wed May 6, 9:00am ET: Post Show HN
- Wed May 6, 10:30am ET: Post Twitter thread
- Thu May 7: Post r/commandline + r/zsh
- Fri May 8: Publish Dev.to article
