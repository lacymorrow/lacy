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

# === Preheat ===
: ${LACY_PREHEAT_EAGER:="false"}
: ${LACY_PREHEAT_SERVER_PORT:="4096"}

# === Colors (256-color palette) ===
LACY_COLOR_SHELL=34        # Green - shell commands
LACY_COLOR_AGENT=200       # Magenta - agent queries
LACY_COLOR_AUTO=75         # Blue - auto mode
LACY_COLOR_NEUTRAL=238     # Dark gray - neutral/dim
LACY_COLOR_SHIMMER=(255 219 213 200 141)  # Spinner shimmer gradient

# === Detection ===
LACY_HARD_AGENT_INDICATORS=(what yes no)
LACY_NL_MARKERS=(the a an my your this that these those please how why where when)
LACY_SHELL_OPERATORS=('|' '&&' '||' ';' '>')

# === UI ===
LACY_INDICATOR_CHAR="▌"
LACY_SPINNER_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
LACY_SPINNER_TEXT='Thinking'

# === Timing (seconds) ===
LACY_SPINNER_FRAME_DELAY=0.08
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
