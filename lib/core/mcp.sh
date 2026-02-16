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
# Tool Command Execution
# ============================================================================

# Run a tool command safely — splits command string into array to avoid eval.
# Usage: _lacy_run_tool_cmd "cmd string" "query"
_lacy_run_tool_cmd() {
    local cmd_str="$1"
    local query="$2"
    local -a cmd_parts
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        cmd_parts=( ${=cmd_str} )
    else
        read -ra cmd_parts <<< "$cmd_str"
    fi
    "${cmd_parts[@]}" "$query"
}

# Tool registry — function-based for maximum portability
# Usage: cmd=$(lacy_tool_cmd <tool_name>)
lacy_tool_cmd() {
    case "$1" in
        lash)     echo "lash run -c" ;;
        claude)   echo "claude -p" ;;
        opencode) echo "opencode run -c" ;;
        gemini)   echo "gemini --resume -p" ;;
        codex)    echo "codex exec resume --last" ;;
        *)        echo "" ;;
    esac
}

# Active tool (set during install or via config)
: "${LACY_ACTIVE_TOOL:=""}"

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

# Send query to AI agent (configurable tool or fallback)
lacy_shell_query_agent() {
    local query="$1"
    local tool="${LACY_ACTIVE_TOOL}"

    # Auto-detect if not set
    local _auto_detected=false
    if [[ -z "$tool" ]]; then
        local t
        for t in lash claude opencode gemini codex; do
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
Current Directory: $(pwd)
Query: $query
EOF
            echo ""
            lacy_start_spinner
            lacy_shell_send_to_ai_streaming "$temp_file" "$query"
            local exit_code=$?
            lacy_stop_spinner
            rm -f "$temp_file"
            echo ""
            return $exit_code
        fi

        echo ""
        echo "No AI CLI tool found."
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
            echo "Would you like to install lash (recommended)?"
            echo ""
            if [[ -t 0 ]]; then
                read -p "Install lash now? [Y/n]: " install_now
            else
                read -p "Install lash now? [Y/n]: " install_now < /dev/tty 2>/dev/null || install_now="n"
            fi

            if [[ ! "$install_now" =~ ^[Nn]$ ]]; then
                echo ""
                if command -v npm >/dev/null 2>&1; then
                    echo "Installing lash..."
                    if npm install -g lashcode; then
                        echo ""
                        echo "lash installed! Re-running your query..."
                        echo ""
                        tool="lash"
                    else
                        echo ""
                        echo "Installation failed. You can try manually: npm install -g lashcode"
                        return 1
                    fi
                elif command -v brew >/dev/null 2>&1; then
                    echo "Installing lash..."
                    if brew tap lacymorrow/tap && brew install lash; then
                        echo ""
                        echo "lash installed! Re-running your query..."
                        echo ""
                        tool="lash"
                    else
                        echo ""
                        echo "Installation failed. You can try manually: brew install lacymorrow/tap/lash"
                        return 1
                    fi
                else
                    echo "Neither npm nor brew found. Please install one of them first, then run:"
                    echo "  npm install -g lashcode"
                    return 1
                fi
            else
                echo ""
                echo "Install options:"
                echo "  lash:     npm install -g lashcode"
                echo "  claude:   brew install claude"
                echo "  opencode: brew install opencode"
                echo "  gemini:   brew install gemini"
                echo "  codex:    npm install -g @openai/codex"
                return 1
            fi
        else
            echo "Install an AI CLI tool to get started:"
            echo ""
            echo "  npm install -g lashcode     (recommended)"
            echo "  brew install claude"
            echo "  brew install opencode"
            echo "  brew install gemini"
            echo "  npm install -g @openai/codex"
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
    fi

    # Show which tool was auto-detected
    if [[ "$_auto_detected" == true ]]; then
        lacy_print_color 238 "  Using $tool (auto-detected)"
    fi

    # === Preheat: lash/opencode background server ===
    if [[ "$tool" == "lash" || "$tool" == "opencode" ]]; then
        if lacy_preheat_server_is_healthy || lacy_preheat_server_start "$tool"; then
            echo ""
            lacy_start_spinner
            local server_result
            server_result=$(lacy_preheat_server_query "$query")
            local exit_code=$?
            lacy_stop_spinner
            if [[ $exit_code -eq 0 && -n "$server_result" ]]; then
                while [[ "$server_result" == $'\n'* ]]; do server_result="${server_result#$'\n'}"; done
                printf '%s\n' "$server_result"
                echo ""
                return 0
            fi
            # Server query failed — fall through to single-shot
        fi
    fi

    # === Preheat: claude session reuse ===
    if [[ "$tool" == "claude" ]]; then
        local claude_cmd
        claude_cmd=$(lacy_preheat_claude_build_cmd)
        echo ""
        lacy_start_spinner
        local json_output
        json_output=$(_lacy_run_tool_cmd "$claude_cmd" "$query" </dev/tty 2>&1)
        local exit_code=$?
        lacy_stop_spinner

        # Strip agent startup noise (e.g. "> build · big-pickle") before JSON parsing
        json_output=$(_lacy_strip_leading_noise "$json_output")

        if [[ $exit_code -eq 0 ]]; then
            # Check for structured errors (e.g. invalid API key)
            if lacy_format_tool_error "$json_output" "$tool"; then
                return 1
            fi
            local result_text
            result_text=$(lacy_preheat_claude_extract_result "$json_output")
            while [[ "$result_text" == $'\n'* ]]; do result_text="${result_text#$'\n'}"; done
            if [[ -n "$result_text" ]]; then
                printf '%s\n' "$result_text"
            else
                printf '%s\n' "$json_output"
            fi
            lacy_preheat_claude_capture_session "$json_output"
            echo ""
            return 0
        elif [[ -n "$LACY_PREHEAT_CLAUDE_SESSION_ID" ]]; then
            lacy_preheat_claude_reset_session
            claude_cmd=$(lacy_preheat_claude_build_cmd)
            lacy_start_spinner
            json_output=$(_lacy_run_tool_cmd "$claude_cmd" "$query" </dev/tty 2>&1)
            exit_code=$?
            lacy_stop_spinner

            # Strip agent startup noise before JSON parsing
            json_output=$(_lacy_strip_leading_noise "$json_output")

            # Check for structured errors before processing
            if lacy_format_tool_error "$json_output" "$tool"; then
                return 1
            fi

            if [[ $exit_code -eq 0 ]]; then
                local result_text
                result_text=$(lacy_preheat_claude_extract_result "$json_output")
                while [[ "$result_text" == $'\n'* ]]; do result_text="${result_text#$'\n'}"; done
                if [[ -n "$result_text" ]]; then
                    printf '%s\n' "$result_text"
                else
                    printf '%s\n' "$json_output"
                fi
                lacy_preheat_claude_capture_session "$json_output"
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

    # === Generic path (gemini, codex, custom, and fallback) ===
    echo ""
    lacy_start_spinner
    _lacy_run_tool_cmd "$cmd" "$query" </dev/tty 2>&1 | {
        local _spinner_killed=false
        local _full_output=""
        local _line_count=0
        while IFS= read -r line; do
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
            _full_output+="$line"
            (( _line_count++ ))
            # Only buffer first line to check for JSON errors
            if (( _line_count > 1 )); then
                # Multi-line output — not a JSON error blob, flush everything
                if [[ $_line_count -eq 2 ]]; then
                    printf '%s\n' "$_full_output"
                fi
                printf '%s\n' "$line"
            fi
        done
        if ! $_spinner_killed && [[ -n "$LACY_SPINNER_PID" ]]; then
            kill "$LACY_SPINNER_PID" 2>/dev/null
            sleep "$LACY_TERMINAL_FLUSH_DELAY"
            printf '\e[2K\r\e[?25h\e[?7h'
        fi
        # Single-line output — check if it's a JSON error
        if (( _line_count <= 1 )); then
            lacy_format_tool_error "$_full_output" "$tool" || printf '%s\n' "$_full_output"
        fi
    }
    local exit_code
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        exit_code=${pipestatus[1]}
    else
        exit_code=${PIPESTATUS[0]}
    fi
    lacy_stop_spinner
    echo ""
    return $exit_code
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
    content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

    local response
    response=$(curl -s -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{\"model\":\"${LACY_API_MODEL_OPENAI}\",\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}],\"max_tokens\":1500}" \
        "https://api.openai.com/v1/chat/completions")

    _lacy_json_query "$response" '.choices[0].message.content'
}

lacy_shell_query_anthropic() {
    local input_file="$1"
    local api_key="$2"
    local content
    content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

    local response
    response=$(curl -s -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -d "{\"model\":\"${LACY_API_MODEL_ANTHROPIC}\",\"max_tokens\":1500,\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}]}" \
        "https://api.anthropic.com/v1/messages")

    _lacy_json_query "$response" '.content[0].text'
}

# Stub for MCP init (no-op, lash handles MCP)
lacy_shell_init_mcp() { :; }
lacy_shell_cleanup_mcp() { :; }
