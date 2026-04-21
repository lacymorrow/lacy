#!/usr/bin/env bash

# Terminal context for agent queries — delta-based, token-efficient
# Only sends what changed since the last agent query.
# Shared across Bash 4+ and ZSH.

# === State ===
_LACY_CTX_LAST_CWD=""
_LACY_CTX_LAST_GIT=""
_LACY_CTX_CMDS_SINCE_QUERY=0
_LACY_CTX_LAST_EXIT_CODE=0
_LACY_CTX_REAL_CMD=false

# Command ring buffer — explicit array avoids agent queries leaking from fc/history
_LACY_CTX_CMD_BUFFER=()
_LACY_CTX_CMD_BUFFER_MAX=10

# ============================================================================
# Hooks (called from accept-line and precmd)
# ============================================================================

# Called from accept-line when routing input to the shell.
# Records the command text for inclusion in the next agent query context.
# Usage: _lacy_ctx_mark_command "$BUFFER"   (ZSH)
#        _lacy_ctx_mark_command "$READLINE_LINE"  (Bash)
_lacy_ctx_mark_command() {
    local cmd="$1"
    _LACY_CTX_REAL_CMD=true

    # Append to ring buffer, trim to max size
    _LACY_CTX_CMD_BUFFER+=("$cmd")
    if (( ${#_LACY_CTX_CMD_BUFFER[@]} > _LACY_CTX_CMD_BUFFER_MAX )); then
        _LACY_CTX_CMD_BUFFER=("${_LACY_CTX_CMD_BUFFER[@]: -$_LACY_CTX_CMD_BUFFER_MAX}")
    fi
}

# Called from precmd hooks. Captures exit code for real shell commands only.
# Usage: _lacy_ctx_on_precmd $last_exit
_lacy_ctx_on_precmd() {
    local exit_code="$1"
    if [[ "$_LACY_CTX_REAL_CMD" == true ]]; then
        _LACY_CTX_LAST_EXIT_CODE=$exit_code
        (( _LACY_CTX_CMDS_SINCE_QUERY++ ))
        _LACY_CTX_REAL_CMD=false
    fi
}

# ============================================================================
# Context Builder (called at query time)
# ============================================================================

# Build delta-based context and prepend to query.
# Sets _LACY_CTX_RESULT to the enriched query (avoids subshell so state resets
# propagate to the parent). If nothing changed, result is the bare query.
# Format: [cwd: /path] [git: branch] [exit: 1] [recent: cmd1 | cmd2] query
# Usage: _lacy_build_query_context "$query"; query="$_LACY_CTX_RESULT"
_LACY_CTX_RESULT=""

_lacy_build_query_context() {
    local query="$1"
    local ctx=""

    # --- CWD (only if changed) ---
    local cwd="${PWD}"
    if [[ "$cwd" != "$_LACY_CTX_LAST_CWD" ]]; then
        ctx+="[cwd: ${cwd}] "
        _LACY_CTX_LAST_CWD="$cwd"
    fi

    # --- Git branch (only if changed) ---
    local git_branch=""
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    fi
    if [[ "$git_branch" != "$_LACY_CTX_LAST_GIT" ]]; then
        if [[ -n "$git_branch" ]]; then
            ctx+="[git: ${git_branch}] "
        fi
        _LACY_CTX_LAST_GIT="$git_branch"
    fi

    # --- Last exit code (only if non-zero AND a command ran since last query) ---
    if (( _LACY_CTX_CMDS_SINCE_QUERY > 0 && _LACY_CTX_LAST_EXIT_CODE != 0 )); then
        ctx+="[exit: ${_LACY_CTX_LAST_EXIT_CODE}] "
    fi

    # --- Recent commands since last query ---
    if (( _LACY_CTX_CMDS_SINCE_QUERY > 0 )) && [[ ${#_LACY_CTX_CMD_BUFFER[@]} -gt 0 ]]; then
        local cmds=""
        local cmd
        for cmd in "${_LACY_CTX_CMD_BUFFER[@]}"; do
            # Truncate long commands to keep context compact
            if (( ${#cmd} > 80 )); then
                cmd="${cmd:0:77}..."
            fi
            if [[ -n "$cmds" ]]; then
                cmds+=" | $cmd"
            else
                cmds="$cmd"
            fi
        done
        ctx+="[recent: ${cmds}] "
    fi

    # --- Reset counters ---
    _LACY_CTX_CMDS_SINCE_QUERY=0
    _LACY_CTX_LAST_EXIT_CODE=0
    _LACY_CTX_CMD_BUFFER=()

    # --- Set result ---
    _LACY_CTX_RESULT="${ctx}${query}"
}

# ============================================================================
# Reset (called on /new session)
# ============================================================================

# Clear all context state so the next query sends full context.
_lacy_ctx_reset() {
    _LACY_CTX_LAST_CWD=""
    _LACY_CTX_LAST_GIT=""
    _LACY_CTX_CMDS_SINCE_QUERY=0
    _LACY_CTX_LAST_EXIT_CODE=0
    _LACY_CTX_REAL_CMD=false
    _LACY_CTX_CMD_BUFFER=()
}
