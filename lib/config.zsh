#!/usr/bin/env zsh

# Configuration management for Lacy Shell

# Default configuration
typeset -A LACY_SHELL_CONFIG
LACY_SHELL_CONFIG_FILE="${HOME}/.lacy-shell/config.yaml"

# Simple YAML parser for shell (handles basic key: value)
lacy_shell_parse_yaml_value() {
    local file="$1"
    local key="$2"
    
    # Extract value for a simple key: value pair
    grep "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | tr -d "'"
}

# Load configuration from file
lacy_shell_load_config() {
    # Set defaults
    LACY_SHELL_DEFAULT_MODE="auto"
    LACY_SHELL_CURRENT_MODE="auto"
    
    # Create config directory if it doesn't exist
    if [[ ! -d "${HOME}/.lacy-shell" ]]; then
        mkdir -p "${HOME}/.lacy-shell"
    fi
    
    # Create default config if it doesn't exist
    if [[ ! -f "$LACY_SHELL_CONFIG_FILE" ]]; then
        lacy_shell_create_default_config
    fi
    
    # Parse configuration using simple shell parsing
    if [[ -f "$LACY_SHELL_CONFIG_FILE" ]]; then
        # Load default mode
        local mode_line=$(grep -A 1 "^modes:" "$LACY_SHELL_CONFIG_FILE" 2>/dev/null | grep "default:" | head -1)
        if [[ -n "$mode_line" ]]; then
            local default_mode=$(echo "$mode_line" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
            LACY_SHELL_DEFAULT_MODE="${default_mode:-auto}"
        fi
        
        # Load API keys
        local in_api_section=false
        while IFS= read -r line; do
            # Check if we're in the api_keys section
            if [[ "$line" =~ ^api_keys: ]]; then
                in_api_section=true
                continue
            elif [[ "$line" =~ ^[^[:space:]] ]] && [[ ! "$line" =~ ^# ]]; then
                # New section started, exit api_keys
                in_api_section=false
            fi
            
            # Parse API keys
            if [[ "$in_api_section" == true ]] && [[ "$line" =~ ^[[:space:]]+([^:]+):[[:space:]]*(.+) ]]; then
                local key="${match[1]}"
                local value="${match[2]}"
                # Remove quotes and comments
                value=$(echo "$value" | sed 's/#.*//' | tr -d '"' | tr -d "'" | xargs)
                
                if [[ -n "$value" ]] && [[ "$value" != "null" ]]; then
                    if [[ "$key" == "openai" ]]; then
                        export LACY_SHELL_API_OPENAI="$value"
                    elif [[ "$key" == "anthropic" ]]; then
                        export LACY_SHELL_API_ANTHROPIC="$value"
                    fi
                fi
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
    
    # Load persisted mode if exists
    if [[ -f "${HOME}/.lacy_shell_mode" ]]; then
        LACY_SHELL_CURRENT_MODE=$(cat "${HOME}/.lacy_shell_mode")
    else
        LACY_SHELL_CURRENT_MODE="$LACY_SHELL_DEFAULT_MODE"
    fi
    
    # Export the configuration
    export LACY_SHELL_DEFAULT_MODE
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