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
REPO_URL="https://github.com/lacymorrow/lacy-shell.git"

echo -e "${BLUE}🚀 Installing Lacy Shell...${NC}"

# Check prerequisites (minimal)
check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"

    # Check for zsh
    if ! command -v zsh >/dev/null 2>&1; then
        echo -e "${RED}❌ zsh is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ zsh found${NC}"

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

# Clone or update repository
install_plugin() {
    echo -e "${BLUE}📁 Installing plugin files...${NC}"

    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "${YELLOW}⚠️  Existing installation found. Updating...${NC}"
        cd "$INSTALL_DIR" || {
            echo -e "${RED}❌ Cannot access installation directory: $INSTALL_DIR${NC}"
            exit 1
        }
        git pull origin main || {
            echo -e "${RED}❌ Failed to update repository${NC}"
            exit 1
        }
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
    if [[ -f "$zshrc" ]] && grep -q "lacy-shell.plugin.zsh" "$zshrc" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Lacy Shell already configured in .zshrc${NC}"
        return
    fi

    # Create .zshrc if it doesn't exist
    if [[ ! -f "$zshrc" ]]; then
        touch "$zshrc" || {
            echo -e "${RED}❌ Cannot create .zshrc file${NC}"
            exit 1
        }
    fi

    # Add to .zshrc
    {
        echo ""
        echo "# Lacy Shell Plugin"
        echo "$plugin_line"
    } >> "$zshrc" || {
        echo -e "${RED}❌ Cannot write to .zshrc file${NC}"
        exit 1
    }

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

# Final setup instructions
show_instructions() {
    echo ""
    echo -e "${GREEN}🎉 Lacy Shell installation complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Edit your configuration: ${HOME}/.lacy-shell/config.yaml"
    echo "3. (Optional) Install Lash: brew install lacymorrow/tap/lash"
    echo "4. Try it: ask \"what files are in this directory?\""
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
    # Choose installation method
    if [[ "$1" == "--local" ]]; then
        setup_local
    else
        install_plugin
    fi

    configure_zsh
    create_config
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
