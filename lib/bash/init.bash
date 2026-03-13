#!/usr/bin/env bash

# Bash adapter init — sources shared core + Bash-specific modules

# Require Bash 4+ (for declare -A, ${var,,}, READLINE_LINE)
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "Lacy Shell requires Bash 4+. You have Bash ${BASH_VERSION}."
    echo ""
    echo "Upgrade options:"
    echo "  macOS:  brew install bash"
    echo "  Linux:  sudo apt install bash  (or your package manager)"
    echo ""
    echo "After installing, add the new bash to /etc/shells and set it as default:"
    echo "  echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells"
    echo "  chsh -s /opt/homebrew/bin/bash"
    return 1 2>/dev/null || exit 1
fi

# Shell type is already set by lacy.plugin.bash before sourcing this file.
# LACY_SHELL_TYPE="bash"
# _LACY_ARR_OFFSET=0

# Source shared core modules
source "$LACY_SHELL_DIR/lib/core/constants.sh"
source "$LACY_SHELL_DIR/lib/core/config.sh"
source "$LACY_SHELL_DIR/lib/core/modes.sh"
source "$LACY_SHELL_DIR/lib/core/animations.sh"
source "$LACY_SHELL_DIR/lib/core/spinner.sh"
source "$LACY_SHELL_DIR/lib/core/mcp.sh"
source "$LACY_SHELL_DIR/lib/core/preheat.sh"
source "$LACY_SHELL_DIR/lib/core/detection.sh"

# Source Bash-specific adapter modules
source "$LACY_SHELL_DIR/lib/bash/keybindings.bash"
source "$LACY_SHELL_DIR/lib/bash/prompt.bash"
source "$LACY_SHELL_DIR/lib/bash/execute.bash"
