#!/usr/bin/env bash

# Lacy Shell Constants — shared across Bash 4+ and ZSH
# Sourced by lib/zsh/init.zsh and lib/bash/init.bash

# === Runtime State ===
LACY_SHELL_ENABLED=true
LACY_SHELL_DEFER_QUIT=false

# === Shell Type (set by entry point before sourcing) ===
# LACY_SHELL_TYPE — "zsh" or "bash"
# _LACY_ARR_OFFSET — 1 for ZSH (1-based), 0 for Bash (0-based)

# === Paths ===
: "${LACY_SHELL_HOME:="${HOME}/.lacy"}"

: "${LACY_SHELL_CONFIG_FILE:="${LACY_SHELL_HOME}/config.yaml"}"

: "${LACY_SHELL_MODE_FILE:="${LACY_SHELL_HOME}/current_mode"}"

: "${LACY_SHELL_CONVERSATION_FILE:="${LACY_SHELL_HOME}/conversation.log"}"

: "${LACY_SHELL_MCP_DIR:="${LACY_SHELL_HOME}/mcp"}"

# === Defaults ===
: "${LACY_SHELL_DEFAULT_MODE:="auto"}"

: "${LACY_SHELL_DEFAULT_INDICATOR_STYLE:="top"}"

: "${LACY_SHELL_DEFAULT_CONFIDENCE_THRESHOLD:="0.7"}"

: "${LACY_SHELL_DEFAULT_PROVIDER:="openai"}"

: "${LACY_SHELL_DEFAULT_MODEL:="gpt-4o-mini"}"

# === Timeouts (in milliseconds) ===
: "${LACY_SHELL_EXIT_TIMEOUT_MS:=1000}"

: "${LACY_SHELL_EXIT_TIMEOUT_SEC:="1.0"}"

: "${LACY_SHELL_MESSAGE_DURATION_SEC:="1.0"}"

: "${LACY_SHELL_MCP_TIMEOUT_SEC:=5}"

# === UI ===
: "${LACY_SHELL_TOP_BAR_HEIGHT:=1}"

# === Preheat ===
: "${LACY_PREHEAT_EAGER:="false"}"
: "${LACY_PREHEAT_SERVER_PORT:="4096"}"

# === Colors (256-color palette) ===
LACY_COLOR_SHELL=34        # Green - shell commands
LACY_COLOR_AGENT=200       # Magenta - agent queries
LACY_COLOR_AUTO=75         # Blue - auto mode
LACY_COLOR_NEUTRAL=238     # Dark gray - neutral/dim
LACY_COLOR_SHIMMER=(255 219 213 200 141)  # Spinner shimmer gradient

# === Detection ===
LACY_HARD_AGENT_INDICATORS=("what" "yes" "no")
LACY_NL_MARKERS=("the" "a" "an" "my" "your" "this" "that" "these" "those" "please" "how" "why" "where" "when")
LACY_SHELL_OPERATORS=('|' '&&' '||' ';' '>')

# === UI ===
LACY_INDICATOR_CHAR="▌"
LACY_SPINNER_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
LACY_SPINNER_TEXT='Thinking'

# === Timing (seconds) ===
LACY_SPINNER_FRAME_DELAY=0.05
LACY_TERMINAL_FLUSH_DELAY=0.02
LACY_HEALTH_CHECK_ATTEMPTS=30
LACY_HEALTH_CHECK_INTERVAL=0.1
LACY_SESSION_CREATE_TIMEOUT=10
LACY_SESSION_MESSAGE_TIMEOUT=120

# === Thresholds ===
LACY_SIGNAL_EXIT_THRESHOLD=128  # Exit codes >= this are signal-based

# === API Models (fallback only) ===
LACY_API_MODEL_OPENAI="gpt-4o-mini"
LACY_API_MODEL_ANTHROPIC="claude-3-5-sonnet-20241022"

# === Dangerous Commands ===
LACY_DANGEROUS_PATTERNS=("rm -rf" "sudo rm" "mkfs" "dd if=" ">" "truncate")

# === Performance Optimization: Caching ===
LACY_CONFIG_CACHE_VALID=false
declare -A LACY_CACHED_CONFIG 2>/dev/null || true
: "${LACY_SHELL_CONFIG_CACHE_FILE:="${LACY_SHELL_HOME}/.config_cache"}"

# Async health check cache
LACY_PREHEAT_HEALTH_CACHE=false
LACY_PREHEAT_HEALTH_CHECK_PID=""
: "${LACY_SHELL_HEALTH_CACHE_FILE:="${LACY_SHELL_HOME}/.health_cache"}"

# === Portable Helpers ===

# Print colored text — dispatches to shell-appropriate method
# Usage: lacy_print_color <color_code> <text>
lacy_print_color() {
    local color="$1"
    shift
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        print -P "%F{${color}}$*%f"
    else
        printf '\e[38;5;%dm%s\e[0m\n' "$color" "$*"
    fi
}

# Print colored text without trailing newline
# Usage: lacy_print_color_n <color_code> <text>
lacy_print_color_n() {
    local color="$1"
    shift
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        print -Pn "%F{${color}}$*%f"
    else
        printf '\e[38;5;%dm%s\e[0m' "$color" "$*"
    fi
}

# Check if a value is in a list (portable array membership)
# Usage: _lacy_in_list "value" "item1" "item2" ...
_lacy_in_list() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Portable lowercase — works in Bash 4+, ZSH, and falls back to tr
# Usage: result=$(_lacy_lowercase "STRING")
_lacy_lowercase() {
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        echo "${1:l}"
    elif (( BASH_VERSINFO[0] >= 4 )) 2>/dev/null; then
        echo "${1,,}"
    else
        # Bash 3 fallback (macOS default) — only used in test/core contexts
        echo "$1" | tr '[:upper:]' '[:lower:]'
    fi
}

# Portable pipe status — get exit code of first command in pipeline
# Must be called immediately after a pipeline
# Usage: local exit_code=$(_lacy_pipe_status)
_lacy_pipe_status() {
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        echo "${pipestatus[1]}"
    else
        echo "${PIPESTATUS[0]}"
    fi
}

# Portable job control off/on
_lacy_jobctl_off() {
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        [[ -o monitor ]] && LACY_JOBCTL_WAS_SET=1 || LACY_JOBCTL_WAS_SET=""
        setopt NO_MONITOR 2>/dev/null
    else
        LACY_JOBCTL_WAS_SET=""
        case "$-" in *m*) LACY_JOBCTL_WAS_SET=1 ;; esac
        set +m 2>/dev/null
    fi
}

_lacy_jobctl_on() {
    if [[ -n "$LACY_JOBCTL_WAS_SET" ]]; then
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            setopt MONITOR 2>/dev/null
        else
            set -m 2>/dev/null
        fi
        LACY_JOBCTL_WAS_SET=""
    fi
}
