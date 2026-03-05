#!/usr/bin/env bash

# Output rendering for Lacy Shell
# Post-processes agent response text before display.
# Shared across Bash 4+ and ZSH.

# State: are we currently inside a fenced code block?
# Persists across _lacy_render_line calls in the same process.
_LACY_IN_CODE_BLOCK=0
_LACY_CODE_BLOCK_LANG=""

# ============================================================================
# _lacy_render_line "line"
#
# Handles (in order of priority):
#   Feature 4a: fenced code blocks (``` ... ```) — dim fence, preserve content
#   Feature 4b: diff lines inside code blocks — green/red/cyan coloring
#   Feature 1:  markdown todo items outside code blocks — ☐/☑ symbols
# ============================================================================
_lacy_render_line() {
    local line="$1"

    # --- Feature 4a: fenced code block toggle ---
    if [[ "$line" == '```'* ]]; then
        if (( _LACY_IN_CODE_BLOCK == 0 )); then
            _LACY_IN_CODE_BLOCK=1
            _LACY_CODE_BLOCK_LANG="${line#'```'}"
            lacy_print_color 238 "$line"
        else
            _LACY_IN_CODE_BLOCK=0
            _LACY_CODE_BLOCK_LANG=""
            lacy_print_color 238 "$line"
        fi
        return
    fi

    # --- Feature 4b: inside a code block ---
    if (( _LACY_IN_CODE_BLOCK == 1 )); then
        # Diff coloring (unified diff format)
        case "$line" in
            "@@"*"@@"*) lacy_print_color 75  "$line" ;; # cyan  — hunk header
            "--- "*)     lacy_print_color 238 "$line" ;; # gray  — old file header
            "+++ "*)     lacy_print_color 238 "$line" ;; # gray  — new file header
            "+"*)        lacy_print_color 34  "$line" ;; # green — added line
            "-"*)        lacy_print_color 196 "$line" ;; # red   — removed line
            *)           printf '%s\n' "$line" ;;
        esac
        return
    fi

    # --- Feature 1: markdown todo items (outside code blocks) ---
    local stripped="$line"
    while [[ "${stripped:0:1}" == " " || "${stripped:0:1}" == $'\t' ]]; do
        stripped="${stripped:1}"
    done
    local indent="${line:0:$(( ${#line} - ${#stripped} ))}"

    if [[ "$stripped" == "- [ ] "* ]]; then
        lacy_print_color 238 "${indent}☐ ${stripped#"- [ ] "}"
    elif [[ "$stripped" == "- [x] "* ]]; then
        lacy_print_color 34 "${indent}☑ ${stripped#"- [x] "}"
    elif [[ "$stripped" == "- [X] "* ]]; then
        lacy_print_color 34 "${indent}☑ ${stripped#"- [X] "}"
    else
        printf '%s\n' "$line"
    fi
}

# ============================================================================
# lacy_render_response
#
# Read agent response from stdin, render line by line.
# Resets code-block state at the start of each response so buffered
# paths (server/claude) always start clean.
# Usage: printf '%s\n' "$result" | lacy_render_response
# ============================================================================
lacy_render_response() {
    _LACY_IN_CODE_BLOCK=0
    _LACY_CODE_BLOCK_LANG=""
    local line
    while IFS= read -r line; do
        _lacy_render_line "$line"
    done
    # Handle output that doesn't end with a newline
    [[ -n "$line" ]] && _lacy_render_line "$line"
}
