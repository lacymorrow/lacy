# Adding a New AI Backend to Lacy Shell

This guide documents how to add a new AI CLI tool as a supported backend. The hermes integration (PR #40) serves as the reference implementation.

## Prerequisites

Before starting, verify the CLI tool supports:

1. **Single-shot query mode** -- a flag that accepts a prompt string and exits after responding (e.g. `-p`, `-c`, `-q`)
2. **Stdout output** -- response text goes to stdout, not a TUI
3. **Session resume** (optional) -- a flag to continue a previous conversation

## Integration Checklist

### 1. Tool registry (`lib/core/mcp.sh`)

Add two entries:

```bash
# lacy_tool_cmd() -- single-shot command
your_tool) echo "your-tool query-flag" ;;

# lacy_resume_cmd() -- session resume (or omit if unsupported)
your_tool) echo "your-tool --resume-flag" ;;
```

The command string returned by `lacy_tool_cmd()` is split on whitespace and the user's query is appended as the final argument. So `"hermes chat -q"` becomes `hermes chat -q "user's query"`.

Also add install hints to both the interactive prompt section and the non-interactive fallback section in `lacy_shell_query_agent()`.

### 2. Tool list (`lib/core/constants.sh`)

Append your tool to the `LACY_TOOL_LIST` array:

```bash
LACY_TOOL_LIST=(lash claude opencode gemini codex your_tool)
```

This controls auto-detection order and the `tool` command display.

### 3. Session management (`lib/core/preheat.sh`)

Add a session reuse block following the existing pattern:

```bash
LACY_YOURTOOL_SESSION_ID=""
LACY_YOURTOOL_SESSION_ID_FILE="$LACY_SHELL_HOME/.yourtool_session_id_$$"

lacy_preheat_yourtool_restore_session() { ... }
lacy_preheat_yourtool_build_cmd() { ... }
lacy_preheat_yourtool_capture_session() { ... }
lacy_preheat_yourtool_extract_result() { ... }
lacy_preheat_yourtool_reset_session() { ... }
```

Then wire it into:

- `_lacy_get_current_tool()` -- add to the detection loop
- `_lacy_save_last_session()` -- add case for session ID
- `lacy_session_new()` -- call reset function
- `lacy_session_resume()` -- add case to restore session
- `lacy_preheat_cleanup()` -- delete session file

If the tool uses `-p` for its prompt flag, `_lacy_session_build_cmd()` works as-is. For other flags (like hermes `chat -q`), add a conditional in that function.

### 4. Help text (`lib/core/commands.sh`)

Add your tool name to the options list in three places (search for `Options:`):

```
Options: lash, claude, opencode, gemini, codex, your_tool, custom, auto
```

### 5. Node installer (`packages/lacy/index.mjs`)

Update these locations:

- **TOOLS array** -- add selection entry with label and hint
- **Detection loops** -- all `for (const tool of [...])` loops (3 locations)
- **Install prompt** -- add a block after the lash install prompt if your tool has a simple install command

For beta tools, use a label like `"your_tool (beta)"` to signal maturity.

### 6. Docs

- **`CLAUDE.md`** -- add row to the Supported AI CLI Tools table
- **This file** -- reference your PR as an additional example if it introduces new patterns

## Execution Paths

Lacy has three execution paths in `lacy_shell_query_agent()`. Choose the right one:

| Path | Used by | When to use |
|------|---------|-------------|
| **Server** (background `serve` + REST API) | lash, opencode | Tool has a `serve` command for persistent background process |
| **JSON** (single-shot with JSON output parsing) | claude | Tool outputs structured JSON with session IDs |
| **Generic** (streaming stdout) | codex, hermes, custom | Tool streams plain text to stdout |

Most new tools use the **generic path** -- no special handling needed. The tool command runs, stdout streams to the terminal, and the spinner is killed on first output line.

## Beta Integrations

For tools that are new, experimental, or have unverified behavior:

1. Add `(beta)` to the label in the TOOLS array: `label: "your_tool (beta)"`
2. Note any known limitations in the PR description
3. Open questions to verify with the tool installed:
   - Does single-shot mode output cleanly to stdout (no TUI artifacts)?
   - Are exit codes non-zero on errors?
   - What is cold-start latency?
   - Does session resume work as documented?

## Reference: Hermes Integration (PR #40)

The hermes backend added in PR #40 is a minimal example touching 6 files with ~90 lines changed:

| File | Change |
|------|--------|
| `lib/core/constants.sh` | Added `hermes` to `LACY_TOOL_LIST` |
| `lib/core/mcp.sh` | `hermes chat -q` in tool registry, `hermes --continue` for resume, install hints |
| `lib/core/preheat.sh` | Session state, build cmd with `chat -q` flag, cleanup |
| `lib/core/commands.sh` | Help text |
| `packages/lacy/index.mjs` | Detection, selection with `(beta)` label, install prompt |
| `CLAUDE.md` | Supported tools table |
