# Changelog

All notable changes to Lacy are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Lacy ships as patch releases, and many tags carry only a version bump. Those are
folded into the release that contains the change, and the heading names the
version you can install.

## [Unreleased]

## [1.8.25] - 2026-09-29

### Fixed

- Uninstall checks that the rc file it edited still parses. If removing the Lacy block would leave a file the shell cannot read, the write is skipped, the uninstall finishes, and the lines to delete by hand are printed. A dotfiles `.bashrc` was left broken this way on a real machine.

## [1.8.24] - 2026-09-15

Production hardening across zsh, Bash, fish, the core, the installer and CI.
Also tagged 1.8.22 and 1.8.23, which carried release tooling and version changes only.

### Fixed

- zsh: Lacy no longer rewrites `PS1`. The shell/agent mark is drawn after the prompt (`$` shell, `?` agent) and the mode badge is appended to your right prompt, so powerlevel10k, starship, zsh-syntax-highlighting and zsh-autosuggestions keep working.
- zsh: first-word colors are only added on zsh 5.9+, where they can be removed cleanly. Older zsh no longer piles up highlights.
- zsh: Right arrow and Tab call whatever they were bound to before Lacy loaded when there is no suggestion.
- Bash: continuation lines (open quotes, loop bodies, heredocs) are never classified. Before, `done` or `fi` could go to the agent and leave the shell stuck at `>`.
- Bash: Lacy's `PROMPT_COMMAND` hook runs last, so the badge survives prompts rebuilt by starship or `__git_ps1`. Vi mode works.
- Bash: your own Enter, Ctrl+J and Ctrl+Space bindings are restored on `quit`.
- fish: classification matches zsh and Bash, and questions run as ` ask '<question>'` commands so Ctrl+C and history behave normally.
- `exit` exits the shell in every mode and is never sent to the agent.
- The config parser reads sections, strips one pair of quotes, and only treats `#` as a comment after whitespace.
- `NO_COLOR` is honored by the plugin, installer and uninstaller.
- Uninstall stops the background server by port and keeps symlinked rc files as symlinks.
- `lacy doctor` checks the configured tool, an uncommented `source` line and the Bash version, and exits 1 when it finds a problem.
- Ctrl+C during a query no longer waits on the spinner process before returning the prompt.

### Changed

- Startup mode comes from `~/.lacy/current_mode`, then `modes.default`, then auto, in zsh, Bash and fish.
- `tool set <name>` saves the choice to `config.yaml` and says whether it was saved.
- The query log is off by default. `logging.queries: true` turns it on; it stores only the question as typed, readable only by you.
- `spinner.style` accepts `braille` (default) or `ascii`.
- Questions no longer print a "Using X" line. The resume hint only appears after a failure. With no AI tool installed, one message lists how to install each tool.
- curl and npx install the latest release tag instead of `main`. The installer asks nothing when one AI tool is installed, one question when none is, and shows a picker only when there are several. Without a terminal it asks nothing. The success message is two lines.
- `install.sh` takes `--update`, `--reinstall` and `--uninstall`. `lacy update` moves to the latest tag; update and reinstall refuse a symlinked or modified `~/.lacy`.
- A one-time gray hint (`what files are here`) shows on the first prompt in zsh.
- Tests run with `script/test.sh`. CI runs the suites on Ubuntu and macOS, an installer smoke test, npm package and version checks, and a fish word-list check.
- Fish word lists are generated from `lib/core/constants.sh` by `script/sync-word-lists.sh`.
- License is FSL-1.1-MIT everywhere.
- Releases are cut with shipx instead of `script/release.ts` (1.8.22).

### Removed

- Nushell support.
- The direct OpenAI and Anthropic API fallback and the `api_keys` config section.
- The `stop`, `quit_lacy`, `disable_lacy`, `enable_lacy` and `spinner` commands, double Ctrl+C to quit, and the Ctrl+T toggle. Ctrl+C and Ctrl+D are back to shell defaults; `quit` leaves Lacy.
- Installer `--beta` and `--channel` options.
- Launch and marketing material from the repository.

## [1.8.21] - 2026-09-14

### Added

- Experimental Nushell plugin, removed again in 1.8.24.

### Fixed

- The root `install` npm script is now `setup:local`, so `npm install` in the repo no longer runs the installer.
- The preheat server is stopped by port. Orphaned `lash serve` processes no longer hold port 4096, which was the cause of the intermittent Bun errors.
- Agent failures print the tool's exit code and the last lines of its error output. An unknown tool name no longer runs the query as a shell command.
- zsh cleanup runs from `zshexit_functions` instead of an EXIT trap that fired early under zinit and antidote.
- 22 inputs that are plain shell syntax (paths, redirects, subshells, `[[`, env prefixes, `! true`) now go to the shell.
- Classifying input no longer forks on every keystroke. Long pastes went from about 300 ms to under 1 ms.
- Internal state cleanup uses `command rm` so user aliases for `rm` are bypassed.

### Security

- `.lash/` session state and local Claude settings are no longer tracked or shipped to installs. A pre-commit hook (`.githooks/pre-commit`) blocks logs, databases and API tokens.
- Release notes are passed to `gh release create` by file, so a commit subject can no longer run shell code on the release machine.

## [1.8.18] - 2026-05-25

Also tagged 1.8.17, 1.8.19 and 1.8.20, which were version bumps.

### Fixed

- `npx lacy` works again. 1.8.12 through 1.8.17 were published from the root package, which has no `bin`. The root is now private, and the `packages/lacy` version and lockfile are back in sync.

## [1.8.16] - 2026-05-24

### Fixed

- Uninstall no longer prints an npm error, and it offers to restart the shell.

## [1.8.14] - 2026-05-20

Also tagged 1.8.13 and 1.8.15, which were version bumps.

### Fixed

- The README images use absolute URLs, so they render on the npm page.

## [1.8.12] - 2026-05-18

### Added

- Backends for GitHub Copilot CLI, Hermes, Goose, Amp and Aider.
- You can run Lacy under fish (`lacy.plugin.fish`).
- Tab completion for the `lacy` CLI in zsh and bash (`lacy completions`).
- `lacy changelog`, and `lacy logs [N]` / `lacy logs --clear`.
- `spinner.style` config key, with `dots` and `ascii` styles.
- About 40 more agent words for natural language routing.

### Changed

- The license is FSL-1.1-MIT.
- Git is optional for installation. Without it, the installer falls back to curl and a tarball.
- When no AI tool is found, every supported tool is listed with its install command.
- The repository carries CONTRIBUTING.md, issue templates, a security policy, CI workflows, a new logo and a social preview image.

### Fixed

- The npx installer no longer hangs after it finishes.
- Installing from bash no longer requires zsh or git, and the Bash version check reads your bash instead of `/bin/bash`.
- `lacy doctor` detects hermes, copilot and goose.

## [1.8.11] - 2026-05-05

### Fixed

- Commands with a path prefix (`./script.sh`, `/usr/bin/env`) go to the shell, and backslashes survive in history.

## [1.8.10] - 2026-04-21

### Added

- Agent queries carry terminal context: working directory, git branch, last exit code and recent commands, sent only when something changed since the last query.

### Fixed

- Quoted paths go to the shell.
- Trailing punctuation is stripped before agent word matching, so `thanks!` reaches the agent.

### Security

- The telemetry JSON payload is escaped properly.

## [1.8.9] - 2026-03-23

Covers 1.8.6 through 1.8.9. 1.8.7 and 1.8.8 were version bumps.

### Fixed

- Detection checks every supported tool instead of stopping at lash and claude.
- Uninstall handles the Homebrew symlink.

## [1.8.5] - 2026-03-22

### Added

- Ghost text follow-up suggestion in zsh. After a rerouted command gets an agent reply, a suggestion appears on the next empty prompt. Right arrow or Tab accepts it.

## [1.8.4] - 2026-03-13

### Added

- `/new`, `/reset`, `/clear` and `/resume` session commands. A leading slash always routes to these commands, never to the shell.
- `tool set` writes the choice to `config.yaml` so it survives a new shell.

### Fixed

- Gemini no longer leaves the spinner running forever.
- Horizontal rules and headers render correctly in agent output.

## [1.8.3] - 2026-03-07

Also tagged 1.8.1 and 1.8.2.

### Changed

- The spinner style is random by default.

### Fixed

- An agent word that is also a real command is routed by what follows it. `which python` and `nice -n 10 make` go to the shell, `which version should I install` and `nice work` go to the agent.
- `gemini --resume` is passed only when a session exists, so the first query no longer fails with "No previous sessions found".
- opencode sessions resume correctly.

## [1.8.0] - 2026-03-03

### Added

- A hint shows how to resume the last agent session.

## [1.7.14] - 2026-02-22

Also tagged 1.7.11-beta.0, 1.7.11-beta.1, 1.7.12 and 1.7.13.

### Added

- JSON from AI tools is read with jq, python3 or grep, whichever is present, so session capture and resume work without jq installed.

### Fixed

- Your Enter key binding is restored when you `quit` from Bash.

## [1.7.10] - 2026-02-13

Also tagged 1.7.7, 1.7.8 and 1.7.9.

### Added

- `spinner` command with several animation styles and `spinner preview`, removed again in 1.8.24.

### Fixed

- `VAR=value command` lines go to the shell, so `RUST_LOG=debug cargo run` and `CC=gcc make -j4` run instead of reaching the agent.

## [1.7.6] - 2026-02-08

Also tagged 1.7.2, 1.7.3, 1.7.4 and 1.7.5.

### Changed

- Uninstall no longer asks whether to keep the config.

### Fixed

- A tool failure prints a short message instead of the raw JSON error blob.

## [1.7.1] - 2026-02-07

Bash support and the standalone CLI. The 1.7.0 line shipped as 1.7.0-beta.0 through 1.7.0-beta.4, and 1.7.1 is its first stable tag.

### Added

- You can run Lacy under Bash 4+ as well as zsh: `bind -x` for the Enter override, `PROMPT_COMMAND` for post-execution hooks, and a PS1 badge for the mode. macOS ships Bash 3.2, and Lacy says so instead of failing quietly.
- `bin/lacy`, a pure bash CLI with no dependencies: `setup`, `status`, `doctor`, `update`, `uninstall`, `reinstall`, `config`, `version`, `help`. It hands off to `npx lacy@latest` for the richer interface when Node is available.
- Shell reserved words (`do`, `done`, `then`, `else`, `in`, `select`, `function`) go to the agent. They pass `command -v` but are never standalone commands.
- `lacy_shell_detect_natural_language()`, which checks failed command output against 17 error patterns for natural language signals.
- `tests/test_core.sh` with 81 cross-shell tests, and `tests/test_bash.bash` with 16 Bash tests.
- The npm installer (`packages/lacy/index.mjs`) is rebuilt on `@clack/prompts`: interactive setup, tool selection, mode picker and diagnostics.

### Changed

- `lib/` is split into `lib/core/` for shared Bash and zsh code, `lib/zsh/` for ZLE widgets and `region_highlight`, and `lib/bash/` for `bind -x` and `PROMPT_COMMAND`. The old `lib/*.zsh` paths are thin wrappers.
- `LACY_NL_MARKERS` grows from 14 words to about 108.
- `install.sh` detects Bash or zsh and sources the matching plugin file.
- Uninstall cleans up both `~/.lacy` and the older `~/.lacy-shell`.

### Fixed

- Tool commands are built as arrays instead of running through `eval`, so a query containing double quotes (`what does "map" do`) no longer breaks.
- The Ctrl+Space toggle command is removed from Bash history immediately.
- The config cache freshness check is inverted. It had been serving the stale cache after every config edit.
- `_LACY_ORIGINAL_PROMPT_COMMAND` is restored when the Bash adapter cleans up.
- Both adapters check the disabled and quitting state before the reroute check, so suggestions no longer fire after `quit`.
- Ctrl+C under macOS Bash no longer spawns a python3 subprocess.
- `bin/lacy setup` validates input before comparing it as a number, and `bin/lacy reinstall` backs up `config.yaml`.

### Security

- Config cache values are written with `printf %q` instead of being interpolated into single quotes.
- `\`, `|` and `&` in `yaml_write` values are escaped before they reach sed.
- The Node installer validates command names against `/^[a-zA-Z0-9._-]+$/` before passing them to `execSync`.

## [1.6.5] - 2026-02-06

Also tagged 1.6.0, 1.6.1, 1.6.2, 1.6.3 and 1.6.4.

### Changed

- Releases are cut from `script/release.ts`: version sync across the package files, npm publish with an OTP retry menu, and a Homebrew formula update.

## [1.5.3] - 2026-02-06

Also tagged 1.5.0, 1.5.1 and 1.5.2.

### Added

- The installer offers to install lash when it finds no AI CLI tool.
- `yes` and `no` go to the agent.

### Changed

- Shared values live in `lib/constants.zsh`.

### Fixed

- The prompt no longer overwrites a one line agent response.
- The MONITOR and NOTIFY options are restored after a query, so the spinner no longer leaves job control notifications suppressed in your shell.

## [1.4.0] - 2026-02-04

### Added

- A failed command can be rerouted to the agent. A real command carrying several bare words with natural language markers, like `kill the process on localhost:3000`, runs in the shell first. If it fails, Lacy offers you the same line for the agent.
- `lacy_shell_has_nl_markers()`, which counts bare words (skipping flags, paths, numbers and variables) and looks for articles, pronouns, question words and "please".
- The first word is highlighted as you type in zsh through `region_highlight`: green for a shell command, magenta for an agent query.

### Changed

- The project, the plugin file and the npm package are named `lacy`, replacing `lacy-shell` and `lacy-sh`.
- Reroute never fires from `mode shell`, and never on exit codes of 128 or above, which mean Ctrl+C or another signal.

## [1.3.0] - 2026-02-03

### Added

- The agent is preheated to cut per-query latency. lash and opencode run a background `serve`, and queries go over a local REST API instead of paying a cold start each time.
- The Claude session is reused. `session_id` is captured from `--output-format json` and passed back as `--resume` on later queries.
- `preheat` config section with `eager` (start the server on plugin load) and `server_port` (default 4096).
- The server lifecycle is handled for you: lazy start on the first query, health checks, crash recovery, and cleanup on quit or tool switch.

### Fixed

- JSON output is parsed with `printf` instead of `echo` in zsh, which had been interpreting the escape sequences inside JSON strings.

## [1.2.0] - 2026-02-03

### Added

- `custom` tool option with `agent_tools.custom_command`, for any command that takes a query.

## [1.1.1] - 2026-02-03

### Added

- Spinner with shimmer text while a query runs.

### Changed

- Routing is decided in one function, `lacy_shell_classify_input()`, so the typing indicator and the execution can no longer disagree.
- `command -v` lookups are cached, which cuts input lag on a long PATH.

### Fixed

- Leading whitespace no longer sends a line to the agent, so `  ls -la` runs in the shell.
- The spinner no longer leaves job control disabled, and no longer leaves the cursor hidden after Ctrl+C.
- `exit` reaches the shell builtin in shell mode and quits Lacy in auto and agent mode, even when it is aliased.
- Sourcing the plugin twice no longer loads it twice.

## [1.1.0] - 2026-02-02

First tagged release. Work on Lacy started on 2025-08-11, and everything below landed before this tag.

### Added

- zsh plugin that decides, on Enter, whether a line runs in your shell or goes to an AI tool. The decision uses word lists and a `command -v` check, not a model.
- Three modes, shell, agent and auto, with Ctrl+Space to switch and a single character indicator on the prompt.
- Support for the AI CLI tools you already have installed rather than API keys, with auto-detection and a `tool` command to switch.
- Installer via `curl -fsSL https://lacy.sh/install | bash` and `npx lacy-sh`, installing to `~/.lacy`.
- YAML configuration at `~/.lacy/config.yaml`.

### Removed

- The Python helper and the direct OpenAI and Anthropic API calls the first prototype used.

[Unreleased]: https://github.com/lacymorrow/lacy/compare/v1.8.25...HEAD
[1.8.25]: https://github.com/lacymorrow/lacy/compare/v1.8.24...v1.8.25
[1.8.24]: https://github.com/lacymorrow/lacy/compare/v1.8.21...v1.8.24
[1.8.21]: https://github.com/lacymorrow/lacy/compare/v1.8.18...v1.8.21
[1.8.18]: https://github.com/lacymorrow/lacy/compare/v1.8.16...v1.8.18
[1.8.16]: https://github.com/lacymorrow/lacy/compare/v1.8.14...v1.8.16
[1.8.14]: https://github.com/lacymorrow/lacy/compare/v1.8.12...v1.8.14
[1.8.12]: https://github.com/lacymorrow/lacy/compare/v1.8.11...v1.8.12
[1.8.11]: https://github.com/lacymorrow/lacy/compare/v1.8.10...v1.8.11
[1.8.10]: https://github.com/lacymorrow/lacy/compare/v1.8.9...v1.8.10
[1.8.9]: https://github.com/lacymorrow/lacy/compare/v1.8.5...v1.8.9
[1.8.5]: https://github.com/lacymorrow/lacy/compare/v1.8.4...v1.8.5
[1.8.4]: https://github.com/lacymorrow/lacy/compare/v1.8.3...v1.8.4
[1.8.3]: https://github.com/lacymorrow/lacy/compare/v1.8.0...v1.8.3
[1.8.0]: https://github.com/lacymorrow/lacy/compare/v1.7.14...v1.8.0
[1.7.14]: https://github.com/lacymorrow/lacy/compare/v1.7.10...v1.7.14
[1.7.10]: https://github.com/lacymorrow/lacy/compare/v1.7.6...v1.7.10
[1.7.6]: https://github.com/lacymorrow/lacy/compare/v1.7.1...v1.7.6
[1.7.1]: https://github.com/lacymorrow/lacy/compare/v1.6.5...v1.7.1
[1.6.5]: https://github.com/lacymorrow/lacy/compare/v1.5.3...v1.6.5
[1.5.3]: https://github.com/lacymorrow/lacy/compare/v1.4.0...v1.5.3
[1.4.0]: https://github.com/lacymorrow/lacy/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/lacymorrow/lacy/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/lacymorrow/lacy/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/lacymorrow/lacy/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/lacymorrow/lacy/releases/tag/v1.1.0
