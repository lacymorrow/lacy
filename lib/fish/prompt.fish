# Lacy Shell — Fish prompt indicator
#
# Appends a colored mode badge to the right prompt so users can see
# the current routing mode at a glance.
# Note: real-time per-keystroke indicator is not available in Fish
# without a custom event loop — the badge updates on each new prompt.

function fish_right_prompt --description "Show Lacy mode badge in right prompt"
    switch $LACY_SHELL_MODE
        case shell
            printf '\e[38;5;34mSHELL\e[0m'
        case agent
            printf '\e[38;5;200mAGENT\e[0m'
        case auto
            printf '\e[38;5;75mAUTO\e[0m'
    end
end
