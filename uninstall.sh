#!/usr/bin/env bash

# Lacy Shell Uninstallation Script

set -e

LACY_DIR="${HOME}/.lacy"
LACY_DIR_OLD="${HOME}/.lacy-shell"
ZSHRC="${HOME}/.zshrc"

echo "Uninstalling Lacy Shell..."
echo ""

# Remove from .zshrc
if [[ -f "$ZSHRC" ]]; then
    echo "Removing from .zshrc..."
    tmp_file=$(mktemp)
    grep -v "lacy.plugin.zsh" "$ZSHRC" > "$tmp_file" || true
    # Also remove the comment line
    grep -v "# Lacy Shell" "$tmp_file" > "${tmp_file}.2" || true
    mv "${tmp_file}.2" "$ZSHRC"
    rm -f "$tmp_file"
    echo "  ✓ .zshrc updated"
fi

# Remove new installation directory
if [[ -d "$LACY_DIR" ]]; then
    echo "Removing $LACY_DIR..."
    rm -rf "$LACY_DIR"
    echo "  ✓ Installation removed"
fi

# Remove old installation directory (if exists)
if [[ -d "$LACY_DIR_OLD" ]]; then
    echo "Removing old installation at $LACY_DIR_OLD..."
    rm -rf "$LACY_DIR_OLD"
    echo "  ✓ Old installation removed"
fi

echo ""
echo "Lacy Shell uninstalled."
echo "Restart your terminal or run: source ~/.zshrc"
