# Lacy Shell — Nushell prompt indicator
#
# Appends a colored mode badge to the right prompt.
# Real-time per-keystroke indicator is not available in Nushell;
# the badge updates on each new prompt.

def _lacy_mode_badge [] -> string {
    match ($env.LACY_SHELL_MODE? | default "auto") {
        "shell" => $"\e[38;5;34mSHELL\e[0m"
        "agent" => $"\e[38;5;200mAGENT\e[0m"
        _       => $"\e[38;5;75mAUTO\e[0m"
    }
}

# If PROMPT_COMMAND_RIGHT is already set, wrap it so both render.
# Otherwise, install the badge as the right prompt.
let _existing_right = ($env.PROMPT_COMMAND_RIGHT? | default null)

$env.PROMPT_COMMAND_RIGHT = if $_existing_right != null {
    { $"(do $_existing_right) (_lacy_mode_badge)" }
} else {
    { _lacy_mode_badge }
}
