# Security Policy

## Reporting a vulnerability

Lacy intercepts every command you type and routes it either to the shell or to an AI backend. The security-relevant surfaces are:

- Command classification / routing logic (does a destructive command stay shell-side as intended?)
- Backend command construction (no shell injection when forwarding to `claude`, `gemini`, `opencode`, `codex`, `lash`)
- Credential leakage in fallback paths or panic logs

If you've found a security issue, please report it privately:

➔ https://github.com/lacymorrow/lacy/security/advisories/new

Or email **lacy@lacymorrow.com** with `[lacy security]` in the subject line.

Expect an acknowledgement within 72 hours.

## Supported versions

Only the latest published version on npm / Homebrew / install.sh receives security updates.

## Scope

In scope:
- The `lacy` zsh/bash/fish plugins
- `install.sh` / `uninstall.sh`
- The Node CLI shim (`lib/`)

Out of scope:
- Vulnerabilities in upstream AI CLIs (`claude`, `gemini`, `opencode`, `codex`, `lash`) — report to those repos
- Issues that require an attacker who already has shell access on your machine
