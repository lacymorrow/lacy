# Mission

**Enable developers to talk directly to their shell.**

## What This Is

A shell plugin that detects natural language and routes it to an AI coding agent. Commands execute normally. Questions go to the AI. No context switching. No friction.

## What This Is Not

- Not a native terminal app (works in your existing terminal)
- Not a voice assistant (text-based)
- Not a cloud service (runs locally, calls lash)

## How It Works

```
You type: ls -la
→ "ls" highlighted green (valid command)
→ Executes in shell

You type: fix the authentication bug
→ "fix" highlighted magenta (not a command)
→ Routes to lash/AI agent
→ AI responds in terminal

You type: kill the process on localhost:3000
→ "kill" highlighted green (valid command)
→ Shell tries it, fails
→ Detects natural language ("the", 4 bare words)
→ Automatically reroutes to AI agent
```

## Design Principles

1. **Shell-native** — Works in your existing terminal
2. **Zero friction** — Auto-detects intent, no special syntax needed
3. **Visual feedback** — Real-time indicator and first-word highlighting show where input will go
4. **Typo-friendly** — Single-word typos go to shell (not AI); ambiguous multi-word commands (2 bare words) also stay in shell
5. **Smart fallback** — Commands with clear natural language that fail in shell are automatically rerouted to the AI agent
6. **Provider-agnostic** — Works with lash, opencode, or direct API calls
7. **Open source** — No vendor lock-in

## The Stack

```
┌─────────────────────────────────┐
│  Your Terminal                   │
│  ┌───────────────────────────┐  │
│  │  lacy                      │  │
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
