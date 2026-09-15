# Security Policy

## Reporting a vulnerability

Lacy intercepts every command you type and routes it either to the shell or to an AI backend. The security-relevant surfaces are:

- Command classification / routing logic (does a destructive command stay shell-side as intended?)
- Backend command construction (no shell injection when forwarding a query to any supported AI CLI)
- Credential or query leakage in logs (the opt-in query log, tool error output, panic logs)

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
- The standalone CLI (`bin/lacy`) and the npm installer (`packages/lacy`)

Out of scope:
- Vulnerabilities in upstream AI CLIs (`lash`, `claude`, `opencode`, `gemini`, `codex`, and the rest). Report those to their own repos.
- Issues that require an attacker who already has shell access on your machine
