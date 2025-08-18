#!/usr/bin/env bash

set -e

LACY_DIR="${HOME}/.lacy-shell"
ZSHRC="${HOME}/.zshrc"

echo "🔧 Removing Lacy Shell from .zshrc"
if [[ -f "$ZSHRC" ]]; then
  tmp_file=$(mktemp)
  grep -v "lacy-shell.plugin.zsh" "$ZSHRC" > "$tmp_file" || true
  mv "$tmp_file" "$ZSHRC"
  echo "✅ .zshrc updated"
fi

echo "🗑  Removing installation directory: $LACY_DIR"
rm -rf "$LACY_DIR"

echo "✅ Uninstall complete. Restart your terminal or 'source ~/.zshrc'"


