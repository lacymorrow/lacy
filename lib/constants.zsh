#!/usr/bin/env zsh

# Lacy Shell Constants

# === Runtime State ===
LACY_SHELL_ENABLED=true
LACY_SHELL_DEFER_QUIT=false

# === Paths ===
readonly LACY_SHELL_HOME="${HOME}/.lacy-shell"
readonly LACY_SHELL_CONFIG_FILE="${LACY_SHELL_HOME}/config.yaml"
readonly LACY_SHELL_MODE_FILE="${LACY_SHELL_HOME}/current_mode"
readonly LACY_SHELL_CONVERSATION_FILE="${LACY_SHELL_HOME}/conversation.log"
readonly LACY_SHELL_MCP_DIR="${LACY_SHELL_HOME}/mcp"

# === Defaults ===
readonly LACY_SHELL_DEFAULT_MODE="auto"
readonly LACY_SHELL_DEFAULT_INDICATOR_STYLE="top"
readonly LACY_SHELL_DEFAULT_CONFIDENCE_THRESHOLD="0.7"

# === Timeouts (in milliseconds) ===
readonly LACY_SHELL_EXIT_TIMEOUT_MS=1000
readonly LACY_SHELL_EXIT_TIMEOUT_SEC="1.0"
readonly LACY_SHELL_MESSAGE_DURATION_SEC="1.0"
readonly LACY_SHELL_MCP_TIMEOUT_SEC=5

# === UI ===
readonly LACY_SHELL_TOP_BAR_HEIGHT=1