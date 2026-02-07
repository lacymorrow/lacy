#!/usr/bin/env bash

# Lacy Shell Installation Script
# https://github.com/lacymorrow/lacy
#
# Install methods:
#   curl -fsSL https://lacy.sh/install | bash
#   npx lacy
#   brew install lacymorrow/tap/lacy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="${HOME}/.lacy"
REPO_URL="https://github.com/lacymorrow/lacy.git"
CONFIG_FILE="${INSTALL_DIR}/config.yaml"

# Selected tool (set during installation)
SELECTED_TOOL=""
CUSTOM_COMMAND=""

# Detected shell (set during installation)
DETECTED_SHELL=""

# Detect user's login shell
detect_user_shell() {
    if [[ -n "$LACY_FORCE_SHELL" ]]; then
        DETECTED_SHELL="$LACY_FORCE_SHELL"
        return
    fi

    local login_shell
    login_shell=$(basename "${SHELL:-}")

    case "$login_shell" in
        zsh)  DETECTED_SHELL="zsh" ;;
        bash) DETECTED_SHELL="bash" ;;
        *)    DETECTED_SHELL="zsh" ;;  # Default to zsh
    esac
}

# Get the RC file for the detected shell
get_rc_file() {
    case "$DETECTED_SHELL" in
        zsh)  echo "${HOME}/.zshrc" ;;
        bash)
            # macOS uses .bash_profile for login shells
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "${HOME}/.bash_profile"
            else
                echo "${HOME}/.bashrc"
            fi
            ;;
        *)    echo "${HOME}/.zshrc" ;;
    esac
}

# Get the plugin file for the detected shell
get_plugin_file() {
    case "$DETECTED_SHELL" in
        zsh)  echo "lacy.plugin.zsh" ;;
        bash) echo "lacy.plugin.bash" ;;
        *)    echo "lacy.plugin.zsh" ;;
    esac
}

# Get the shell restart command
get_shell_restart_cmd() {
    case "$DETECTED_SHELL" in
        zsh)  echo "zsh -l" ;;
        bash) echo "bash -l" ;;
        *)    echo "zsh -l" ;;
    esac
}

# Get the source command for the RC file
get_source_hint() {
    local rc_file
    rc_file=$(get_rc_file)
    echo "source $rc_file"
}

# Check if we should use Node installer
use_node_installer() {
    # Skip Node installer if --bash flag is passed
    [[ "$LACY_FORCE_BASH" == "1" ]] && return 1

    # Check if npx is available and we have an interactive terminal
    # Note: when piped (curl | bash), -t 0 is false but /dev/tty is still available
    if command -v npx >/dev/null 2>&1 && { [[ -t 0 ]] || [[ -c /dev/tty ]]; }; then
        return 0
    fi
    return 1
}

# Run Node installer via npx
run_node_installer() {
    # Quietly check if package exists first
    if ! npm view lacy version >/dev/null 2>&1; then
        return 1
    fi

    printf "${BLUE}Using interactive installer...${NC}\n"
    printf "\n"
    # Redirect stdin from /dev/tty so the Node process gets an interactive TTY
    # even when this script is piped (curl | bash)
    if npx --yes lacy@latest < /dev/tty; then
        exit 0
    fi

    # npx failed for some reason, fall back
    printf "\n"
    printf "${YELLOW}Falling back to standard installer...${NC}\n"
    printf "\n"
    return 1
}

print_banner() {
    printf "\n"
    printf "${MAGENTA}${BOLD}"
    printf "  _                      \n"
    printf " | |    __ _  ___ _   _  \n"
    printf " | |   / _\` |/ __| | | | \n"
    printf " | |__| (_| | (__| |_| | \n"
    printf " |_____\__,_|\___|\__, | \n"
    printf "                  |___/  \n"
    printf "${NC}"
    printf "${CYAN}Talk directly to your shell${NC}\n"
    printf "\n"
}

# Check prerequisites
check_prerequisites() {
    printf "${BLUE}Checking prerequisites...${NC}\n"
    local missing=0

    # Check for the target shell
    case "$DETECTED_SHELL" in
        zsh)
            if command -v zsh >/dev/null 2>&1; then
                printf "  ${GREEN}✓${NC} zsh\n"
            else
                printf "  ${RED}✗${NC} zsh (required)\n"
                missing=1
            fi
            ;;
        bash)
            if command -v bash >/dev/null 2>&1; then
                local bash_version
                bash_version=$(bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo "0")
                if [[ "$bash_version" -ge 4 ]]; then
                    printf "  ${GREEN}✓${NC} bash ${bash_version}+\n"
                else
                    printf "  ${RED}✗${NC} bash 4+ required (found bash ${bash_version})\n"
                    printf "    ${DIM}Install with: brew install bash${NC}\n"
                    missing=1
                fi
            else
                printf "  ${RED}✗${NC} bash (required)\n"
                missing=1
            fi
            ;;
    esac

    # Check for curl
    if command -v curl >/dev/null 2>&1; then
        printf "  ${GREEN}✓${NC} curl\n"
    else
        printf "  ${RED}✗${NC} curl (required)\n"
        missing=1
    fi

    # Check for git
    if command -v git >/dev/null 2>&1; then
        printf "  ${GREEN}✓${NC} git\n"
    else
        printf "  ${RED}✗${NC} git (required)\n"
        missing=1
    fi

    printf "\n"

    if [[ $missing -eq 1 ]]; then
        printf "${RED}Please install missing prerequisites and try again.${NC}\n"
        exit 1
    fi
}

# Detect installed AI CLI tools
detect_tools() {
    printf "${BLUE}Detecting AI CLI tools...${NC}\n"
    local found=0

    for tool in lash claude opencode gemini codex; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} $tool\n"
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        printf "  ${YELLOW}○${NC} No AI CLI tools found\n"
        printf "\n"
        printf "${YELLOW}Lacy Shell requires an AI CLI tool to work.${NC}\n"
        printf "Would you like to install ${GREEN}lash${NC} (recommended)?\n"
        printf "\n"
        read -p "Install lash now? [Y/n]: " install_now < /dev/tty
        if [[ ! "$install_now" =~ ^[Nn]$ ]]; then
            install_lash_cli
            printf "\n"
            # Re-check if lash was installed successfully
            if command -v lash >/dev/null 2>&1; then
                printf "  ${GREEN}✓${NC} lash\n"
            fi
        fi
    fi

    printf "\n"
}

# Interactive tool selection (bash fallback)
select_tool() {
    printf "${BOLD}Which AI CLI tool do you want to use?${NC}\n"
    printf "\n"
    printf "  1) lash       ${DIM}- recommended${NC}\n"
    printf "  2) claude     ${DIM}- Claude Code CLI${NC}\n"
    printf "  3) opencode   ${DIM}- OpenCode CLI${NC}\n"
    printf "  4) gemini     ${DIM}- Google Gemini CLI${NC}\n"
    printf "  5) codex      ${DIM}- OpenAI Codex CLI${NC}\n"
    printf "  6) Auto-detect ${DIM}(use first available)${NC}\n"
    printf "  7) None       ${DIM}- I'll install one later${NC}\n"
    printf "  8) Custom     ${DIM}- enter your own command${NC}\n"
    printf "\n"

    local choice
    read -p "Select [1-8, default=6]: " choice < /dev/tty

    case "$choice" in
        1) SELECTED_TOOL="lash" ;;
        2) SELECTED_TOOL="claude" ;;
        3) SELECTED_TOOL="opencode" ;;
        4) SELECTED_TOOL="gemini" ;;
        5) SELECTED_TOOL="codex" ;;
        6|"") SELECTED_TOOL="" ;;
        7) SELECTED_TOOL="none" ;;
        8)
            SELECTED_TOOL="custom"
            printf "\n"
            read -p "Enter command (e.g. claude --dangerously-skip-permissions -p): " CUSTOM_COMMAND < /dev/tty
            if [[ -z "$CUSTOM_COMMAND" ]]; then
                printf "${RED}No command entered. Falling back to auto-detect.${NC}\n"
                SELECTED_TOOL=""
            fi
            ;;
        *) SELECTED_TOOL="" ;;
    esac

    if [[ -n "$SELECTED_TOOL" && "$SELECTED_TOOL" != "none" && "$SELECTED_TOOL" != "custom" ]]; then
        printf "\n"
        printf "Selected: ${GREEN}$SELECTED_TOOL${NC}\n"

        # Check if selected tool is installed
        if ! command -v "$SELECTED_TOOL" >/dev/null 2>&1; then
            printf "${YELLOW}Note: $SELECTED_TOOL is not installed.${NC}\n"

            if [[ "$SELECTED_TOOL" == "lash" ]]; then
                printf "\n"
                read -p "Would you like to install lash now? [y/N]: " install_lash < /dev/tty
                if [[ "$install_lash" =~ ^[Yy]$ ]]; then
                    install_lash_cli
                fi
            else
                printf "You can install it later with:\n"
                case "$SELECTED_TOOL" in
                    claude) printf "  brew install claude\n" ;;
                    opencode) printf "  brew install opencode\n" ;;
                    gemini) printf "  brew install gemini\n" ;;
                    codex) printf "  npm install -g @openai/codex\n" ;;
                esac
            fi
        fi
    elif [[ "$SELECTED_TOOL" == "custom" ]]; then
        printf "\n"
        printf "Selected: ${GREEN}custom${NC} (${CUSTOM_COMMAND})\n"
    elif [[ "$SELECTED_TOOL" == "none" ]]; then
        printf "\n"
        printf "No tool selected. Lacy will prompt you to install one when needed.\n"
    else
        printf "\n"
        printf "Using: ${GREEN}auto-detect${NC} (first available tool)\n"
    fi

    printf "\n"
}

# Install lash CLI
install_lash_cli() {
    printf "${BLUE}Installing lash...${NC}\n"

    if command -v npm >/dev/null 2>&1; then
        npm install -g lash-cli
        printf "${GREEN}✓ lash installed${NC}\n"
    elif command -v brew >/dev/null 2>&1; then
        brew tap lacymorrow/tap
        brew install lash
        printf "${GREEN}✓ lash installed${NC}\n"
    else
        printf "${RED}Could not install lash. Please install npm or homebrew first.${NC}\n"
    fi
}

# Clone or update repository
install_plugin() {
    printf "${BLUE}Installing Lacy...${NC}\n"

    if [[ -d "$INSTALL_DIR" ]]; then
        printf "${YELLOW}Existing installation found. Updating...${NC}\n"
        cd "$INSTALL_DIR" || exit 1
        git pull origin main 2>/dev/null || git pull 2>/dev/null || {
            printf "${YELLOW}Could not update, using existing installation${NC}\n"
        }
    else
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
            printf "${RED}Failed to clone repository${NC}\n"
            exit 1
        }
    fi

    printf "${GREEN}✓ Lacy installed to $INSTALL_DIR${NC}\n"
    printf "\n"
}

# Configure shell integration (multi-shell aware)
configure_shell() {
    printf "${BLUE}Configuring ${DETECTED_SHELL} shell...${NC}\n"

    local rc_file plugin_file plugin_line rc_name

    rc_file=$(get_rc_file)
    plugin_file=$(get_plugin_file)
    rc_name=$(basename "$rc_file")

    plugin_line="source ${INSTALL_DIR}/${plugin_file}"

    # PATH line for the lacy CLI binary
    local path_line
    case "$DETECTED_SHELL" in
        fish)
            path_line="fish_add_path ${INSTALL_DIR}/bin"
            ;;
        *)
            path_line="export PATH=\"${INSTALL_DIR}/bin:\$PATH\""
            ;;
    esac

    # Check if already configured
    if [[ -f "$rc_file" ]] && grep -q "lacy.plugin" "$rc_file" 2>/dev/null; then
        printf "${GREEN}✓ Already configured in ${rc_name}${NC}\n"

        # Add PATH if missing (upgrade from older install)
        if ! grep -q '\.lacy/bin' "$rc_file" 2>/dev/null; then
            printf "%s\n" "$path_line" >> "$rc_file"
            printf "${GREEN}✓ Added lacy CLI to PATH in ${rc_name}${NC}\n"
        fi
    else
        # Ensure parent directory exists
        mkdir -p "$(dirname "$rc_file")"

        # Create RC file if it doesn't exist
        [[ ! -f "$rc_file" ]] && touch "$rc_file"

        # Add source line + PATH
        {
            printf "\n"
            printf "# Lacy Shell\n"
            printf "%s\n" "$plugin_line"
            printf "%s\n" "$path_line"
        } >> "$rc_file"

        printf "${GREEN}✓ Added to ${rc_name}${NC}\n"
    fi

    # For Bash on macOS, also add to .bashrc if it exists (some terminals source it)
    if [[ "$DETECTED_SHELL" == "bash" && "$OSTYPE" == "darwin"* ]]; then
        local bashrc="${HOME}/.bashrc"
        if [[ -f "$bashrc" ]] && ! grep -q "lacy.plugin" "$bashrc" 2>/dev/null; then
            {
                printf "\n"
                printf "# Lacy Shell\n"
                printf "%s\n" "$plugin_line"
                printf "%s\n" "$path_line"
            } >> "$bashrc"
            printf "${GREEN}✓ Also added to .bashrc${NC}\n"
        fi
    fi

    printf "\n"
}

# Backward compat alias
configure_zsh() { configure_shell; }

# Create configuration with selected tool
create_config() {
    printf "${BLUE}Creating configuration...${NC}\n"

    mkdir -p "$INSTALL_DIR"

    # Determine active tool value for config
    local active_tool_value=""
    if [[ -n "$SELECTED_TOOL" && "$SELECTED_TOOL" != "none" ]]; then
        active_tool_value="$SELECTED_TOOL"
    fi

    # Build custom_command line
    local custom_command_line="  # custom_command: \"your-command -flags\""
    if [[ "$SELECTED_TOOL" == "custom" && -n "$CUSTOM_COMMAND" ]]; then
        custom_command_line="  custom_command: \"$CUSTOM_COMMAND\""
    fi

    # Create config file
    cat > "$CONFIG_FILE" << EOF
# Lacy Shell Configuration
# https://github.com/lacymorrow/lacy

# AI CLI tool selection
# Options: lash, claude, opencode, gemini, codex, custom, or empty for auto-detect
agent_tools:
  active: $active_tool_value
$custom_command_line

# API Keys (optional - only needed if no CLI tool is installed)
api_keys:
  # openai: "your-key-here"
  # anthropic: "your-key-here"

# Operating modes
modes:
  default: auto  # Options: shell, agent, auto

# Smart auto-detection settings
auto_detection:
  enabled: true
  confidence_threshold: 0.7
EOF

    printf "${GREEN}✓ Configuration created at $CONFIG_FILE${NC}\n"
    printf "\n"
}

# Show success message
show_success() {
    printf "${GREEN}${BOLD}Installation complete!${NC}\n"
    printf "\n"
    printf "${BOLD}Try it:${NC}\n"
    printf "  ${CYAN}what files are here${NC}  ${DIM}→ AI answers${NC}\n"
    printf "  ${CYAN}ls -la${NC}               ${DIM}→ runs in shell${NC}\n"
    printf "\n"
    printf "${BOLD}Commands:${NC}\n"
    printf "  ${CYAN}mode${NC}          Show/change mode (shell/agent/auto)\n"
    printf "  ${CYAN}tool${NC}          Show/change AI tool\n"
    printf "  ${CYAN}ask \"query\"${NC}   Direct query to AI\n"
    printf "  ${CYAN}Ctrl+Space${NC}    Toggle between modes\n"
    printf "\n"
    printf "${BOLD}Visual feedback:${NC}\n"
    printf "  ${GREEN}▌${NC} Green   = will run in shell\n"
    printf "  ${MAGENTA}▌${NC} Magenta = will go to AI\n"
    printf "\n"

    if [[ "$SELECTED_TOOL" == "none" ]] || { [[ -z "$SELECTED_TOOL" ]] && ! command -v lash >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1; }; then
        printf "${YELLOW}Remember to install an AI CLI tool:${NC}\n"
        printf "  npm install -g lash-cli     # or\n"
        printf "  brew install claude\n"
        printf "\n"
    fi

    printf "${DIM}Learn more: https://github.com/lacymorrow/lacy${NC}\n"
    printf "\n"
}

# Restart shell to apply changes
restart_shell() {
    # Only restart if we're in an interactive terminal
    if [[ -t 0 ]] || [[ -c /dev/tty ]]; then
        printf "\n"
        read -p "Restart shell now to apply changes? [Y/n]: " restart < /dev/tty
        if [[ ! "$restart" =~ ^[Nn]$ ]]; then
            printf "${BLUE}Restarting shell...${NC}\n"
            local restart_cmd
            restart_cmd=$(get_shell_restart_cmd)
            exec $restart_cmd
        else
            printf "\n"
            printf "Run ${CYAN}$(get_source_hint)${NC} or restart your terminal to apply changes.\n"
        fi
    fi
}

# Remove lacy lines from an RC file
_remove_from_rc() {
    local rc_file="$1"
    local rc_name
    rc_name=$(basename "$rc_file")
    if [[ -f "$rc_file" ]]; then
        if grep -q "lacy.plugin" "$rc_file" 2>/dev/null; then
            printf "${BLUE}Removing from ${rc_name}...${NC}\n"
            local tmp_file
            tmp_file=$(mktemp)
            grep -v "lacy.plugin" "$rc_file" | grep -v "# Lacy Shell" | grep -v '\.lacy/bin' > "$tmp_file" || true
            mv "$tmp_file" "$rc_file"
            printf "  ${GREEN}✓${NC} Removed from ${rc_name}\n"
        fi
    fi
}

# Uninstall function
do_uninstall() {
    printf "${BLUE}Uninstalling Lacy Shell...${NC}\n"
    printf "\n"

    # Check if installed
    if [[ ! -d "$INSTALL_DIR" ]]; then
        printf "${YELLOW}Lacy Shell is not installed${NC}\n"
        exit 0
    fi

    # Remove from all possible RC files
    _remove_from_rc "${HOME}/.zshrc"
    _remove_from_rc "${HOME}/.bashrc"
    _remove_from_rc "${HOME}/.bash_profile"
    _remove_from_rc "${HOME}/.config/fish/conf.d/lacy.fish"

    # Remove installation directories
    if [[ -d "$INSTALL_DIR" ]]; then
        printf "${BLUE}Removing $INSTALL_DIR...${NC}\n"
        rm -rf "$INSTALL_DIR"
        printf "  ${GREEN}✓${NC} Removed\n"
    fi

    printf "\n"
    printf "${GREEN}Lacy Shell uninstalled${NC}\n"

    # Restart shell
    if [[ -t 0 ]] || [[ -c /dev/tty ]]; then
        printf "\n"
        detect_user_shell
        read -p "Restart shell now? [Y/n]: " restart < /dev/tty
        if [[ ! "$restart" =~ ^[Nn]$ ]]; then
            local restart_cmd
            restart_cmd=$(get_shell_restart_cmd)
            exec $restart_cmd
        else
            printf "\n"
            printf "Restart your terminal to apply changes.\n"
        fi
    fi
}

# Check if already installed and show menu
check_existing_installation() {
    if [[ -d "$INSTALL_DIR" ]]; then
        print_banner
        printf "${YELLOW}Lacy Shell is already installed.${NC}\n"
        printf "\n"
        printf "What would you like to do?\n"
        printf "\n"
        printf "  1) Update      ${DIM}- pull latest changes${NC}\n"
        printf "  2) Reinstall   ${DIM}- fresh installation${NC}\n"
        printf "  3) Uninstall   ${DIM}- remove Lacy Shell${NC}\n"
        printf "  4) Cancel\n"
        printf "\n"

        local choice
        read -p "Select [1-4]: " choice < /dev/tty

        case "$choice" in
            1)
                printf "\n"
                printf "${BLUE}Updating Lacy...${NC}\n"
                cd "$INSTALL_DIR" 2>/dev/null || {
                    printf "${RED}Could not find installation directory${NC}\n"
                    exit 1
                }
                if git pull origin main 2>/dev/null || git pull 2>/dev/null; then
                    printf "${GREEN}✓ Lacy updated${NC}\n"
                    restart_shell
                else
                    printf "${RED}Update failed. Try reinstalling.${NC}\n"
                fi
                exit 0
                ;;
            2)
                printf "\n"
                printf "${BLUE}Removing existing installation...${NC}\n"
                rm -rf "$INSTALL_DIR" 2>/dev/null
                printf "${GREEN}✓ Removed${NC}\n"
                printf "\n"
                # Continue with fresh install
                return 0
                ;;
            3)
                do_uninstall
                exit 0
                ;;
            4|*)
                printf "\n"
                printf "Cancelled.\n"
                exit 0
                ;;
        esac
    fi
}

# Main installation flow (bash)
main_bash() {
    print_banner
    detect_user_shell
    printf "${DIM}Detected shell: ${DETECTED_SHELL}${NC}\n\n"
    check_prerequisites
    detect_tools
    select_tool
    install_plugin
    configure_shell
    create_config
    show_success
    restart_shell
}

# Main entry point
main() {
    # Try Node installer first (better UX) — it handles existing installations too
    if use_node_installer && run_node_installer; then
        return
    fi

    # Bash installer (fallback)
    # Check for existing installation first (interactive menu)
    if [[ -t 0 ]] || [[ -c /dev/tty ]]; then
        check_existing_installation
    fi

    main_bash
}

# Handle command line arguments
case "$1" in
    "--help"|"-h")
        printf "Lacy Shell Installation Script\n"
        printf "\n"
        printf "Usage: $0 [options]\n"
        printf "\n"
        printf "Options:\n"
        printf "  --help       Show this help message\n"
        printf "  --uninstall  Uninstall Lacy Shell\n"
        printf "  --bash       Force bash installer (skip Node)\n"
        printf "  --shell X    Force shell type (zsh, bash)\n"
        printf "  --tool X     Pre-select tool (lash, claude, opencode, gemini, codex, custom, auto)\n"
        printf "\n"
        printf "Examples:\n"
        printf "  curl -fsSL https://lacy.sh/install | bash\n"
        printf "  curl -fsSL https://lacy.sh/install | bash -s -- --uninstall\n"
        printf "  curl -fsSL https://lacy.sh/install | bash -s -- --tool claude\n"
        printf "  curl -fsSL https://lacy.sh/install | bash -s -- --tool custom \"claude -p\"\n"
        printf "  npx lacy\n"
        printf "  npx lacy --uninstall\n"
        exit 0
        ;;
    "--uninstall"|"-u")
        do_uninstall
        ;;
    "--bash")
        LACY_FORCE_BASH=1
        shift
        main "$@"
        ;;
    "--shell")
        LACY_FORCE_SHELL="$2"
        shift 2
        main "$@"
        ;;
    "--tool")
        SELECTED_TOOL="$2"
        if [[ "$SELECTED_TOOL" == "custom" ]]; then
            CUSTOM_COMMAND="$3"
            if [[ -z "$CUSTOM_COMMAND" ]]; then
                printf "${RED}Error: --tool custom requires a command string.${NC}\n"
                printf "Usage: $0 --tool custom \"command -flags\"\n"
                exit 1
            fi
            shift 3
        else
            shift 2
        fi
        print_banner
        detect_user_shell
        check_prerequisites
        install_plugin
        configure_shell
        create_config
        show_success
        restart_shell
        ;;
    *)
        main "$@"
        ;;
esac
