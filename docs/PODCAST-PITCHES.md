# Podcast Pitches — Lacy Shell

Ready-to-send pitches for dev podcasts. Personalize the subject line with latest stats before sending.

---

## Changelog (changelog.com)

**Submission:** https://changelog.com/guest (guest form)

**Subject:** Pitch: Transparent AI shell routing — no hotkeys, no prefix, just type

**Body:**
```
Hey Changelog team,

I'm Lacy Morrow, and I built Lacy Shell — a ZSH/Bash plugin that automatically routes input between your shell and AI agent. Commands run normally. Natural language goes to AI. No prefix, no hotkey, no new terminal.

The part that might be interesting for your audience: the detection is pure lexical analysis. No API call, no model. It checks command validity, counts words, looks for articles/pronouns, and handles shell reserved words (do, in, then — which pass `command -v` but are never real commands). Sub-millisecond.

Current traction: 10K+ monthly npm installs, 17 GitHub stars, v1.8.20. Works with Claude Code, Gemini CLI, OpenCode, Codex, and any custom command.

I think this fits well alongside episodes about developer tooling and the "AI in the terminal" trend. The story arc I'd pitch:

1. The context-switching problem (20x/day alt-tab loop)
2. Why existing solutions (Warp, shell-gpt, inline prefixes) feel like patches
3. How transparent routing changes the mental model
4. The technical challenge of lexical NL detection in a shell context
5. What "making AI invisible" actually means for developer workflow

Site: https://lacy.sh
Source: https://github.com/lacymorrow/lacy
Dev.to: https://dev.to/lacymorrow/how-i-made-my-terminal-understand-english

Happy to send a demo recording if useful.

— Lacy
```

---

## DevTools FM (devtools.fm)

**Submission:** Email or Twitter DM @devtoolsfm

**Subject:** Guest pitch: Lacy Shell — AI shell routing for ZSH/Bash

**Body:**
```
Hi DevTools FM,

Long-time listener. I built Lacy Shell (lacy.sh) — a ZSH/Bash plugin that routes natural language to your AI agent and commands to your shell automatically. It's the "invisible layer" between your terminal and whatever AI CLI you already use.

Quick numbers: 10K+ monthly npm installs, 39 releases, works with Claude Code, Gemini, OpenCode, Codex.

What I think would make a good episode:

- The UX decision to use a visual indicator (color bar) instead of output — why showing intent before execution is the key insight
- How you do NL detection without AI (the reserved-word list, lexical heuristics, post-execution reroute)
- ZSH internals: `region_highlight`, `POSTDISPLAY`, `zle-line-pre-redraw`, and why plugins fight over these
- The Bash adapter story — why Bash can't do real-time indicators and how we worked around it with macros
- "AI in the terminal" ecosystem map: where Lacy fits alongside Warp, shell-gpt, Claude Code

GitHub: https://github.com/lacymorrow/lacy
Site: https://lacy.sh

— Lacy Morrow
```

---

## Terminal Trove (terminaltrove.com)

**Submission:** https://terminaltrove.com/submit

**Tool entry:**
```
Name: Lacy Shell
Description: ZSH/Bash plugin that routes natural language to your AI agent and commands to your shell. No prefix, no hotkey — pure lexical analysis, sub-millisecond detection.
URL: https://lacy.sh
GitHub: https://github.com/lacymorrow/lacy
Category: AI / Shell plugins
Tags: zsh, bash, ai, shell-plugin, natural-language, claude, gemini
```

---

## Console.dev

**Submission email:** hello@console.dev (or their submission form)

**Subject:** Tool submission: Lacy Shell — AI shell plugin for ZSH/Bash

**Body:**
```
Hi Console team,

I'd like to submit Lacy Shell for consideration in Console.

What it does: Lacy is a ZSH/Bash plugin that automatically routes terminal input — commands run in your shell, natural language goes to your AI agent. Real-time color indicator shows the routing decision as you type.

Key differentiator: detection is 100% local lexical analysis (no API call, <1ms). Works with Claude Code, Gemini CLI, OpenCode, Codex, or any custom command.

- GitHub: https://github.com/lacymorrow/lacy (17 stars, v1.8.20, 39 releases)
- npm: 10K+ monthly installs
- License: MIT
- Platforms: macOS, Linux, WSL (ZSH + Bash 4+)
- Install: curl -fsSL https://lacy.sh/install | bash

Thanks for running Console — it's a great resource.

— Lacy Morrow
```

---

## TLDR Newsletter

**Submission:** https://tldr.tech/suggest (suggest a story)

**Story pitch:**
```
Title: Lacy Shell — ZSH/Bash plugin that auto-routes between shell and AI with no prefix needed

URL: https://lacy.sh

Summary: A shell plugin that detects whether terminal input is a command or natural language using sub-millisecond lexical analysis, then routes it accordingly — commands run in shell, questions go to whatever AI CLI you use (Claude Code, Gemini, OpenCode). Visual indicator shows routing decision before Enter.
```

**TLDR DevTools** is the best fit — submit via their newsletter-specific suggest form.
