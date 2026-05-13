#!/usr/bin/env zsh

# ZSH tab completion for the `lacy` CLI
# Sourced by lib/zsh/init.zsh after all core modules are loaded

_lacy_complete() {
    local -a commands
    commands=(
        'setup:Interactive settings'
        'install:Install Lacy Shell'
        'uninstall:Remove Lacy Shell'
        'update:Pull latest changes'
        'reinstall:Fresh installation'
        'status:Show installation status'
        'info:Show basic information'
        'doctor:Diagnose common issues'
        'config:Show or edit configuration'
        'new:Clear saved session'
        'resume:Show saved session info'
        'logs:Show recent agent query log'
        'changelog:Show latest release notes'
        'completions:Print shell completion script'
        'version:Show version'
        'help:Show help'
    )

    local -a tool_names
    tool_names=(lash claude opencode gemini codex custom auto)

    case "${words[2]}" in
        config)
            local -a sub
            sub=('show:Print config' 'edit:Open in $EDITOR' 'path:Print config path')
            _describe 'config subcommand' sub
            ;;
        logs)
            local -a sub
            sub=('--clear:Clear the log' '--count:Print entry count')
            _describe 'logs option' sub
            ;;
        tool)
            case "${words[3]}" in
                set) _describe 'tool name' tool_names ;;
                *)
                    local -a sub
                    sub=('set:Set active tool' 'list:List available tools')
                    _describe 'tool subcommand' sub
                    ;;
            esac
            ;;
        completions)
            _describe 'shell' '(zsh bash)'
            ;;
        *)
            _describe 'lacy command' commands
            ;;
    esac
}

compdef _lacy_complete lacy 2>/dev/null || true
