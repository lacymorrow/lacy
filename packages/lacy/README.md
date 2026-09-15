# lacy

Installer for [Lacy Shell](https://github.com/lacymorrow/lacy). Talk directly to your shell.

## Install

```bash
npx lacy
```

- Uses your AI CLI tool without asking when exactly one is installed
- Asks which one to use only when several are installed
- Offers to install lash when none is found
- Installs the latest release, and asks nothing when there is no terminal (CI, Docker)

Run `npx lacy` again after installing to change the tool or mode, update, or uninstall.

## Uninstall

```bash
npx lacy --uninstall
```

## Options

```
Usage:
  npx lacy              Install, or open settings when installed
  npx lacy setup        Open settings
  npx lacy info         Show a short introduction
  npx lacy --uninstall  Remove Lacy Shell

Options:
  -h, --help       Show this help
  -u, --uninstall  Remove Lacy Shell
```

## What is Lacy Shell?

Lacy sends commands to your shell and questions to your AI tool.

```
❯ ls -la                → runs in shell
❯ what files are here   → AI answers
❯ git status            → runs in shell
❯ fix the build error   → AI answers
```

Works with: **lash**, **claude**, **opencode**, **gemini**, **codex**, **hermes**, **copilot**, **goose**, **amp**, **aider**

## Other install methods

```bash
# curl
curl -fsSL https://lacy.sh/install | bash

# Homebrew
brew tap lacymorrow/tap
brew install lacy
```

## License

FSL-1.1-MIT
