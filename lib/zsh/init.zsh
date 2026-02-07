#!/usr/bin/env zsh

# ZSH adapter init — sources shared core + ZSH-specific modules

# Shell type is already set by lacy.plugin.zsh before sourcing this file.
# LACY_SHELL_TYPE="zsh"
# _LACY_ARR_OFFSET=1

# Source shared core modules
source "$LACY_SHELL_DIR/lib/core/constants.sh"
source "$LACY_SHELL_DIR/lib/core/config.sh"
source "$LACY_SHELL_DIR/lib/core/modes.sh"
source "$LACY_SHELL_DIR/lib/core/spinner.sh"
source "$LACY_SHELL_DIR/lib/core/mcp.sh"
source "$LACY_SHELL_DIR/lib/core/preheat.sh"
source "$LACY_SHELL_DIR/lib/core/detection.sh"

# Source ZSH-specific adapter modules
source "$LACY_SHELL_DIR/lib/zsh/keybindings.zsh"
source "$LACY_SHELL_DIR/lib/zsh/prompt.zsh"
source "$LACY_SHELL_DIR/lib/zsh/execute.zsh"
