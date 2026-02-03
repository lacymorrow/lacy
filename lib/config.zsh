#!/usr/bin/env zsh

# Configuration management for Lacy Shell

# Default configuration
typeset -A LACY_SHELL_CONFIG
# LACY_SHELL_CONFIG_FILE is defined in constants.zsh

# ============================================================================
# Config Parsing Helpers (reduces code duplication)
# ============================================================================

# Simple YAML parser for shell (handles basic key: value)
lacy_shell_parse_yaml_value() {
    local file="$1"
    local key="$2"

    # Extract value for a simple key: value pair
    grep "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | tr -d "'"
}

# Clean a config value (remove quotes, comments, whitespace)
lacy_shell_clean_config_value() {
    local value="$1"
    echo "$value" | sed 's/#.*//' | tr -d '"' | tr -d "'" | xargs
}

# Parse a key-value line from config and export if valid
# Usage: lacy_shell_export_config_value <key> <value> <key_map>
# key_map format: "config_key1:ENV_VAR1,config_key2:ENV_VAR2"
lacy_shell_export_config_value() {
    local key="$1"
    local value="$2"
    local key_map="$3"

    # Clean the value
    value=$(lacy_shell_clean_config_value "$value")

    # Skip empty or null values
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        return 1
    fi

    # Look up the key in the map and export
    local mapping
    for mapping in ${(s:,:)key_map}; do
        local config_key="${mapping%%:*}"
        local env_var="${mapping#*:}"
        if [[ "$key" == "$config_key" ]]; then
            export "$env_var"="$value"
            return 0
        fi
    done
    return 1
}

# Load configuration from file
lacy_shell_load_config() {
    # Set defaults from constants
    LACY_SHELL_CURRENT_MODE="$LACY_SHELL_DEFAULT_MODE"

    # Ensure config directory exists
    mkdir -p "$LACY_SHELL_HOME"

    # Create default config if it doesn't exist
    if [[ ! -f "$LACY_SHELL_CONFIG_FILE" ]]; then
        lacy_shell_create_default_config
    fi

    # Parse configuration using simple shell parsing
    if [[ -f "$LACY_SHELL_CONFIG_FILE" ]]; then
        # Define key mappings for each section
        local api_keys_map="openai:LACY_SHELL_API_OPENAI,anthropic:LACY_SHELL_API_ANTHROPIC"
        local model_map="provider:LACY_SHELL_PROVIDER,name:LACY_SHELL_MODEL_NAME"
        local agent_map="command:LACY_SHELL_AGENT_COMMAND,context_mode:LACY_SHELL_AGENT_CONTEXT_MODE,needs_api_keys:LACY_SHELL_AGENT_NEEDS_API_KEYS"
        local agent_tools_map="active:LACY_ACTIVE_TOOL"

        # Track current section
        local current_section=""

        while IFS= read -r line; do
            # Detect section headers
            if [[ "$line" =~ ^api_keys: ]]; then
                current_section="api_keys"
                continue
            elif [[ "$line" =~ ^model: ]]; then
                current_section="model"
                continue
            elif [[ "$line" =~ ^agent_tools: ]]; then
                current_section="agent_tools"
                continue
            elif [[ "$line" =~ ^agent: ]]; then
                current_section="agent"
                continue
            elif [[ "$line" =~ ^[^[:space:]] ]] && [[ ! "$line" =~ ^# ]]; then
                # New section started (not indented, not a comment)
                current_section=""
            fi

            # Parse key-value pairs within sections
            if [[ -n "$current_section" ]] && [[ "$line" =~ ^[[:space:]]+([^:]+):[[:space:]]*(.+) ]]; then
                local key="${match[1]}"
                local value="${match[2]}"

                # Use appropriate key map based on section
                case "$current_section" in
                    "api_keys")
                        lacy_shell_export_config_value "$key" "$value" "$api_keys_map"
                        ;;
                    "model")
                        lacy_shell_export_config_value "$key" "$value" "$model_map"
                        ;;
                    "agent")
                        lacy_shell_export_config_value "$key" "$value" "$agent_map"
                        ;;
                    "agent_tools")
                        lacy_shell_export_config_value "$key" "$value" "$agent_tools_map"
                        ;;
                esac
            fi
        done < "$LACY_SHELL_CONFIG_FILE"

        # Check for MCP configuration (simplified)
        if grep -q "^mcp:" "$LACY_SHELL_CONFIG_FILE" 2>/dev/null && \
           grep -q "^[[:space:]]*servers:" "$LACY_SHELL_CONFIG_FILE" 2>/dev/null; then
            LACY_SHELL_MCP_SERVERS="configured"
            # For now, we'll use basic MCP config
            LACY_SHELL_MCP_SERVERS_JSON='[{"name":"filesystem","command":"npx","args":["@modelcontextprotocol/server-filesystem"]}]'
        else
            LACY_SHELL_MCP_SERVERS=""
            LACY_SHELL_MCP_SERVERS_JSON=""
        fi

        # Export variables for global access
        export LACY_SHELL_MCP_SERVERS
        export LACY_SHELL_MCP_SERVERS_JSON
    fi

    # Also check environment variables as fallback
    if [[ -z "$LACY_SHELL_API_OPENAI" ]] && [[ -n "$OPENAI_API_KEY" ]]; then
        export LACY_SHELL_API_OPENAI="$OPENAI_API_KEY"
    fi
    if [[ -z "$LACY_SHELL_API_ANTHROPIC" ]] && [[ -n "$ANTHROPIC_API_KEY" ]]; then
        export LACY_SHELL_API_ANTHROPIC="$ANTHROPIC_API_KEY"
    fi

    # Provider/model overrides via env
    if [[ -z "$LACY_SHELL_PROVIDER" ]] && [[ -n "$LACY_SHELL_DEFAULT_PROVIDER" ]]; then
        export LACY_SHELL_PROVIDER="$LACY_SHELL_DEFAULT_PROVIDER"
    fi
    if [[ -z "$LACY_SHELL_MODEL_NAME" ]] && [[ -n "$LACY_SHELL_DEFAULT_MODEL" ]]; then
        export LACY_SHELL_MODEL_NAME="$LACY_SHELL_DEFAULT_MODEL"
    fi

    # Agent CLI defaults (if not configured, use defaults from constants.zsh)
    : ${LACY_SHELL_AGENT_COMMAND:="$LACY_SHELL_DEFAULT_AGENT_COMMAND"}
    : ${LACY_SHELL_AGENT_CONTEXT_MODE:="$LACY_SHELL_DEFAULT_AGENT_CONTEXT_MODE"}
    : ${LACY_SHELL_AGENT_NEEDS_API_KEYS:="$LACY_SHELL_DEFAULT_AGENT_NEEDS_API_KEYS"}
    export LACY_SHELL_AGENT_COMMAND LACY_SHELL_AGENT_CONTEXT_MODE LACY_SHELL_AGENT_NEEDS_API_KEYS

    # Active AI tool (empty = auto-detect)
    export LACY_ACTIVE_TOOL

    # Initialize current mode from default
    LACY_SHELL_CURRENT_MODE="$LACY_SHELL_DEFAULT_MODE"

    # Export configuration
    export LACY_SHELL_CURRENT_MODE
}

# Create default configuration file
lacy_shell_create_default_config() {
    cat > "$LACY_SHELL_CONFIG_FILE" << 'EOF'
# Lacy Shell Configuration
# Edit this file to customize your settings

# API Keys for AI providers
api_keys:
  openai: # Add your OpenAI API key here
  anthropic: # Add your Anthropic API key here

# Operating modes
modes:
  default: auto  # Options: shell, agent, auto

# Smart auto-detection settings
auto_detection:
  enabled: true
  confidence_threshold: 0.7

# MCP (Model Context Protocol) configuration
mcp:
  enabled: false
  servers:
    - name: filesystem
      command: npx
      args: ["@modelcontextprotocol/server-filesystem", "/"]
    - name: web
      command: npx
      args: ["@modelcontextprotocol/server-web"]

# Appearance
appearance:
  show_mode_indicator: true
  mode_colors:
    shell: green
    agent: blue
    auto: yellow

# Model selection (used when agent CLI is not installed)


# AI CLI tool selection
# Lacy auto-detects installed tools, or you can set one explicitly
agent_tools:
  # Options: lash, claude, opencode, gemini, codex, or empty for auto-detect
  active:

# Agent CLI configuration (legacy)
# Configure which CLI tool to use for AI queries
agent:
  # Command to run. Variables: {query}, {context_file}
  command: "lash run --prompt {query}"
  # How to pass context: stdin or file
  context_mode: stdin
  # Set to true if the CLI needs API keys from lacy-shell
  needs_api_keys: false
EOF

    echo "Created default configuration at: $LACY_SHELL_CONFIG_FILE"
}

# Check if API keys are available
lacy_shell_check_api_keys() {
    if [[ -n "$LACY_SHELL_API_OPENAI" ]] || [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
        return 0
    else
        return 1
    fi
}

# Get active API provider
lacy_shell_get_api_provider() {
    if [[ -n "$LACY_SHELL_API_OPENAI" ]]; then
        echo "openai"
    elif [[ -n "$LACY_SHELL_API_ANTHROPIC" ]]; then
        echo "anthropic"
    else
        echo "none"
    fi
}

# Export config functions (quietly)
