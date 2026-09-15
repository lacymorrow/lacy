<p align="center">
  <a href="https://lacy.sh">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/lacymorrow/lacy/HEAD/.github/assets/logo-horizontal-dark.svg">
      <img src="https://raw.githubusercontent.com/lacymorrow/lacy/HEAD/.github/assets/logo-horizontal.svg" alt="Lacy" width="220">
    </picture>
  </a>
</p>

Talk to your shell. Commands run in your shell, and questions go to the AI coding tool you already use.

```
? what files are here      answered by your AI tool
$ ls -la                   runs in your shell
```

## Install

```bash
curl -fsSL https://lacy.sh/install | bash
```

<details>
<summary>Other methods</summary>

```bash
npx lacy
brew install lacymorrow/tap/lacy
```

</details>

The installer fetches the latest release and asks at most one question. With one AI tool installed it asks nothing. It asks which to use if you have several, and offers to install [lash](https://lash.lacy.sh) if you have none. Open a new terminal when it's done.

Lacy runs in zsh, Bash 4+ and fish on macOS, Linux and WSL. It works with lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, or a command you choose.

## How it works

Lacy picks a destination when you press Enter. That step doesn't use AI: it checks word lists and whether the first word is a command.

| Input                            | Goes to | Why                                     |
| -------------------------------- | ------- | --------------------------------------- |
| `ls -la`                         | shell   | `ls` is a command                       |
| `what files are here`            | agent   | starts with a question word             |
| `fix the bug`                    | agent   | several words, and `fix` is not a command |
| `do we have a way to uninstall?` | agent   | `do` is never a command on its own      |
| `!rm -rf node_modules`           | shell   | `!` sends the line to the shell         |
| `@ make sure the tests pass`     | agent   | `@` sends the line to the agent         |

In zsh, a mark after your prompt shows where the line will go as you type: `$` for the shell, `?` for the agent. In Bash and fish the prompt shows the current mode.

Sometimes a real command gets a sentence for arguments, like `make sure the tests pass`. It runs in the shell, and if it fails, Lacy suggests `@ make sure the tests pass` as your next line. zsh shows that as gray text (Right arrow or Tab takes it, Enter sends it). Bash prints it above the prompt. Nothing goes to the agent until you send it.

Questions asked from zsh or Bash carry what changed since your last one: directory, git branch, recent commands, the last exit code, and the visible terminal output in tmux, screen, iTerm2 and Terminal.app.

## Commands

| Command                  | What it does                                        |
| ------------------------ | --------------------------------------------------- |
| `mode shell\|agent\|auto` | Send everything to the shell, to the agent, or decide per line (default) |
| `Ctrl+Space`             | Switch mode                                         |
| `tool set <name>`        | Pick the AI tool and save it to the config          |
| `ask "question"`         | Send a question to the agent                        |
| `/new`, `/resume`        | Start a new conversation, or resume the last one    |
| `quit`                   | Turn Lacy off. The shell keeps running              |
| `exit`                   | Exit the shell, as usual                            |

Fish supports `mode`, `ask`, `quit` and `Ctrl+Space`.

Outside the shell, the `lacy` command handles setup and maintenance: `lacy doctor`, `lacy update`, `lacy setup`, `lacy logs`. Run `lacy help` for the full list.

## Configuration

Settings live in `~/.lacy/config.yaml`:

```yaml
agent_tools:
  active: claude   # leave empty to use the first tool found

modes:
  default: auto    # shell, agent, or auto
```

The full reference, including the query log, spinner style, terminal context, environment variables and `NO_COLOR`, is in [docs/DOCS.md](docs/DOCS.md).

Lacy sends anonymous events on install, update, uninstall and first load (install method, OS, architecture, shell, version). Set `DO_NOT_TRACK=1` to turn them off.

## Uninstall

```bash
lacy uninstall
```

Or `npx lacy --uninstall`, or `curl -fsSL https://lacy.sh/install | bash -s -- --uninstall`.

## Troubleshooting

Start with `lacy doctor`. It checks the install, your shell config and the AI tool, and exits 1 if something is wrong.

- A command went to the agent: start the line with `!`, or run `mode shell`.
- A question went to the shell: start the line with `@`.

## License

[FSL-1.1-MIT](LICENSE). To contribute, see [CONTRIBUTING.md](CONTRIBUTING.md).
