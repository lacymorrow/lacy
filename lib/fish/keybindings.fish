# Lacy Shell: Fish keybindings
#
# Enter and Ctrl+Space are bound from fish_user_key_bindings, which fish runs
# again whenever the binding set changes (fish_vi_key_bindings and back).

function _lacy_setup_bindings --description "Register Lacy keybindings"
    # `default` is the emacs map and vi normal mode; `insert` is vi insert.
    # Enter typed while a command is still running arrives as ctrl-j (the
    # terminal maps CR to NL), so ctrl-j is routed too.
    for m in default insert
        if test "$_LACY_FISH_MAJOR" -ge 4
            bind -M $m enter _lacy_accept_line
            bind -M $m ctrl-j _lacy_accept_line
            bind -M $m ctrl-space _lacy_toggle_mode
        else
            bind -M $m \r _lacy_accept_line
            bind -M $m \n _lacy_accept_line
            bind -M $m \c@ _lacy_toggle_mode
        end
    end
end

function _lacy_remove_bindings --description "Remove Lacy keybindings"
    for m in default insert
        if test "$_LACY_FISH_MAJOR" -ge 4
            bind -M $m -e enter ctrl-j ctrl-space 2>/dev/null
        else
            bind -M $m -e \r \n \c@ 2>/dev/null
        end
    end
    if set -q _LACY_FISH_KEYS_WRAPPED
        functions -e fish_user_key_bindings
        if functions -q _lacy_user_key_bindings
            functions -c _lacy_user_key_bindings fish_user_key_bindings
            functions -e _lacy_user_key_bindings
            fish_user_key_bindings
        end
        set -e _LACY_FISH_KEYS_WRAPPED
    end
end

function _lacy_next_mode --description "Cycle modes: auto, shell, agent"
    switch "$LACY_SHELL_MODE"
        case auto
            _lacy_set_mode shell
        case shell
            _lacy_set_mode agent
        case '*'
            _lacy_set_mode auto
    end
end

function _lacy_toggle_mode --description "Cycle through shell/agent/auto modes"
    _lacy_next_mode
    printf '\n'
    _lacy_print_mode_line
    commandline -f repaint
end

# Wrap the user's fish_user_key_bindings: copy it aside with `functions -c`
# and call the copy, then add Lacy's bindings. Done once per session so a
# second source never wraps the wrapper.
if not set -q _LACY_FISH_KEYS_WRAPPED
    set -g _LACY_FISH_KEYS_WRAPPED 1
    if functions -q fish_user_key_bindings
        functions -c fish_user_key_bindings _lacy_user_key_bindings
    end
    function fish_user_key_bindings --description "User key bindings, then Lacy's"
        functions -q _lacy_user_key_bindings; and _lacy_user_key_bindings
        _lacy_setup_bindings
    end
end

# Loaded after fish set up its bindings (e.g. re-enabled with `lacy`): bind now
status is-interactive; and _lacy_setup_bindings
