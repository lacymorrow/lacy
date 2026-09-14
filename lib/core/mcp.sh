#!/usr/bin/env bash

# Agent query functions for Lacy Shell
# Routes queries to configured AI CLI tools
# Shared across Bash 4+ and ZSH

# ============================================================================
# JSON Extraction Helpers
# ============================================================================

# Extract a value from JSON using the best available tool (jq > python3 > grep).
# For top-level fields: _lacy_json_get "$json" "field_name"
# Returns the field value on stdout, or empty string if not found.
_lacy_json_get() {
    local json="$1"
    local field="$2"

    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$json" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$json" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    v = d.get('$field')
    if v is not None:
        print(v if isinstance(v, str) else json.dumps(v))
except: pass" 2>/dev/null
    else
        # Grep fallback — handles simple "key": "value" and "key": true/false/number
        local val
        val=$(printf '%s' "$json" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed "s/\"${field}\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//')
        if [[ -n "$val" ]]; then
            printf '%s' "$val"
        else
            # Try unquoted values (booleans, numbers)
            printf '%s' "$json" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[^,}\"]*" | head -1 | sed "s/\"${field}\"[[:space:]]*:[[:space:]]*//" | tr -d ' '
        fi
    fi
}

# Run an arbitrary query expression against JSON (jq syntax, python3 fallback).
# Usage: _lacy_json_query "$json" '.choices[0].message.content'
# The second argument is a jq expression. A python3 equivalent is auto-generated
# for common patterns: .a.b.c and .a[N].b.c
# Returns empty string if the query fails or tools are unavailable.
_lacy_json_query() {
    local json="$1"
    local expr="$2"

    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$json" | jq -r "$expr // empty" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$json" | python3 -c "
import json, sys, re
try:
    d = json.loads(sys.stdin.read())
    # Parse jq-like expression: .key[0].key2
    parts = re.findall(r'\.(\w+)|\[(\d+)\]', '''$expr''')
    obj = d
    for key, idx in parts:
        if key:
            obj = obj[key]
        else:
            obj = obj[int(idx)]
    if obj is not None:
        print(obj if isinstance(obj, str) else json.dumps(obj))
except: pass" 2>/dev/null
    else
        # No structured parser available — return empty
        return 1
    fi
}

# ============================================================================
# Markdown Rendering
# ============================================================================

# Cached renderer (set on first call)
_LACY_MD_RENDERER=""

# Render markdown for terminal display.
# Uses glow if available, otherwise a basic sed fallback for bold/headers/code.
# Usage: _lacy_render_markdown "$text"
_lacy_render_markdown() {
    local text="$1"
    [[ -z "$text" ]] && return

    # Auto-detect on first call
    if [[ -z "$_LACY_MD_RENDERER" ]]; then
        if command -v glow >/dev/null 2>&1; then
            _LACY_MD_RENDERER="glow"
        else
            _LACY_MD_RENDERER="basic"
        fi
    fi

    case "$_LACY_MD_RENDERER" in
        glow)  printf '%s\n' "$text" | glow -s dark ;;
        basic) _lacy_render_markdown_basic "$text" ;;
    esac
}

# Minimal markdown rendering via sed — bold, headers, inline code, rules.
# Uses literal escape chars (via $'') for BSD/GNU sed portability.
_lacy_render_markdown_basic() {
    local bold=$'\e[1m' nobold=$'\e[22m'
    local cyan=$'\e[36m' reset=$'\e[0m'
    local dim=$'\e[38;5;238m'
    local cols; cols=$(tput cols 2>/dev/null || echo 80)
    local hr="${dim}$(printf '%*s' "$cols" | tr ' ' '─')${reset}"

    printf '%s\n' "$1" | sed -E \
        -e "s/^#{1,6}[[:space:]]+(.*)/${bold}\1${nobold}/" \
        -e "s/^---*$/${hr}/" \
        -e "s/^\*\*\*.*$/${hr}/" \
        -e "s/\*\*([^*]*)\*\*/${bold}\1${nobold}/g" \
        -e "s/\`([^\`]*)\`/${cyan}\1${reset}/g"
}

# ============================================================================
# Tool Command Execution
# ============================================================================

# Run a tool command safely — splits command string into array to avoid eval.
# Usage: _lacy_run_tool_cmd "cmd string" "query"
_lacy_run_tool_cmd() {
    local cmd_str="$1"
    local query="$2"
    if [[ -z "${cmd_str//[[:space:]]/}" ]]; then
        echo "  No tool command configured." >&2
        return 127
    fi
    local -a cmd_parts
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        cmd_parts=( ${=cmd_str} )
    else
        read -ra cmd_parts <<< "$cmd_str"
    fi
    "${cmd_parts[@]}" "$query"
}

# Internal helper to build and run a Gemini query with session context and spinner.
# Returns 0 on success, non-zero on error. Outputs tool response to stdout.
# NOTE: Uses LACY_GEMINI_SESSION_ID which is managed in lib/core/preheat.sh.
_lacy_gemini_query_exec() {
    local query="$1"
    local gemini_cmd
    gemini_cmd=$(lacy_preheat_gemini_build_cmd)

    # Only include context on the first message of a session (when ID is empty)
    local gemini_query
    if [[ -z "$LACY_GEMINI_SESSION_ID" ]]; then
        local _gemini_ctx
        _gemini_ctx="${LACY_GEMINI_CONTEXT//\{cwd\}/$(pwd 2>/dev/null)}"
        gemini_query="$_gemini_ctx $query"
    else
        gemini_query="$query"
    fi

    if [[ -t 0 ]]; then
        _lacy_run_tool_cmd "$gemini_cmd" "$gemini_query" </dev/tty 2>/dev/null
    else
        _lacy_run_tool_cmd "$gemini_cmd" "$gemini_query" 2>/dev/null
    fi
}

# Install command for a supported tool (empty for unknown names)
# Usage: hint=$(lacy_tool_install_cmd <tool_name>)
lacy_tool_install_cmd() {
    case "$1" in
        lash)     echo "npm install -g lashcode" ;;
        claude)   echo "brew install claude" ;;
        opencode) echo "brew install opencode" ;;
        gemini)   echo "brew install gemini" ;;
        codex)    echo "npm install -g @openai/codex" ;;
        hermes)   echo "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash" ;;
        copilot)  echo "gh extension install github/gh-copilot" ;;
        goose)    echo "brew install goose" ;;
        amp)      echo "npm install -g @sourcegraph/amp" ;;
        aider)    echo "pipx install aider-chat" ;;
        *)        echo "" ;;
    esac
}

# Known tool names joined for messages: "lash, claude, ..."
_lacy_tool_list_joined() {
    local joined
    joined=$(printf '%s, ' "${LACY_TOOL_LIST[@]}")
    printf '%s' "${joined%, }"
}

# Tool registry — function-based for maximum portability
# Usage: cmd=$(lacy_tool_cmd <tool_name>)
lacy_tool_cmd() {
    case "$1" in
        lash)     echo "lash run -c" ;;
        claude)   echo "claude -p" ;;
        opencode) echo "opencode run -c" ;;
        gemini)   echo "gemini -p" ;;
        codex)    echo "codex exec resume --last" ;;
        hermes)   echo "hermes chat -q" ;;
        copilot)  echo "copilot -p" ;;
        goose)    echo "goose run -t" ;;
        amp)      echo "amp -x" ;;
        aider)    echo "aider --no-auto-commits --message" ;;
        *)        echo "" ;;
    esac
}

# Active tool (set during install or via config)
: "${LACY_ACTIVE_TOOL:=""}"

# Last resume command (set after each successful agent query)
LACY_LAST_RESUME_CMD=""

# Resume command registry — returns the command to resume a conversation
# Usage: cmd=$(lacy_resume_cmd <tool_name>)
lacy_resume_cmd() {
    case "$1" in
        claude)
            [[ -n "$LACY_PREHEAT_CLAUDE_SESSION_ID" ]] && \
                echo "claude --resume $LACY_PREHEAT_CLAUDE_SESSION_ID"
            ;;
        lash)
            [[ -n "$LACY_PREHEAT_SERVER_SESSION_ID" ]] && \
                echo "lash --session $LACY_PREHEAT_SERVER_SESSION_ID"
            ;;
        opencode)
            [[ -n "$LACY_PREHEAT_SERVER_SESSION_ID" ]] && \
                echo "opencode --session $LACY_PREHEAT_SERVER_SESSION_ID"
            ;;
        gemini)
            [[ -n "$LACY_GEMINI_SESSION_ID" ]] && \
                echo "gemini --resume $LACY_GEMINI_SESSION_ID"
            ;;
        codex)    echo "codex exec resume --last" ;;
        hermes)   echo "hermes --continue" ;;
        copilot)  echo "copilot --resume" ;;
        goose)    echo "goose session resume" ;;
        amp)      echo "amp --continue" ;;
    esac
}

# Print resume hint after successful agent query
# Usage: _lacy_print_resume_hint <tool_name>
_lacy_print_resume_hint() {
    local tool="$1"
    local resume_cmd
    resume_cmd=$(lacy_resume_cmd "$tool")

    if [[ -n "$resume_cmd" ]]; then
        LACY_LAST_RESUME_CMD="$resume_cmd"
        lacy_print_color 238 "$resume_cmd"
        # Persist for cross-shell resume (lacy /resume in a new shell)
        _lacy_save_last_session
    fi
}

# Format tool error output — detects JSON error blobs and prints a clean message.
# Returns 0 if an error was detected and formatted, 1 if output is not a tool error.
# Usage: lacy_format_tool_error "$output" "$tool_name"
lacy_format_tool_error() {
    local output="$1"
    local tool="${2:-agent}"

    # Quick check: does it look like JSON with an error?
    [[ "$output" == "{"* ]] || return 1

    local is_error="" result_text=""
    is_error=$(_lacy_json_get "$output" "is_error")
    result_text=$(_lacy_json_get "$output" "result")

    [[ "$is_error" == "true" ]] || return 1

    # We have an error — format it nicely
    local red=196
    local dim=238
    local yellow=220

    echo ""
    lacy_print_color "$red" "  Error from ${tool}"
    echo ""
    if [[ -n "$result_text" ]]; then
        # Split on " · " delimiter that Claude uses
        local IFS_BAK="$IFS"
        local msg="$result_text"
        local main_msg="" hint_msg=""
        if [[ "$msg" == *" · "* ]]; then
            main_msg="${msg%% · *}"
            hint_msg="${msg#* · }"
        else
            main_msg="$msg"
        fi
        lacy_print_color "$yellow" "  ${main_msg}"
        if [[ -n "$hint_msg" ]]; then
            echo ""
            lacy_print_color "$dim" "  ${hint_msg}"
        fi
    else
        lacy_print_color "$yellow" "  The agent returned an error (no details available)"
    fi
    echo ""
    return 0
}

# Strip non-JSON leading lines from captured output.
# Agent CLIs (e.g. claude) emit startup/build text to stderr which gets
# merged into stdout by 2>&1. This strips everything before the first '{'.
_lacy_strip_leading_noise() {
    local output="$1"
    while [[ -n "$output" && "$output" != "{"* ]]; do
        # Remove everything up to and including the first newline
        local rest="${output#*$'\n'}"
        # If no newline found, the whole string is noise
        [[ "$rest" == "$output" ]] && output="" && break
        output="$rest"
    done
    printf '%s' "$output"
}

# Normalize claude JSON output — handles startup noise, JSON arrays, and NDJSON.
# Claude --output-format json wraps all events in a JSON array: [{init},{assistant},{result}]
# This extracts the last element (the result object) so downstream parsing works.
_lacy_claude_normalize_output() {
    local output="$1"

    # Strip non-JSON leading lines (agent startup text on stderr merged via 2>&1)
    local stripped="$output"
    while [[ -n "$stripped" && "$stripped" != "{"* && "$stripped" != "["* ]]; do
        local rest="${stripped#*$'\n'}"
        [[ "$rest" == "$stripped" ]] && stripped="" && break
        stripped="$rest"
    done
    [[ -z "$stripped" ]] && stripped="$output"

    # JSON array — extract the last element (the result object)
    if [[ "$stripped" == "["* ]]; then
        local last_obj=""
        if command -v jq >/dev/null 2>&1; then
            last_obj=$(printf '%s\n' "$stripped" | jq -c '.[-1]' 2>/dev/null)
        elif command -v python3 >/dev/null 2>&1; then
            last_obj=$(printf '%s\n' "$stripped" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    if isinstance(d, list): print(json.dumps(d[-1]))
except: pass" 2>/dev/null)
        fi
        [[ -n "$last_obj" ]] && stripped="$last_obj"
    fi

    printf '%s' "$stripped"
}

# Append a query entry to the query log (rotates at ~1000 lines or ~1 MB).
# Usage: _lacy_log_query "tool_name" "query_text"
_lacy_log_query() {
    local tool="$1"
    local query="$2"
    local log_dir="${LACY_SHELL_HOME}/logs"
    local log_file="${log_dir}/queries.log"

    mkdir -p "$log_dir" 2>/dev/null || return 0

    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "unknown")
    local escaped_query="${query//$'\n'/\\n}"
    printf '%s\t%s\t%s\n' "$ts" "$tool" "$escaped_query" >> "$log_file" 2>/dev/null || true

    # Rotate: keep last 1000 lines if file is large
    local size
    if [[ -f "$log_file" ]]; then
        size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
        if (( size > 1048576 )); then
            local tmp
            tmp=$(mktemp) && tail -n 1000 "$log_file" > "$tmp" && mv "$tmp" "$log_file" 2>/dev/null || true
        fi
    fi
}

# Send query to AI agent (configurable tool or fallback)
lacy_shell_query_agent() {
    local query="$1"
    local tool="${LACY_ACTIVE_TOOL}"
    # Declared once. A second `local exit_code` in the same scope prints
    # "exit_code=N" in zsh and clobbers pipestatus.
    local exit_code=0

    # Prepend delta-based terminal context (cwd, git, exit code, recent commands).
    # Only includes what changed since the last query — zero overhead when idle.
    # Uses result variable (not subshell) so state resets propagate.
    _lacy_build_query_context "$query"
    query="$_LACY_CTX_RESULT"

    # Auto-detect if not set
    local _auto_detected=false
    if [[ -z "$tool" ]]; then
        local t
        for t in "${LACY_TOOL_LIST[@]}"; do
            if command -v "$t" >/dev/null 2>&1; then
                tool="$t"
                _auto_detected=true
                break
            fi
        done
    fi

    # If still no tool, try API fallback
    if [[ -z "$tool" ]]; then
        if lacy_shell_check_api_keys; then
            local temp_file
            temp_file=$(mktemp)
            cat > "$temp_file" << EOF
Query: $query
EOF
            echo ""
            lacy_start_spinner
            lacy_shell_send_to_ai_streaming "$temp_file" "$query"
            exit_code=$?
            lacy_stop_spinner
            command rm -f "$temp_file"
            echo ""
            return $exit_code
        fi

        echo ""
        printf '\e[38;5;196m  No AI tool detected.\e[0m Lacy needs an AI CLI to handle queries.\n'
        echo ""
        printf '\e[1m  Supported tools:\e[0m\n'
        echo ""
        printf '    \e[38;5;34m%-12s\e[0m %s\n' "lash" "$(lacy_tool_install_cmd lash)        (recommended)"
        local _t
        for _t in "${LACY_TOOL_LIST[@]}"; do
            [[ "$_t" == "lash" ]] && continue
            printf '    \e[38;5;238m%-12s\e[0m %s\n' "$_t" "$(lacy_tool_install_cmd "$_t")"
        done
        echo ""
        printf '  \e[38;5;75mThen run:\e[0m  lacy setup\n'
        printf '  \e[38;5;75mDocs:\e[0m      %s\n' "$LACY_DOCS_URL"
        echo ""

        # Offer to install lash interactively if terminal is available
        local can_prompt=false
        if [[ -t 0 ]]; then
            can_prompt=true
        elif [[ -c /dev/tty ]]; then
            can_prompt=true
        fi

        if [[ "$can_prompt" == true ]]; then
            local install_now=""
            printf '  Install \e[38;5;34mlash\e[0m now? (AI coding agent — lash.lacy.sh)\n'
            echo ""
            if [[ -t 0 ]]; then
                read -p "  [Y/n]: " install_now
            else
                read -p "  [Y/n]: " install_now < /dev/tty 2>/dev/null || install_now="n"
            fi

            if [[ ! "$install_now" =~ ^[Nn]$ ]]; then
                echo ""
                if command -v npm >/dev/null 2>&1; then
                    echo "  Installing lash..."
                    if npm install -g lashcode; then
                        echo ""
                        printf '  \e[38;5;34m✓\e[0m lash installed! Re-running your query...\n'
                        echo ""
                        tool="lash"
                    else
                        echo ""
                        printf '  \e[38;5;196m✗\e[0m Installation failed. Try manually: npm install -g lashcode\n'
                        return 1
                    fi
                elif command -v brew >/dev/null 2>&1; then
                    echo "  Installing lash..."
                    if brew tap lacymorrow/tap && brew install lash; then
                        echo ""
                        printf '  \e[38;5;34m✓\e[0m lash installed! Re-running your query...\n'
                        echo ""
                        tool="lash"
                    else
                        echo ""
                        printf '  \e[38;5;196m✗\e[0m Installation failed. Try manually: brew install lacymorrow/tap/lash\n'
                        return 1
                    fi
                else
                    printf '  \e[38;5;196m✗\e[0m Neither npm nor brew found. Install one, then run:\n'
                    echo "    npm install -g lashcode"
                    return 1
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    fi

    local cmd
    if [[ "$tool" == "custom" ]]; then
        if [[ -z "$LACY_CUSTOM_TOOL_CMD" ]]; then
            echo "Error: custom tool selected but no command configured."
            echo "Set one with: tool set custom \"your-command -flags\""
            echo "Or add to ~/.lacy/config.yaml:"
            echo "  agent_tools:"
            echo "    active: custom"
            echo "    custom_command: \"your-command -flags\""
            return 1
        fi
        cmd="$LACY_CUSTOM_TOOL_CMD"
    else
        cmd=$(lacy_tool_cmd "$tool")
        if [[ -z "$cmd" ]]; then
            echo ""
            lacy_print_color 196 "  Unknown tool '${tool}'. Known: $(_lacy_tool_list_joined)"
            lacy_print_color 238 "  Pick one with: tool set <name>"
            echo ""
            return 1
        fi
    fi

    # The tool binary must exist before anything is sent
    local _tool_bin="${cmd%% *}"
    if ! command -v "$_tool_bin" >/dev/null 2>&1; then
        echo ""
        if [[ "$tool" == "custom" ]]; then
            lacy_print_color 196 "  Custom tool command '${_tool_bin}' is not installed."
        else
            lacy_print_color 196 "  ${tool} is set as your tool but is not installed."
            local _install_hint
            _install_hint=$(lacy_tool_install_cmd "$tool")
            [[ -n "$_install_hint" ]] && lacy_print_color 238 "  Install: ${_install_hint}"
        fi
        lacy_print_color 238 "  Or switch: tool set <name>"
        echo ""
        return 1
    fi

    # Log the query (tool name + input text, not the AI response)
    _lacy_log_query "$tool" "$query"

    # Show which tool was auto-detected
    if [[ "$_auto_detected" == true ]]; then
        lacy_print_color 238 "  Using $tool (auto-detected)"
    fi

    # === Preheat: lash/opencode background server ===
    local _blank_printed=false
    if [[ "$tool" == "lash" || "$tool" == "opencode" ]]; then
        echo ""
        _blank_printed=true
        lacy_start_spinner
        if lacy_preheat_server_is_healthy || lacy_preheat_server_start "$tool"; then
            local server_result
            server_result=$(lacy_preheat_server_query "$query")
            exit_code=$?
            lacy_stop_spinner
            # Restore session ID from file (lost in subshell)
            lacy_preheat_server_restore_session
            case "$exit_code" in
                "$LACY_SERVER_QUERY_OK")
                    while [[ "$server_result" == $'\n'* ]]; do server_result="${server_result#$'\n'}"; done
                    if [[ -n "$server_result" ]]; then
                        _lacy_render_markdown "$server_result"
                    else
                        lacy_print_color 238 "  (no text response)"
                    fi
                    _lacy_print_resume_hint "$tool"
                    echo ""
                    return 0
                    ;;
                "$LACY_SERVER_QUERY_TIMEOUT")
                    # The server has the prompt and is still working on it.
                    lacy_print_color 238 "  still running: ${tool} --session ${LACY_PREHEAT_SERVER_SESSION_ID}"
                    echo ""
                    return 0
                    ;;
                "$LACY_SERVER_QUERY_LOST")
                    lacy_print_color 196 "  Lost the connection to ${tool} mid-request."
                    [[ -n "$LACY_PREHEAT_SERVER_SESSION_ID" ]] && \
                        lacy_print_color 238 "  Check on it: ${tool} --session ${LACY_PREHEAT_SERVER_SESSION_ID}"
                    echo ""
                    return 1
                    ;;
                "$LACY_SERVER_QUERY_HTTP_ERROR")
                    _lacy_print_server_error "$tool" "$server_result"
                    return 1
                    ;;
                "$LACY_SERVER_QUERY_SESSION_GONE")
                    # The subshell already reset its copy; mirror it here
                    LACY_PREHEAT_SERVER_SESSION_ID=""
                    : > "$LACY_PREHEAT_SERVER_SESSION_FILE"
                    lacy_print_color 196 "  That session is gone. Send it again to start a new one."
                    echo ""
                    return 1
                    ;;
            esac
            # Unreachable: the server is gone, drop the session and go single-shot
            LACY_PREHEAT_SERVER_SESSION_ID=""
            : > "$LACY_PREHEAT_SERVER_SESSION_FILE"
        else
            lacy_stop_spinner
        fi
    fi

    # === Preheat: claude session reuse ===
    if [[ "$tool" == "claude" ]]; then
        local claude_cmd
        claude_cmd=$(lacy_preheat_claude_build_cmd)
        echo ""
        lacy_start_spinner
        local json_output
        json_output=$(unset CLAUDECODE; _lacy_run_tool_cmd "$claude_cmd" "$query" </dev/tty 2>&1)
        exit_code=$?
        lacy_stop_spinner

        # Normalize: strip noise, extract last element from JSON array
        json_output=$(_lacy_claude_normalize_output "$json_output")

        if [[ $exit_code -eq 0 ]]; then
            # Check for structured errors (e.g. invalid API key)
            if lacy_format_tool_error "$json_output" "$tool"; then
                return 1
            fi
            local result_text
            result_text=$(lacy_preheat_claude_extract_result "$json_output")
            while [[ "$result_text" == $'\n'* ]]; do result_text="${result_text#$'\n'}"; done
            if [[ -n "$result_text" ]]; then
                _lacy_render_markdown "$result_text"
            else
                printf '%s\n' "$json_output"
            fi
            lacy_preheat_claude_capture_session "$json_output"
            _lacy_print_resume_hint "$tool"
            echo ""
            return 0
        elif [[ -n "$LACY_PREHEAT_CLAUDE_SESSION_ID" ]]; then
            lacy_preheat_claude_reset_session
            claude_cmd=$(lacy_preheat_claude_build_cmd)
            lacy_start_spinner
            json_output=$(unset CLAUDECODE; _lacy_run_tool_cmd "$claude_cmd" "$query" </dev/tty 2>&1)
            exit_code=$?
            lacy_stop_spinner

            # Normalize: strip noise, extract last element from JSON array
            json_output=$(_lacy_claude_normalize_output "$json_output")

            # Check for structured errors before processing
            if lacy_format_tool_error "$json_output" "$tool"; then
                return 1
            fi

            if [[ $exit_code -eq 0 ]]; then
                local result_text
                result_text=$(lacy_preheat_claude_extract_result "$json_output")
                while [[ "$result_text" == $'\n'* ]]; do result_text="${result_text#$'\n'}"; done
                if [[ -n "$result_text" ]]; then
                    _lacy_render_markdown "$result_text"
                else
                    printf '%s\n' "$json_output"
                fi
                lacy_preheat_claude_capture_session "$json_output"
                _lacy_print_resume_hint "$tool"
                echo ""
                return 0
            fi
            lacy_format_tool_error "$json_output" "$tool" || printf '%s\n' "$json_output"
            echo ""
            return $exit_code
        else
            lacy_format_tool_error "$json_output" "$tool" || printf '%s\n' "$json_output"
            echo ""
            return $exit_code
        fi
    fi

    # === Gemini session reuse ===
    if [[ "$tool" == "gemini" ]]; then
        echo ""
        local json_output
        lacy_start_spinner
        json_output=$(_lacy_gemini_query_exec "$query")
        exit_code=$?
        lacy_stop_spinner
        # Restore session ID lost in subshell
        lacy_preheat_gemini_restore_session

        if [[ $exit_code -ne 0 && -n "$LACY_GEMINI_SESSION_ID" ]]; then
            # --resume failed (session expired/missing) — retry without it
            lacy_preheat_gemini_reset_session
            lacy_start_spinner
            json_output=$(_lacy_gemini_query_exec "$query")
            exit_code=$?
            lacy_stop_spinner
        fi

        if [[ $exit_code -eq 0 ]]; then
            local result_text
            result_text=$(lacy_preheat_gemini_extract_result "$json_output")
            while [[ "$result_text" == $'\n'* ]]; do result_text="${result_text#$'\n'}"; done
            if [[ -n "$result_text" ]]; then
                _lacy_render_markdown "$result_text"
            else
                printf '%s\n' "$json_output"
            fi
            lacy_preheat_gemini_capture_session "$json_output"
            _lacy_print_resume_hint "$tool"
        fi
        echo ""
        return $exit_code
    fi

    # === Generic path (codex, custom, and fallback) ===
    # stdout streams live and is copied to a temp file; stderr goes only to a
    # second temp file. A failure shows the tail of both instead of a raw
    # stack trace.
    [[ "$_blank_printed" == true ]] || echo ""
    local _out_file _err_file
    _out_file=$(mktemp 2>/dev/null) || _out_file="${LACY_SHELL_HOME}/.tool_out_$$"
    _err_file="${_out_file}.err"
    : > "$_out_file"
    : > "$_err_file"
    # Tools may prompt on the terminal; without one (CI, tests) feed /dev/null
    local _stdin_src=/dev/null
    ( : </dev/tty ) 2>/dev/null && _stdin_src=/dev/tty
    local -a _ps
    lacy_start_spinner
    _lacy_run_tool_cmd "$cmd" "$query" <"$_stdin_src" 2>>"$_err_file" | _lacy_stream_tool_output "$tool" "$_out_file"
    _ps=("${pipestatus[@]}" "${PIPESTATUS[@]}")
    exit_code="${_ps[$_LACY_ARR_OFFSET]}"
    lacy_stop_spinner

    if [[ "$exit_code" -eq 0 ]]; then
        _lacy_print_resume_hint "$tool"
    elif [[ "$exit_code" -ge "$LACY_SIGNAL_EXIT_THRESHOLD" ]]; then
        # Signal (Ctrl+C and friends): nothing to explain
        command rm -f "$_out_file" "$_err_file"
        return "$exit_code"
    else
        _lacy_print_tool_failure "$tool" "$exit_code" "$_out_file" "$_err_file"
    fi
    command rm -f "$_out_file" "$_err_file"
    echo ""
    return "$exit_code"
}

# Stream a tool's output live from the read side of a pipe.
# The first line is held back so a single-line JSON error can be formatted;
# from the second line on everything is printed as it arrives. Each line is
# also appended to $2 for the failure summary.
_lacy_stream_tool_output() {
    local tool="$1" out_file="$2"
    local line _first_line="" _line_count=0 _spinner_killed=false
    # `|| [[ -n "$line" ]]` keeps a final line that has no trailing newline
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip agent startup noise (e.g. "> build · big-pickle", "exit_code=0")
        [[ "$line" =~ ^'> '[a-z]+' · ' ]] && continue
        [[ "$line" =~ ^exit_code= ]] && continue
        if ! $_spinner_killed; then
            if [[ -n "$LACY_SPINNER_PID" ]] && kill -0 "$LACY_SPINNER_PID" 2>/dev/null; then
                kill "$LACY_SPINNER_PID" 2>/dev/null
                sleep "$LACY_TERMINAL_FLUSH_DELAY"
                printf '\e[2K\r\e[?25h\e[?7h'
            fi
            _spinner_killed=true
        fi
        [[ -n "$out_file" ]] && printf '%s\n' "$line" >> "$out_file"
        (( _line_count++ ))
        if (( _line_count == 1 )); then
            _first_line="$line"
            continue
        fi
        (( _line_count == 2 )) && printf '%s\n' "$_first_line"
        printf '%s\n' "$line"
    done
    if ! $_spinner_killed && [[ -n "$LACY_SPINNER_PID" ]]; then
        kill "$LACY_SPINNER_PID" 2>/dev/null
        sleep "$LACY_TERMINAL_FLUSH_DELAY"
        printf '\e[2K\r\e[?25h\e[?7h'
    fi
    # Single-line output: it may be a JSON error blob
    if (( _line_count == 1 )); then
        lacy_format_tool_error "$_first_line" "$tool" || printf '%s\n' "$_first_line"
    fi
}

# Framed failure summary for the generic path: exit code, the last lines the
# tool wrote (stdout then stderr, dimmed, escapes stripped), and a recovery hint.
_lacy_print_tool_failure() {
    local tool="$1" code="$2" out_file="$3" err_file="$4"
    # A single JSON error line was already rendered by the stream; do not repeat it
    local first_line=""
    IFS= read -r first_line < "$out_file" 2>/dev/null
    if [[ ! -s "$err_file" ]] && [[ "$(wc -l < "$out_file" 2>/dev/null | tr -d ' ')" == "1" ]] && \
       lacy_format_tool_error "$first_line" "$tool" >/dev/null 2>&1; then
        lacy_print_color 238 "  Check your setup: lacy doctor"
        lacy_print_color 238 "  Switch tools:     tool set <name>"
        return 0
    fi
    echo ""
    lacy_print_color 196 "  ${tool} exited with code ${code}"
    if [[ -s "$out_file" || -s "$err_file" ]]; then
        local line
        # awk 1 prints every line with a newline, so a file whose last line
        # has none (Bun's "Bun v1.x (macOS arm64)") does not glue to the next
        while IFS= read -r line || [[ -n "$line" ]]; do
            lacy_print_color 238 "  ${line}"
        done < <(awk 1 "$out_file" "$err_file" 2>/dev/null | tail -n 10 | sed $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g')
    fi
    echo ""
    lacy_print_color 238 "  Check your setup: lacy doctor"
    lacy_print_color 238 "  Switch tools:     tool set <name>"
}

# Pull a readable message out of a lash/opencode error body.
# Tries .info.error and .error shapes, then falls back to the raw body.
_lacy_server_error_message() {
    local body="$1" msg="" expr
    for expr in '.info.error.data.message' '.info.error.message' '.info.error.name' \
                '.error.data.message' '.error.message' '.error' '.data.message' '.message' '.name'; do
        msg=$(_lacy_json_query "$body" "$expr")
        [[ -n "$msg" && "$msg" != "{"* && "$msg" != "["* && "$msg" != "null" ]] && break
        msg=""
    done
    if [[ -z "$msg" ]]; then
        msg="${body//$'\n'/ }"
        (( ${#msg} > 200 )) && msg="${msg:0:200}..."
    fi
    printf '%s' "$msg"
}

# Print a server (HTTP) error in the same frame as lacy_format_tool_error.
_lacy_print_server_error() {
    local tool="$1" body="$2"
    local msg
    msg=$(_lacy_server_error_message "$body")
    echo ""
    lacy_print_color 196 "  Error from ${tool}"
    echo ""
    if [[ -n "$msg" ]]; then
        lacy_print_color 220 "  ${msg}"
    else
        lacy_print_color 220 "  The server returned an error (no details available)"
    fi
    echo ""
}

# Check if API keys are configured (used by mcp.sh)
lacy_shell_check_api_keys() {
    [[ -n "$LACY_SHELL_API_OPENAI" || -n "$LACY_SHELL_API_ANTHROPIC" || -n "$OPENAI_API_KEY" || -n "$ANTHROPIC_API_KEY" ]]
}

# ============================================================================
# Direct API Fallback (when no CLI tool installed)
# ============================================================================

lacy_shell_send_to_ai_streaming() {
    local input_file="$1"
    local query="$2"

    local provider="${LACY_SHELL_PROVIDER:-$LACY_SHELL_DEFAULT_PROVIDER}"
    local api_key_openai="${LACY_SHELL_API_OPENAI:-$OPENAI_API_KEY}"
    local api_key_anthropic="${LACY_SHELL_API_ANTHROPIC:-$ANTHROPIC_API_KEY}"

    if [[ "$provider" == "anthropic" && -n "$api_key_anthropic" ]]; then
        lacy_shell_query_anthropic "$input_file" "$api_key_anthropic"
    elif [[ -n "$api_key_openai" ]]; then
        lacy_shell_query_openai "$input_file" "$api_key_openai"
    elif [[ -n "$api_key_anthropic" ]]; then
        lacy_shell_query_anthropic "$input_file" "$api_key_anthropic"
    else
        echo "Error: No API keys configured"
        return 1
    fi
}

lacy_shell_query_openai() {
    local input_file="$1"
    local api_key="$2"
    local content
    content=$(_lacy_json_escape_str "$(cat "$input_file")")

    local response
    response=$(curl -s -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{\"model\":\"${LACY_API_MODEL_OPENAI}\",\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}],\"max_tokens\":1500}" \
        "$LACY_API_URL_OPENAI")

    _lacy_json_query "$response" '.choices[0].message.content'
}

lacy_shell_query_anthropic() {
    local input_file="$1"
    local api_key="$2"
    local content
    content=$(_lacy_json_escape_str "$(cat "$input_file")")

    local response
    response=$(curl -s -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -d "{\"model\":\"${LACY_API_MODEL_ANTHROPIC}\",\"max_tokens\":1500,\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}]}" \
        "$LACY_API_URL_ANTHROPIC")

    _lacy_json_query "$response" '.content[0].text'
}

# Stub for MCP init (no-op, lash handles MCP)
lacy_shell_init_mcp() { :; }
lacy_shell_cleanup_mcp() { :; }
