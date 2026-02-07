#!/usr/bin/env bash

# Configuration management for Lacy Shell
# Shared across Bash 4+ and ZSH

# Default configuration
declare -A LACY_SHELL_CONFIG 2>/dev/null || true
# LACY_SHELL_CONFIG_FILE is defined in constants.sh

# ============================================================================
# Config Parsing Helpers (reduces code duplication)
# ============================================================================

# Simple YAML parser for shell (handles basic key: value)
lacy_shell_parse_yaml_value() {
    local file="$1"
    local key="$2"

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

    # Split key_map by comma and iterate
    local IFS_save="$IFS"
    IFS=','
    local -a mappings
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        mappings=( ${(s:,:)key_map} )
    else
        read -ra mappings <<< "$key_map"
    fi
    IFS="$IFS_save"

    local mapping config_key env_var
    for mapping in "${mappings[@]}"; do
        config_key="${mapping%%:*}"
        env_var="${mapping#*:}"
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
        LACY_CONFIG_CACHE_VALID=false
    fi

    # Check if we can use cached config
    if [[ "$LACY_CONFIG_CACHE_VALID" == true ]] && \
       [[ -f "$LACY_SHELL_CONFIG_CACHE_FILE" ]] && \
       [[ "$LACY_SHELL_CONFIG_FILE" -nt "$LACY_SHELL_CONFIG_CACHE_FILE" ]]; then
        # Use cached config - much faster
        source "$LACY_SHELL_CONFIG_CACHE_FILE"
        return
    fi

    # Parse configuration using optimized single-pass parsing
    if [[ -f "$LACY_SHELL_CONFIG_FILE" ]]; then
        # Define key mappings for each section
        local api_keys_map="openai:LACY_SHELL_API_OPENAI,anthropic:LACY_SHELL_API_ANTHROPIC"
        local model_map="provider:LACY_SHELL_PROVIDER,name:LACY_SHELL_MODEL_NAME"
        local agent_map="command:LACY_SHELL_AGENT_COMMAND,context_mode:LACY_SHELL_AGENT_CONTEXT_MODE,needs_api_keys:LACY_SHELL_AGENT_NEEDS_API_KEYS"
        local agent_tools_map="active:LACY_ACTIVE_TOOL,custom_command:LACY_CUSTOM_TOOL_CMD"
        local preheat_map="eager:LACY_PREHEAT_EAGER,server_port:LACY_PREHEAT_SERVER_PORT"

        # Track current section
        local current_section=""

        local line key value
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
            elif [[ "$line" =~ ^preheat: ]]; then
                current_section="preheat"
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
                if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
                    key="${match[1]}"
                    value="${match[2]}"
                else
                    key="${BASH_REMATCH[1]}"
                    value="${BASH_REMATCH[2]}"
                fi

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
                    "preheat")
                        lacy_shell_export_config_value "$key" "$value" "$preheat_map"
                        ;;
                esac
            fi
        done < "$LACY_SHELL_CONFIG_FILE"

        # Check for MCP configuration (simplified)
        local mcp_line servers_line
        mcp_line=$(grep "^mcp:" "$LACY_SHELL_CONFIG_FILE" 2>/dev/null || true)
        servers_line=$(grep "^[[:space:]]*servers:" "$LACY_SHELL_CONFIG_FILE" 2>/dev/null || true)
        if [[ -n "$mcp_line" ]] && [[ -n "$servers_line" ]]; then
            LACY_SHELL_MCP_SERVERS="configured"
            LACY_SHELL_MCP_SERVERS_JSON='[{"name":"filesystem","command":"npx","args":["@modelcontextprotocol/server-filesystem"]}]'
        else
            LACY_SHELL_MCP_SERVERS=""
            LACY_SHELL_MCP_SERVERS_JSON=""
        fi

        # Cache the parsed configuration for fast future loads
        {
            echo "# Generated config cache - do not edit"
            echo "LACY_SHELL_CURRENT_MODE='$LACY_SHELL_CURRENT_MODE'"
            echo "LACY_SHELL_API_OPENAI='$LACY_SHELL_API_OPENAI'"
            echo "LACY_SHELL_API_ANTHROPIC='$LACY_SHELL_API_ANTHROPIC'"
            echo "LACY_SHELL_PROVIDER='$LACY_SHELL_PROVIDER'"
            echo "LACY_SHELL_MODEL_NAME='$LACY_SHELL_MODEL_NAME'"
            echo "LACY_ACTIVE_TOOL='$LACY_ACTIVE_TOOL'"
            echo "LACY_CUSTOM_TOOL_CMD='$LACY_CUSTOM_TOOL_CMD'"
            echo "LACY_SHELL_MCP_SERVERS='$LACY_SHELL_MCP_SERVERS'"
            echo "LACY_SHELL_MCP_SERVERS_JSON='$LACY_SHELL_MCP_SERVERS_JSON'"
        } > "$LACY_SHELL_CONFIG_CACHE_FILE"

        LACY_CONFIG_CACHE_VALID=true

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

    # Agent CLI defaults (if not configured, use defaults from constants)
    : "${LACY_SHELL_AGENT_COMMAND:="$LACY_SHELL_DEFAULT_AGENT_COMMAND"}"
    : "${LACY_SHELL_AGENT_CONTEXT_MODE:="$LACY_SHELL_DEFAULT_AGENT_CONTEXT_MODE"}"
    : "${LACY_SHELL_AGENT_NEEDS_API_KEYS:="$LACY_SHELL_DEFAULT_AGENT_NEEDS_API_KEYS"}"
    export LACY_SHELL_AGENT_COMMAND LACY_SHELL_AGENT_CONTEXT_MODE LACY_SHELL_AGENT_NEEDS_API_KEYS

    # Active AI tool (empty = auto-detect)
    export LACY_ACTIVE_TOOL
    export LACY_CUSTOM_TOOL_CMD

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
  # Options: lash, claude, opencode, gemini, codex, custom, or empty for auto-detect
  active:
  # Custom command (used when active: custom)
  # custom_command: "your-command -flags"

# Preheat: keep agents warm between queries (lash, opencode)
# preheat:
#   eager: false          # Start background server on plugin load
#   server_port: 4096     # Port for background server

# Agent CLI configuration (legacy)
# Configure which CLI tool to use for AI queries
agent:
  # Command to run. Variables: {query}, {context_file}
  command: "lash run --prompt {query}"
  # How to pass context: stdin or file
  context_mode: stdin
  # Set to true if the CLI needs API keys from lacy
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
