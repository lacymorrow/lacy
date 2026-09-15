# Contributing to Lacy

This guide covers setup, testing, and pull requests. Follow [STYLE.md](STYLE.md) for anything users read.

## Getting Started

### Prerequisites

- **zsh**, **Bash 4+**, or **fish 4** (macOS ships Bash 3.2; install a newer one with `brew install bash`)
- **Git**
- An AI CLI tool for testing agent routing (lash, Claude Code, Gemini CLI, etc.)

### Development Setup

1. **Fork and clone** the repository:

   ```bash
   git clone https://github.com/<your-username>/lacy.git
   cd lacy
   ```

2. **Enable the repo git hooks.** They refuse to commit agent session state, logs, and anything that looks like an API key:

   ```bash
   git config core.hooksPath .githooks
   ```

3. **Symlink for development** instead of using the installed copy:

   ```bash
   # Back up your installed copy if you have one
   mv ~/.lacy ~/.lacy.bak

   # Symlink repo to install path
   ln -s "$(pwd)" ~/.lacy
   ```

   `lacy update` and `lacy reinstall` refuse to run on a symlinked `~/.lacy`. Update the checkout with git.

4. **Source the plugin** in your shell:

   ```bash
   # zsh
   source ~/.lacy/lacy.plugin.zsh

   # Bash 4+
   source ~/.lacy/lacy.plugin.bash

   # fish (in ~/.config/fish/conf.d/lacy.fish)
   source ~/.lacy/lacy.plugin.fish
   ```

5. **Open a new terminal** after editing files to reload.

### Project Structure

```
lacy.plugin.{zsh,bash,fish}   # Entry points
lib/
  core/           # Shared by zsh and Bash 4+
    constants.sh  # Colors, word lists, error patterns, messages
    config.sh     # config.yaml template, parser, writer
    detection.sh  # Input classification (the core algorithm)
    modes.sh      # Mode state and persistence
    context.sh    # Terminal context for agent queries
    commands.sh   # mode, tool, and session commands
    animations.sh # Spinner frames
    spinner.sh    # Loading animation
    mcp.sh        # AI tool routing and the query log
    preheat.sh    # Background server and sessions
    telemetry.sh  # One-time first-load event
  zsh/            # zsh adapter (ZLE widgets, prompt badge, completions)
  bash/           # Bash 4+ adapter (readline bindings, PROMPT_COMMAND, completions)
  fish/           # fish adapter (word lists generated from constants.sh)
bin/lacy          # Standalone CLI (pure bash)
install.sh        # Installer
uninstall.sh      # Uninstaller
script/           # test.sh, sync-word-lists.sh
packages/lacy/    # npm package (interactive installer)
tests/            # Test suites
docs/             # Reference and specs
```

## Making Changes

### Branching

Create a feature branch from `main`:

```bash
git checkout -b feat/your-feature
```

### Code Style

- `lib/core/` must work in both Bash 4+ and zsh. `install.sh` must run on Bash 3.2.
- Use `printf` instead of `echo -e`.
- Use `lacy_print_color` for colored output so `NO_COLOR` is honored.
- Use `command rm` for cleanup so user aliases are bypassed.
- Keep functions focused and well-named.
- Use conventional commit messages: `feat:`, `fix:`, `chore:`, `docs:`.

### Key Design Principles

- **Single source of truth**: all input classification goes through `lacy_shell_classify_input()` in `lib/core/detection.sh`. The fish port in `lib/fish/detection.fish` must match it.
- **Word lists live in `lib/core/constants.sh`**. After changing one, run `script/sync-word-lists.sh` to regenerate the fish copies. CI fails if they drift.
- **Leave the user's shell alone**: zsh never rewrites `PS1`, hooks are added with `add-zle-hook-widget` and `add-zsh-hook`, and replaced key bindings are restored on `quit`. Tag `region_highlight` entries with `memo=lacy` and never clear the array.
- **No Node dependency at runtime**: the shell plugin and `bin/lacy` must work without Node.js. Node is only used for the optional interactive installer.

### Testing

Run every suite in the shells it targets (Bash 4+, zsh, and fish when installed). Each suite runs with a throwaway `HOME`, so your real `~/.lacy` and rc files are not touched:

```bash
script/test.sh                              # all shells
script/test.sh --shell zsh                  # one shell
script/test.sh --skip test_installer.sh     # skip a suite
```

When testing by hand outside the runner, use a sandbox:

```bash
HOME=$(mktemp -d) LACY_NO_NODE=1 DO_NOT_TRACK=1 bin/lacy doctor
```

Then open a fresh shell and check:

- Mode switching works (`mode shell`, `mode agent`, `mode auto`, Ctrl+Space)
- Commands show `$` and questions show `?` (zsh)
- Agent routing works for your change
- Normal shell commands still run

## Submitting a Pull Request

1. **Test your changes** in zsh and Bash 4+ when modifying `lib/core/`, and in fish when touching word lists or classification.
2. **Commit** with a conventional commit message:
   ```bash
   git commit -m "fix: keep heredoc bodies in the shell"
   ```
3. **Push** your branch and open a PR against `main`.
4. **Describe** what your PR does and why. Include before and after behavior if applicable.
5. **Link** any related issues.

## Reporting Bugs

Open an issue with:

- Your shell and version (`echo $SHELL && $SHELL --version`)
- Your OS (`uname -a`)
- Steps to reproduce
- Expected and actual behavior
- Output of `lacy doctor`

## Feature Requests

Open an issue describing the feature, the problem it solves, and how you would expect it to work. Discussion is welcome before implementation.

## License

By contributing, you agree that your contributions will be licensed under the [Functional Source License 1.1, MIT Future License](LICENSE) (FSL-1.1-MIT).
