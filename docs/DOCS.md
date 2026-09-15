# Lacy Shell reference

Details that do not fit in the [README](../README.md): shells, keys, routing, configuration, logging, telemetry, and the `lacy` command.

## Supported shells

| Shell | Version                        | Live indicator      | First-word color | Mode badge         | Reroute suggestion | Terminal context |
| ----- | ------------------------------ | ------------------- | ---------------- | ------------------ | ------------------ | ---------------- |
| zsh   | any (colors need 5.9+)         | yes, as you type    | 5.9+             | right prompt       | ghost text         | yes              |
| Bash  | 4+                             | no                  | no               | start of the prompt | hint line         | yes              |
| fish  | 3.1+ (fish 4 tested)           | no                  | no               | right prompt       | no                 | no               |

macOS ships Bash 3.2. Install a newer one with `brew install bash`; Lacy prints upgrade steps if it is loaded in Bash 3.

Fish support covers routing, `mode`, `ask`, `quit` and Ctrl+Space. The `tool` command, `/new`, `/resume`, terminal context and the background server are zsh and Bash only. Fish 3 code paths exist but are not tested.

## What you see

**zsh.** Lacy never changes your `PS1`. After the prompt it draws a mark that updates as you type:

| Mark | Meaning                          |
| ---- | -------------------------------- |
| `$`  | the line will run in the shell (green) |
| `?`  | the line will go to the agent (magenta) |
| `▌`  | nothing decided yet (gray). `\|` when the locale is not UTF-8 |

On zsh 5.9 and newer the first word is colored the same way. The mode (`SHELL`, `AGENT`, `AUTO`) is added to the end of your right prompt and removed when you `quit`. Lacy works alongside zsh-syntax-highlighting, zsh-autosuggestions, powerlevel10k and starship.

The first time Lacy loads, the empty prompt shows `what files are here` as gray text. Press Enter to ask it, or start typing. It is shown once.

**Bash.** The prompt starts with the mode: `SHELL $`, `AGENT ?` or `AUTO ▌`. Lacy's `PROMPT_COMMAND` hook runs last, so it sits on top of prompts built by starship or `__git_ps1`. Continuation lines (an open quote, a `for` loop body, a heredoc) are never classified. Vi mode works.

**fish.** The right prompt ends with `$ SHELL`, `? AGENT` or `▌ AUTO`. A question runs as an ` ask '<question>'` command, so Ctrl+C and `$status` behave normally, and on fish 4 history keeps the text you typed.

## Modes

| Mode  | Behavior                                  |
| ----- | ----------------------------------------- |
| auto  | decide per line (default)                 |
| shell | every line runs in the shell              |
| agent | every line goes to the agent              |

Switch with `mode shell`, `mode agent`, `mode auto`, `mode toggle`, or Ctrl+Space. `mode` alone shows the current mode and what `$` and `?` mean.

At startup Lacy uses the mode saved in `~/.lacy/current_mode`. If that file is missing, it uses `modes.default` from the config, then auto. Every mode change writes the file, and all three shells share it.

## Keys and exiting

| Key or command | Action                                              |
| -------------- | --------------------------------------------------- |
| Ctrl+Space     | Switch mode                                         |
| Right arrow, Tab | Accept Lacy's gray suggestion (zsh). Otherwise the key does what it did before Lacy loaded |
| Ctrl+C         | Shell default. Stops a running question             |
| Ctrl+D         | Shell default                                       |
| `exit`         | Exits the shell, in every mode                      |
| `quit`         | Turns Lacy off. The shell keeps running. Type `lacy` to turn it back on |

Lacy saves the bindings it replaces (Enter, Ctrl+J and Ctrl+Space in Bash; Ctrl+Space, Right arrow and Tab in zsh) and restores them on `quit`.

## Routing

In auto mode:

1. `!` at the start sends the line to the shell, and `@` sends it to the agent. Both work in every mode.
2. Paths, redirects, subshells, `[[ ]]` tests, comments and `VAR=value command` lines go to the shell.
3. A first word such as `do`, `then`, `in` or `fi` goes to the agent. These are shell keywords that never start a command on their own.
4. A first word from a list of about 200 conversational words (`what`, `why`, `thanks`, `explain`, ...) goes to the agent. If that word is also a command and the rest looks like shell arguments (`which python`), the line goes to the shell. A single word you defined as an alias or function goes to the shell.
5. A first word that is a command goes to the shell.
6. One word that is not a command goes to the shell, so typos get the normal error. Several words go to the agent.

The full algorithm is in [NATURAL_LANGUAGE_DETECTION.md](NATURAL_LANGUAGE_DETECTION.md).

### Reroute suggestion

A command can get sentence-like arguments: `make sure the tests pass`, `kill the process on localhost:3000`. In auto mode Lacy runs it in the shell. If it exits with a code from 1 to 127 and its arguments contain a common English word (`the`, `my`, `sure`, `ahead`, ...), Lacy suggests the same line with `@` in front:

- zsh: `@ make sure the tests pass` appears as gray text on the next empty prompt. Right arrow or Tab puts it on the line, and Enter sends it. Typing something else, or pressing Enter on the empty line, dismisses it.
- Bash: `? @ make sure the tests pass` is printed above the next prompt.

Nothing is sent automatically. Commands stopped by a signal (Ctrl+C) and lines typed in shell mode never get a suggestion. Fish does not suggest.

## Terminal context

Questions asked from zsh or Bash start with whatever changed since your last question:

| Context                                  | Included when                                                      |
| ---------------------------------------- | ------------------------------------------------------------------ |
| `[cwd: /path]`                           | the directory changed                                              |
| `[git: branch]`                          | the git branch changed                                             |
| `[exit: N]`                              | the last command failed and a command ran since the last question  |
| `[recent: cmd1 \| cmd2]`                 | commands ran since the last question (up to 10, each cut at 80 characters) |
| `[terminal-output]...[/terminal-output]` | the terminal is tmux, screen, iTerm2 or Terminal.app (colors stripped, 50 lines by default) |

Recent commands come from Lacy's own list, not shell history, so earlier questions are not included. `/new` clears the context so the next question sends all of it.

## Configuration

`~/.lacy/config.yaml` is created on first load:

```yaml
# Lacy Shell configuration
agent_tools:
  # lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, custom
  # Leave empty to auto-detect.
  active:
  # custom_command: "your-command --flags"

modes:
  default: auto  # shell, agent, or auto

# preheat:
#   eager: false
#   server_port: 4096

# logging:
#   queries: false  # true writes ~/.lacy/logs/queries.log (owner-only)
```

| Setting                      | Default   | Meaning                                                    |
| ---------------------------- | --------- | ---------------------------------------------------------- |
| `agent_tools.active`         | empty     | Tool to use. Empty means the first installed one, in the order listed above |
| `agent_tools.custom_command` | empty     | Command for `active: custom`. The question is added as the last argument |
| `modes.default`              | `auto`    | Startup mode when `~/.lacy/current_mode` does not exist    |
| `preheat.eager`              | `false`   | Start the lash or opencode background server when the shell loads |
| `preheat.server_port`        | `4096`    | Port for that server                                       |
| `context.output`             | `true`    | Include visible terminal output with questions             |
| `context.output_lines`       | `50`      | Maximum lines of terminal output                           |
| `spinner.style`              | `braille` | `ascii` for terminals without Unicode                      |
| `logging.queries`            | `false`   | Keep a log of your questions (see below)                   |

`tool set <name>` in zsh or Bash writes `agent_tools.active` and prints `Saved to ~/.lacy/config.yaml`, or `Not saved (reason)` if the file cannot be written.

The file is read as simple YAML: `section:` followed by indented `key: value` lines. One pair of surrounding quotes is removed from a value. `#` starts a comment when it follows a space and is not inside quotes. Unknown keys are ignored, and nothing in the file is executed. Fish reads `agent_tools` and `modes` only.

If `agent_tools.active` is not a known tool name, `custom`, or empty, Lacy prints `lacy: agent_tools.active '<value>' is not a known tool. Using auto-detect.` when the shell loads and uses the first installed tool.

Lacy uses the AI tool's own login. It does not take API keys.

### Background server and sessions

lash and opencode answer through a background `serve` process on `preheat.server_port`, which avoids a cold start on each question. claude and gemini continue the same conversation between questions. `/new` starts over and `/resume` picks up the last saved session, including one from another terminal. `lacy uninstall` stops the background server.

## Query log

Off by default. With `logging.queries: true`, each question is appended to `~/.lacy/logs/queries.log` as one line: time, tool, and the question exactly as typed, with no terminal context. The file is readable only by you and is cut to its last 1000 lines once it passes 1 MB.

```bash
lacy logs          # last 50 questions
lacy logs 200      # last 200
lacy logs --clear  # empty the log
```

## Telemetry

Lacy sends anonymous usage events to `https://analytics.lacy.sh` (a self-hosted Umami instance):

| Sent by                | When                                     |
| ---------------------- | ---------------------------------------- |
| zsh and Bash plugin    | once, the first time Lacy loads          |
| `install.sh`           | install, update, uninstall               |
| `npx lacy`             | install, uninstall                       |

Each event contains the install method (curl, npx, brew, git), OS, CPU architecture, shell and Lacy version. No commands, questions, paths or usernames are sent. The fish plugin sends nothing.

To turn it off, set either variable to `1` before installing and in your shell profile:

```bash
export DO_NOT_TRACK=1
# or
export LACY_NO_TELEMETRY=1
```

## Color

Set `NO_COLOR` to any value and Lacy prints no color codes: the prompt badge, indicator, messages, installer and uninstaller all use plain text. The `$` and `?` marks still show the routing. `TERM=dumb` has the same effect.

## The lacy command

```
lacy                Open a shell with Lacy loaded
lacy setup          Change AI tool, mode, or config
lacy install        Install Lacy Shell
lacy uninstall      Remove Lacy Shell
lacy update         Move to the latest release
lacy reinstall      Fresh copy of the latest release (keeps config)
lacy status         Show installation status
lacy info           Show a short introduction
lacy doctor         Check for common problems
lacy config         Show config (config edit, config path)
lacy new            Forget the saved agent session
lacy resume         Show the saved agent session
lacy logs [N]       Show the last N agent queries (default: 50)
lacy logs --clear   Clear the query log
lacy changelog      Show the latest release notes
lacy completions    Print a completion script (zsh or bash)
lacy version        Show version
lacy help           Show this help
```

- `setup`, `install` and `uninstall` use the Node interface when Node is available and fall back to plain prompts otherwise.
- `update` moves to the newest release tag. `update` and `reinstall` refuse to touch `~/.lacy` when it is a symlink (a Homebrew install or a developer checkout) or has local changes.
- `doctor` checks that the plugin is installed, that your rc file has an uncommented `source` line, your Bash version, the config file, that the configured AI tool is installed, and that `~/.lacy/bin` is on your `PATH`. It exits with status 1 when something is wrong.

## Installer

```bash
curl -fsSL https://lacy.sh/install | bash -s -- [options]
```

| Option                 | Meaning                                         |
| ---------------------- | ----------------------------------------------- |
| `--update`             | Move an existing install to the latest release  |
| `--reinstall`          | Fresh copy of the latest release, keeps config  |
| `--uninstall`          | Remove Lacy Shell                               |
| `--shell zsh\|bash\|fish` | Configure this shell instead of the detected one |
| `--tool NAME`          | Use this AI tool, or `auto`                     |
| `--tool custom "CMD"`  | Use your own command                            |
| `--bash`               | Skip the Node installer                         |

The installer asks nothing when one AI tool is installed, asks which one to use when there are several, and offers to install lash when there are none. Without a terminal (CI, Docker) it asks nothing. It adds a `source` line and a `PATH` line to `~/.zshrc`, `~/.bashrc` (`~/.bash_profile` on macOS) or `~/.config/fish/conf.d/lacy.fish`.

`npx lacy` does the same. Once Lacy is installed, `npx lacy` opens a settings menu, or updates without prompts when there is no terminal.

Uninstalling stops the background server, removes the lines Lacy added to your rc files (a symlinked rc file stays a symlink), and deletes `~/.lacy`.

## Environment variables

| Variable             | Effect                                                     |
| -------------------- | ---------------------------------------------------------- |
| `NO_COLOR`           | Plain output, no color codes                               |
| `DO_NOT_TRACK=1`     | No telemetry                                               |
| `LACY_NO_TELEMETRY=1` | No telemetry                                              |
| `LACY_NO_NODE=1`     | `lacy` and the installer skip the Node interface           |
| `LACY_REF`           | Install this branch, tag or commit instead of the latest release |
| `LACY_REPO_URL`      | Install from another git URL                               |
| `LACY_TARBALL_URL`   | Archive base URL used when git is not available            |
| `LACY_SHELL_HOME`    | Lacy's directory (default `~/.lacy`)                       |
