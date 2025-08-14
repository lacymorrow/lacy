#!/usr/bin/env zsh

# Keybinding setup for Lacy Shell

# Set up all keybindings
lacy_shell_setup_keybindings() {
    # Enable emacs mode (more compatible)
    bindkey -e
    
    # Primary mode toggle - Ctrl+Space (most universal)
    bindkey '^@' lacy_shell_toggle_mode_widget      # Ctrl+Space: Toggle mode
    
    # Alternative keybindings
    bindkey '^T' lacy_shell_toggle_mode_widget      # Ctrl+T: Toggle mode (backup)
    
    # Direct mode switches (Ctrl+X prefix)
    bindkey '^X^A' lacy_shell_agent_mode_widget     # Ctrl+X Ctrl+A: Agent mode
    bindkey '^X^S' lacy_shell_shell_mode_widget     # Ctrl+X Ctrl+S: Shell mode  
    bindkey '^X^U' lacy_shell_auto_mode_widget      # Ctrl+X Ctrl+U: Auto mode
    bindkey '^X^H' lacy_shell_help_widget           # Ctrl+X Ctrl+H: Help
}

# Widget to toggle mode
lacy_shell_toggle_mode_widget() {
    lacy_shell_toggle_mode
    zle reset-prompt
}

# Widget to switch to agent mode
lacy_shell_agent_mode_widget() {
    lacy_shell_set_mode "agent"
    zle reset-prompt
}

# Widget to switch to shell mode
lacy_shell_shell_mode_widget() {
    lacy_shell_set_mode "shell"
    zle reset-prompt
}

# Widget to switch to auto mode
lacy_shell_auto_mode_widget() {
    lacy_shell_set_mode "auto"
    zle reset-prompt
}

# Widget to show help
lacy_shell_help_widget() {
    echo ""
    echo "Lacy Shell Help:"
    echo "================"
    echo "Modes:"
    echo "  Shell: Normal shell execution (\$)"
    echo "  Agent: AI-powered assistance (?)"
    echo "  Auto:  Smart detection (~)"
    echo ""
    echo "Keybindings:"
    echo "  Ctrl+Space:    Toggle mode (primary)"
    echo "  Ctrl+T:        Toggle mode (backup)"
    echo "  Ctrl+X Ctrl+A: Agent mode"
    echo "  Ctrl+X Ctrl+S: Shell mode"
    echo "  Ctrl+X Ctrl+U: Auto mode"
    echo "  Ctrl+X Ctrl+H: This help"
    echo ""
    echo "Commands:"
    echo "  ask \"question\"     - Direct AI query"
    echo "  clear_chat         - Clear conversation"
    echo ""
    echo "Current mode: $LACY_SHELL_CURRENT_MODE"
    zle reset-prompt
}

# Enhanced execute line widget that shows mode info
lacy_shell_execute_line_widget() {
    local input="$BUFFER"
    
    # If buffer is empty, just accept line normally
    if [[ -z "$input" ]]; then
        zle accept-line
        return
    fi
    
    # Silent execution - mode shows in prompt
    
    # Accept the line for normal processing
    zle accept-line
}

# Register all widgets
zle -N lacy_shell_toggle_mode_widget
zle -N lacy_shell_agent_mode_widget
zle -N lacy_shell_shell_mode_widget
zle -N lacy_shell_auto_mode_widget
zle -N lacy_shell_help_widget
zle -N lacy_shell_execute_line_widget

# Alternative keybindings that don't conflict with system shortcuts
lacy_shell_setup_safe_keybindings() {
    # Use Alt-based bindings that are less likely to conflict
    bindkey '^[^M' lacy_shell_toggle_mode_widget    # Alt+Enter
    bindkey '^[1' lacy_shell_shell_mode_widget      # Alt+1
    bindkey '^[2' lacy_shell_agent_mode_widget      # Alt+2  
    bindkey '^[3' lacy_shell_auto_mode_widget       # Alt+3
    bindkey '^[h' lacy_shell_help_widget            # Alt+H
    
    echo "Using safe keybindings:"
    echo "  Alt+Enter: Toggle mode"
    echo "  Alt+1:     Shell mode"
    echo "  Alt+2:     Agent mode"
    echo "  Alt+3:     Auto mode"
    echo "  Alt+H:     Help"
}
