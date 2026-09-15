# Changelog

All notable changes to Lacy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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

### Removed

- Nushell support.
- The direct OpenAI and Anthropic API fallback and the `api_keys` config section.
- The `stop`, `quit_lacy`, `disable_lacy`, `enable_lacy` and `spinner` commands, double Ctrl+C to quit, and the Ctrl+T toggle. Ctrl+C and Ctrl+D are back to shell defaults; `quit` leaves Lacy.
- Installer `--beta` and `--channel` options.
- Launch and marketing material from the repository.

## [1.8.23] - 2026-09-14

- Version bump only.

## [1.8.22] - 2026-09-14

### Changed

- Releases are cut with shipx instead of `script/release.ts`.

## [1.8.21] - 2026-09-14

### Added

- Experimental Nushell plugin.

### Fixed

- `.lash/` session state and local Claude settings are no longer tracked or shipped to installs. A pre-commit hook (`.githooks/pre-commit`) blocks logs, databases, and API tokens.
- Release notes are passed to `gh release create` by file, so a commit subject can no longer run shell code on the release machine.
- The root `install` npm script is now `setup:local`, so `npm install` in the repo no longer runs the installer.
- The preheat server is stopped by port. Orphaned `lash serve` processes no longer hold port 4096, which was the cause of the intermittent Bun errors.
- Agent failures print the tool's exit code and the last lines of its error output. An unknown tool name no longer runs the query as a shell command.
- zsh cleanup runs from `zshexit_functions` instead of an EXIT trap that fired early under zinit and antidote.
- 22 inputs that are plain shell syntax (paths, redirects, subshells, `[[`, env prefixes, `! true`) now go to the shell.
- Classifying input no longer forks on every keystroke. Long pastes went from about 300 ms to under 1 ms.
- Internal state cleanup uses `command rm` so user aliases for `rm` are bypassed.

## [1.8.20] - 2026-05-25

- Version bump only.

## [1.8.19] - 2026-05-25

- Version bump only.

## [1.8.18] - 2026-05-25

### Fixed

- `npx lacy` works again. 1.8.12 through 1.8.17 were published from the root package, which has no `bin`. The root is now private, and `packages/lacy` version and lockfile are back in sync.

## [1.8.17] - 2026-05-24

- Version bump only.

## [1.8.16] - 2026-05-24

### Fixed

- Uninstall no longer prints an npm error, and it offers to restart the shell.

## [1.8.15] - 2026-05-20

- Version bump only.

## [1.8.14] - 2026-05-20

- Version bump only.

## [1.8.13] - 2026-05-20

### Changed

- README images use absolute URLs so they render on npm.

## [1.8.12] - 2026-05-18

### Added

- Backends: GitHub Copilot CLI, Hermes, Goose, Amp, and Aider.
- Fish shell support (`lacy.plugin.fish`).
- Tab completion for the `lacy` CLI in zsh and bash (`lacy completions`).
- `lacy changelog` and `lacy logs [N]` / `lacy logs --clear`.
- `spinner.style` config key, plus `dots` and `ascii` spinner styles.
- About 40 more agent words for natural language routing.

### Changed

- License is now FSL-1.1-MIT.
- Git is optional for installation (curl/tarball fallback).
- "No AI tool found" messages list every supported tool with its install command.
- Repo polish: CONTRIBUTING.md, issue templates, security policy, CI, new logo and social preview.

### Fixed

- The npx installer no longer hangs after it finishes.
- Installing from bash no longer requires zsh or git, and the Bash version check uses your bash instead of `/bin/bash`.
- `lacy doctor` detects hermes, copilot, and goose.

## [1.8.11] - 2026-05-05

### Fixed

- Path-prefixed commands (`./script.sh`, `/usr/bin/env`) go to the shell, and backslashes are kept in history.

## [1.8.10] - 2026-04-21

### Added

- Agent queries carry terminal context (cwd, git branch, last exit code, recent commands), sent only when something changed.

### Fixed

- Quoted paths go to the shell.
- Trailing punctuation is stripped before agent word matching, so `thanks!` routes to the agent.
- Telemetry JSON payload escaping is hardened.

## [1.8.9] - 2026-03-23

### Fixed

- Uninstall handles the Homebrew symlink.

## [1.8.8] - 2026-03-23

- Version bump only.

## [1.8.7] - 2026-03-23

- Version bump only.

## [1.8.6] - 2026-03-23

### Fixed

- Tool detection checks every supported tool, not only lash and claude.

## [1.8.5] - 2026-03-22

### Added

- Ghost text follow-up suggestion (zsh). After a rerouted command gets an agent reply, a suggestion shows on the next empty prompt. Right arrow or Tab accepts it.

## [1.8.4] - 2026-03-13

### Added

- `/new`, `/reset`, `/clear`, and `/resume` session commands. A leading slash always routes to these commands, never to the shell.
- `tool set` persists the choice to `config.yaml`.

### Fixed

- Gemini no longer leaves the spinner running forever.
- Formatting fixes for rendered agent output (horizontal rules, headers).

## [1.8.3] - 2026-03-07

### Changed

- The spinner style defaults to random.

### Fixed

- opencode session resume.

## [1.8.2] - 2026-03-07

- Version bump only.

## [1.8.1] - 2026-03-07

- Detection and agent routing tweaks (no release notes recorded).

## [1.8.0] - 2026-03-03

### Added

- Hint showing how to resume the last agent session.

## [1.7.0] - 2026-02-07

### Added

- **Bash 4+ adapter**: Lacy Shell now works in Bash 4+ in addition to ZSH. Uses `bind -x` for Enter override, `PROMPT_COMMAND` for post-execution hooks, and `PS1` badge for mode display. Requires Bash 4+ (macOS: `brew install bash`); shows a clear error on Bash 3.2
- **Standalone CLI** (`bin/lacy`): pure-bash CLI with zero dependencies. Commands: `lacy setup`, `lacy status`, `lacy doctor`, `lacy update`, `lacy uninstall`, `lacy reinstall`, `lacy config`, `lacy version`, `lacy help`. Delegates to `npx lacy@latest` for rich UI when Node is available, falls back to bash
- **Multi-shell architecture**: `lib/core/*.sh` (portable Bash 4+/ZSH shared logic), `lib/zsh/*.zsh` (ZLE widgets, `region_highlight`, `print -P`), `lib/bash/*.bash` (`bind -x`, `PROMPT_COMMAND`, `printf` ANSI). Old `lib/*.zsh` files are thin backward-compat wrappers
- `lacy.plugin.bash` entry point: sets `LACY_SHELL_TYPE=bash`, `_LACY_ARR_OFFSET=0`, loads bash adapter modules
- `tests/test_bash.bash`: 16 Bash-specific integration tests (detection, prompt, modes, command functions)
- `tests/test_core.sh`: 81 cross-shell tests (runs under both ZSH and Bash 4+)
- **Layer 1: Shell reserved word filtering**: words like `do`, `done`, `then`, `else`, `in`, `select`, `function` that pass `command -v` but are never standalone commands are now routed directly to the agent
- **Layer 2: Post-execution natural language detection**: `lacy_shell_detect_natural_language()` analyzes failed command output against 17 error patterns and checks for NL signals
- `LACY_SHELL_RESERVED_WORDS`, `LACY_SHELL_ERROR_PATTERNS` constants
- Expanded `LACY_NL_MARKERS` from 14 to ~108 common English words
- `NATURAL_LANGUAGE_DETECTION.md`: shared spec for NL detection (synced with lash)
- npm installer (`packages/lacy/index.mjs`) rewritten with `@clack/prompts`: interactive setup, tool selection, mode picker, doctor diagnostics

### Changed

- Reorganized `lib/` into `lib/core/` (shared), `lib/zsh/`, `lib/bash/` with backward-compat wrappers in old `lib/*.zsh` locations
- `lacy_shell_classify_input()` now checks `LACY_SHELL_RESERVED_WORDS` before `command -v`
- `install.sh` now detects Bash vs ZSH and sources the appropriate plugin file
- `uninstall.sh` cleans up both `~/.lacy` and legacy `~/.lacy-shell` paths

### Fixed

- **Tool invocation with special characters**: replaced `eval` with array-based `_lacy_run_tool_cmd()` so queries containing double quotes (e.g. `what does "map" do`) no longer break command parsing
- **Ctrl+Space history pollution** (Bash): the injected `_lacy_mode_toggle_` command is now removed from history immediately
- **Config cache freshness check inverted**: `config.yaml -nt cache` was incorrectly using the stale cache; now correctly checks `! -nt` so config changes take effect
- **Config cache write injection**: cache values are now written with `printf %q` instead of raw single-quote interpolation
- **`bin/lacy setup_tool` crash on non-numeric input**: added regex validation before numeric comparison
- **`bin/lacy reinstall` destroys user config**: config.yaml is now backed up and restored across reinstall
- **`yaml_write` sed injection**: sed special characters (`\`, `|`, `&`) in values are now escaped
- **`commandExists` shell injection** (Node installer): command names are validated against `/^[a-zA-Z0-9._-]+$/` before `execSync`
- **PROMPT_COMMAND not restored on cleanup** (Bash): `lacy_shell_cleanup()` now restores `_LACY_ORIGINAL_PROMPT_COMMAND`
- **Reroute candidate fires when disabled**: moved disabled/quitting guard before reroute check in both `execute.bash` and `execute.zsh`
- **`python3` subprocess on every Ctrl+C** (macOS Bash): replaced with `$(( $(date +%s) * 1000 ))` fallback for second-precision timestamps
- **`(( PASS++ ))` in tests**: replaced with `PASS=$(( PASS + 1 ))` to avoid exit code 1 when counter is 0
- Removed dead `lacy_shell_detect_mode()` function from `detection.sh`

---

## [1.4.0] - 2026-02-04

### Added

- Post-execution error fallback for smart command routing: when a valid command has 3+ bare words with natural language markers (e.g. `kill the process on localhost:3000`), shell executes first; if it fails, input is automatically re-routed to the agent
- `lacy_shell_has_nl_markers()`: NL detection function that counts bare words (excluding flags, paths, numbers, variables) and checks for strong markers (articles, pronouns, question words, "please")
- First-word syntax highlighting via ZSH `region_highlight`: the first word is highlighted green for shell commands and magenta for agent queries in real-time as you type

### Changed

- `lacy_shell_precmd()` now captures `$?` as its first operation to support exit code checking for reroute candidates
- Exit codes >= 128 (signal-based: Ctrl+C, SIGKILL) are excluded from reroute triggering
- Explicit `mode shell` never triggers rerouting: only auto mode

---

## [1.3.0] - 2026-02-03

### Added

- Agent preheating to reduce per-query latency
- Background server mode for lash and opencode: starts `lash serve` / `opencode serve` in background, routes queries via local REST API to eliminate cold-start
- Claude session reuse: captures `session_id` from `--output-format json` and passes `--resume` on subsequent queries for conversation continuity
- New `preheat` config section with `eager` (start server on plugin load) and `server_port` (default 4096) options
- Automatic server lifecycle management: lazy start on first query, health checks, crash recovery, cleanup on quit or tool switch

### Fixed

- Fixed JSON output parsing in zsh: replaced `echo` with `printf '%s
'` to prevent zsh from interpreting escape sequences (`
`, `\"`) in JSON strings

---

## [1.1.1] - 2026-02-03

### Fixed

- Leading whitespace no longer misroutes input to agent (`  ls -la` now correctly executes in shell)
- Spinner no longer permanently disables job control (`fg`/`bg` work after AI queries)
- Spinner no longer leaves cursor hidden after Ctrl+C interrupts
- `exit` no longer shadowed by alias: passes through to shell builtin in shell mode, quits lacy in auto/agent mode

### Changed

- Centralized detection logic into single `lacy_shell_classify_input()` function: indicator and execution can no longer disagree
- Added single-entry cache for `command -v` lookups to reduce input lag with large PATH

---

## [1.1.0] - 2024-12-19 - SMART AUTO MODE 🧠

### ⚡ Major Enhancement: Intelligent Auto Mode

**Smart Command Execution**: Auto mode now executes real commands first, then falls back to AI

- **Command-First Strategy**: Real shell commands execute immediately without AI overhead
- **Natural Language Detection**: Obvious questions go directly to AI (no failed shell attempts)
- **Smart Fallback**: Unknown commands try shell first, then automatically ask AI for help
- **Better Performance**: Eliminates unnecessary AI calls for standard commands

### 🎯 New Smart Auto Mode Features

- `lacy_shell_execute_smart_auto()` - Core smart execution logic
- `lacy_shell_command_exists()` - Robust command existence checking (includes builtins)
- `lacy_shell_is_obvious_natural_language()` - Natural language pattern detection
- Smart routing indicators: 💻 for commands, 🤖 for AI, ❓ for fallback attempts

### 🧪 Testing & Validation

- `test-smart-auto.sh` - Comprehensive test suite for smart auto mode
- `test_smart_auto` alias for quick function testing
- Real-world test cases covering edge cases and common scenarios

### 📈 Performance Improvements

- ⚡ Real commands execute instantly (no AI delay)
- 🧠 Natural language bypasses shell attempts
- 🔄 Graceful fallback maintains workflow continuity
- 📚 Educational feedback when introducing new tools

### 🔄 Breaking Changes

- Auto mode behavior significantly improved (backwards compatible)
- Detection logic now optimized for performance over pattern matching
- Mode descriptions updated to reflect new "try shell first" behavior

---

## [1.0.1] - 2024-12-19 - PRODUCTION HARDENING 🛡️

### 🚨 Critical Fixes

- **Fixed Input "Swallowing" Issue**: Resolved commands disappearing with no feedback
- **MCP Server Error Handling**: Added proper startup validation and error reporting
- **Emergency Recovery System**: Multiple escape routes when things go wrong
- **API Timeout Protection**: 30-second timeout prevents hanging on AI calls

### 🔧 New Emergency Commands

- `!command` - Emergency bypass prefix for direct shell execution
- `disable_lacy` - Disable input interception entirely (alias: `lacy_shell_disable_interception`)
- `enable_lacy` - Re-enable input interception (alias: `lacy_shell_enable_interception`)
- `mcp_check` - Verify MCP package dependencies with installation instructions
- `mode status` - Show detailed mode information including persistence state

### 🛡️ Reliability Improvements

- Pre-flight API key validation before agent execution
- Process validation for MCP servers with PID checking
- Clear error messages with actionable troubleshooting steps
- Graceful fallback to shell execution when AI services unavailable
- Enhanced error logging for MCP server diagnostics

### 📚 Documentation Updates

- Comprehensive troubleshooting section in README
- Emergency recovery procedures in all docs
- API documentation for new diagnostic functions
- Architecture docs updated with error handling patterns

### 🎯 Mode Persistence Enhancement

- **Persistent Mode Memory**: Your preferred mode is saved across shell sessions
- Mode state file: `~/.lacy-shell/current_mode`
- Enhanced `mode status` command shows current, default, and saved modes
- Graceful handling of invalid saved modes with fallback to default

## [1.0.0] - 2024-12-19

### 🎉 Initial Release

#### Added

- **Three intelligent modes**: Shell, Agent, and Auto
- **Smart mode switching** with `Ctrl+Space` keybinding
- **AI integration** with OpenAI and Anthropic APIs
- **Streaming responses** with typewriter effect
- **Persistent conversation history** across sessions
- **MCP (Model Context Protocol) support** for extensible AI capabilities
- **Auto-detection engine** for command vs. query classification
- **Visual mode indicators** in shell prompt
- **Comprehensive configuration system** via YAML
- **Zero-configuration setup** with sensible defaults

#### Features

**Core Functionality:**

- 🐚 **Shell Mode** (`$`) - Pure shell execution
- 🤖 **Agent Mode** (`?`) - AI-powered assistance
- ⚡ **Auto Mode** (`~`) - Smart routing between shell and agent

**User Interface:**

- Single-character mode indicators on prompt right side
- Clean, minimal visual design
- Real-time streaming AI responses
- Context-aware help system

**AI Integration:**

- Support for OpenAI GPT-4 and Anthropic Claude models
- Conversation memory and context preservation
- Streaming responses for real-time feedback
- MCP server integration framework

**Smart Detection:**

- Keyword-based classification (help, how, what, etc.)
- Command pattern recognition (git, npm, docker, etc.)
- Natural language query detection
- Customizable detection rules

**Configuration:**

- YAML-based configuration with fallback parsing
- API key management
- MCP server configuration
- Custom detection keywords and commands

**Keybindings:**

- `Ctrl+Space` - Primary mode toggle (universal compatibility)
- `Ctrl+T` - Alternative mode toggle
- `Ctrl+X` prefix commands for direct mode switching
- Compatible with Mac, VS Code, and all major terminals

**Developer Features:**

- Modular architecture with clear separation of concerns
- Comprehensive test suite
- Debug and troubleshooting commands
- Extension points for custom functionality

#### Technical Implementation

**Architecture:**

- ZSH plugin with widget-based input interception
- Modular design with 7 core components
- Hook-based integration with existing shell setups
- Thread-safe mode management

**Performance:**

- Lazy loading for fast startup
- Minimal memory footprint
- Efficient detection algorithms
- API response caching

**Compatibility:**

- Works with zsh, starship, oh-my-zsh
- MacOS, Linux, and WSL support
- VS Code terminal integration
- Compatible with existing shell configurations

**Security:**

- Local API key storage
- No automatic command execution from AI
- Sandboxed execution environment
- User-controlled data sharing

#### Installation & Setup

**Installation Methods:**

- Automated installer script
- Manual plugin installation
- Package manager support (planned)

**Dependencies:**

- zsh shell
- Python 3.x for configuration parsing
- curl for API communication
- Optional: Node.js for MCP servers

#### Documentation

**Comprehensive Documentation:**

- User guide with examples
- API documentation for developers
- Architecture deep dive
- Contributing guidelines
- Troubleshooting guide

**Example Workflows:**

- Development assistance scenarios
- System administration tasks
- Learning and exploration use cases
- Debugging and problem-solving

### Known Issues

- JSON escaping edge cases in complex queries (workaround available)
- MCP server integration is framework-only (servers not auto-started)

### Breaking Changes

None (initial release)

### Migration Guide

None (initial release)

---

## [Unreleased]

### Added

- feat: add GitHub Copilot CLI as a supported backend (LAC-1144)

### Planned Features

- **Fish shell support**
- **Real MCP server auto-startup**
- **Plugin ecosystem support**

---

## Version History Summary

| Version | Release Date | Key Features                                                               |
| ------- | ------------ | -------------------------------------------------------------------------- |
| 1.7.0   | 2026-02-07   | Bash 4+ adapter, standalone CLI, multi-shell architecture, security fixes  |
| 1.5.0   | 2026-02-07   | NL detection layers 1 & 2, reserved word filtering, error pattern matching |
| 1.4.0   | 2026-02-04   | Post-exec reroute, NL markers, first-word syntax highlighting              |
| 1.3.0   | 2026-02-03   | Agent preheating, background server, claude session reuse                  |
| 1.1.1   | 2026-02-03   | Centralized detection, spinner/cursor fixes, whitespace handling           |
| 1.1.0   | 2024-12-19   | Smart auto mode, command-first strategy, NL detection                      |
| 1.0.1   | 2024-12-19   | Production hardening: error handling, emergency recovery, mode persistence |
| 1.0.0   | 2024-12-19   | Initial release with three modes, AI integration, MCP support              |

## Contributors

- **Initial Development**: Lacy Shell Team
- **Architecture Design**: Core development team
- **Documentation**: Community contributors
- **Testing**: Beta user community

## Acknowledgments

- Inspired by Warp Terminal's AI integration
- Built on the Model Context Protocol (MCP) standard
- Thanks to the zsh and shell scripting community
- OpenAI and Anthropic for AI API access

---

_For detailed technical changes, see the git commit history._
_For upgrade instructions, see the [README.md](README.md) file._