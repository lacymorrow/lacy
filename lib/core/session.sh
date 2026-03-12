#!/usr/bin/env bash

# Session management for Lacy Shell
# Shared across Bash 4+ and ZSH

# Start a fresh session with fresh context
lacy_shell_new() {
    lacy_preheat_server_stop
    lacy_preheat_claude_reset_session
    lacy_preheat_gemini_reset_session
    
    # Clear latest session files
    rm -f "${LACY_PREHEAT_SERVER_SESSION_FILE%_*}_latest" 2>/dev/null
    rm -f "${LACY_PREHEAT_SESSION_FILE%_*}_latest" 2>/dev/null
    rm -f "${LACY_GEMINI_SESSION_ID_FILE%_*}_latest" 2>/dev/null
    
    # Clear conversation history
    rm -f "$LACY_SHELL_CONVERSATION_FILE"
    
    echo ""
    lacy_print_color 34 "✨ Fresh session started"
    echo ""
}

# Resume the latest session
lacy_shell_resume() {
    if lacy_preheat_resume_latest; then
        echo ""
        lacy_print_color 34 "🔄 Resumed latest session"
        echo ""
    else
        echo ""
        lacy_print_color 196 "❌ No session found to resume"
        echo ""
    fi
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
