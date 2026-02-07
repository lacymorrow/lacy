# Lacy Shell - LLM Quick Reference

## Essential Commands
```bash
lacy help          # Show all commands
lacy status        # Check installation status
lacy setup         # Interactive settings (tool, mode)
lacy config        # Show current config
lacy config edit   # Open config in $EDITOR
lacy update        # Pull latest changes
lacy doctor        # Diagnose issues
lacy reinstall     # Fresh installation
lacy version       # Show version
```

## Mode Management
```bash
mode               # Show current mode
mode shell         # Force shell mode
mode agent         # Force agent mode  
mode auto          # Auto detection (default)
Ctrl+Space         # Toggle modes
```

## AI Tool Management
```bash
tool               # Show active tool and options
tool set claude    # Set AI tool (lash, opencode, gemini, codex, custom)
tool set auto      # Auto tool selection
```

## Self-Updating
- **Update:** `lacy update` pulls latest from repo
- **Reinstall:** `lacy reinstall` fresh install
- **Local testing:** Edit files in `~/.lacy/` (install location)
- **Dev vs Install:** Repo (`./`) is source, install dir (`~/.lacy/`) is active copy

## Key Files
- Config: `~/.lacy/config.yaml`
- Core detection: `~/.lacy/lib/core/detection.sh`
- Install dir: `~/.lacy/` (separate from repo)

## How It Works
- Green indicator = shell execution
- Magenta indicator = AI agent
- Auto mode routes commands vs natural language
- No context switching needed

Just run `lacy help` to explore all options.