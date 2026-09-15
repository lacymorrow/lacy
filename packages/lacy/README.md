# lacy

Installer for [Lacy Shell](https://github.com/lacymorrow/lacy). Talk to your shell.

## Install

```bash
npx lacy
```

- Installs the latest Lacy Shell release into `~/.lacy` and adds it to your zsh, Bash or fish config
- Uses your AI CLI tool without asking when exactly one is installed
- Asks which one to use when several are installed
- Offers to install lash when none is found
- Asks nothing when there is no terminal (CI, Docker)

Run `npx lacy` again after installing to change the tool or mode, edit the config, update, reinstall, or uninstall. Without a terminal it updates to the latest release instead.

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

The installer sends an anonymous event on install and on uninstall (OS, architecture, shell, version). Set `DO_NOT_TRACK=1` to turn it off.

## What is Lacy Shell?

Lacy sends commands to your shell and questions to your AI tool.

```
$ ls -la                  runs in shell
? what files are here     AI answers
$ git status              runs in shell
? fix the build error     AI answers
```

Works with lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, or a custom command.

## Other install methods

```bash
# curl
curl -fsSL https://lacy.sh/install | bash

# Homebrew
brew install lacymorrow/tap/lacy
```

## License

[FSL-1.1-MIT](https://github.com/lacymorrow/lacy/blob/main/LICENSE)
