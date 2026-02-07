#!/usr/bin/env bash

# Lacy Shell Uninstallation Script

set -e

LACY_DIR="${HOME}/.lacy"
LACY_DIR_OLD="${HOME}/.lacy-shell"

echo "Uninstalling Lacy Shell..."
echo ""

# Helper: remove lacy lines from a file
remove_from_file() {
    local file="$1"
    local name
    name=$(basename "$file")
    if [[ -f "$file" ]] && grep -q "lacy.plugin" "$file" 2>/dev/null; then
        echo "Removing from ${name}..."
        tmp_file=$(mktemp)
        grep -v "lacy.plugin" "$file" > "$tmp_file" || true
        # Also remove the comment line and PATH line
        grep -v "# Lacy Shell" "$tmp_file" | grep -v '\.lacy/bin' > "${tmp_file}.2" || true
        mv "${tmp_file}.2" "$file"
        rm -f "$tmp_file"
        echo "  done"
    fi
}

# Remove from all possible RC files
remove_from_file "${HOME}/.zshrc"
remove_from_file "${HOME}/.bashrc"
remove_from_file "${HOME}/.bash_profile"
remove_from_file "${HOME}/.config/fish/conf.d/lacy.fish"

# Remove new installation directory
if [[ -d "$LACY_DIR" ]]; then
    echo "Removing $LACY_DIR..."
    rm -rf "$LACY_DIR"
    echo "  done"
fi

# Remove old installation directory (if exists)
if [[ -d "$LACY_DIR_OLD" ]]; then
    echo "Removing old installation at $LACY_DIR_OLD..."
    rm -rf "$LACY_DIR_OLD"
    echo "  done"
fi

echo ""
echo "Lacy Shell uninstalled."
echo "Restart your terminal to apply changes."
