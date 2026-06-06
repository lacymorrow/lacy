# Product Hunt Listing — Lacy Shell

Ready to submit. All copy below is final.

---

## Tagline (60 char max)

```
Talk to your shell. Commands run, questions go to AI.
```

## Topics

- Developer Tools
- Artificial Intelligence
- Open Source
- Productivity

## Description

```
Lacy is a ZSH/Bash plugin that figures out whether you're typing a command or asking a question, then sends it to the right place.

Commands run in your shell. Questions go to your AI agent. No prefix, no hotkey, no new terminal. You just type.

A color indicator next to your prompt changes as you type — green means shell, magenta means AI. You see what's going to happen before you press Enter.

Detection is pure lexical analysis. No network call, no API key needed. Sub-millisecond.

Works with Claude Code, Gemini CLI, OpenCode, Codex, Lash, or any custom command. Lacy doesn't replace your AI tool — it makes it easier to reach.

Install:
curl -fsSL https://lacy.sh/install | bash

Also: brew install lacymorrow/tap/lacy
Or: npx lacy

ZSH + Bash 4+. macOS, Linux, WSL.
```

## First Comment (Maker Intro)

```
Hey everyone, I'm Lacy — I built this because I got tired of the same loop:

Run something in the terminal. Hit a wall. Alt-tab to Claude or ChatGPT. Paste context. Get an answer. Alt-tab back. Paste. Try again. Repeat 20 times a day.

AI coding tools already live in the terminal — Claude Code, Gemini CLI, OpenCode, Codex. But you still have to context-switch into them. Type `claude`, ask your thing, exit, go back to your shell. Two workflows, one terminal.

Lacy sits on top of whatever AI CLI you already use and makes the boundary disappear. The part I'm most proud of is the detection: it uses lexical analysis (word counts, command validity, article/pronoun markers, known error patterns) instead of AI to classify input. The whole thing runs in under a millisecond.

The trickiest bit was handling shell reserved words. Words like `do`, `then`, and `in` are valid shell syntax — they pass `command -v` — but nobody types "do" and means a do-loop. "Do we have auth?" is obviously a question. I maintain a list of these and route them to the agent.

My favorite feature: if a valid command fails with natural language patterns, Lacy silently reroutes to AI. Type `kill the process on localhost:3000` — `kill` is real, so the shell tries it. It fails. Lacy checks the error output, notices the NL markers, and sends it to your agent without you doing anything.

Currently at v1.8.20, 39 releases, 10K+ monthly npm installs. Daily driver for me and growing organically. Would love to hear what you think.

Source: https://github.com/lacymorrow/lacy
Site: https://lacy.sh
```

## Media (upload in this order)

1. `docs/demo-full.gif` — Hero: full routing demo showing green/magenta indicator
2. `docs/demo-indicator.gif` — Indicator color changing as you type
3. `docs/demo-color-transition.gif` — Real-time color transition close-up
4. Screenshot of README showing install methods and routing table

## Response Templates

### "How is this different from Warp?"

```
Warp is a full terminal replacement. Lacy is a plugin for your existing shell — zsh or bash. You keep your terminal, your dotfiles, your workflow. Lacy just adds a layer that routes natural language to your AI agent. Different approaches to the same problem.
```

### "Why not just type `claude` or `gemini`?"

```
You can! Lacy just removes that step. Instead of switching modes in your head ("now I'm in the shell... now I'm talking to AI..."), you type naturally and it routes. The color indicator shows you what's going to happen before you press enter, so there's no guessing.
```

### "What about false positives?"

```
Three escape hatches: (1) Ctrl+Space locks you into shell-only or agent-only mode, (2) prefix any command with `!` to force shell execution, (3) the indicator shows you what will happen before you press enter. In practice the detection is solid — it handles edge cases like shell reserved words (`do`, `in`, `then`) and post-execution rerouting for commands that fail with NL patterns.
```

### "Does this send my commands to an API?"

```
No. The classification is 100% local — pure lexical analysis, no network call. When you type something that routes to AI, Lacy calls your local AI CLI tool (claude, gemini, opencode, etc.). Those tools handle their own auth. Lacy itself never phones home.
```

### "Bash support?"

```
Bash 4+ is fully supported. The real-time indicator works differently (Bash can't redraw on keystroke like ZSH), but routing, rerouting, and all commands work the same. macOS ships with Bash 3.2 — `brew install bash` gets you there.
```
