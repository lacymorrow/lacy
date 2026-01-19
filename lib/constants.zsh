#!/usr/bin/env zsh

# Lacy Shell Constants

# === Runtime State ===
LACY_SHELL_ENABLED=true
LACY_SHELL_DEFER_QUIT=false

# === Paths ===
: ${LACY_SHELL_HOME:="${HOME}/.lacy-shell"}
readonly LACY_SHELL_HOME

: ${LACY_SHELL_CONFIG_FILE:="${LACY_SHELL_HOME}/config.yaml"}
readonly LACY_SHELL_CONFIG_FILE

: ${LACY_SHELL_MODE_FILE:="${LACY_SHELL_HOME}/current_mode"}
readonly LACY_SHELL_MODE_FILE

: ${LACY_SHELL_CONVERSATION_FILE:="${LACY_SHELL_HOME}/conversation.log"}
readonly LACY_SHELL_CONVERSATION_FILE

: ${LACY_SHELL_MCP_DIR:="${LACY_SHELL_HOME}/mcp"}
readonly LACY_SHELL_MCP_DIR

# === Defaults ===
: ${LACY_SHELL_DEFAULT_MODE:="auto"}
readonly LACY_SHELL_DEFAULT_MODE

: ${LACY_SHELL_DEFAULT_INDICATOR_STYLE:="top"}
readonly LACY_SHELL_DEFAULT_INDICATOR_STYLE

: ${LACY_SHELL_DEFAULT_CONFIDENCE_THRESHOLD:="0.7"}
readonly LACY_SHELL_DEFAULT_CONFIDENCE_THRESHOLD

: ${LACY_SHELL_DEFAULT_PROVIDER:="openai"}
readonly LACY_SHELL_DEFAULT_PROVIDER

: ${LACY_SHELL_DEFAULT_MODEL:="gpt-4o-mini"}
readonly LACY_SHELL_DEFAULT_MODEL

# === Timeouts (in milliseconds) ===
: ${LACY_SHELL_EXIT_TIMEOUT_MS:=1000}
readonly LACY_SHELL_EXIT_TIMEOUT_MS

: ${LACY_SHELL_EXIT_TIMEOUT_SEC:="1.0"}
readonly LACY_SHELL_EXIT_TIMEOUT_SEC

: ${LACY_SHELL_MESSAGE_DURATION_SEC:="1.0"}
readonly LACY_SHELL_MESSAGE_DURATION_SEC

: ${LACY_SHELL_MCP_TIMEOUT_SEC:=5}
readonly LACY_SHELL_MCP_TIMEOUT_SEC

# === UI ===
: ${LACY_SHELL_TOP_BAR_HEIGHT:=1}
readonly LACY_SHELL_TOP_BAR_HEIGHT

# === Agent CLI Defaults ===
# Note: Using explicit assignment because {query} braces conflict with zsh ${:-} syntax
[[ -z "$LACY_SHELL_DEFAULT_AGENT_COMMAND" ]] && LACY_SHELL_DEFAULT_AGENT_COMMAND='lash run {query}'
readonly LACY_SHELL_DEFAULT_AGENT_COMMAND

: ${LACY_SHELL_DEFAULT_AGENT_CONTEXT_MODE:="stdin"}
readonly LACY_SHELL_DEFAULT_AGENT_CONTEXT_MODE

: ${LACY_SHELL_DEFAULT_AGENT_NEEDS_API_KEYS:="false"}
readonly LACY_SHELL_DEFAULT_AGENT_NEEDS_API_KEYS

# === Loader Animation ===
# Fun pink sparkle loader frames - bright and playful!
LACY_SHELL_LOADER_FRAMES=(
    "♡ ✧ ˚ ·"
    "✧ ♡ ✧ ˚"
    "˚ ✧ ♡ ✧"
    "· ˚ ✧ ♡"
    "✦ ˚ ♥ ·"
    "˚ ✦ ˚ ♥"
    "♥ ˚ ✦ ˚"
    "· ♥ ˚ ✦"
    "⋆ ✧ · ♡"
    "✧ ⋆ ✧ ·"
    "· ✧ ⋆ ✧"
    "♡ · ✧ ⋆"
)

# Bright magenta/pink color (ANSI 199 = bright magenta pink)
LACY_SHELL_LOADER_COLOR="\033[1;38;5;199m"
LACY_SHELL_LOADER_RESET="\033[0m"

# Loader speed (seconds between frames) - snappy and fun!
: ${LACY_SHELL_LOADER_SPEED:="0.08"}
readonly LACY_SHELL_LOADER_SPEED
