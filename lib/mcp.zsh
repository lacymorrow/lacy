#!/usr/bin/env zsh

# Agent query functions for Lacy Shell
# Routes queries to configured AI CLI tools

# Tool registry with command patterns
# Format: tool_name -> "command args" where query is appended or uses quoting
typeset -gA LACY_TOOL_CMD=(
    [lash]="lash run -c"
    [claude]="claude -p"
    [opencode]="opencode run"
    [gemini]="gemini -p"
    [codex]="codex exec"
)

# Active tool (set during install or via config)
: ${LACY_ACTIVE_TOOL:=""}

# Send query to AI agent (configurable tool or fallback)
lacy_shell_query_agent() {
    local query="$1"
    local tool="${LACY_ACTIVE_TOOL}"

    # Auto-detect if not set
    if [[ -z "$tool" ]]; then
        for t in lash claude opencode gemini codex; do
            if command -v "$t" >/dev/null 2>&1; then
                tool="$t"
                break
            fi
        done
    fi

    # If still no tool, try API fallback
    if [[ -z "$tool" ]]; then
        if lacy_shell_check_api_keys; then
            echo ""
            local temp_file=$(mktemp)
            cat > "$temp_file" << EOF
Current Directory: $(pwd)
Query: $query
EOF
            lacy_start_spinner
            lacy_shell_send_to_ai_streaming "$temp_file" "$query"
            local exit_code=$?
            lacy_stop_spinner
            rm -f "$temp_file"
            echo ""
            return $exit_code
        fi

        echo "No AI CLI tool found. Install one of: lash, claude, opencode, gemini, codex"
        echo ""
        echo "Install options:"
        echo "  lash:     npm install -g lash-cli"
        echo "  claude:   brew install claude"
        echo "  opencode: brew install opencode"
        echo "  gemini:   brew install gemini"
        echo "  codex:    npm install -g @openai/codex"
        return 1
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
        cmd="${LACY_TOOL_CMD[$tool]}"
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
        json_output=$(eval "$claude_cmd \"\$query\"" </dev/tty 2>&1)
        local exit_code=$?
        lacy_stop_spinner

        if [[ $exit_code -eq 0 ]]; then
            # Extract and display result
            local result_text
            result_text=$(lacy_preheat_claude_extract_result "$json_output")
            if [[ -n "$result_text" ]]; then
                printf '%s\n' "$result_text"
            else
                # JSON parsing failed or no result field — show raw output
                printf '%s\n' "$json_output"
            fi
            # Capture session for next query
            lacy_preheat_claude_capture_session "$json_output"
            echo ""
            return 0
        elif [[ -n "$LACY_PREHEAT_CLAUDE_SESSION_ID" ]]; then
            # --resume failed with existing session — retry without it
            lacy_preheat_claude_reset_session
            claude_cmd=$(lacy_preheat_claude_build_cmd)
            lacy_start_spinner
            json_output=$(eval "$claude_cmd \"\$query\"" </dev/tty 2>&1)
            exit_code=$?
            lacy_stop_spinner

            if [[ $exit_code -eq 0 ]]; then
                local result_text
                result_text=$(lacy_preheat_claude_extract_result "$json_output")
                if [[ -n "$result_text" ]]; then
                    printf '%s\n' "$result_text"
                else
                    printf '%s\n' "$json_output"
                fi
                lacy_preheat_claude_capture_session "$json_output"
                echo ""
                return 0
            fi
            # Both attempts failed — show raw output
            printf '%s\n' "$json_output"
            echo ""
            return $exit_code
        else
            # No session to reset — show raw output
            printf '%s\n' "$json_output"
            echo ""
            return $exit_code
        fi
    fi

    # === Generic path (gemini, codex, custom, and fallback) ===
    echo ""
    lacy_start_spinner
    eval "$cmd \"\$query\"" </dev/tty 2>&1 | {
        local _spinner_killed=false
        while IFS= read -r line; do
            if ! $_spinner_killed; then
                # First output from tool — kill spinner
                if [[ -n "$LACY_SPINNER_PID" ]] && kill -0 "$LACY_SPINNER_PID" 2>/dev/null; then
                    kill "$LACY_SPINNER_PID" 2>/dev/null
                    # Brief delay for spinner's terminal output to flush
                    sleep "$LACY_TERMINAL_FLUSH_DELAY"
                    printf '\e[2K\r\e[?25h'
                fi
                _spinner_killed=true
            fi
            printf '%s\n' "$line"
        done
        # Tool exited with no output
        if ! $_spinner_killed && [[ -n "$LACY_SPINNER_PID" ]]; then
            kill "$LACY_SPINNER_PID" 2>/dev/null
            sleep "$LACY_TERMINAL_FLUSH_DELAY"
            printf '\e[2K\r\e[?25h'
        fi
    }
    local exit_code=${pipestatus[1]}
    lacy_stop_spinner
    echo ""
    return $exit_code
}

# Check if API keys are configured
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
    local content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

    local response=$(curl -s -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{\"model\":\"${LACY_API_MODEL_OPENAI}\",\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}],\"max_tokens\":1500}" \
        "https://api.openai.com/v1/chat/completions")

    echo "$response" | grep -o '"content":"[^"]*' | sed 's/"content":"//' | head -1
}

lacy_shell_query_anthropic() {
    local input_file="$1"
    local api_key="$2"
    local content=$(cat "$input_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

    local response=$(curl -s -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -d "{\"model\":\"${LACY_API_MODEL_ANTHROPIC}\",\"max_tokens\":1500,\"messages\":[{\"role\":\"user\",\"content\":\"$content\"}]}" \
        "https://api.anthropic.com/v1/messages")

    echo "$response" | grep -o '"text":"[^"]*' | sed 's/"text":"//' | head -1
}

# Stub for MCP init (no-op, lash handles MCP)
lacy_shell_init_mcp() { :; }
lacy_shell_cleanup_mcp() { :; }
