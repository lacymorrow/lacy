#!/usr/bin/env zsh

# Configuration management for Lacy Shell

# Default configuration
typeset -A LACY_SHELL_CONFIG
LACY_SHELL_CONFIG_FILE="${HOME}/.lacy-shell/config.yaml"

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
    
    # Try to load config using Python with YAML, fallback to basic parsing
    if command -v python3 >/dev/null 2>&1; then
        # Load default mode
        local default_mode=$(python3 -c "
import sys
import os
try:
    import yaml
    with open('$LACY_SHELL_CONFIG_FILE', 'r') as f:
        config = yaml.safe_load(f)
    if 'modes' in config and 'default' in config['modes']:
        print(config['modes']['default'])
    else:
        print('auto')
except:
    print('auto')
" 2>/dev/null)
        LACY_SHELL_DEFAULT_MODE="${default_mode:-auto}"
        
        # Load API keys
        local api_exports=$(python3 -c "
import sys
import os
try:
    import yaml
    with open('$LACY_SHELL_CONFIG_FILE', 'r') as f:
        config = yaml.safe_load(f)
    if 'api_keys' in config:
        for key, value in config['api_keys'].items():
            if value and not str(value).startswith('#'):
                print(f'export LACY_SHELL_API_{key.upper()}=\"{value}\"')
except:
    pass
" 2>/dev/null)
        if [[ -n "$api_exports" ]]; then
            eval "$api_exports"
            # Ensure API keys are exported globally
            export LACY_SHELL_API_OPENAI
            export LACY_SHELL_API_ANTHROPIC
        fi
        
        # Load MCP configuration
        # First check if MCP servers are configured
        if python3 -c "import yaml; config=yaml.safe_load(open('$LACY_SHELL_CONFIG_FILE')); exit(0 if 'mcp' in config and 'servers' in config['mcp'] and config['mcp']['servers'] else 1)" 2>/dev/null; then
            LACY_SHELL_MCP_SERVERS="configured"
            
            # Save MCP servers JSON to temp file
            python3 -c "
import yaml
import json
with open('$LACY_SHELL_CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
servers_json = json.dumps(config['mcp']['servers'])
with open('/tmp/lacy-shell-mcp-servers.json', 'w') as f:
    f.write(servers_json)
" 2>/dev/null
            
            # Load JSON from temp file
            if [[ -f "/tmp/lacy-shell-mcp-servers.json" ]]; then
                LACY_SHELL_MCP_SERVERS_JSON=$(cat /tmp/lacy-shell-mcp-servers.json)
                rm -f /tmp/lacy-shell-mcp-servers.json
            else
                LACY_SHELL_MCP_SERVERS_JSON=""
            fi
        else
            LACY_SHELL_MCP_SERVERS=""
            LACY_SHELL_MCP_SERVERS_JSON=""
        fi
        
        # Export variables for global access
        export LACY_SHELL_MCP_SERVERS
        export LACY_SHELL_MCP_SERVERS_JSON
    else
        echo "Warning: Python3 not found. Using default configuration."
        LACY_SHELL_DEFAULT_MODE="auto"
        LACY_SHELL_MCP_SERVERS=""
        LACY_SHELL_MCP_SERVERS_JSON=""
    fi
}

# Create default configuration file
lacy_shell_create_default_config() {
    cat > "$LACY_SHELL_CONFIG_FILE" << 'EOF'
# Lacy Shell Configuration

api_keys:
  # openai: "your-openai-api-key"
  # anthropic: "your-anthropic-api-key"

mcp:
  servers:
    - name: "filesystem"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/tmp"]
    # - name: "web"
    #   command: "npx"  
    #   args: ["@modelcontextprotocol/server-web"]

modes:
  default: "auto"  # shell, agent, auto

keybindings:
  toggle_mode: "^[^M"     # Alt+Enter
  agent_mode: "^A"       # Ctrl+A  
  shell_mode: "^S"       # Ctrl+S

# Auto-detection settings
detection:
  # Keywords that suggest agent mode
  agent_keywords:
    - "help"
    - "how"
    - "what"
    - "why"
    - "explain"
    - "show me"
    - "find"
    - "search"
  
  # Commands that should always use shell mode
  shell_commands:
    - "ls"
    - "cd"
    - "pwd"
    - "cp"
    - "mv"
    - "rm"
    - "mkdir"
    - "rmdir"
    - "chmod"
    - "chown"
    - "ps"
    - "kill"
    - "top"
    - "htop"
    - "grep"
    - "sed"
    - "awk"
    - "git"
    - "npm"
    - "yarn"
    - "pip"
    - "cargo"
EOF
    
    # Quiet config creation - user can edit later if needed
}

# Get configuration value
lacy_shell_get_config() {
    local key="$1"
    echo "${LACY_SHELL_CONFIG[$key]:-}"
}

# Check if API keys are configured
lacy_shell_check_api_keys() {
    if [[ -z "$LACY_SHELL_API_OPENAI" && -z "$LACY_SHELL_API_ANTHROPIC" ]]; then
        echo "Warning: No API keys configured. Agent mode will not work."
        echo "Please add API keys to $LACY_SHELL_CONFIG_FILE"
        return 1
    fi
    return 0
}
