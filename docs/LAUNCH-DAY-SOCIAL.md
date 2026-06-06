# Launch Day Social — Product Hunt (June 17, 2026)

All copy is ready. Times are ET.

---

## Twitter/X — 6:00am PT (9:00am ET)

### Tweet 1 (announce + link)

```
Lacy Shell is live on Product Hunt today.

It's a ZSH/Bash plugin that routes your input — commands go to your shell, questions go to your AI agent. No prefix. No hotkey. You just type.

Upvote if you find it useful: [PH link]
```

### Tweet 2 (hook)

```
I've been doing this 20 times a day:

Copy terminal output → switch to Claude → paste → get answer → switch back → paste → run

So I made it stop.

[PH link]
```

### Tweet 3 (mid-day engagement — post when you hit 100 upvotes)

```
100 upvotes on Product Hunt 🙏

The thing people keep asking: "how does it know if I'm typing a command or asking a question?"

Short answer: it checks whether the first word is a real command, then counts words and looks for articles/pronouns. No AI involved. Takes <1ms.

[PH link]
```

### Tweet 4 (evening — post if in top 5)

```
Lacy Shell hit top 5 on Product Hunt today. Thank you.

If you've been doing the alt-tab dance between your terminal and Claude, give it a try.

One line: curl -fsSL https://lacy.sh/install | bash

Still free, still open source.
```

---

## Reddit cross-post on launch day (r/commandline)

**Title:** Lacy Shell is on Product Hunt today — ZSH/Bash plugin that routes input to shell or AI

**Body:**
```
Built this over the past few months and it's on Product Hunt today if you want to check it out.

Short version: Lacy is a shell plugin that watches what you type. Commands run in your shell, natural language goes to your AI agent. A color indicator shows you what will happen before you press enter.

No AI call to classify your input — it uses lexical analysis (command validity, word counts, article/pronoun markers). Sub-millisecond.

Works with whatever AI CLI you already have: Claude Code, Gemini CLI, OpenCode, Codex, Lash.

Product Hunt: [PH link]
GitHub: https://github.com/lacymorrow/lacy
Install: curl -fsSL https://lacy.sh/install | bash
```

---

## GitHub Discussion post (on launch day)

**Title:** Lacy Shell is on Product Hunt today — come say hi if you've been using it

**Body:**
```
Hey, if you've been using Lacy Shell — would love a Product Hunt upvote today if you find it useful.

[PH link]

Also happy to answer any questions here or on the PH page. If you've run into any friction during install or daily use, this is a good time to surface it.

Thanks for trying it out.
```

---

## GitHub star request email (send to GitHub watchers)

```
Subject: Lacy Shell is on Product Hunt today

Hi,

Lacy Shell is on Product Hunt today. If you've been using it and find it useful, an upvote would mean a lot.

[PH link]

Thanks,
Lacy
```

---

## Newsletter submission copy

### Changelog (changelog.com/news)

**Submission:**
```
Lacy Shell — ZSH/Bash plugin for transparent AI routing

Lacy detects whether you're typing a command or natural language, then sends it to the right place. Commands run in your shell. Questions go to your AI agent. No prefix, no hotkey — you just type.

Detection is pure lexical analysis (no AI, no network call, sub-millisecond). Works with Claude Code, Gemini CLI, OpenCode, Codex, or any custom command.

v1.8.20, MIT licensed, 10K monthly npm installs.

GitHub: https://github.com/lacymorrow/lacy
Site: https://lacy.sh
Install: curl -fsSL https://lacy.sh/install | bash
```

### Console.dev (console.substack.com/submit)

**Submission:**
```
Name: Lacy Shell
URL: https://lacy.sh
Type: Open source CLI tool / shell plugin
Description: ZSH and Bash 4+ plugin that routes input — commands to the shell, natural language to your AI agent (Claude Code, Gemini CLI, OpenCode, etc.). Real-time color indicator. Detection uses lexical analysis, not AI. No config required.
```

### TLDR Newsletter

```
Lacy Shell is a ZSH/Bash plugin that automatically routes input — shell commands execute normally, natural language goes to your AI agent. It uses lexical analysis (not AI) to classify input in under a millisecond. Works with Claude Code, Gemini CLI, OpenCode, and others. v1.8.20, 10K monthly npm installs.

https://github.com/lacymorrow/lacy
```
