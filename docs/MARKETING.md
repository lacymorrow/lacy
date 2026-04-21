# Lacy Shell — Marketing Launch Kit

All launch copy is ready to submit. Demo GIFs are recorded and hosted.

**GIF URLs (raw GitHub):**
- Full demo: `https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-full.gif`
- Indicator: `https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-indicator.gif`
- Color transition: `https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-color-transition.gif`

---

## 1. Show HN Post

**Best time:** Tuesday or Wednesday, 9-10am ET

**Title:**
```
Show HN: Lacy Shell – Talk to your terminal. Commands run, questions go to AI
```

**Body:**
```
Hi HN,

I built Lacy, a ZSH/Bash plugin that figures out whether you're typing a command or asking a question, then sends it to the right place. Commands run in your shell. Questions go to your AI agent. You don't type a prefix or hit a hotkey. You just type.

There's a color indicator next to your prompt that changes as you type — green means it'll run in the shell, magenta means it's headed to AI. The first word gets syntax-highlighted too. Updates every keystroke.

How it decides:

- `ls -la` → Shell (valid command, green)
- `what files are here` → AI (natural language, magenta)
- `do we have auth?` → AI (shell reserved words like "do", "in", "then" are never standalone commands)
- `kill the process on 3000` → Shell first, then AI (valid command fails with NL patterns, silent reroute)

No AI call to classify your input. It's pure lexical analysis — checks command validity, word counts, article/pronoun markers, and known error patterns. Sub-millisecond.

Works with whatever AI CLI you already have: Claude Code, Gemini CLI, OpenCode, Codex, or Lash (my OpenCode fork). Lacy doesn't replace any of them. It just makes them easier to reach.

Install:

    curl -fsSL https://lacy.sh/install | bash

Or: `brew install lacymorrow/tap/lacy` | `npx lacy`

macOS, Linux, WSL. ZSH and Bash 4+.

Site: https://lacy.sh
Source: https://github.com/lacymorrow/lacy
```

---

## 2. Twitter/X Launch Thread

**Best time:** Same day as HN, 1-2 hours after

**Tweet 1 (Hook):**
```
I made my terminal understand English.

Type a command → it runs in your shell.
Type a question → it goes to your AI agent.

No prefix. No hotkey. Just type.

It's called Lacy Shell. Free and open source.

https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-full.gif
```

**Tweet 2 (Problem):**
```
The problem: every time you need AI help, you leave your terminal.

Copy output. Switch to Claude/ChatGPT. Paste. Wait. Copy answer. Switch back. Paste.

I was doing that 20+ times a day. So I fixed it.
```

**Tweet 3 (How it works):**
```
How it works:

A color indicator next to your prompt updates as you type:

🟢 Green = shell command (runs normally)
🟣 Magenta = natural language (goes to AI)

No AI call to classify. Pure lexical analysis. Sub-millisecond.

If a command fails with NL patterns, it silently reroutes to AI.
```

**Tweet 4 (Tool agnostic):**
```
Lacy works with whatever AI tool you already have.

- Claude Code
- Gemini CLI
- OpenCode
- Codex CLI
- Lash
- Any custom command

It auto-detects what's installed. You don't configure anything.
```

**Tweet 5 (CTA):**
```
One line to install:

curl -fsSL https://lacy.sh/install | bash

Also: brew install lacymorrow/tap/lacy

ZSH + Bash 4+. macOS, Linux, WSL.

github.com/lacymorrow/lacy
lacy.sh
```

**Tags:** @AnthropicAI @GoogleDeepMind

---

## 3. Reddit Posts

### r/commandline

**Title:**
```
I built a ZSH/Bash plugin that figures out if you're typing a command or talking to AI
```

**Body:**
```
I kept doing the same thing over and over: run a command, realize I need AI help, alt-tab to Claude, paste context, get answer, alt-tab back. So I built a plugin that just... does this for me.

Lacy is a shell plugin that watches what you type and routes it. There's a color indicator next to your prompt that updates as you type. Green means the shell will run it, magenta means it's headed to your AI agent. You see what's going to happen before you hit enter.

Examples:
- `git status` → runs in your shell (green)
- `what changed in the last commit` → goes to AI (magenta)
- `do we have a way to deploy?` → AI (reserved words like `do` and `in` never appear as standalone commands)
- `make sure tests pass` → shell tries it first, it fails, then silently reroutes to AI

If something fails and looks like it was natural language, Lacy shows ghost text on the next prompt suggesting you retry through the agent. Right arrow or tab accepts it. Coexists fine with zsh-autosuggestions.

No AI call to classify your input. It checks `command -v`, word patterns, and known error messages. All local, sub-millisecond.

Works with Claude Code, Gemini CLI, OpenCode, Codex, Lash, or a custom command you set. It checks what's installed on first run.

    curl -fsSL https://lacy.sh/install | bash

Also `brew install lacymorrow/tap/lacy` or `npx lacy`.

ZSH and Bash 4+ on macOS, Linux, WSL. MIT licensed. I've been using it daily for a while, currently on v1.8.9.

https://github.com/lacymorrow/lacy
```

### r/zsh

**Title:**
```
ZSH plugin that routes input to shell or AI agent, with real-time indicator and ghost text
```

**Body:**
```
I wrote a ZSH plugin (works in Bash 4+ too) that classifies your input and routes it to either the shell or an AI agent. The ZSH-specific bits ended up being the most interesting part, so figured I'd share here.

What it does:

- Color indicator left of your prompt updates as you type: green for shell commands, magenta for AI queries
- First word gets highlighted via `region_highlight` with `memo=lacy` tags, updates on `zle-line-pre-redraw`
- Mode badge in `RPS1` (SHELL / AGENT / AUTO)
- Ctrl+Space toggles modes via a custom `zle` widget
- Custom accept-line widget for routing
- Ghost text via `POSTDISPLAY`. When a reroute candidate fails, the next empty prompt shows a suggestion to retry through the agent. Right arrow or tab accepts.

Classification is all local, no network calls. Checks `command -v`, word counts, article/pronoun markers, reserved words. Sub-millisecond.

How auto mode works:
1. ~150 conversational words ("explain", "why", "thanks") → always AI
2. Shell reserved words (`do`, `then`, `in`, `fi`) → AI. They pass `command -v` but nobody types `do` as a standalone command.
3. First word is a valid command → shell
4. Single word, not a command → shell (probably a typo, let it error)
5. Multiple words, first word isn't a command → AI
6. Valid command + natural language args, command fails → shell first, reroute to AI on failure

The `zsh-autosuggestions` coexistence was the trickiest part. Lacy uses `memo=lacy` tags on `region_highlight` entries so it only removes its own highlights on redraw. For `POSTDISPLAY`, Lacy calls `_zsh_autosuggest_clear` before writing ghost text, and autosuggestions picks back up once the user starts typing. Right arrow and tab fall back to `zle forward-char` (not `.forward-char`) so autosuggestions' widget wrappers still fire.

Works with Claude Code, Gemini CLI, OpenCode, Codex, or Lash.

`curl -fsSL https://lacy.sh/install | bash`

https://github.com/lacymorrow/lacy
```

---

## 4. Dev.to Article

**Title:**
```
How I Made My Terminal Understand English
```

**Tags:** `#terminal #ai #devtools #opensource`

**Body:**

```markdown
Every time I need AI help while coding, I do the same thing:

1. Copy terminal output
2. Switch to Claude/ChatGPT
3. Paste and ask my question
4. Wait for the response
5. Copy the answer
6. Switch back to terminal
7. Paste and run

That loop happens 20+ times a day. It's death by a thousand context switches.

So I built [Lacy Shell](https://lacy.sh) — a ZSH/Bash plugin that detects whether you're typing a command or natural language and routes accordingly. Commands execute in your shell. Questions go to your AI agent. No prefix, no hotkey, no new terminal.

## The Real-Time Indicator

As you type, a colored indicator shows what will happen when you press enter:

- **Green** → shell command (will execute normally)
- **Magenta** → natural language (will go to AI agent)

The first word also gets syntax-highlighted in real-time. It updates on every keystroke.

## How Detection Works

The interesting part: Lacy doesn't use AI to classify your input. It's pure lexical analysis:

1. **Agent words** — ~150 common conversational words like "explain", "why", "thanks", "perfect" always route to AI
2. **Shell reserved words** — `do`, `then`, `in`, `fi` pass `command -v` but are never standalone commands. "Do we have auth?" is natural language, not a `do` loop.
3. **Command validity** — if the first word is a valid command, it goes to shell
4. **Word count heuristic** — single non-command words go to shell (typos). Multiple words starting with a non-command go to AI.
5. **Post-execution reroute** — if a valid command fails with natural language patterns (3+ bare words, articles/pronouns), it silently reroutes to AI

This makes it sub-millisecond. No network call, no API key needed for classification.

## Tool Agnostic

Lacy doesn't replace your AI tool — it makes it accessible:

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
| `kill the process on 3000` | Shell → AI | Valid command fails with NL patterns |

## Install

One line:

```bash
curl -fsSL https://lacy.sh/install | bash
```

Also: `brew install lacymorrow/tap/lacy` or `npx lacy`

Works on macOS, Linux, WSL. ZSH and Bash 4+. MIT licensed.

[GitHub](https://github.com/lacymorrow/lacy) | [Website](https://lacy.sh)
```

---

## 5. Awesome List Submissions

Submit PRs to these repos (after launch posts get traction):

| List | Repo | Category |
|------|------|----------|
| awesome-zsh-plugins | unixorn/awesome-zsh-plugins | Plugins / AI |
| awesome-cli-apps | agarrharr/awesome-cli-apps | Productivity / AI |
| awesome-shell | alebcay/awesome-shell | AI / Productivity |
| awesome-ai-tools | mahseema/awesome-ai-tools | Developer Tools |
| terminals-are-sexy | k4m4/terminals-are-sexy | Shell Plugins |

**PR description template:**
```
Add Lacy Shell — a ZSH/Bash plugin that auto-routes natural language to AI agents (Claude Code, Gemini, OpenCode, Codex). Real-time color indicator, sub-millisecond lexical detection.
```

---

## 6. One-Liner Descriptions (by context)

**GitHub description (140 chars):**
```
Talk to your shell. Commands run, questions go to AI. Real-time indicator. Works with Claude, Gemini, OpenCode, Codex.
```

**npm description:**
```
Talk to your terminal — AI agent routing for your shell
```

**Tweet-length (280 chars):**
```
Lacy Shell: type commands or natural language in your terminal. Commands run in your shell. Questions go to AI. Real-time color indicator shows the routing before you press enter. Works with Claude Code, Gemini, OpenCode, Codex. One line install: curl -fsSL https://lacy.sh/install | bash
```

**Elevator pitch (30 seconds):**
```
Lacy is a shell plugin that lets you talk to your terminal. Type a command — it runs. Type a question — it goes to your AI agent. A real-time color indicator shows which will happen before you press enter. No prefix, no hotkey, no new terminal. It works with whatever AI CLI you already use. One line to install, MIT licensed.
```

---

## 7. Demo GIF Recording Script

Record with [vhs](https://github.com/charmbracelet/vhs), [asciinema](https://asciinema.org/), or Screen Studio.

### GIF A: "The Indicator" (5 seconds)

```
1. Terminal open, clean prompt
2. Type `ls -la` — green indicator appears
3. Clear line
4. Type `what files are here` — magenta indicator appears
5. Hold for 1 second
```

### GIF B: "Full Demo" (10 seconds)

```
1. Type `ls -la` — green indicator → press enter → output
2. Type `what files are here` — magenta indicator → press enter → AI responds
3. Hold for 2 seconds showing AI output
```

### GIF C: "Color Transition" (5 seconds)

```
1. Type `g` — green (git?)
2. Type `gi` — green
3. Type `git` — green
4. Backspace all
5. Type `w` — neutral
6. Type `wh` — neutral
7. Type `what` — magenta (agent word)
8. Hold 1 second
```

### GIF Specs
- **Size:** 800x500px (optimize < 5MB for GitHub)
- **Terminal:** Dark theme, font 16pt+
- **Colors:** Ensure green (34) and magenta (200) are visible
- **FPS:** 10-15 (keeps file size down)

---

## 8. Launch Day Checklist

### Pre-launch (day before)
- [x] Demo GIF recorded and hosted (3 variants in docs/)
- [x] README updated with GIF at top + badges + "Why Lacy?" section
- [x] Analytics on lacy.sh (Plausible/Umami) — LAC-43 done
- [x] All copy reviewed and links tested
- [x] GitHub topics set (14 topics)
- [x] Demo videos recorded (docs/videos/)

### Launch Day (Tuesday/Wednesday)
- [ ] 9:00am ET — Post Show HN
- [ ] 10:30am ET — Post Twitter thread (after HN settles)
- [ ] Monitor HN comments — respond to every question within 30 min
- [ ] Monitor Twitter replies

### Day 2
- [ ] Post r/commandline
- [ ] Post r/zsh
- [ ] Respond to all HN/Twitter engagement from day 1

### Day 3-4
- [ ] Publish Dev.to article
- [ ] Cross-post to Hashnode
- [ ] Submit first awesome-list PR

### Week 2
- [x] Build SEO comparison pages on lacy.sh (5 pages: vs Warp, ShellGPT, GitHub Copilot CLI, AI Shell, Amazon Q)
- [ ] Submit remaining awesome-list PRs
- [ ] Begin Product Hunt prep

### Ongoing
- See `docs/GROWTH-STRATEGY.md` for the full sustained growth plan
