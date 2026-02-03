# Mission

**Enable developers to talk directly to their shell.**

## What This Is

A ZSH plugin that detects natural language and routes it to an AI coding agent. Commands execute normally. Questions go to the AI. No mode switching. No friction.

## What This Is Not

- Not a native terminal app (works in your existing terminal)
- Not a voice assistant (text-based)
- Not a cloud service (runs locally, calls lash)

## How It Works

```
You type: ls -la
→ Green indicator (shell command)
→ Executes in shell

You type: fix the authentication bug
→ Magenta indicator (natural language)
→ Routes to lash/AI agent
→ AI responds in terminal
```

## Design Principles

1. **Shell-native** — Works in your existing ZSH terminal
2. **Zero friction** — Auto-detects intent, no special syntax needed
3. **Visual feedback** — Real-time indicator shows where input will go
4. **Typo-friendly** — Single-word typos go to shell (not AI)
5. **Provider-agnostic** — Works with lash, opencode, or direct API calls
6. **Open source** — No vendor lock-in

## The Stack

```
┌─────────────────────────────────┐
│  Your Terminal (ZSH)            │
│  ┌───────────────────────────┐  │
│  │  lacy-shell               │  │
│  │  Real-time detection      │  │
│  │  Green = shell            │  │
│  │  Magenta = agent          │  │
│  └─────────────┬─────────────┘  │
│                │                │
│  ┌─────────────▼─────────────┐  │
│  │  lash run -c "query"      │  │
│  │  AI coding agent          │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## The Goal

Open terminal. Type naturally. Ship code.
