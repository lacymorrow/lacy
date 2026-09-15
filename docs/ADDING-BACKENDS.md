# Adding a New AI Backend to Lacy Shell

How to add an AI CLI tool as a supported backend.

## Prerequisites

Before starting, verify the CLI tool supports:

1. **Single-shot query mode**: a flag that accepts a prompt string and exits after responding (e.g. `-p`, `-c`, `-q`)
2. **Stdout output**: response text goes to stdout, not a TUI
3. **Non-zero exit codes on errors**
4. **Session resume** (optional): a flag to continue a previous conversation

## Integration Checklist

### 1. Tool registry (`lib/core/mcp.sh`)

Add entries to three functions:

```bash
# lacy_tool_cmd(): single-shot command
your_tool) echo "your-tool query-flag" ;;

# lacy_resume_cmd(): shown as "Resume: ..." after a failed query (omit if unsupported)
your_tool) echo "your-tool --resume-flag" ;;

# lacy_tool_install_cmd(): install line shown when no tool is found
your_tool) echo "npm install -g your-tool" ;;
```

The command string from `lacy_tool_cmd()` is split into words and the query is appended as the final argument. `"hermes chat -q"` becomes `hermes chat -q "user's query"`.

### 2. Tool list

Append the tool to `LACY_TOOL_LIST` in `lib/core/constants.sh`. The order is the auto-detect order and the order in `tool` output. Messages such as `Options: ...` are built from this list.

The same list is copied in other places. Keep them identical (the tests check):

- `install.sh`: `TOOL_LIST`
- `bin/lacy`: `TOOL_LIST`
- `packages/lacy/index.mjs`: `TOOL_LIST` and `TOOL_HINTS`
- `lib/fish/config.fish`: generated. Run `script/sync-word-lists.sh`.

### 3. Fish (`lib/fish/execute.fish`)

Add the command to the `switch` in `_lacy_tool_cmd`.

### 4. Sessions (`lib/core/preheat.sh`)

Tools without their own session handling share the `default` session entry: add the tool to the `codex|hermes|copilot|goose|amp` cases in `_lacy_save_last_session()` and `lacy_session_resume()`.

If the tool returns a session ID you can pass back (as claude and gemini do), follow the claude or gemini pattern: `*_restore_session`, `*_reset_session`, and wiring in `_lacy_get_current_tool()`, `_lacy_save_last_session()`, `lacy_session_new()`, `lacy_session_resume()` and `lacy_preheat_cleanup()`. If the prompt flag is not `-p`, check `_lacy_session_build_cmd()`.

### 5. Docs

- `CLAUDE.md`: Supported AI CLI Tools table
- `lib/core/config.sh`: the tool list comment in the default config (and its copies in `install.sh` and `packages/lacy/index.mjs`)

## Execution Paths

`lacy_shell_query_agent()` has four paths:

| Path       | Used by               | When to use                                                  |
| ---------- | --------------------- | ------------------------------------------------------------ |
| **Server** | lash, opencode        | Tool has a `serve` command with an HTTP API                  |
| **claude** | claude                | JSON output with session IDs, `--resume`                     |
| **gemini** | gemini                | Session reuse with `--resume`                                |
| **Generic** | everything else, custom | Tool streams plain text to stdout                         |

Most new tools use the generic path and need nothing more. The command runs, stdout streams to the terminal, and on failure Lacy prints the exit code, the last lines of error output, and the resume hint.

## Before Opening the PR

With the tool installed, check:

- Single-shot mode prints cleanly to stdout (no TUI artifacts)
- Exit codes are non-zero on errors
- Cold-start latency is acceptable
- Session resume works as documented, if you added it

Run `script/test.sh` and note any known limitations in the PR description.
