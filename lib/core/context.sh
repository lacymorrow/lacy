#!/usr/bin/env bash

# Terminal context for agent queries — delta-based, token-efficient
# Only sends what changed since the last agent query.
# Shared across Bash 4+ and ZSH.

# === State: Delta Tracking ===
_LACY_CTX_LAST_CWD=""
_LACY_CTX_LAST_GIT=""
_LACY_CTX_CMDS_SINCE_QUERY=0
_LACY_CTX_LAST_EXIT_CODE=0
_LACY_CTX_REAL_CMD=false

# Command ring buffer — explicit array avoids agent queries leaking from fc/history
_LACY_CTX_CMD_BUFFER=()
_LACY_CTX_CMD_BUFFER_MAX=10

# === State: Terminal Output Capture ===
_LACY_CTX_TERMINAL_CAPTURE_CMD=""   # Detected at load time; empty = unsupported
_LACY_CTX_OUTPUT_ENABLED=true       # Toggled via config (context.output)
_LACY_CTX_OUTPUT_MAX_LINES=50       # Configurable cap (context.output_lines)

# ============================================================================
# Terminal Detection (called once at source time)
# ============================================================================

# Detect terminal/multiplexer API for screen capture.
# Sets _LACY_CTX_TERMINAL_CAPTURE_CMD to a command string (or function name),
# or empty if unsupported. Checked once at source time.
#
# Priority: tmux > screen > Kitty > WezTerm > iTerm2 > Terminal.app
# Multiplexers are checked first because terminal emulator APIs return wrong
# content when running inside a multiplexer.
_lacy_ctx_detect_terminal() {
    _LACY_CTX_TERMINAL_CAPTURE_CMD=""

    # 1. tmux: native pane capture (takes priority over terminal APIs)
    if [[ -n "${TMUX:-}" ]]; then
        if command -v tmux >/dev/null 2>&1; then
            _LACY_CTX_TERMINAL_CAPTURE_CMD="tmux capture-pane -p"
            return
        fi
    fi

    # 2. screen: hardcopy to temp file
    if [[ -n "${STY:-}" ]]; then
        if command -v screen >/dev/null 2>&1; then
            _LACY_CTX_TERMINAL_CAPTURE_CMD="_lacy_ctx_screen_capture"
            return
        fi
    fi

    # 3. Kitty: remote control API
    if [[ -n "${KITTY_PID:-}" ]] || [[ "${TERM_PROGRAM:-}" == "kitty" ]]; then
        if command -v kitty >/dev/null 2>&1; then
            _LACY_CTX_TERMINAL_CAPTURE_CMD="kitty @ get-text --extent=screen"
            return
        fi
    fi

    # 4. WezTerm: CLI API
    if [[ -n "${WEZTERM_EXECUTABLE:-}" ]] || [[ "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
        if command -v wezterm >/dev/null 2>&1; then
            _LACY_CTX_TERMINAL_CAPTURE_CMD="wezterm cli get-text"
            return
        fi
    fi

    # 5-6. macOS: AppleScript for iTerm2 and Terminal.app
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
            _LACY_CTX_TERMINAL_CAPTURE_CMD="_lacy_ctx_iterm2_capture"
            return
        fi
        if [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; then
            _LACY_CTX_TERMINAL_CAPTURE_CMD="_lacy_ctx_terminal_app_capture"
            return
        fi
    fi
}

# ============================================================================
# Capture Helpers (multi-step captures that can't be a single command)
# ============================================================================

# screen: hardcopy writes to a file, not stdout
_lacy_ctx_screen_capture() {
    local tmpfile
    tmpfile=$(mktemp) || return
    screen -X hardcopy "$tmpfile" 2>/dev/null || { rm -f "$tmpfile"; return; }
    cat "$tmpfile" 2>/dev/null
    rm -f "$tmpfile" 2>/dev/null
}

# iTerm2: AppleScript to get current session contents
_lacy_ctx_iterm2_capture() {
    osascript -e 'tell application "iTerm2" to tell current session of current window to get contents' 2>/dev/null
}

# Terminal.app: AppleScript to get current tab contents
_lacy_ctx_terminal_app_capture() {
    osascript -e 'tell application "Terminal" to get contents of selected tab of front window' 2>/dev/null
}

# ============================================================================
# Screen Capture (called lazily at query time)
# ============================================================================

# Capture visible terminal screen text, stripped of ANSI escapes.
# Returns captured text on stdout, or empty if unavailable/disabled.
_lacy_ctx_capture_screen() {
    [[ "$_LACY_CTX_OUTPUT_ENABLED" != true ]] && return
    [[ -z "$_LACY_CTX_TERMINAL_CAPTURE_CMD" ]] && return

    local raw_output
    raw_output=$(eval "$_LACY_CTX_TERMINAL_CAPTURE_CMD" 2>/dev/null) || return

    # Strip ANSI escape sequences (SGR, cursor movement, etc.)
    local cleaned
    cleaned=$(printf '%s\n' "$raw_output" | sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g')

    # Remove trailing blank lines
    while [[ "$cleaned" == *$'\n' ]]; do
        cleaned="${cleaned%$'\n'}"
    done

    [[ -z "$cleaned" ]] && return

    # Truncate from the top, keeping the last N lines (errors are at the bottom)
    local max_lines="${_LACY_CTX_OUTPUT_MAX_LINES:-50}"
    if (( max_lines > 0 )); then
        local line_count
        line_count=$(printf '%s\n' "$cleaned" | wc -l)
        if (( line_count > max_lines )); then
            cleaned=$(printf '%s\n' "$cleaned" | tail -n "$max_lines")
        fi
    fi

    printf '%s' "$cleaned"
}

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
# With output: ...context header...\n[terminal-output]\n...\n[/terminal-output]\nquery
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
        # Detached HEAD returns literal "HEAD" — fall back to short hash
        if [[ "$git_branch" == "HEAD" ]]; then
            git_branch=$(git rev-parse --short HEAD 2>/dev/null)
        fi
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

    # --- Terminal screen output (lazy capture, only if commands ran) ---
    local screen_output=""
    if (( _LACY_CTX_CMDS_SINCE_QUERY > 0 )); then
        screen_output=$(_lacy_ctx_capture_screen)
    fi

    # --- Reset counters ---
    _LACY_CTX_CMDS_SINCE_QUERY=0
    _LACY_CTX_LAST_EXIT_CODE=0
    _LACY_CTX_CMD_BUFFER=()

    # --- Set result ---
    if [[ -n "$screen_output" ]]; then
        _LACY_CTX_RESULT="${ctx}
[terminal-output]
${screen_output}
[/terminal-output]
${query}"
    else
        _LACY_CTX_RESULT="${ctx}${query}"
    fi
}

# ============================================================================
# Reset (called on /new session)
# ============================================================================

# Clear all context state so the next query sends full context.
# Does NOT reset terminal detection or config — those are session-lifetime.
_lacy_ctx_reset() {
    _LACY_CTX_LAST_CWD=""
    _LACY_CTX_LAST_GIT=""
    _LACY_CTX_CMDS_SINCE_QUERY=0
    _LACY_CTX_LAST_EXIT_CODE=0
    _LACY_CTX_REAL_CMD=false
    _LACY_CTX_CMD_BUFFER=()
}

# ============================================================================
# Init (runs once when sourced)
# ============================================================================

_lacy_ctx_detect_terminal
