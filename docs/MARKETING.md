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

I built Lacy, a ZSH/Bash plugin that detects whether you're typing a command or natural language and routes accordingly. Commands execute in your shell. Questions go to your AI agent. No prefix, no hotkey, no new terminal.

A real-time color indicator shows the routing before you press enter — green means shell, magenta means AI. The first word gets syntax-highlighted too. It updates on every keystroke.

How it decides:

- `ls -la` → Shell (valid command, green)
- `what files are here` → AI (natural language, magenta)
- `do we have auth?` → AI (shell reserved words like "do", "in", "then" are never standalone commands)
- `kill the process on 3000` → Shell first, then AI (valid command fails with NL patterns → silent reroute)

The detection is purely lexical — no AI call to classify input. It checks command validity, word counts, article/pronoun markers, and known error patterns. Sub-millisecond.

It works with whatever AI CLI you already use: Claude Code, Gemini CLI, OpenCode, Codex, or Lash (my OpenCode fork). Lacy doesn't replace any of them — it's a routing layer that makes them all accessible without context switching.

Install:

    curl -fsSL https://lacy.sh/install | bash

Or: `brew install lacymorrow/tap/lacy` | `npx lacy`

Works on macOS, Linux, WSL. ZSH and Bash 4+.

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

No prefix. No hotkey. No new app. Just type.

It's called Lacy Shell and it's free + open source.

https://raw.githubusercontent.com/lacymorrow/lacy/main/docs/demo-full.gif
```

**Tweet 2 (Problem):**
```
The problem: every time you need AI help, you leave your terminal.

Copy output. Switch to Claude/ChatGPT. Paste. Wait. Copy answer. Switch back. Paste.

That loop breaks your flow 20+ times a day. Lacy kills it.
```

**Tweet 3 (How it works):**
```
How it works:

A real-time color indicator updates as you type:

🟢 Green = shell command (runs normally)
🟣 Magenta = natural language (goes to AI)

No AI call to classify — it's pure lexical analysis. Sub-millisecond.

If a command fails with NL patterns, it silently reroutes to AI.
```

**Tweet 4 (Tool agnostic):**
```
Lacy doesn't replace your AI tool — it makes it better.

Works with:
- Claude Code
- Gemini CLI
- OpenCode
- Codex CLI
- Lash
- Any custom command

It auto-detects what you have installed. Zero config.
```

**Tweet 5 (CTA):**
```
One line to install:

curl -fsSL https://lacy.sh/install | bash

Also: brew install lacymorrow/tap/lacy

ZSH + Bash 4+. macOS, Linux, WSL.

Star it: github.com/lacymorrow/lacy
Site: lacy.sh
```

**Tags:** @AnthropicAI @GoogleDeepMind

---

## 3. Reddit Posts

### r/commandline

**Title:**
```
I built a ZSH/Bash plugin that auto-routes natural language to AI agents
```

**Body:**
```
I got tired of context-switching between my terminal and AI chat, so I built Lacy — a shell plugin that detects whether you're typing a command or natural language and routes accordingly.

**How it works:**
- `git status` → runs in your shell (green indicator)
- `what changed in the last commit` → goes to AI agent (magenta indicator)
- `do we have a way to deploy?` → AI (shell reserved words are never standalone commands)
- `make sure tests pass` → shell first → fails → silently reroutes to AI

The detection is lexical, not AI-powered. It checks command validity, word patterns, and known error signatures. Real-time indicator updates on every keystroke so you know what will happen before you press enter.

Works with Claude Code, Gemini CLI, OpenCode, Codex, Lash, or any custom command. Lacy auto-detects whatever you have installed.

**Install:**

    curl -fsSL https://lacy.sh/install | bash

Also available via Homebrew (`brew install lacymorrow/tap/lacy`) and npx.

ZSH and Bash 4+ on macOS, Linux, WSL. MIT licensed.

GitHub: https://github.com/lacymorrow/lacy
Site: https://lacy.sh
```

### r/zsh

**Title:**
```
New ZSH plugin: transparent AI routing with real-time indicator and first-word syntax highlighting
```

**Body:**
```
Built a ZSH plugin (also supports Bash 4+) that adds transparent AI agent routing to your shell.

**ZSH-specific features:**

- **Real-time indicator** (left of prompt) changes color as you type: green for shell commands, magenta for AI queries
- **First-word syntax highlighting** via `region_highlight` — updates on every `zle-line-pre-redraw`
- **Right prompt mode badge** (`RPS1`) — shows SHELL/AGENT/AUTO with matching colors
- **Ctrl+Space** toggles between modes via `zle` widget
- **Smart accept-line** via custom `zle` widget — routes based on `lacy_shell_classify_input()`

The classification is purely lexical — no network call. Checks `command -v`, word counts, article markers, shell reserved words. Sub-millisecond.

**Auto mode routing rules:**
1. Agent words (~150 conversational words) → AI
2. Shell reserved words (`do`, `then`, `in`, `fi`) → AI (pass `command -v` but never standalone)
3. Valid first word → Shell
4. Single non-command word → Shell (let it error)
5. Multiple words, first not a command → AI
6. Valid command + NL args that fails → Shell, then reroute to AI

Works with Claude Code, Gemini CLI, OpenCode, Codex, or Lash.

Install: `curl -fsSL https://lacy.sh/install | bash`

Source: https://github.com/lacymorrow/lacy
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
- [ ] Build SEO comparison pages on lacy.sh
- [ ] Submit remaining awesome-list PRs
- [ ] Begin Product Hunt prep
