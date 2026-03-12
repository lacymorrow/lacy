#!/usr/bin/env bash

# Session management for Lacy Shell
# Shared across Bash 4+ and ZSH

# Start a fresh session with fresh context
lacy_shell_new() {
    lacy_preheat_server_stop
    
    # Reset sessions and clear latest files for all supported tools
    local t
    for t in lash claude opencode gemini; do
        # Tool-specific reset functions
        case "$t" in
            claude) lacy_preheat_claude_reset_session ;;
            gemini) lacy_preheat_gemini_reset_session ;;
        esac

        # Clear latest session files
        local session_file var_name
        eval $(_lacy_get_session_vars_for_tool "$t")
        if [[ -n "$session_file" ]]; then
            rm -f "${session_file%_*}_latest" 2>/dev/null
        fi
    done
    
    # Clear conversation history
    rm -f "$LACY_SHELL_CONVERSATION_FILE"
    
    echo ""
    lacy_print_color 34 "✨ Fresh session started"
    echo ""
}

# Resume the latest session
lacy_shell_resume() {
    echo ""
    if lacy_preheat_resume_latest; then
        lacy_print_color 34 "🔄 Resumed latest session"
    else
        lacy_print_color 196 "❌ No session found to resume"
    fi
    echo ""
}

# Clear conversation history
lacy_shell_clear_conversation() {
    rm -f "$LACY_SHELL_CONVERSATION_FILE"
    echo "Conversation history cleared"
}

# Show conversation history
lacy_shell_show_conversation() {
    if [[ -f "$LACY_SHELL_CONVERSATION_FILE" ]]; then
        cat "$LACY_SHELL_CONVERSATION_FILE"
    else
        echo "No conversation history found"
    fi
}
