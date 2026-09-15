#!/usr/bin/env zsh

# Prompt handling for Lacy Shell
# - PS1 is never touched. The live shell/agent indicator is drawn in
#   PREDISPLAY by keybindings.zsh, so p10k, starship and friends keep PS1.
# - The mode badge is appended to the user's RPS1 and removed again on quit.

# Exact suffix Lacy appended to RPS1 (empty when none)
_LACY_RPS1_BADGE=""

# Setup prompt integration (called during init)
lacy_shell_setup_prompt() {
    _LACY_RPS1_BADGE=""
}

# Append the mode badge to RPS1, replacing Lacy's previous badge if present.
# If a prompt system rebuilt RPS1 since, the old suffix is already gone.
lacy_shell_update_rprompt() {
    local mode_text mode_color
    case "$LACY_SHELL_CURRENT_MODE" in
        "shell") mode_text="SHELL"; mode_color="$LACY_COLOR_SHELL" ;;
        "agent") mode_text="AGENT"; mode_color="$LACY_COLOR_AGENT" ;;
        "auto")  mode_text="AUTO";  mode_color="$LACY_COLOR_AUTO" ;;
        *)       mode_text="?";     mode_color="$LACY_COLOR_NEUTRAL" ;;
    esac

    local badge="$mode_text"
    [[ -z ${NO_COLOR-} ]] && badge="%F{${mode_color}}${mode_text}%f"

    local base="$RPS1"
    [[ -n "$_LACY_RPS1_BADGE" ]] && base="${base%"$_LACY_RPS1_BADGE"}"
    if [[ -n "$base" ]]; then
        _LACY_RPS1_BADGE=" $badge"
    else
        _LACY_RPS1_BADGE="$badge"
    fi
    RPS1="${base}${_LACY_RPS1_BADGE}"
}

# Update prompt (called by precmd and on mode change)
lacy_shell_update_prompt() {
    lacy_shell_update_rprompt
}

# Remove the mode badge, leaving the user's RPS1 as it is now
lacy_shell_restore_prompt() {
    if [[ -n "$_LACY_RPS1_BADGE" ]]; then
        RPS1="${RPS1%"$_LACY_RPS1_BADGE"}"
    fi
    _LACY_RPS1_BADGE=""
}
