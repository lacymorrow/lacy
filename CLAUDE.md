# CLAUDE.md

Guidance for Claude Code (claude.ai/code) in this repository. Internal reference: terse, exact. Code wins over this file; fix this file when they disagree.

## Mission

Enable developers to talk directly to their shell.

## Project Overview

Lacy Shell is a shell plugin (zsh, Bash 4+, fish) that classifies each line you type and runs it in the shell or sends it to an AI CLI tool.

- Install location: `~/.lacy`
- npm package: `lacy` (`packages/lacy`)
- License: FSL-1.1-MIT

## Installation Methods

| Method   | Command                                      |
| -------- | -------------------------------------------- |
| curl     | `curl -fsSL https://lacy.sh/install \| bash` |
| npx      | `npx lacy`                                   |
| Homebrew | `brew install lacymorrow/tap/lacy`           |

curl and npx install the newest `vX.Y.Z` release tag (falls back to `main` only when no tag is found). `LACY_REF` overrides.

## Visual Feedback

### zsh

- PS1 is never modified.
- Live indicator drawn in `PREDISPLAY` (between prompt and buffer), updated on `zle-line-pre-redraw`:
  - `$` green (34) = shell
  - `?` magenta (200) = agent
  - `▌` gray (238) = neutral (auto mode, nothing decided yet). `|` when the locale is not UTF-8.
  - Lacy writes `PREDISPLAY` only when empty or still holding its own last value.
- First-word highlight (green/magenta bold) via `region_highlight`, zsh 5.9+ only (`memo=` needs 5.9). Older zsh: glyph only, no highlights. `NO_COLOR`: no highlights.
- Mode badge `SHELL` / `AGENT` / `AUTO` appended to the user's `RPS1`, removed on `quit`.
- Ghost text (`POSTDISPLAY`, gray, empty buffer only):
  - Reroute suggestion `@ <command>` (see Auto Mode Logic, rule 9). Right arrow or Tab accepts into BUFFER. Enter on the empty line dismisses it. Typing clears it.
  - First-run hint `what files are here   (Enter to ask, or just type)`: once per install (flag file `$LACY_SHELL_HOME/.hinted`), not in shell mode. Enter on the empty line asks it.

### Bash 4+

- No per-keystroke indicator (readline has no redraw hook).
- Badge prepended to PS1 each prompt: `SHELL $` (green), `AGENT ?` (magenta), `AUTO ▌` (blue). Plain text with `NO_COLOR`.

### fish

- No per-keystroke indicator.
- Badge `$ SHELL` / `? AGENT` / `▌ AUTO` appended to `fish_right_prompt` (wraps the existing one, restored on `quit`).

## Auto Mode Logic

Canonical: `_lacy_classify_impl` in `lib/core/detection.sh`. Order:

1. Empty input: `shell` / `agent` in locked modes, `neutral` in auto.
2. Leading `!` → shell, any mode. Glued (`!rm -rf x`) the accept-line widget strips the `!`. With a space (`! true`) it is shell negation, left intact.
3. Leading `@` → agent, any mode. Widget strips `@` and leading whitespace before sending.
4. Shell mode → shell. Agent mode → agent.
5. (auto) `#` comment → shell. Path/syntax first token (contains `/`, starts with `\ ( { [[ < >`, `N>`, `&>`) → shell.
6. First word (lowercased, trailing `?.,;:!` stripped) in `LACY_SHELL_RESERVED_WORDS` (11: `do done then else elif fi esac in select } !`) → agent. `function coproc { [[` are not in the list.
7. First word in `LACY_AGENT_WORDS` (209 entries) → agent, except:
   - single word that is a user alias or function → shell (builtins/externals do not get this pass)
   - valid command + args with an operator (`| && || ; >`) → shell
   - valid command + 0 bare words, or exactly 1 bare word that is not an NL marker → shell (`which python`, `nice -n 10 make`)
8. `VAR=value cmd`: skip assignments; quoted or `$(` RHS → shell; operator after assignment → shell; next word valid command → shell.
9. First word valid command (`command -v`, cached) → shell. In auto mode, if `lacy_shell_has_nl_markers` is true the line is a reroute candidate (see below).
10. Single word, not a command → shell (typo), except a word with an odd number of apostrophes
    (`what's`, `don't`) → agent, since the shell would only open a continuation prompt.
    Multiple words, first not a command → agent.

Only the first line of a multi-line buffer is classified.

### Reroute (one story, all docs must match)

- `lacy_shell_has_nl_markers(input)`: true when there is no shell operator and at least 1 bare word after the first word (not a flag, path, number, or `$var`) is in `LACY_NL_MARKERS`.
- zsh (`lib/zsh/execute.zsh`): accept-line stores the candidate (auto mode only). `precmd`: if exit code is 1-127, sets ghost text `@ <command>` on the next empty prompt. User accepts with Right arrow/Tab, then presses Enter; `@` routes it to the agent.
- Bash (`lib/bash/execute.bash`): same trigger; prints a hint line `  ? @ <command>`. User retypes it.
- fish: no reroute.
- Nothing is sent to the agent automatically. Exit codes >= 128 (signals, Ctrl+C) never suggest. Shell mode never suggests.
- `lacy_shell_detect_natural_language` (Layer 2: error pattern + NL signal) exists in `detection.sh` and is tested in `tests/test_core.sh`, but no adapter calls it. It is kept for parity with the lash spec.

Examples (verified against `tests/test_core.sh` and a sandboxed classify run):

- `ls -la` → shell
- `what files are here` → agent (agent word)
- `do we have a way to uninstall?` → agent (reserved word)
- `fix the bug` → agent (multi-word, `fix` not a command)
- `which python` → shell; `nice work` → agent
- `kill the process on localhost:3000` → shell; candidate; fails → suggestion `@ kill the process on localhost:3000`
- `make sure the tests pass` → shell; candidate (`sure`); fails → suggestion
- `kill -9 my baby` → shell; candidate (`my` is a marker, test_core.sh:315); suggestion only if it fails
- `echo the quick brown fox` → shell; candidate; succeeds → nothing
- `@ make sure the tests pass` → agent
- `!rm -rf x` → shell, `!` stripped

## Canonical Functions

### `lacy_shell_classify_input(input)`

File: `lib/core/detection.sh`. Prints `shell` / `agent` / `neutral` and sets `_LACY_CLASSIFY_RESULT`. Hot-path callers discard stdout and read the variable (no fork per keystroke):

```bash
lacy_shell_classify_input "$BUFFER" >/dev/null
case "$_LACY_CLASSIFY_RESULT" in ...
```

Never add parallel detection logic. Fish carries a port in `lib/fish/detection.fish`; `tests/test_fish.fish` runs the core probe inputs against it.

Consumers:

- zsh: `keybindings.zsh:lacy_shell_update_input_indicator()` (indicator glyph + first-word highlight)
- zsh: `execute.zsh:lacy_shell_smart_accept_line()` (routing)
- Bash: `execute.bash:lacy_shell_smart_accept_line_bash()` (routing)
- fish: `execute.fish:_lacy_accept_line()` via `_lacy_classify_input` (port)

### `lacy_shell_has_nl_markers(input)`

File: `lib/core/detection.sh`. Reroute candidate test. See Reroute above.

### `lacy_shell_detect_natural_language(input, output, exit_code)`

File: `lib/core/detection.sh`. Layer 2 helper, not wired into any adapter. Returns 0 when: exit code non-zero, 2+ words, output matches one of 17 `LACY_SHELL_ERROR_PATTERNS`, and (second word in `LACY_NL_MARKERS` OR 4+ words with `parse error` / `syntax error` / `unexpected token`).

### `_lacy_build_query_context(query)`

File: `lib/core/context.sh`. Prepends delta-based context (cwd, git branch, exit code, recent commands, terminal output) to agent queries. Only what changed since the last query.

Format: `[cwd: /path] [git: branch] [exit: 1] [recent: cmd1 | cmd2] <query>`

With terminal output (tmux, screen, iTerm2, Terminal.app):

```
[cwd: /path] [exit: 1] [recent: npm test]
[terminal-output]
npm ERR! Test failed. See above for more details.
[/terminal-output]
why did that fail?
```

Delta tracking:

- cwd and git branch: skipped if unchanged. Detached HEAD shows short hash.
- Exit code: only when non-zero AND a shell command ran since the last query.
- Recent commands: ring buffer (max 10, each truncated at 80 chars), not `fc`/history.
- Terminal output: captured at query time, ANSI stripped, capped by `context.output_lines` (default 50). tmux/screen checked before terminal emulator APIs. Off with `context.output: false`.
- Counters reset after each query. `/new` calls `_lacy_ctx_reset()`.

Hook chain: accept-line (shell) → `_lacy_ctx_mark_command`; precmd → `_lacy_ctx_on_precmd($?)`; agent query → `_lacy_build_query_context` sets `_LACY_CTX_RESULT` and resets counters. Result variable, not `$()`, so resets persist. zsh and Bash only.

## Plugin Coexistence (zsh)

Full rationale in the header of `lib/zsh/keybindings.zsh`. Tested with zsh-syntax-highlighting, zsh-autosuggestions, powerlevel10k, starship.

- Hooks: `add-zle-hook-widget line-init|line-pre-redraw` and `add-zsh-hook precmd|zshexit`. Never `zle -N zle-line-pre-redraw` (kills z-sy-h's dispatcher). Every hook ends `return 0` (add-zle-hook-widget stops on non-zero). Cleanup runs from `zshexit`, not an EXIT trap (EXIT fires on function return under zinit/antidote/`lacy`).
- PS1: never touched. Indicator lives in `PREDISPLAY`; badge is a suffix on `RPS1`.
- `region_highlight`: tag every entry `memo=lacy`; remove with `region_highlight=("${(@)region_highlight:#*memo=lacy*}")`. Never `region_highlight=()`. Skip highlights entirely below zsh 5.9.
- `POSTDISPLAY`: call `_zsh_autosuggest_clear` before writing ghost text. Clear only when it still holds Lacy's text.
- Keys: binds `^@` (Ctrl+Space), `^[[C` / `^[OC` (Right arrow), `^I` (Tab). Saves each key's `bindkey -L` line and restores it verbatim on cleanup. Without ghost text, Right arrow/Tab call the widget previously bound to that key (by name, no dot prefix) so autosuggest/fzf wrappers fire.
- Ctrl+C: no `TRAPINT`. Queries run in `{ ... } always { _lacy_query_interrupt_cleanup }` (stops spinner, restores MONITOR/NOTIFY).

## Supported AI CLI Tools

From `lacy_tool_cmd()` in `lib/core/mcp.sh`. Order in `LACY_TOOL_LIST` is auto-detect order.

| Tool     | Command                                     |
| -------- | ------------------------------------------- |
| lash     | `lash run -c "query"` (recommended)         |
| claude   | `claude -p "query"`                         |
| opencode | `opencode run -c "query"`                   |
| gemini   | `gemini -p "query"`                         |
| codex    | `codex exec resume --last "query"`          |
| hermes   | `hermes chat -q "query"`                    |
| copilot  | `copilot -p "query"`                        |
| goose    | `goose run -t "query"`                      |
| amp      | `amp -x "query"`                            |
| aider    | `aider --no-auto-commits --message "query"` |
| custom   | `agent_tools.custom_command`                |

lash is an opencode fork by the same author (lash.lacy.sh). Tools handle their own auth. No API keys, no direct API fallback.

Execution paths in `lacy_shell_query_agent()`: server (lash, opencode via background `serve`), claude (JSON + `--resume`), gemini (session), generic (everything else).

Per-query output: no "Using X" line. Resume hint (`Resume: <cmd>`) only after a failure. No tool installed: one `No AI tool found` message listing an install line per tool, no prompt.

## Architecture

```
lacy.plugin.zsh          # Entry (zsh): sources lib/zsh/init.zsh, hooks, zshexit cleanup
lacy.plugin.bash         # Entry (Bash 4+): sources lib/bash/init.bash, PROMPT_COMMAND hooks
lacy.plugin.fish         # Entry (fish 3.1+ required, fish 4 tested)
install.sh               # Installer (Bash 3.2+), --update/--reinstall/--uninstall
uninstall.sh             # The one uninstall implementation, never prompts
bin/lacy                 # Standalone CLI (pure bash)
lib/
├── core/                # Shared by zsh and Bash 4+
│   ├── constants.sh     # Paths, colors, word lists, error patterns, messages, helpers
│   ├── config.sh        # config.yaml template, parser, lacy_config_set
│   ├── modes.sh         # Mode state, toggle, current_mode persistence
│   ├── animations.sh    # Spinner frames (braille, ascii)
│   ├── spinner.sh       # Spinner + shimmer "Thinking"
│   ├── mcp.sh           # Tool registry, install hints, lacy_shell_query_agent, query log
│   ├── preheat.sh       # Background server (lash/opencode), claude/gemini sessions, /new /resume
│   ├── context.sh       # Terminal context for queries
│   ├── detection.sh     # classify_input, has_nl_markers, detect_natural_language
│   ├── commands.sh      # mode, tool, lacy (session subcommands), execute_agent
│   └── telemetry.sh     # One-time first-load event
├── zsh/
│   ├── init.zsh         # Sources core + zsh modules
│   ├── keybindings.zsh  # PREDISPLAY indicator, region_highlight, ghost text, keys
│   ├── prompt.zsh       # RPS1 badge
│   ├── execute.zsh      # accept-line, precmd, reroute suggestion, first-run hint, quit
│   └── completions.zsh  # `lacy` CLI completion
├── bash/
│   ├── init.bash        # Bash 4+ check, sources core + bash modules
│   ├── keybindings.bash # Enter macro, Ctrl+Space, saved bindings
│   ├── prompt.bash      # PS1 badge
│   ├── execute.bash     # Enter handler, PROMPT_COMMAND hooks, reroute hint, quit
│   └── completions.bash # `lacy` CLI completion
└── fish/
    ├── config.fish      # Config reader, mode state (generated tool list)
    ├── detection.fish   # Classifier port (generated word lists)
    ├── execute.fish     # Enter handler, ask/mode/quit, tool invocation
    ├── keybindings.fish # Enter, Ctrl+J, Ctrl+Space
    └── prompt.fish      # Right-prompt badge
script/
├── test.sh              # Runs every suite in its target shells
└── sync-word-lists.sh   # Regenerates fish lists from constants.sh (--check in CI)
tests/                   # test_core.sh, test_config.sh, test_query_agent.sh, test_runtime.sh,
                         # test_gemini*.sh, test_bash*.bash, test_zsh_adapter.zsh,
                         # test_preheat_server.zsh, test_fish.fish, test_installer.sh
packages/lacy/           # npm installer (@clack/prompts): index.mjs, commands/info.sh
```

Nushell adapter removed. No `lib/*.zsh` wrappers, no `lib/commands/`.

## Shell Adapters

### Bash 4+ (`lib/bash/keybindings.bash`, `execute.bash`)

- Enter: `\C-m` and `\C-j` are macros `"\C-x\C-l\C-x\C-j"`. `\C-x\C-l` is `bind -x` to `lacy_shell_smart_accept_line_bash` (classify; agent query clears `READLINE_LINE` and sets `LACY_SHELL_PENDING_QUERY`). `\C-x\C-j` is `accept-line`. `bind -x` straight on `\C-m` would replace accept-line.
- `\C-j` gets the macro too: Enter typed while a command runs arrives as NL.
- Bound in `emacs`, `vi-insert`, `vi-command` (vi mode supported).
- Ctrl+Space: `bind -x '"\C-@": _lacy_ctrl_space_toggle'`, keeps the in-progress line.
- Before binding, the user's existing `\C-m`, `\C-j`, `\C-@` bindings (from `bind -X`, `-s`, `-p`) are saved per keymap and restored on `quit`. Enter falls back to `accept-line` if nothing was saved.
- PROMPT_COMMAND: `_lacy_bash_capture_exit` first (passes `$?` through), `lacy_shell_precmd_bash` last, so the badge lands on PS1 rebuilt by starship/`__git_ps1`. Array form on Bash 5.1+, newline-joined string otherwise. Removed on `quit`.
- Continuation lines: `_LACY_BASH_AT_PS1` is 1 only between precmd and the first accepted line. PS2 lines go straight to accept-line, never classified.
- Queries run from precmd; a temporary INT trap stops the spinner only, user's INT trap restored after.
- macOS `/bin/bash` is 3.2: `init.bash` refuses with upgrade instructions.

### fish (`lib/fish/`)

- Requires fish 3.1+. fish 4 is tested in CI; fish 3 code paths (`\r` key names, no `history append`) are untested.
- Commands: `mode [shell|agent|auto|toggle]`, `ask`, `quit`. Ctrl+Space cycles modes. No `tool`, `/new`, `/resume`, terminal context, preheat, reroute, or ghost text.
- Enter (`bind -M default|insert enter|ctrl-j`, via wrapped `fish_user_key_bindings`): an agent line is rewritten to ` ask '<query>'` and executed as a normal command (Ctrl+C reaches the tool, `$status` set). On fish 4 the typed text is added with `history append` and the rewrite is deleted from history on `fish_postexec`.
- Pager and history search keep Enter's normal meaning.
- Word lists and tool list are generated blocks copied from `lib/core/constants.sh` by `script/sync-word-lists.sh`. Edit constants.sh, then run the script.
- Known gap: `_lacy_query_agent` in `execute.fish` calls `_lacy_log_query` without checking `logging.queries`.

## Modes and Keys

- `exit` exits the shell in every mode (checked before classification, never routed to the agent).
- `quit` leaves Lacy; the shell keeps running. Typing `lacy` with no args re-enables.
- Ctrl+C and Ctrl+D are shell defaults. Ctrl+C aborts a running query.
- Ctrl+Space toggles mode (shell → agent → auto → shell).
- Removed: `stop`, `quit_lacy`, `disable_lacy`, `enable_lacy`, `spinner` in-shell commands; double Ctrl+C quit; Ctrl+T toggle.

Startup mode (zsh, Bash, fish share it): `~/.lacy/current_mode` if valid, else `modes.default`, else auto. Every mode change rewrites `current_mode`, so `modes.default` only applies until the first switch.

## Key Commands (inside Lacy)

- `mode shell|agent|auto|toggle` (short: `s a u t`). `mode` or `mode status` prints `lacy_shell_mode_status` (mode, `$`/`?` legend, how to switch). fish: `mode` prints the mode line and usage.
- `tool` shows active and installed tools. `tool set <name>` (`lash claude opencode gemini codex hermes copilot goose amp aider custom auto`) persists `agent_tools.active` to config.yaml and prints `Saved to <file>` or `Not saved (<reason>). Applies to this shell only.` `tool set custom "cmd"` also writes `custom_command`. zsh/Bash only.
- `ask "query"` sends straight to the agent.
- `/new` `/reset` `/clear` start a new session; `/resume` resumes the last one. Intercepted in accept-line (zsh/Bash). `lacy new|reset|clear|resume` does the same in-shell.
- `quit` leaves Lacy.

## CLI (`bin/lacy`, pure bash)

Exactly as `lacy help` lists:

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

- `setup`, `install`, `uninstall` try `npx --yes lacy@latest` first, then bash. `LACY_NO_NODE=1` skips Node.
- `update` / `reinstall` run `install.sh --update` / `--reinstall`. Both refuse when `~/.lacy` is a symlink (Homebrew: use `brew upgrade`; dev checkout: use git) or a git checkout with uncommitted changes.
- `doctor` checks: plugin file present, uncommented source line in the rc file, Bash 4+ (bash users), config file, configured tool installed (or auto-detect finds one, or custom command exists), `~/.lacy/bin` on PATH. Exits 1 on any issue.
- `uninstall` asks `[y/N]` on a TTY, then runs `uninstall.sh`.

### Testing the Node UI locally

`bin/lacy` runs the published `lacy@latest`, not local code. For local changes:

```bash
node packages/lacy/index.mjs          # install, or dashboard when installed
node packages/lacy/index.mjs --help
LACY_NO_NODE=1 bin/lacy setup         # bash fallback
```

## Installer

`install.sh` (Bash 3.2+) and `packages/lacy/index.mjs` behave the same:

- Tool question: one tool installed → none asked. None → one question (install lash? Y/n). Several → picker. No TTY → nothing asked. Skipped when config.yaml exists.
- Already installed on a TTY (curl): menu Update / Reinstall / Uninstall / Cancel. npx: settings dashboard. npx without TTY: `install.sh --update`.
- Flags: `--update`, `--reinstall`, `--uninstall`, `--bash` (skip Node), `--shell zsh|bash|fish`, `--tool NAME|auto`, `--tool custom "CMD"`. `--beta` / `--channel` removed.
- Env: `LACY_REPO_URL`, `LACY_REF`, `LACY_TARBALL_URL`, `LACY_NO_NODE`, `NO_COLOR`, `DO_NOT_TRACK`, `LACY_NO_TELEMETRY`.
- Download goes to a staging dir and is swapped in after it verifies.
- rc files: zsh `~/.zshrc`; Bash `~/.bash_profile` on macOS else `~/.bashrc`; fish `~/.config/fish/conf.d/lacy.fish`. Adds `# Lacy Shell`, the source line, and the `~/.lacy/bin` PATH line.
- Success message, two lines: `Lacy Shell vX.Y.Z installed for <shell>, using <tool>.` / `Open a new terminal, then type: what files are here`.

`uninstall.sh`: stops the preheat server by port (only signals a PID whose command line is `serve --port <port>`), strips Lacy lines from rc files writing through the path (symlinked rc files stay symlinks), deletes an empty `conf.d/lacy.fish`, removes `~/.lacy` (a symlink: only the link) and `~/.lacy-shell`, uninstalls the Homebrew formula if applicable.

## Configuration

`~/.lacy/config.yaml`. Canonical template: `_lacy_default_config_text` in `lib/core/config.sh` (install.sh and index.mjs carry copies).

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

Keys read (`_lacy_config_var_for`): `agent_tools.active`, `agent_tools.custom_command`, `modes.default`, `preheat.eager`, `preheat.server_port`, `context.output`, `context.output_lines`, `spinner.style` (`braille` default, `ascii`), `logging.queries`. fish reads only `agent_tools.*` and `modes.default`. An `agent_tools.active` that is not in `LACY_TOOL_LIST` or `custom` prints a warning and falls back to auto-detect.

Parser: flat YAML subset. Only direct children of a top-level section. One matching outer quote pair removed. `#` starts a comment only at value start or after whitespace, never inside quotes. `null` / `~` = empty. Unknown keys ignored. Nothing executed. `lacy_config_set` rewrites in place keeping comments and order, writing through the path (symlinks stay).

Query log (`logging.queries: true`): `~/.lacy/logs/queries.log`, one line `timestamp<TAB>tool<TAB>query` (raw query, no context), dir 0700, file 0600, trimmed to the last 1000 lines past 1 MB. Off by default.

Preheat: lash/opencode keep a background `serve` on `preheat.server_port`; claude reuses sessions with `--resume`.

`NO_COLOR` (any non-empty value) removes all escape sequences in zsh, Bash, fish, installer, and uninstaller. `TERM=dumb` sets `NO_COLOR=1` (not exported) in constants.sh, config.fish, bin/lacy, install.sh, uninstall.sh.

Telemetry (`lib/core/telemetry.sh`): zsh/Bash send one `first_load` event per install (flag `~/.lacy/.telemetry_sent`). install.sh sends `install` / `update` / `uninstall`; index.mjs sends `install` / `uninstall`. POST to `https://analytics.lacy.sh/api/send` (Umami) with install method, OS, arch, shell, version. Disabled by `DO_NOT_TRACK=1` or `LACY_NO_TELEMETRY=1` (exact value `1`). fish sends nothing.

## Release and CI

- Release: `bun run release` via shipx (`shipx.config.ts`, see RELEASING.md). No beta channel.
- Tests: `script/test.sh [--shell bash|zsh|fish|all] [--skip NAME]...`. Each suite gets a throwaway HOME. Missing fish → SKIP; missing zsh or Bash 4+ → FAIL. `LACY_TEST_BASH` picks the Bash binary.
- CI (`.github/workflows/ci.yml`): syntax check per shell (bash, zsh, fish 4) plus `script/sync-word-lists.sh --check`; shellcheck; test suites on ubuntu and macOS for bash and zsh; installer smoke on ubuntu and macOS (install, reinstall, doctor, uninstall in a sandboxed HOME); npm package (help, `npm pack --dry-run`, version sync across package.json, packages/lacy, lockfile, bin/lacy).

## Development Notes

- Repo (`lib/`) and install dir (`~/.lacy/lib/`) are separate copies. Changes must be applied to both (or symlink `~/.lacy` to the repo).
- Colors (256): shell 34, agent 200, auto 75, neutral 238.
- Output helpers: `lacy_print_color` / `lacy_print_color_n` (honor `NO_COLOR`, print text as-is). Bash adapter: `_lacy_bash_print_color`. fish: `_lacy_sgr`.
- Use `command rm` for internal cleanup (users alias `rm`).
- Installer uses `printf`, not `echo -e`.
- Never touch the real `~/.lacy` or rc files in tests: `HOME=$(mktemp -d) LACY_NO_NODE=1 DO_NOT_TRACK=1`.
- Word lists: edit `lib/core/constants.sh`, run `script/sync-word-lists.sh`.
- `docs/NATURAL_LANGUAGE_DETECTION.md` is the shared spec with lash.
