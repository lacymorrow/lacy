#!/usr/bin/env zsh

# Lacy Shell Constants

# === Runtime State ===
LACY_SHELL_ENABLED=true
LACY_SHELL_DEFER_QUIT=false

# === Paths ===
: ${LACY_SHELL_HOME:="${HOME}/.lacy"}
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

# === Agent CLI ===
# Primary: lash (npm install -g lash-cli)
# Fallback: opencode, or direct API calls

# === Colors ===
# Shell commands: Green (34)
# Agent queries: Magenta (200)
# Neutral: Dark gray (238)
# Auto mode: Blue (75)
