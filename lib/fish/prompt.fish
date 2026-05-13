# Lacy Shell — Fish prompt indicator
#
# Appends a colored mode badge to the right prompt.
# Note: real-time per-keystroke indicator is not available in Fish
# without a custom event loop — the badge updates on each new prompt.

function _lacy_mode_badge --description "Print Lacy mode badge"
    switch $LACY_SHELL_MODE
        case shell
            printf '\e[38;5;34mSHELL\e[0m'
        case agent
            printf '\e[38;5;200mAGENT\e[0m'
        case auto
            printf '\e[38;5;75mAUTO\e[0m'
    end
end

# If fish_right_prompt already exists (e.g. Tide, Starship, oh-my-fish),
# copy it and wrap it so both the theme output and Lacy badge render.
if functions -q fish_right_prompt
    functions -c fish_right_prompt _lacy_original_right_prompt
    function fish_right_prompt --description "fish_right_prompt with Lacy mode badge"
        _lacy_original_right_prompt
        _lacy_mode_badge
    end
else
    function fish_right_prompt --description "Show Lacy mode badge in right prompt"
        _lacy_mode_badge
    end
end
