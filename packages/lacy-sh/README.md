# lacy-sh

Interactive installer for [Lacy Shell](https://github.com/lacymorrow/lacy-shell) — talk directly to your shell.

## Install

```bash
npx lacy-sh
```

Features:
- Arrow-key tool selection
- Auto-detects installed AI CLI tools
- Offers to install lash if selected
- Automatic shell restart

## Uninstall

```bash
npx lacy-sh --uninstall
```

## Options

```
Usage:
  npx lacy-sh              Install Lacy Shell
  npx lacy-sh --uninstall  Uninstall Lacy Shell

Options:
  -h, --help       Show help message
  -u, --uninstall  Uninstall Lacy Shell
```

## What is Lacy Shell?

Lacy Shell is a ZSH plugin that routes natural language to AI and commands to your shell — automatically.

```
❯ ls -la                → runs in shell
❯ what files are here   → AI answers
❯ git status            → runs in shell
❯ fix the build error   → AI answers
```

Works with: **lash**, **claude**, **opencode**, **gemini**, **codex**

## Alternative Install Methods

```bash
# curl
curl -fsSL https://lacy.sh/install | bash

# Homebrew
brew tap lacymorrow/tap
brew install lacy
```

## License

MIT
