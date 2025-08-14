#!/usr/bin/env bash

# Lacy Shell Installation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="${HOME}/.lacy-shell"
REPO_URL="https://github.com/username/lacy-shell.git"

echo -e "${BLUE}🚀 Installing Lacy Shell...${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"
    
    # Check for zsh
    if ! command -v zsh >/dev/null 2>&1; then
        echo -e "${RED}❌ zsh is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ zsh found${NC}"
    
    # Check for Python3
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}❌ python3 is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ python3 found${NC}"
    
    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}❌ curl is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ curl found${NC}"
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}❌ git is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ git found${NC}"
}

# Install Python dependencies
install_dependencies() {
    echo -e "${BLUE}📦 Installing Python dependencies...${NC}"
    
    # Try different installation methods
    if command -v brew >/dev/null 2>&1; then
        echo -e "${BLUE}Using brew to install PyYAML...${NC}"
        brew list python-yq >/dev/null 2>&1 || brew install python-yq
        echo -e "${GREEN}✅ PyYAML available via brew${NC}"
    elif command -v pip3 >/dev/null 2>&1; then
        echo -e "${BLUE}Attempting pip3 installation...${NC}"
        if pip3 install --user PyYAML requests 2>/dev/null; then
            echo -e "${GREEN}✅ Python dependencies installed via pip3${NC}"
        elif pip3 install --break-system-packages PyYAML requests 2>/dev/null; then
            echo -e "${GREEN}✅ Python dependencies installed (system packages)${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not install via pip3. Plugin will use fallback YAML parser.${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No package manager found. Plugin will use fallback YAML parser.${NC}"
        echo -e "${YELLOW}   For better YAML support, install PyYAML manually${NC}"
    fi
}

# Clone or update repository
install_plugin() {
    echo -e "${BLUE}📁 Installing plugin files...${NC}"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "${YELLOW}⚠️  Existing installation found. Updating...${NC}"
        cd "$INSTALL_DIR"
        git pull origin main
    else
        echo -e "${BLUE}📥 Cloning repository...${NC}"
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    
    echo -e "${GREEN}✅ Plugin files installed${NC}"
}

# Setup local installation (if not using git)
setup_local() {
    echo -e "${BLUE}📁 Setting up local installation...${NC}"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Copy files from current directory
    if [[ -f "lacy-shell.plugin.zsh" ]]; then
        cp -r . "$INSTALL_DIR/"
        echo -e "${GREEN}✅ Files copied to $INSTALL_DIR${NC}"
    else
        echo -e "${RED}❌ Plugin files not found in current directory${NC}"
        exit 1
    fi
}

# Configure zsh integration
configure_zsh() {
    echo -e "${BLUE}⚙️  Configuring zsh integration...${NC}"
    
    local zshrc="${HOME}/.zshrc"
    local plugin_line="source ${INSTALL_DIR}/lacy-shell.plugin.zsh"
    
    # Check if already configured
    if grep -q "lacy-shell.plugin.zsh" "$zshrc" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Lacy Shell already configured in .zshrc${NC}"
        return
    fi
    
    # Add to .zshrc
    echo "" >> "$zshrc"
    echo "# Lacy Shell Plugin" >> "$zshrc"
    echo "$plugin_line" >> "$zshrc"
    
    echo -e "${GREEN}✅ Added to .zshrc${NC}"
}

# Create initial configuration
create_config() {
    echo -e "${BLUE}📝 Creating initial configuration...${NC}"
    
    local config_dir="${HOME}/.lacy-shell"
    local config_file="${config_dir}/config.yaml"
    
    mkdir -p "$config_dir"
    
    if [[ ! -f "$config_file" ]]; then
        # Create default config
        cat > "$config_file" << 'EOF'
# Lacy Shell Configuration
# Edit this file to customize your settings

api_keys:
  # Add your API keys here:
  # openai: "your-openai-api-key-here"
  # anthropic: "your-anthropic-api-key-here"

mcp:
  servers:
    - name: "filesystem"
      command: "npx"
      args: ["@modelcontextprotocol/server-filesystem", "/tmp"]
    # - name: "web"
    #   command: "npx"
    #   args: ["@modelcontextprotocol/server-web"]

modes:
  default: "auto"  # Options: shell, agent, auto

keybindings:
  toggle_mode: "^[^M"     # Alt+Enter
  agent_mode: "^A"       # Ctrl+A
  shell_mode: "^S"       # Ctrl+S

detection:
  agent_keywords:
    - "help"
    - "how"
    - "what"
    - "why"
    - "explain"
    - "show me"
    - "find"
    - "search"
  
  shell_commands:
    - "ls"
    - "cd"
    - "pwd"
    - "git"
    - "npm"
    - "yarn"
    - "pip"
EOF
        echo -e "${GREEN}✅ Configuration file created at $config_file${NC}"
    else
        echo -e "${YELLOW}⚠️  Configuration file already exists${NC}"
    fi
}

# Setup MCP servers
setup_mcp() {
    echo -e "${BLUE}🔧 Setting up MCP servers...${NC}"
    
    # Check if npm is available for MCP servers
    if command -v npm >/dev/null 2>&1; then
        echo -e "${BLUE}📦 Installing MCP server packages...${NC}"
        
        # Install MCP filesystem server
        if ! npm list -g @modelcontextprotocol/server-filesystem >/dev/null 2>&1; then
            npm install -g @modelcontextprotocol/server-filesystem
            echo -e "${GREEN}✅ MCP filesystem server installed${NC}"
        else
            echo -e "${YELLOW}⚠️  MCP filesystem server already installed${NC}"
        fi
        
        # Install MCP web server (optional)
        read -p "Install MCP web server? (y/N): " install_web
        if [[ "$install_web" == "y" || "$install_web" == "Y" ]]; then
            npm install -g @modelcontextprotocol/server-web
            echo -e "${GREEN}✅ MCP web server installed${NC}"
        fi
        
        # Test MCP installation
        echo -e "${BLUE}🧪 Testing MCP server installation...${NC}"
        if npx @modelcontextprotocol/server-filesystem --help >/dev/null 2>&1; then
            echo -e "${GREEN}✅ MCP filesystem server is working${NC}"
        else
            echo -e "${YELLOW}⚠️  MCP filesystem server test failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  npm not found. MCP servers will need to be installed manually.${NC}"
        echo -e "${YELLOW}   Install with: npm install -g @modelcontextprotocol/server-filesystem${NC}"
    fi
}

# Final setup instructions
show_instructions() {
    echo ""
    echo -e "${GREEN}🎉 Lacy Shell installation complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Edit your configuration: ${HOME}/.lacy-shell/config.yaml"
    echo "3. Add your API keys (OpenAI or Anthropic)"
    echo "4. Try it out with: ask \"what files are in this directory?\""
    echo ""
    echo -e "${BLUE}🔧 Configuration file:${NC} ${HOME}/.lacy-shell/config.yaml"
    echo -e "${BLUE}📖 Documentation:${NC} ${INSTALL_DIR}/README.md"
    echo ""
    echo -e "${BLUE}⌨️  Keybindings:${NC}"
    echo "   Alt+Enter: Toggle mode"
    echo "   Ctrl+A:    Agent mode"
    echo "   Ctrl+S:    Shell mode"
    echo "   Alt+H:     Help"
    echo ""
    echo -e "${YELLOW}💡 Test the detection: lacy_shell_test_detection${NC}"
}

# Main installation flow
main() {
    check_prerequisites
    install_dependencies
    
    # Choose installation method
    if [[ "$1" == "--local" ]]; then
        setup_local
    else
        install_plugin
    fi
    
    configure_zsh
    create_config
    setup_mcp
    show_instructions
}

# Handle command line arguments
case "$1" in
    "--help"|"-h")
        echo "Lacy Shell Installation Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --local    Install from current directory instead of git"
        echo "  --help     Show this help message"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
