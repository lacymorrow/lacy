#!/usr/bin/env bash

# Shared command implementations — portable across Bash 4+ and ZSH
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

# Check if any tool from LACY_TOOL_LIST is installed
_lacy_is_any_tool_installed() {
    local _t
    for _t in "${LACY_TOOL_LIST[@]}"; do
        command -v "$_t" >/dev/null 2>&1 && return 0
    done
    return 1
}

# === Agent Execution ===

# Execute command via AI agent — shows error hints on failure
lacy_shell_execute_agent() {
    local query="$1"

    if ! lacy_shell_query_agent "$query"; then
        if [[ -z "$LACY_ACTIVE_TOOL" ]] && ! _lacy_is_any_tool_installed; then
            echo ""
            lacy_print_color 196 "$LACY_MSG_NO_TOOL"
            echo ""
            lacy_print_color 238 "$LACY_MSG_INSTALL_HINT"
            lacy_print_color 238 "$LACY_MSG_CONFIGURE_HINT"
            echo ""
        else
            local _tool="${LACY_ACTIVE_TOOL}"
            if [[ -z "$_tool" ]]; then
                local _t
                for _t in "${LACY_TOOL_LIST[@]}"; do
                    if command -v "$_t" >/dev/null 2>&1; then
                        _tool="$_t"
                        break
                    fi
                done
            fi
            echo ""
            lacy_print_color 238 "$LACY_MSG_RECOVERY_TOOL"
            lacy_print_color 238 "$LACY_MSG_RECOVERY_ASK"
            lacy_print_color 238 "$LACY_MSG_RECOVERY_DOCTOR"
            echo ""
        fi
    fi
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
            echo ""
            echo "Usage: mode [shell|agent|auto|toggle|status]"
            echo ""
            echo -n "Current: "
            case "$LACY_SHELL_CURRENT_MODE" in
                "shell") lacy_print_color "$LACY_COLOR_SHELL" "SHELL" ;;
                "agent") lacy_print_color "$LACY_COLOR_AGENT" "AGENT" ;;
                "auto")  lacy_print_color "$LACY_COLOR_AUTO" "AUTO" ;;
            esac
            echo ""
            echo "Colors:"
            _lacy_print_indicator_msg "$LACY_COLOR_SHELL" "$LACY_MSG_COLOR_SHELL"
            _lacy_print_indicator_msg "$LACY_COLOR_AGENT" "$LACY_MSG_COLOR_AGENT"
            echo ""
            ;;
    esac
}

# === Tool Command ===

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
            if [[ -z "$2" ]]; then
                echo "Usage: tool set <name>"
                echo "Options: lash, claude, opencode, gemini, codex, custom, auto"
                echo "  tool set custom \"command -flags\""
                return 1
            fi
            if [[ "$2" == "auto" ]]; then
                lacy_preheat_cleanup
                LACY_ACTIVE_TOOL=""
                export LACY_ACTIVE_TOOL
                echo "Tool set to: auto-detect"
            elif [[ "$2" == "custom" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: tool set custom \"command -flags\""
                    echo "Example: tool set custom \"claude --dangerously-skip-permissions -p\""
                    return 1
                fi
                lacy_preheat_cleanup
                LACY_ACTIVE_TOOL="custom"
                LACY_CUSTOM_TOOL_CMD="$3"
                export LACY_ACTIVE_TOOL LACY_CUSTOM_TOOL_CMD
                echo "Tool set to: custom ($LACY_CUSTOM_TOOL_CMD)"
            else
                lacy_preheat_cleanup
                LACY_ACTIVE_TOOL="$2"
                export LACY_ACTIVE_TOOL
                echo "Tool set to: $2"
            fi
            ;;
        *)
            echo "Usage: tool [set <name>]"
            echo "Options: lash, claude, opencode, gemini, codex, custom, auto"
            echo "  tool set custom \"command -flags\""
            ;;
    esac
}

# === Spinner Command ===

lacy_shell_spinner() {
    case "$1" in
        "")
            echo ""
            echo "Active spinner: ${LACY_SPINNER_STYLE:-braille}"
            echo ""
            echo "Available animations:"
            lacy_list_spinner_animations
            echo ""
            echo "Usage: spinner set <name>"
            echo "       spinner preview [name|all]"
            echo ""
            ;;
        set)
            if [[ -z "$2" ]]; then
                echo "Usage: spinner set <name>"
                echo "Available: ${LACY_SPINNER_ANIMATIONS[*]} random"
                return 1
            fi
            if [[ "$2" == "random" ]] || _lacy_in_list "$2" "${LACY_SPINNER_ANIMATIONS[@]}"; then
                LACY_SPINNER_STYLE="$2"
                export LACY_SPINNER_STYLE
                echo "Spinner set to: $2"
            else
                echo "Unknown animation: $2"
                echo "Available: ${LACY_SPINNER_ANIMATIONS[*]} random"
                return 1
            fi
            ;;
        preview)
            if [[ "$2" == "all" ]]; then
                echo "Previewing all animations (Ctrl+C to stop)"
                echo ""
                lacy_preview_all_spinners 5
            else
                local style="${2:-${LACY_SPINNER_STYLE:-braille}}"
                if [[ "$style" != "random" ]] && ! _lacy_in_list "$style" "${LACY_SPINNER_ANIMATIONS[@]}"; then
                    echo "Unknown animation: $style"
                    return 1
                fi
                local _saved="$LACY_SPINNER_STYLE"
                LACY_SPINNER_STYLE="$style"
                echo "Previewing: $style (Ctrl+C to stop)"
                lacy_start_spinner
                sleep 3
                lacy_stop_spinner
                LACY_SPINNER_STYLE="$_saved"
            fi
            ;;
        *)
            echo "Usage: spinner [set <name> | preview [name|all]]"
            ;;
    esac
}

# === Conversation Management ===

lacy_shell_clear_conversation() {
    rm -f "$LACY_SHELL_CONVERSATION_FILE"
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
