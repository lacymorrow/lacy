#!/usr/bin/env bash

# Configuration for Lacy Shell
# Shared across Bash 4+ and ZSH
#
# config.yaml is read as a small, flat YAML subset:
#
#   section:
#     key: value   # comment
#
# Only direct children of a known top-level section are read. Deeper nesting,
# lists, and unknown keys are ignored. Values lose one matching pair of outer
# quotes. `#` starts a comment only at the start of a value or after
# whitespace, and never inside quotes. Nothing in a value is ever executed.
#
# LACY_SHELL_CONFIG_FILE is defined in constants.sh.

# ============================================================================
# Default config (canonical copy; install.sh and packages/lacy/index.mjs
# carry the same text)
# ============================================================================

_lacy_default_config_text() {
    cat <<'EOF'
# Lacy Shell configuration
agent_tools:
  # lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, custom
  # Leave empty to auto-detect.
  active:
  # custom_command: "your-command --flags"

modes:
  default: auto  # shell, agent, or auto

# preheat:
#   eager: false
#   server_port: 4096

# logging:
#   queries: false  # true writes ~/.lacy/logs/queries.log (owner-only)
EOF
}

# Create the default configuration file. Refuses to touch anything that
# already exists, and says so when it cannot write.
lacy_shell_create_default_config() {
    local cfg="$LACY_SHELL_CONFIG_FILE"
    if [[ -d "$cfg" ]]; then
        printf 'lacy: %s is a directory, not a config file.\n' "$cfg" >&2
        return 1
    fi
    if [[ -e "$cfg" ]]; then
        return 0
    fi
    mkdir -p "${cfg%/*}" 2>/dev/null
    if ! _lacy_default_config_text > "$cfg" 2>/dev/null; then
        printf 'lacy: could not create %s\n' "$cfg" >&2
        return 1
    fi
    echo "Created default configuration at: $cfg"
}

# ============================================================================
# Known settings
# ============================================================================

# Map "section.key" to the variable it sets. Result in _LACY_CFG_VAR.
_lacy_config_var_for() {
    case "$1" in
        agent_tools.active)         _LACY_CFG_VAR="LACY_ACTIVE_TOOL" ;;
        agent_tools.custom_command) _LACY_CFG_VAR="LACY_CUSTOM_TOOL_CMD" ;;
        modes.default)              _LACY_CFG_VAR="LACY_CONFIG_DEFAULT_MODE" ;;
        preheat.eager)              _LACY_CFG_VAR="LACY_PREHEAT_EAGER" ;;
        preheat.server_port)        _LACY_CFG_VAR="LACY_PREHEAT_SERVER_PORT" ;;
        context.output)             _LACY_CFG_VAR="_LACY_CTX_OUTPUT_ENABLED" ;;
        context.output_lines)       _LACY_CFG_VAR="_LACY_CTX_OUTPUT_MAX_LINES" ;;
        spinner.style)              _LACY_CFG_VAR="LACY_SPINNER_STYLE" ;;
        logging.queries)            _LACY_CFG_VAR="LACY_LOG_QUERIES" ;;
        *)                          _LACY_CFG_VAR="" ;;
    esac
}

# Reset every config-backed variable to its default. Runs before each parse so
# values inherited from a parent shell's environment never survive a reload.
_lacy_config_reset_vars() {
    LACY_ACTIVE_TOOL=""
    LACY_CUSTOM_TOOL_CMD=""
    LACY_CONFIG_DEFAULT_MODE=""
    LACY_PREHEAT_EAGER="false"
    LACY_PREHEAT_SERVER_PORT="4096"
    _LACY_CTX_OUTPUT_ENABLED=true
    _LACY_CTX_OUTPUT_MAX_LINES=50
    LACY_SPINNER_STYLE="braille"
    LACY_LOG_QUERIES="false"
}

# Normalize a YAML-ish boolean into "true" or "false"
_lacy_config_bool() {
    case "$1" in
        true|True|TRUE|yes|Yes|YES|on|On|ON) printf -v "$2" '%s' "true" ;;
        *)                                    printf -v "$2" '%s' "false" ;;
    esac
}

# ============================================================================
# Line parsing
# ============================================================================

# Parse a scalar that follows "key:". Sets:
#   _LACY_CFG_VALUE    the value (comment removed, trimmed, one outer quote pair gone)
#   _LACY_CFG_COMMENT  the raw comment including the whitespace before it, or empty
#
# Quoted value ('...' or "..."): it ends at the first matching quote that is
# followed only by whitespace, or by whitespace and a comment. Nothing inside
# is unescaped. Plain value: "#" after whitespace starts a comment unless it
# sits inside quotes; "null" and "~" mean empty.
_lacy_config_scalar() {
    local raw="$1" s c i n tail rest
    s="${raw#"${raw%%[![:space:]]*}"}"
    n=${#s}
    c="${s:0:1}"

    if [[ "$c" == '"' || "$c" == "'" ]]; then
        for (( i = 1; i < n; i++ )); do
            [[ "${s:$i:1}" == "$c" ]] || continue
            tail="${s:$(( i + 1 ))}"
            rest="${tail#"${tail%%[![:space:]]*}"}"
            if [[ -z "$rest" ]] || [[ "$rest" == "#"* && "$rest" != "$tail" ]]; then
                _LACY_CFG_VALUE="${s:1:$(( i - 1 ))}"
                if [[ -n "$rest" ]]; then
                    _LACY_CFG_COMMENT="$tail"
                else
                    _LACY_CFG_COMMENT=""
                fi
                return 0
            fi
        done
        # No closing quote: read it as a plain value below
    fi

    local out="" prev=" " q="" comment=""
    n=${#raw}
    for (( i = 0; i < n; i++ )); do
        c="${raw:$i:1}"
        if [[ -n "$q" ]]; then
            [[ "$c" == "$q" ]] && q=""
        elif [[ "$c" == '"' || "$c" == "'" ]]; then
            q="$c"
        elif [[ "$c" == "#" && ( "$prev" == " " || "$prev" == $'\t' ) ]]; then
            comment="${raw:$i}"
            break
        fi
        out+="$c"
        prev="$c"
    done

    # Whitespace between the value and the comment belongs to the comment.
    # Take the trailing run first so an all-blank value keeps its spacing.
    local trail="${out##*[![:space:]]}"
    out="${out%"$trail"}"
    out="${out#"${out%%[![:space:]]*}"}"
    [[ -n "$comment" ]] && comment="${trail}${comment}"

    if [[ "$out" == "null" || "$out" == "~" ]]; then
        out=""
    fi

    _LACY_CFG_VALUE="$out"
    _LACY_CFG_COMMENT="$comment"
}

# Split "key: value" (leading whitespace already removed). Sets _LACY_CFG_KEY
# plus the scalar results. Returns 1 when the line is not a simple mapping.
_lacy_config_split_key() {
    local s="$1"
    local key="${s%%:*}"
    [[ "$key" != "$s" ]] || return 1
    [[ -n "$key" && "$key" != *[!A-Za-z0-9_.-]* ]] || return 1
    local rest="${s#*:}"
    # "key:value" without a space is a plain string in YAML, not a mapping
    if [[ -n "$rest" && "$rest" != [[:space:]]* ]]; then
        return 1
    fi
    _LACY_CFG_KEY="$key"
    _lacy_config_scalar "$rest"
}

# Read a config file and set the variable for each known, non-empty setting.
_lacy_config_parse_file() {
    local file="$1"
    local line trimmed section="" indent child_indent=-1 ln=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        (( ln++ ))
        line="${line%$'\r'}"
        trimmed="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$trimmed" || "$trimmed" == "#"* ]] && continue
        indent=$(( ${#line} - ${#trimmed} ))

        if (( indent == 0 )); then
            section=""
            child_indent=-1
            _lacy_config_split_key "$trimmed" || continue
            # A top-level key with no value opens a section
            [[ -z "$_LACY_CFG_VALUE" ]] && section="$_LACY_CFG_KEY"
            continue
        fi

        [[ -n "$section" ]] || continue
        (( child_indent < 0 )) && child_indent=$indent
        # Only direct children; nested maps under a section are ignored
        (( indent == child_indent )) || continue
        _lacy_config_split_key "$trimmed" || continue

        _lacy_config_var_for "${section}.${_LACY_CFG_KEY}"
        [[ -n "$_LACY_CFG_VAR" ]] || continue
        # Empty means "use the default", which the reset already applied
        [[ -n "$_LACY_CFG_VALUE" ]] || continue
        printf -v "$_LACY_CFG_VAR" '%s' "$_LACY_CFG_VALUE"
    done < "$file"
}

# ============================================================================
# Load
# ============================================================================

# Load configuration from $LACY_SHELL_CONFIG_FILE into shell variables.
# Returns 1 (and keeps defaults) when the file cannot be read.
lacy_shell_load_config() {
    _lacy_config_reset_vars
    local rc=0
    local cfg="$LACY_SHELL_CONFIG_FILE"

    mkdir -p "$LACY_SHELL_HOME" 2>/dev/null

    # Older versions cached parsed config (API keys included) in a
    # world-readable file that nothing reads any more.
    [[ -f "$LACY_SHELL_HOME/.config_cache" ]] && command rm -f "$LACY_SHELL_HOME/.config_cache"
    # Older versions wrote the query log world-readable
    [[ -f "$LACY_SHELL_HOME/logs/queries.log" ]] && chmod 600 "$LACY_SHELL_HOME/logs/queries.log" 2>/dev/null

    if [[ -d "$cfg" ]]; then
        printf 'lacy: %s is a directory, not a config file. Using defaults.\n' "$cfg" >&2
        rc=1
    elif [[ ! -e "$cfg" ]]; then
        lacy_shell_create_default_config || rc=1
    fi

    if (( rc == 0 )); then
        if [[ -r "$cfg" ]]; then
            _lacy_config_parse_file "$cfg"
        else
            printf 'lacy: cannot read %s. Using defaults.\n' "$cfg" >&2
            rc=1
        fi
    fi

    _lacy_config_bool "$LACY_PREHEAT_EAGER" LACY_PREHEAT_EAGER
    _lacy_config_bool "$LACY_LOG_QUERIES" LACY_LOG_QUERIES
    _lacy_config_bool "$_LACY_CTX_OUTPUT_ENABLED" _LACY_CTX_OUTPUT_ENABLED
    [[ "$LACY_PREHEAT_SERVER_PORT" == *[!0-9]* ]] && LACY_PREHEAT_SERVER_PORT="4096"
    [[ "$_LACY_CTX_OUTPUT_MAX_LINES" == *[!0-9]* ]] && _LACY_CTX_OUTPUT_MAX_LINES=50

    case "$LACY_CONFIG_DEFAULT_MODE" in
        ""|shell|agent|auto) ;;
        *)
            printf "lacy: modes.default '%s' is not shell, agent, or auto. Using auto.\n" "$LACY_CONFIG_DEFAULT_MODE" >&2
            LACY_CONFIG_DEFAULT_MODE=""
            ;;
    esac

    LACY_SHELL_CURRENT_MODE="${LACY_CONFIG_DEFAULT_MODE:-${LACY_SHELL_DEFAULT_MODE:-auto}}"
    return $rc
}

# ============================================================================
# Write
# ============================================================================

# Render a value for writing so the parser reads back exactly the same string.
# Tries plain (simple values only), then '...', then "...", and keeps the first
# form that parses back to the value. Sets _LACY_CFG_RENDERED. Returns 1 when
# no form round-trips (for example a value containing a newline).
_lacy_config_render_value() {
    local v="$1" cand
    _LACY_CFG_RENDERED=""
    [[ -z "$v" ]] && return 0
    [[ "$v" == *$'\n'* || "$v" == *$'\r'* ]] && return 1
    for cand in "$v" "'${v}'" "\"${v}\""; do
        if [[ "$cand" == "$v" ]]; then
            # Plain only for simple values that are valid YAML as-is
            [[ "$v" != *[!A-Za-z0-9_./@+=,-]* && "$v" != -* ]] || continue
        fi
        _lacy_config_scalar " $cand"
        if [[ "$_LACY_CFG_VALUE" == "$v" ]]; then
            _LACY_CFG_RENDERED="$cand"
            return 0
        fi
    done
    return 1
}

# Set section.key in config.yaml, keeping comments, order, and other keys.
# The file is rewritten through a temp file with `cat tmp > file`, so a
# symlinked config.yaml stays a symlink.
# Usage: lacy_config_set <section> <key> <value>
# On failure returns 1 and puts a reason in _LACY_CONFIG_SET_ERROR.
lacy_config_set() {
    local section="$1" key="$2" value="$3"
    local cfg="$LACY_SHELL_CONFIG_FILE"
    _LACY_CONFIG_SET_ERROR=""

    if [[ -d "$cfg" ]]; then
        _LACY_CONFIG_SET_ERROR="$cfg is a directory"
        return 1
    fi
    if [[ ! -e "$cfg" ]]; then
        lacy_shell_create_default_config >/dev/null || {
            _LACY_CONFIG_SET_ERROR="could not create $cfg"
            return 1
        }
    fi
    if [[ ! -r "$cfg" || ! -w "$cfg" ]]; then
        _LACY_CONFIG_SET_ERROR="$cfg is not writable"
        return 1
    fi
    if ! _lacy_config_render_value "$value"; then
        _LACY_CONFIG_SET_ERROR="the value cannot be written safely"
        return 1
    fi
    local rendered="$_LACY_CFG_RENDERED"

    # Pass 1: find the section header and whether the key already exists
    local line trimmed indent cur="" child_indent=-1 ln=0
    local header_ln=0 found=false insert_indent="  "
    while IFS= read -r line || [[ -n "$line" ]]; do
        (( ln++ ))
        line="${line%$'\r'}"
        trimmed="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$trimmed" || "$trimmed" == "#"* ]] && continue
        indent=$(( ${#line} - ${#trimmed} ))
        if (( indent == 0 )); then
            cur=""
            child_indent=-1
            if _lacy_config_split_key "$trimmed" && [[ -z "$_LACY_CFG_VALUE" && "$_LACY_CFG_KEY" == "$section" ]]; then
                cur="$section"
                (( header_ln == 0 )) && header_ln=$ln
            fi
            continue
        fi
        [[ -n "$cur" ]] || continue
        if (( child_indent < 0 )); then
            child_indent=$indent
            (( ln > header_ln )) && [[ "$insert_indent" == "  " ]] && insert_indent="${line%%[![:space:]]*}"
        fi
        (( indent == child_indent )) || continue
        _lacy_config_split_key "$trimmed" || continue
        [[ "$_LACY_CFG_KEY" == "$key" ]] && found=true
    done < "$cfg"

    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/lacy-config.XXXXXX" 2>/dev/null) || {
        _LACY_CONFIG_SET_ERROR="could not create a temp file"
        return 1
    }

    # Pass 2: write everything back, replacing or inserting the one line
    local cr lead newline body
    cur=""
    child_indent=-1
    ln=0
    {
        while IFS= read -r line || [[ -n "$line" ]]; do
            (( ln++ ))
            cr=""
            [[ "$line" == *$'\r' ]] && cr=$'\r'
            body="${line%$'\r'}"
            trimmed="${body#"${body%%[![:space:]]*}"}"
            if [[ -n "$trimmed" && "$trimmed" != "#"* ]]; then
                indent=$(( ${#body} - ${#trimmed} ))
                if (( indent == 0 )); then
                    cur=""
                    child_indent=-1
                    if _lacy_config_split_key "$trimmed" && [[ -z "$_LACY_CFG_VALUE" && "$_LACY_CFG_KEY" == "$section" ]]; then
                        cur="$section"
                    fi
                elif [[ -n "$cur" ]]; then
                    (( child_indent < 0 )) && child_indent=$indent
                    if (( indent == child_indent )) && _lacy_config_split_key "$trimmed" && [[ "$_LACY_CFG_KEY" == "$key" ]]; then
                        lead="${body%%[![:space:]]*}"
                        if [[ -n "$rendered" ]]; then
                            newline="${lead}${key}: ${rendered}"
                        else
                            newline="${lead}${key}:"
                        fi
                        printf '%s%s%s\n' "$newline" "$_LACY_CFG_COMMENT" "$cr"
                        continue
                    fi
                fi
            fi
            printf '%s\n' "$line"
            if [[ "$found" == false ]] && (( ln == header_ln )); then
                if [[ -n "$rendered" ]]; then
                    printf '%s%s: %s%s\n' "$insert_indent" "$key" "$rendered" "$cr"
                else
                    printf '%s%s:%s\n' "$insert_indent" "$key" "$cr"
                fi
            fi
        done < "$cfg"
        if (( header_ln == 0 )); then
            printf '\n%s:\n' "$section"
            if [[ -n "$rendered" ]]; then
                printf '  %s: %s\n' "$key" "$rendered"
            else
                printf '  %s:\n' "$key"
            fi
        fi
    } > "$tmp" 2>/dev/null

    if ! cat "$tmp" > "$cfg" 2>/dev/null; then
        command rm -f "$tmp"
        _LACY_CONFIG_SET_ERROR="could not write $cfg"
        return 1
    fi
    command rm -f "$tmp"
    return 0
}
