# Lacy Shell — Fish configuration loader

# ============================================================================
# Defaults
# ============================================================================

set -g LACY_SHELL_MODE auto         # shell | agent | auto
set -g LACY_ACTIVE_TOOL ""          # empty = auto-detect
set -g LACY_CUSTOM_TOOL_CMD ""
set -g LACY_TOOL_LIST lash claude opencode gemini codex

# Colors (256-color indices)
set -g LACY_COLOR_SHELL 34          # green
set -g LACY_COLOR_AGENT 200         # magenta
set -g LACY_COLOR_AUTO 75           # blue
set -g LACY_COLOR_NEUTRAL 238       # dark gray

# ============================================================================
# YAML config parser (reads ~/.lacy/config.yaml)
# ============================================================================

function _lacy_yaml_value --description "Read a key from ~/.lacy/config.yaml"
    set -l file "$LACY_SHELL_HOME/config.yaml"
    set -l key $argv[1]
    test -f "$file" || return 1
    grep "^[[:space:]]*$key:" "$file" 2>/dev/null | head -1 \
        | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | tr -d "'"
end

function _lacy_load_config --description "Load config.yaml into Fish globals"
    set -l file "$LACY_SHELL_HOME/config.yaml"
    test -f "$file" || return

    # agent_tools section
    set -l in_tools 0
    while read -l line
        if string match -qr '^agent_tools:' -- "$line"
            set in_tools 1
            continue
        end
        if test $in_tools -eq 1
            if string match -qr '^\S' -- "$line"
                set in_tools 0
            end
            set -l kv (string match -r '^\s+(\w+):\s*(.*)' -- "$line")
            if set -q kv[1]
                set -l k (string trim -- $kv[2])
                set -l v (string trim -- $kv[3] | tr -d '"' | tr -d "'")
                switch $k
                    case active
                        set -gx LACY_ACTIVE_TOOL $v
                    case custom_command
                        set -gx LACY_CUSTOM_TOOL_CMD $v
                end
            end
        end
    end < "$file"

    # modes section
    set -l default_mode (_lacy_yaml_value "default")
    if test -n "$default_mode"
        set -g LACY_SHELL_MODE $default_mode
    end
end

_lacy_load_config
