# Lacy Shell: Fish prompt indicator
#
# Appends the mode badge to the right prompt. Fish has no per-keystroke hook
# without a custom event loop, so the badge updates on each new prompt.

function _lacy_mode_badge --description "Print Lacy mode badge"
    set -l style (_lacy_mode_style $LACY_SHELL_MODE)
    set -l on (_lacy_sgr "38;5;$style[1]")
    set -l off (_lacy_sgr 0)
    printf '%s%s %s%s' "$on" $style[2] $style[3] "$off"
end

# If fish_right_prompt already exists (Tide, Starship, oh-my-fish), copy it
# and wrap it so both the theme output and the Lacy badge render.
if not set -q _LACY_FISH_PROMPT_WRAPPED
    set -g _LACY_FISH_PROMPT_WRAPPED 1
    if functions -q fish_right_prompt
        functions -c fish_right_prompt _lacy_original_right_prompt
    end
    function fish_right_prompt --description "fish_right_prompt with Lacy mode badge"
        functions -q _lacy_original_right_prompt; and _lacy_original_right_prompt
        _lacy_mode_badge
    end
end

function _lacy_restore_right_prompt --description "Put the user's right prompt back"
    set -q _LACY_FISH_PROMPT_WRAPPED; or return
    functions -e fish_right_prompt
    if functions -q _lacy_original_right_prompt
        functions -c _lacy_original_right_prompt fish_right_prompt
        functions -e _lacy_original_right_prompt
    end
    set -e _LACY_FISH_PROMPT_WRAPPED
end
