# Lacy Shell

Dead-simple zsh plugin that adds an AI agent to your terminal. When `lash` is installed, this plugin becomes a thin wrapper that delegates all model and MCP work to Lash.

## What you get

- Shell, Agent, and Auto modes (toggle quickly)
- If `lash` exists: agent queries route to `lash run` (Lash manages models, MCP, providers, and tools)
- If `lash` is missing: fallback to simple OpenAI/Anthropic HTTP calls using your local config

## Install

```bash
git clone https://github.com/lacymorrow/lacy-shell.git ~/.lacy-shell
echo 'source ~/.lacy-shell/lacy-shell.plugin.zsh' >> ~/.zshrc
source ~/.zshrc
```

Optional: install Lash for full power (recommended)

```bash
brew tap lacymorrow/tap
brew install lacymorrow/tap/lash
```

Lash docs and configuration live here: [lacymorrow/lash](https://github.com/lacymorrow/lash)

## Configure

Minimal config file: `~/.lacy-shell/config.yaml`

```yaml
api_keys:
  openai: "sk-your-openai-key"   # or
  anthropic: "your-anthropic-key"

modes:
  default: "auto"

model:
  provider: openai                 # openai | anthropic
  name: gpt-4o-mini                # used when lash is not installed
```

Notes:

- When `lash` is installed, configure models, providers, and MCP in your project’s `crush.json`/`.crush.json` as per Lash docs.
- This plugin no longer manages MCP when Lash is present.

## Use

- Toggle modes: `Ctrl+Space` or `mode toggle`
- Explicit: `mode shell | mode agent | mode auto | mode status`
- Ask the agent: `ask "how do I tail logs?"`

Behavior in Auto mode:

- Real commands execute normally
- Natural language is sent to the agent
- Unknown commands fall back to the agent

## Troubleshooting

- Ensure the plugin is sourced: `source ~/.lacy-shell/lacy-shell.plugin.zsh`
- Check keys for fallback mode: `env | grep LACY_SHELL_API`
- Prefer installing `lash` for models/MCP: see `brew` commands above
 - On macOS without `coreutils`, MCP timeouts fall back to a portable method; optionally install `gtimeout` via `brew install coreutils` for best behavior

## License

MIT — see `LICENSE`.
