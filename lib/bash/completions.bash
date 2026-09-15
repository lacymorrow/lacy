#!/usr/bin/env bash

# Bash tab completion for the `lacy` CLI
# Sourced by lib/bash/init.bash after all core modules are loaded

_lacy_completions() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="setup install uninstall update reinstall status info doctor config new resume logs changelog completions version help"
    # Tool names come from the canonical list in lib/core/constants.sh
    local IFS=' '
    local tool_names="${LACY_TOOL_LIST[*]} custom auto"
    IFS=$' \t\n'

    case "$prev" in
        config)
            COMPREPLY=( $(compgen -W "show edit path" -- "$cur") )
            return
            ;;
        logs)
            COMPREPLY=( $(compgen -W "--clear --count" -- "$cur") )
            return
            ;;
        set)
            COMPREPLY=( $(compgen -W "$tool_names" -- "$cur") )
            return
            ;;
        tool)
            COMPREPLY=( $(compgen -W "set list" -- "$cur") )
            return
            ;;
        completions)
            COMPREPLY=( $(compgen -W "zsh bash" -- "$cur") )
            return
            ;;
    esac

    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
}

complete -F _lacy_completions lacy
