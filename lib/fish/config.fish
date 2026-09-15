# Lacy Shell: Fish configuration loader

# ============================================================================
# Defaults
# ============================================================================

set -g LACY_SHELL_MODE auto         # shell | agent | auto
set -g LACY_ACTIVE_TOOL ""          # empty = auto-detect
set -g LACY_CUSTOM_TOOL_CMD ""

# Set by lacy.plugin.fish; default here so the modules also load on their own
set -q _LACY_FISH_MAJOR; or set -g _LACY_FISH_MAJOR (string match -r -- '^\d+' $version)

# BEGIN GENERATED TOOL LIST
# Generated from lib/core/constants.sh. Do not edit by hand.
set -g LACY_TOOL_LIST \
    'lash' 'claude' 'opencode' 'gemini' 'codex' 'hermes' 'copilot' 'goose' \
    'amp' 'aider'
# END GENERATED TOOL LIST

# Colors (256-color indices)
set -g LACY_COLOR_SHELL 34          # green
set -g LACY_COLOR_AGENT 200         # magenta
set -g LACY_COLOR_AUTO 75           # blue
set -g LACY_COLOR_NEUTRAL 238       # dark gray

# ============================================================================
# Output helpers
# ============================================================================

# Print an SGR escape (e.g. "38;5;34", "1", "0"), or nothing when NO_COLOR is set.
function _lacy_sgr --description "Print an SGR escape unless NO_COLOR is set"
    test -n "$NO_COLOR"; and return
    printf '\e[%sm' $argv[1]
end

# Print colour, glyph and label for a mode, one per line. The glyph carries
# the mode without colour: shell $, agent ?
function _lacy_mode_style --description "Print colour, glyph and label for a mode"
    switch "$argv[1]"
        case shell
            printf '%s\n' $LACY_COLOR_SHELL '$' SHELL
        case agent
            printf '%s\n' $LACY_COLOR_AGENT '?' AGENT
        case '*'
            printf '%s\n' $LACY_COLOR_AUTO '▌' AUTO
    end
end

# Print "  <glyph> <MODE> mode" in the mode colour
function _lacy_print_mode_line --description "Print the current mode"
    set -l style (_lacy_mode_style $LACY_SHELL_MODE)
    set -l on (_lacy_sgr "38;5;$style[1]")
    set -l off (_lacy_sgr 0)
    printf '  %s%s%s %s mode\n' "$on" $style[2] "$off" $style[3]
end

# ============================================================================
# YAML config parser (reads $LACY_SHELL_HOME/config.yaml)
# ============================================================================

# Print the value of KEY inside top-level SECTION. Returns 1 if not found.
# One matching pair of outer quotes is removed; an unquoted value loses a
# trailing " # comment".
function _lacy_yaml_value --description "Read section.key from config.yaml"
    set -l section $argv[1]
    set -l key $argv[2]
    set -l file "$LACY_SHELL_HOME/config.yaml"
    test -f "$file"; or return 1

    set -l in_section 0
    while read -l line
        if string match -qr -- '^[^\s#]' "$line"
            if string match -q -- "$section:*" "$line"
                set in_section 1
            else
                set in_section 0
            end
            continue
        end
        test $in_section -eq 1; or continue

        set -l kv (string split -m1 -- : (string trim -- "$line"))
        test "$kv[1]" = "$key"; or continue

        set -l value (string trim -- "$kv[2]")
        if set -l inner (string match -r -- '^"([^"]*)"' "$value")
            set value "$inner[2]"
        else if set -l inner (string match -r -- "^'([^']*)'" "$value")
            set value "$inner[2]"
        else
            set value (string replace -r -- '\s+#.*$' '' "$value")
        end
        echo "$value"
        return 0
    end < "$file"
    return 1
end

function _lacy_load_config --description "Load config.yaml into Fish globals"
    set -g LACY_ACTIVE_TOOL ""
    set -g LACY_CUSTOM_TOOL_CMD ""
    set -l value
    if set value (_lacy_yaml_value agent_tools active)
        set -g LACY_ACTIVE_TOOL "$value"
    end
    if set value (_lacy_yaml_value agent_tools custom_command)
        set -g LACY_CUSTOM_TOOL_CMD "$value"
    end
end

# ============================================================================
# Mode state
# ============================================================================

# Startup mode: $LACY_SHELL_HOME/current_mode if it holds a valid mode, else
# modes.default from config.yaml, else auto. Same order as zsh and bash.
function _lacy_init_mode --description "Pick the startup mode"
    set -l mode_file "$LACY_SHELL_HOME/current_mode"
    set -l saved
    if test -f "$mode_file"
        read -l first_line < "$mode_file"
        set saved (string trim -- "$first_line")
    end
    if contains -- "$saved" shell agent auto
        set -g LACY_SHELL_MODE $saved
        return
    end
    set -l default_mode (_lacy_yaml_value modes default)
    if contains -- "$default_mode" shell agent auto
        set -g LACY_SHELL_MODE $default_mode
        return
    end
    set -g LACY_SHELL_MODE auto
end

# Set and persist the mode (the file is shared with zsh and bash).
function _lacy_set_mode --description "Set and persist the Lacy mode"
    if not contains -- "$argv[1]" shell agent auto
        echo "Invalid mode: $argv[1]. Available modes: shell agent auto" >&2
        return 1
    end
    set -g LACY_SHELL_MODE $argv[1]
    mkdir -p "$LACY_SHELL_HOME" 2>/dev/null
    printf '%s\n' $argv[1] > "$LACY_SHELL_HOME/current_mode" 2>/dev/null
    return 0
end

_lacy_load_config
_lacy_init_mode
