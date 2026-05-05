# Contributing to Lacy

Thanks for your interest in contributing to Lacy! This guide will help you get started.

## Getting Started

### Prerequisites

- **ZSH** or **Bash 4+** (macOS ships with Bash 3.2 -- install Bash 4+ via `brew install bash`)
- **Git**
- An AI CLI tool for testing agent routing (Claude Code, Lash, Gemini CLI, etc.)

### Development Setup

1. **Fork and clone** the repository:

   ```bash
   git clone https://github.com/<your-username>/lacy.git
   cd lacy
   ```

2. **Symlink for development** instead of using the installed copy:

   ```bash
   # Back up your installed copy if you have one
   mv ~/.lacy ~/.lacy.bak

   # Symlink repo to install path
   ln -s "$(pwd)" ~/.lacy
   ```

3. **Source the plugin** in your shell:

   ```bash
   # ZSH
   source ~/.lacy/lacy.plugin.zsh

   # Bash 4+
   source ~/.lacy/lacy.plugin.bash
   ```

4. **Open a new terminal** to test your changes. After editing files, open a fresh shell to reload.

### Project Structure

```
lib/
  core/           # Shared modules (Bash 4+ and ZSH)
    constants.sh  # Colors, detection arrays, error patterns
    config.sh     # YAML config parsing
    detection.sh  # Input classification (the core algorithm)
    modes.sh      # Mode state management
    context.sh    # Terminal context for agent queries
    commands.sh   # Built-in command implementations
    spinner.sh    # Loading animation
    mcp.sh        # AI tool routing
    preheat.sh    # Agent warm-up
  zsh/            # ZSH-specific modules
  bash/           # Bash 4+ adapter modules
bin/lacy          # Standalone CLI (pure bash)
packages/lacy/    # npm package (interactive installer)
tests/            # Test scripts
docs/             # Documentation and specs
```

## Making Changes

### Branching

Create a feature branch from `main`:

```bash
git checkout -b feat/your-feature
```

### Code Style

- Shell scripts should be compatible with **Bash 4+** (for `lib/core/`) or **ZSH** (for `lib/zsh/`)
- Use `printf` instead of `echo -e` for portability
- Use `print -P` for colored output in ZSH (`%F{N}%f` escapes)
- Use `printf '\e[38;5;Nm...\e[0m'` for colored output in Bash
- Keep functions focused and well-named
- Use conventional commit messages: `feat:`, `fix:`, `chore:`, `docs:`

### Key Design Principles

- **Single source of truth**: All input classification goes through `lacy_shell_classify_input()` in `lib/core/detection.sh`. Never create parallel detection logic.
- **Plugin coexistence**: Lacy shares ZLE resources with `zsh-autosuggestions` and `zsh-syntax-highlighting`. Always tag `region_highlight` entries with `memo=lacy`. Never clear `region_highlight` with `region_highlight=()`.
- **No Node dependency at runtime**: The shell plugin and CLI (`bin/lacy`) must work without Node.js installed. Node is only used for the optional interactive installer.
- **Bash/ZSH portability**: Core modules in `lib/core/` must work in both Bash 4+ and ZSH.

### Testing

Run the test suite in both shells:

```bash
bash tests/test_core.sh
zsh tests/test_core.sh
```

For Bash-specific tests:

```bash
bash tests/test_bash.bash
```

Manual testing is also important. Open a fresh shell and verify:

- Mode switching works (`mode shell`, `mode agent`, `mode auto`, `Ctrl+Space`)
- Input classification is correct (commands stay green, natural language turns magenta)
- Agent routing works for your change
- No regressions in normal shell command execution

## Submitting a Pull Request

1. **Test your changes** in both ZSH and Bash 4+ when modifying `lib/core/` code
2. **Commit** with a conventional commit message:
   ```bash
   git commit -m "feat: add support for fish shell"
   ```
3. **Push** your branch and open a PR against `main`
4. **Describe** what your PR does and why. Include before/after behavior if applicable.
5. **Link** any related issues

## Reporting Bugs

Open an issue with:

- Your shell and version (`echo $SHELL && $SHELL --version`)
- Your OS (`uname -a`)
- Steps to reproduce
- Expected vs. actual behavior
- Output of `lacy doctor` if applicable

## Feature Requests

Open an issue describing the feature, the problem it solves, and how you'd expect it to work. Discussion is welcome before implementation.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
