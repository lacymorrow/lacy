#!/usr/bin/env bash

# Terminal context for agent queries: delta-based, token-efficient
# Only sends what changed since the last agent query.
# Shared across Bash 4+ and ZSH.

# === State: Delta Tracking ===
_LACY_CTX_LAST_CWD=""
_LACY_CTX_LAST_GIT=""
_LACY_CTX_CMDS_SINCE_QUERY=0
_LACY_CTX_LAST_EXIT_CODE=0
_LACY_CTX_REAL_CMD=false

# Command ring buffer: explicit array avoids agent queries leaking from fc/history
_LACY_CTX_CMD_BUFFER=()
_LACY_CTX_CMD_BUFFER_MAX=10

# === State: Terminal Output Capture ===
_LACY_CTX_TERMINAL_CAPTURE_CMD=""   # Detected at load time; empty = unsupported
_LACY_CTX_OUTPUT_ENABLED=true       # Toggled via config (context.output)
_LACY_CTX_OUTPUT_MAX_LINES=50       # Configurable cap (context.output_lines)
_LACY_CTX_CAPTURE_DISABLED=false     # Set after an AppleScript capture fails or times out
_LACY_CTX_SCREEN=""                  # Result of _lacy_ctx_capture_screen_into

# ============================================================================
# Terminal Detection (called once at source time)
# ============================================================================

# Detect terminal/multiplexer API for screen capture.
# Sets _LACY_CTX_TERMINAL_CAPTURE_CMD to a command string (or function name),
# or empty if unsupported. Checked once at source time.
#
# Priority: tmux > screen > iTerm2 > Terminal.app
# Multiplexers are checked first because terminal emulator APIs return wrong
# content when running inside a multiplexer.
_lacy_ctx_detect_terminal() {
    _LACY_CTX_TERMINAL_CAPTURE_CMD=""
    _LACY_CTX_CAPTURE_DISABLED=false

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

    # 3-4. macOS: AppleScript for iTerm2 and Terminal.app
    # $OSTYPE instead of $(uname -s): this runs at plugin load, a fork costs ~35 ms.
    if [[ "${OSTYPE:-}" == darwin* ]]; then
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

# Run a command with a time limit of LACY_CTX_CAPTURE_TIMEOUT_TICKS x 0.1 s.
# Prints its stdout and returns its exit code, or 124 when it had to be
# killed. Meant to run inside $(...), where background jobs print no notices.
# `wait` is called right away (not after polling): zsh cannot report the
# status of a child it has already reaped.
_lacy_ctx_run_bounded() {
    local ticks="${LACY_CTX_CAPTURE_TIMEOUT_TICKS:-20}"
    local out pid watchdog rc
    out=$(mktemp 2>/dev/null) || return 1
    "$@" > "$out" 2>/dev/null </dev/null &
    pid=$!
    # The watchdog writes nowhere, so it never holds the $(...) pipe open
    ( sleep "$(( ticks / 10 )).$(( ticks % 10 ))"; kill "$pid" ) >/dev/null 2>&1 </dev/null &
    watchdog=$!
    wait "$pid" 2>/dev/null
    rc=$?
    if kill -0 "$watchdog" 2>/dev/null; then
        kill "$watchdog" 2>/dev/null
    else
        rc=124
    fi
    (( rc == 0 )) && cat "$out" 2>/dev/null
    command rm -f "$out"
    return $rc
}

# screen: hardcopy writes to a file, not stdout
_lacy_ctx_screen_capture() {
    local tmpfile
    tmpfile=$(mktemp) || return
    screen -X hardcopy "$tmpfile" 2>/dev/null || { command rm -f "$tmpfile"; return; }
    cat "$tmpfile" 2>/dev/null
    command rm -f "$tmpfile" 2>/dev/null
}

# iTerm2: AppleScript to get current session contents (time-bounded)
_lacy_ctx_iterm2_capture() {
    _lacy_ctx_run_bounded osascript -e 'tell application "iTerm2" to tell current session of current window to get contents'
}

# Terminal.app: AppleScript to get current tab contents (time-bounded)
_lacy_ctx_terminal_app_capture() {
    _lacy_ctx_run_bounded osascript -e 'tell application "Terminal" to get contents of selected tab of front window'
}

# ============================================================================
# Screen Capture (called lazily at query time)
# ============================================================================

# Filter: remove terminal escape sequences and control bytes from stdin.
# OSC strings (hyperlinks, titles) and DCS/APC/PM strings ending in BEL or
# ESC \, then CSI sequences (colors, cursor moves), then other short escapes,
# then every remaining control byte except newline and tab.
_lacy_ctx_sanitize() {
    local esc=$'\033' bel=$'\007'
    LC_ALL=C sed -E \
        -e "s/${esc}[]P^_X][^${bel}${esc}]*(${bel}|${esc}\\\\)//g" \
        -e "s/${esc}\\[[0-?]*[ -/]*[@-~]//g" \
        -e "s/${esc}[()*+#]?.//g" \
        | LC_ALL=C tr -d '\000-\010\013-\037\177'
}

# Capture visible terminal screen text into _LACY_CTX_SCREEN, cleaned of
# escapes and control bytes and cut to the last N lines. Runs in the calling
# shell (no subshell) so a failed AppleScript capture (Automation permission
# denied, or the app did not answer in time) is remembered and not retried
# for the rest of the session.
_lacy_ctx_capture_screen_into() {
    _LACY_CTX_SCREEN=""
    [[ "$_LACY_CTX_OUTPUT_ENABLED" != true ]] && return
    [[ -z "$_LACY_CTX_TERMINAL_CAPTURE_CMD" ]] && return
    [[ "$_LACY_CTX_CAPTURE_DISABLED" == true ]] && return

    local raw_output rc
    raw_output=$(eval "$_LACY_CTX_TERMINAL_CAPTURE_CMD" 2>/dev/null)
    rc=$?
    if (( rc != 0 )); then
        case "$_LACY_CTX_TERMINAL_CAPTURE_CMD" in
            _lacy_ctx_iterm2_capture|_lacy_ctx_terminal_app_capture)
                _LACY_CTX_CAPTURE_DISABLED=true
                ;;
        esac
        return
    fi

    local cleaned
    cleaned=$(printf '%s\n' "$raw_output" | _lacy_ctx_sanitize)

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

    _LACY_CTX_SCREEN="$cleaned"
}

# Same capture, printed to stdout.
_lacy_ctx_capture_screen() {
    _lacy_ctx_capture_screen_into
    [[ -n "$_LACY_CTX_SCREEN" ]] && printf '%s' "$_LACY_CTX_SCREEN"
    return 0
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
        # Detached HEAD returns literal "HEAD": fall back to short hash
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
        _lacy_ctx_capture_screen_into
        screen_output="$_LACY_CTX_SCREEN"
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
# Does NOT reset terminal detection or config: those are session-lifetime.
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
