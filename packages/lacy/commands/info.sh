#!/usr/bin/env bash

# Lacy Shell: info command
# Run by `npx lacy info` (shipped in the npm package) and `lacy info`.

_lacy_info_version() {
    local pkg="${HOME}/.lacy/package.json"
    if [[ -f "$pkg" ]]; then
        grep '"version"' "$pkg" 2>/dev/null | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//'
    else
        echo "unknown"
    fi
}

if [[ -n "${NO_COLOR:-}" ]]; then
    _blue="" _magenta="" _reset=""
else
    _blue=$'\033[38;5;75m' _magenta=$'\033[38;5;200m' _reset=$'\033[0m'
fi

printf '%sLacy Shell v%s%s\n\n' "$_blue" "$(_lacy_info_version)" "$_reset"
printf 'Lacy runs commands in your shell and sends questions to your AI tool.\n\n'
printf 'Try:\n'
printf '  ls -la                 runs in your shell\n'
printf '  what files are here    goes to your AI tool\n\n'
printf 'Inside Lacy, type %smode%s to see the current mode, or press Ctrl+Space to switch.\n' "$_magenta" "$_reset"
printf 'Run %slacy setup%s to change your AI tool.\n' "$_magenta" "$_reset"
