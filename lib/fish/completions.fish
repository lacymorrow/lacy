# Lacy Shell — Fish completions for the `lacy` CLI

complete -c lacy -f

# Top-level subcommands
complete -c lacy -n "__fish_use_subcommand" -a setup -d "Interactive settings"
complete -c lacy -n "__fish_use_subcommand" -a install -d "Install Lacy Shell"
complete -c lacy -n "__fish_use_subcommand" -a uninstall -d "Remove Lacy Shell"
complete -c lacy -n "__fish_use_subcommand" -a update -d "Pull latest changes"
complete -c lacy -n "__fish_use_subcommand" -a reinstall -d "Fresh installation"
complete -c lacy -n "__fish_use_subcommand" -a status -d "Show installation status"
complete -c lacy -n "__fish_use_subcommand" -a doctor -d "Diagnose common issues"
complete -c lacy -n "__fish_use_subcommand" -a config -d "Show/edit config"
complete -c lacy -n "__fish_use_subcommand" -a version -d "Show version"
complete -c lacy -n "__fish_use_subcommand" -a help -d "Show all commands"

# config subcommands
complete -c lacy -n "__fish_seen_subcommand_from config" -a show -d "Show config"
complete -c lacy -n "__fish_seen_subcommand_from config" -a edit -d "Open config in editor"
complete -c lacy -n "__fish_seen_subcommand_from config" -a path -d "Print config path"

# mode command completions
complete -c mode -f
complete -c mode -a "shell" -d "All commands execute directly"
complete -c mode -a "agent" -d "All input goes to AI"
complete -c mode -a "auto" -d "Smart detection"
complete -c mode -a "toggle" -d "Cycle to next mode"
complete -c mode -a "status" -d "Show current mode"

# tool command completions
complete -c tool -f
complete -c tool -n "__fish_use_subcommand" -a set -d "Set active AI tool"
complete -c tool -n "__fish_seen_subcommand_from set" -a "lash" -d "Recommended"
complete -c tool -n "__fish_seen_subcommand_from set" -a "claude" -d "Claude Code CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "opencode" -d "OpenCode CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "gemini" -d "Gemini CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "codex" -d "Codex CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "hermes" -d "Hermes CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "copilot" -d "GitHub Copilot"
complete -c tool -n "__fish_seen_subcommand_from set" -a "goose" -d "Goose CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "amp" -d "Amp CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "aider" -d "Aider CLI"
complete -c tool -n "__fish_seen_subcommand_from set" -a "custom" -d "Custom command"
complete -c tool -n "__fish_seen_subcommand_from set" -a "auto" -d "Auto-detect"
