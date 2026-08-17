# Lacy Shell — Fish keybindings
#
# Registers key bindings after all other modules are loaded.
# Uses fish_user_key_bindings so it coexists with other plugins.

function _lacy_setup_bindings --description "Register Lacy keybindings"
    # Override Enter to route through Lacy's classifier
    bind \n _lacy_accept_line
    bind \r _lacy_accept_line

    # Ctrl+Space to cycle modes: auto → shell → agent → auto
    bind \c@ _lacy_toggle_mode
    bind \e\[32~ _lacy_toggle_mode
end

function _lacy_toggle_mode --description "Cycle through shell/agent/auto modes"
    switch $LACY_SHELL_MODE
        case auto
            set -g LACY_SHELL_MODE shell
            printf '\n\e[38;5;34m  ▌ SHELL mode\e[0m\n'
        case shell
            set -g LACY_SHELL_MODE agent
            printf '\n\e[38;5;200m  ▌ AGENT mode\e[0m\n'
        case agent
            set -g LACY_SHELL_MODE auto
            printf '\n\e[38;5;75m  ▌ AUTO mode\e[0m\n'
    end
    commandline -f repaint
end

# Register after user bindings so we don't clobber them unless necessary.
if functions -q fish_user_key_bindings
    functions -c fish_user_key_bindings _lacy_original_key_bindings
    function fish_user_key_bindings
        _lacy_original_key_bindings
        _lacy_setup_bindings
    end
else
    function fish_user_key_bindings
        _lacy_setup_bindings
    end
end
