# Show HN Response Templates

Prepared responses for common HN questions. Adapt to match the specific comment. Keep responses concise, technical, and honest.

---

## 1. "How does detection work without AI?"

It's pure lexical analysis against your local PATH. The core function (`lacy_shell_classify_input`) does this:

1. Checks if the first word is a shell reserved word (`do`, `then`, `in`, `fi`, etc.) -- these pass `command -v` but nobody types `do` as a standalone command. Routes to AI.
2. Checks against ~150 common English words (`what`, `why`, `explain`, `thanks`) -- routes to AI.
3. Runs `command -v` on the first word. If it resolves, routes to shell.
4. Single word, no command match -- shell (probably a typo, let it error naturally).
5. Multiple words, first word not a command -- AI.

There's a one-entry cache on `command -v` so repeated checks on the same word during typing are free. The entire classification is a few string comparisons and one PATH lookup. No network, no model, no parsing beyond word splitting.

---

## 2. "What about false positives?"

Three escape hatches:

- `!` prefix forces shell. `!rm -rf /tmp` always runs in the shell, no questions asked.
- `@` prefix forces AI.
- Ctrl+Space toggles between shell/agent/auto modes.

The color indicator shows you where it's going before you hit enter, so you catch misroutes before anything executes. In practice the heuristic gets it right the vast majority of the time, but the visual feedback is the real safety net. You just look left.

For the "valid command + NL args" case (like `kill the process on port 3000`), the command runs first. It only reroutes to AI if the command fails with a recognized error pattern AND the args contain NL markers like articles and pronouns. So a working command is never intercepted.

---

## 3. "Why not just use a prefix like `?` or `!`?"

Yeah, you can. Lacy has `@` for exactly that. I just got tired of it. I was reaching for the AI 20+ times a day and the prefix started to feel like busywork. The indicator already shows you where it's going, so the prefix is redundant information.

The other thing you lose with a prefix: post-execution reroute. When you type `make sure the tests pass` and `make` fails because there's no Makefile target called "sure", Lacy catches the NL pattern and reroutes to AI. With a prefix you'd have to know ahead of time that the command was going to fail.

---

## 4. "Privacy/security -- what data is sent where?"

Lacy itself sends nothing anywhere. Classification is local string comparisons. When something routes to AI, it shells out to whatever CLI tool you have configured (Claude Code, Gemini CLI, etc.) as a subprocess. Those tools handle their own auth and network stuff. Lacy never sees API keys or responses.

The install script (`curl | bash`) pulls from GitHub and copies files to `~/.lacy`. You can also `brew install` or `npx` if you want to audit the package first.

---

## 5. "Does it work with fish/nushell/PowerShell?"

ZSH and Bash 4+ only right now. Fish and nushell could work in theory but they'd need their own adapters. The real-time indicator relies on ZLE hooks (ZSH) and readline bindings (Bash), and those don't have equivalents in other shells. Would happily merge a PR if someone wants to take a crack at it.

Bash 4+ specifically because of associative arrays and `read -ra`. macOS still ships Bash 3.2, so you'd need `brew install bash`.

---

## 6. "How is this different from Warp/ShellGPT/GitHub Copilot CLI?"

Warp is a whole terminal. Lacy is a plugin for your existing shell. No new app, no account, no cloud dependency for the routing part.

ShellGPT and Copilot CLI require you to explicitly call them (`sgpt "query"` or `gh copilot suggest`). Lacy skips that step. You just type and it figures it out.

The classification works differently too. ShellGPT/Copilot send your input to the LLM to figure out what you meant. Lacy does it locally with string matching, so it's sub-millisecond and doesn't burn an API call just to decide where your input goes.

---

## 7. "Sub-millisecond -- how?"

The hot path is: trim whitespace, check first character for `!`/`@`, do one array lookup in ~15 reserved words, one array lookup in ~150 agent words, one `command -v` (cached). All string ops, no forks, no subshells. In ZSH it runs on `zle-line-pre-redraw` which fires on every keystroke, so it has to be fast.

The `command -v` result is cached with a single-entry cache (last word checked). Since the indicator updates as you type and you're usually editing the end of the line, the first word stays cached.

---

## 8. "Why not just use Claude Code directly?"

You should! Lacy doesn't replace Claude Code. It's just a faster way to get to it. Instead of stopping to think "ok now I need to switch to Claude," you just type what you're thinking and it ends up in the right place.

I kept catching myself doing the mental context switch dozens of times a day. This removes it.

---

## 9. "The `curl | bash` install concern"

Yeah, fair. Three alternatives:

- `brew install lacymorrow/tap/lacy`
- `npx lacy`
- Clone the repo and read `install.sh` before running it

The script is ~300 lines, nothing obfuscated. It copies shell files to `~/.lacy` and adds a source line to your rc file. Happy to walk through it.

---

## 10. "How does the reroute work when a command fails?"

When you type something like `go ahead and fix the tests`, Lacy sees `go` is a valid command and lets the shell run it. `go` fails with something like `go ahead: unknown command`. Before showing the error, Lacy checks two things:

1. The error output matches a known shell error pattern (like "unknown command", "not found", "No rule to make target")
2. The arguments contain NL markers (articles, pronouns, prepositions -- like "ahead", "and", "the")

Both must match. If they do, the original input silently reroutes to the AI agent. If either check fails, you just see the normal shell error.

This only activates in auto mode, and only for non-signal exit codes (< 128). A segfault or interrupt is never rerouted.

---

## 11. "What AI tools does it support?"

Anything that takes a text prompt: Claude Code, Gemini CLI, OpenCode, Codex CLI, Lash (my OpenCode fork). Or set a custom command if yours isn't in the list. On first run it checks what's installed and asks you to pick.

The AI tool handles its own auth and conversation state. Lacy just hands it the query string.

---

## 12. "What happens with commands like `test` or `time` that are both real commands and English words?"

`test` and `time` are in `command -v` but NOT in the agent-words list, so they route to shell by default. If you type `test the login flow`, `test` runs and fails, then the post-execution reroute catches it because "the" and "login" are NL markers.

Agent words like `yes`, `nice`, `cancel` are real commands too, but they're almost never typed standalone in a terminal. When they ARE used as commands (like `yes | apt install`), the shell operator `|` triggers shell routing.
