#!/bin/bash

# Lacy Shell - Info command
# Shows basic information and guides users to setup

_lacy_info_version() {
    local pkg="${HOME}/.lacy/package.json"
    if [[ -f "$pkg" ]]; then
        grep '"version"' "$pkg" 2>/dev/null | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//'
    else
        echo "unknown"
    fi
}

printf '\e[38;5;75m%s\e[0m\n' "🔧 Lacy Shell v$(_lacy_info_version)"
echo
printf '%s\n' "Lacy Shell detects natural language and routes it to AI coding agents."
echo
printf '%s\n' "Quick tips:"
printf '  • %s\n' "Type normally for shell commands"
printf '  • %s\n' "Type natural language for AI assistance"
printf '  • %s\n' "Press Ctrl+Space to toggle modes"
echo
printf '%s\n' "Run '\e[38;5;200mlacy setup\e[0m' to configure your AI tool and settings."
printf '%s\n' "Run '\e[38;5;200mlacy mode\e[0m' to see current mode and legend."