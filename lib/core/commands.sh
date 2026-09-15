#!/usr/bin/env bash

# Shared command implementations, portable across Bash 4+ and ZSH
# Uses lacy_print_color / lacy_print_color_n from constants.sh for output.
# Sourced by lib/zsh/init.zsh and lib/bash/init.bash after all core modules.

# === Helpers ===

# Print colored indicator character + message on one line
# Usage: _lacy_print_indicator_msg <color> <message>
_lacy_print_indicator_msg() {
    local color="$1" msg="$2"
    lacy_print_color_n "$color" "  ${LACY_INDICATOR_CHAR}"
    echo " $msg"
}

# === Agent Execution ===

# Execute a query via the AI agent.
# lacy_shell_query_agent explains the failures it understands (no tool, tool
# errors, server errors). Generic recovery hints are printed only when it did
# not, and never after a signal such as Ctrl+C.
lacy_shell_execute_agent() {
    local query="$1"
    local rc
    lacy_shell_query_agent "$query"
    rc=$?
    (( rc == 0 )) && return 0
    (( rc >= LACY_SIGNAL_EXIT_THRESHOLD )) && return 0
    if [[ "$_LACY_QUERY_GUIDED" != true ]]; then
        echo ""
        lacy_print_color 238 "$LACY_MSG_RECOVERY_TOOL"
        lacy_print_color 238 "$LACY_MSG_RECOVERY_ASK"
        lacy_print_color 238 "$LACY_MSG_RECOVERY_DOCTOR"
        echo ""
    fi
    return 0
}

# === Mode Command ===

lacy_shell_mode() {
    case "$1" in
        "shell"|"s")
            lacy_shell_set_mode "shell"
            [[ "$LACY_SHELL_TYPE" == "zsh" ]] && lacy_shell_update_rprompt 2>/dev/null
            echo ""
            _lacy_print_indicator_msg "$LACY_COLOR_SHELL" "$LACY_MSG_MODE_SHELL"
            echo ""
            ;;
        "agent"|"a")
            lacy_shell_set_mode "agent"
            [[ "$LACY_SHELL_TYPE" == "zsh" ]] && lacy_shell_update_rprompt 2>/dev/null
            echo ""
            _lacy_print_indicator_msg "$LACY_COLOR_AGENT" "$LACY_MSG_MODE_AGENT"
            echo ""
            ;;
        "auto"|"u")
            lacy_shell_set_mode "auto"
            [[ "$LACY_SHELL_TYPE" == "zsh" ]] && lacy_shell_update_rprompt 2>/dev/null
            echo ""
            _lacy_print_indicator_msg "$LACY_COLOR_AUTO" "$LACY_MSG_MODE_AUTO"
            echo ""
            ;;
        "toggle"|"t")
            lacy_shell_toggle_mode
            [[ "$LACY_SHELL_TYPE" == "zsh" ]] && lacy_shell_update_rprompt 2>/dev/null
            local new_mode="$LACY_SHELL_CURRENT_MODE"
            echo ""
            case "$new_mode" in
                "shell") _lacy_print_indicator_msg "$LACY_COLOR_SHELL" "$LACY_MSG_MODE_SHELL_SHORT" ;;
                "agent") _lacy_print_indicator_msg "$LACY_COLOR_AGENT" "$LACY_MSG_MODE_AGENT_SHORT" ;;
                "auto")  _lacy_print_indicator_msg "$LACY_COLOR_AUTO" "$LACY_MSG_MODE_AUTO_SHORT" ;;
            esac
            echo ""
            ;;
        "status")
            lacy_shell_mode_status
            ;;
        *)
            lacy_shell_mode_status
            ;;
    esac
}

# === Tool Command ===

# Save the tool choice to config.yaml (agent_tools.active, plus
# agent_tools.custom_command for custom) and say whether it stuck.
# Usage: _lacy_tool_persist <name|auto|custom> [custom_command]
_lacy_tool_persist() {
    local name="$1" custom_cmd="$2" ok=true
    local active="$name"
    [[ "$name" == "auto" ]] && active=""

    if [[ "$name" == "custom" ]]; then
        lacy_config_set agent_tools custom_command "$custom_cmd" || ok=false
    fi
    if [[ "$ok" == true ]]; then
        lacy_config_set agent_tools active "$active" || ok=false
    fi

    if [[ "$ok" == true ]]; then
        lacy_print_color 238 "Saved to ${LACY_SHELL_CONFIG_FILE}"
    else
        lacy_print_color 196 "Not saved (${_LACY_CONFIG_SET_ERROR}). Applies to this shell only."
        return 1
    fi
}

lacy_shell_tool() {
    case "$1" in
        "")
            echo ""
            if [[ "$LACY_ACTIVE_TOOL" == "custom" ]]; then
                echo "Active tool: custom (${LACY_CUSTOM_TOOL_CMD:-not configured})"
            elif [[ -z "$LACY_ACTIVE_TOOL" ]]; then
                local _detected=""
                local _t
                for _t in "${LACY_TOOL_LIST[@]}"; do
                    if command -v "$_t" >/dev/null 2>&1; then
                        _detected="$_t"
                        break
                    fi
                done
                if [[ -n "$_detected" ]]; then
                    echo "Active tool: auto-detect (using $_detected)"
                else
                    echo "Active tool: auto-detect (no tools found)"
                fi
            else
                echo "Active tool: ${LACY_ACTIVE_TOOL}"
            fi
            echo ""
            echo "Available tools:"
            local t
            for t in "${LACY_TOOL_LIST[@]}"; do
                if command -v "$t" >/dev/null 2>&1; then
                    lacy_print_color_n 34 "  ✓"
                    echo " $t"
                else
                    lacy_print_color_n 238 "  ○"
                    echo " $t (not installed)"
                fi
            done
            if [[ -n "$LACY_CUSTOM_TOOL_CMD" ]]; then
                lacy_print_color_n 34 "  ✓"
                echo " custom ($LACY_CUSTOM_TOOL_CMD)"
            else
                lacy_print_color_n 238 "  ○"
                echo " custom (not configured)"
            fi
            echo ""
            echo "Usage: tool set <name>"
            echo "       tool set custom \"command -flags\""
            echo ""
            ;;
        set)
            local _name="$2"
            if [[ -z "$_name" ]]; then
                echo "Usage: tool set <name>"
                echo "Options: $(_lacy_tool_list_joined), custom, auto"
                echo "  tool set custom \"command -flags\""
                return 1
            fi
            if [[ "$_name" != "auto" && "$_name" != "custom" ]] && \
               ! _lacy_in_list "$_name" "${LACY_TOOL_LIST[@]}"; then
                echo "Unknown tool: $_name"
                echo "Options: $(_lacy_tool_list_joined), custom, auto"
                return 1
            fi
            if [[ "$_name" == "custom" && -z "${3//[[:space:]]/}" ]]; then
                echo "Usage: tool set custom \"command -flags\""
                echo "Example: tool set custom \"claude --dangerously-skip-permissions -p\""
                return 1
            fi
            if [[ "$_name" == "custom" ]] && ! _lacy_split_cmd "$3"; then
                echo "Could not read that command (unbalanced quotes): $3"
                return 1
            fi

            lacy_preheat_cleanup
            case "$_name" in
                auto)
                    LACY_ACTIVE_TOOL=""
                    echo "Tool set to: auto-detect"
                    ;;
                custom)
                    LACY_ACTIVE_TOOL="custom"
                    LACY_CUSTOM_TOOL_CMD="$3"
                    echo "Tool set to: custom ($LACY_CUSTOM_TOOL_CMD)"
                    ;;
                *)
                    LACY_ACTIVE_TOOL="$_name"
                    echo "Tool set to: $_name"
                    ;;
            esac
            _lacy_tool_persist "$_name" "$3"
            ;;
        *)
            echo "Usage: tool [set <name>]"
            echo "Options: $(_lacy_tool_list_joined), custom, auto"
            echo "  tool set custom \"command -flags\""
            ;;
    esac
}

# === Conversation Management ===

lacy_shell_clear_conversation() {
    command rm -f "$LACY_SHELL_CONVERSATION_FILE"
    echo "$LACY_MSG_CONVERSATION_CLEARED"
}

lacy_shell_show_conversation() {
    if [[ -f "$LACY_SHELL_CONVERSATION_FILE" ]]; then
        cat "$LACY_SHELL_CONVERSATION_FILE"
    else
        echo "$LACY_MSG_NO_CONVERSATION"
    fi
}

# === Session Command Override ===

# Override lacy command to handle session subcommands without subprocess
lacy() {
    local cmd="${1:-}"
    cmd="${cmd#/}"  # strip optional leading slash (/new → new)
    case "$cmd" in
        new|reset|clear) lacy_session_new ;;
        resume)          lacy_session_resume ;;
        *)               command lacy "$@" ;;
    esac
}
