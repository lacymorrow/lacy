#!/usr/bin/env bash

# Output rendering for Lacy Shell
# Post-processes agent response text before display.
# Shared across Bash 4+ and ZSH.

# ============================================================================
# State (persists across _lacy_render_line calls in the same process)
# ============================================================================
_LACY_IN_CODE_BLOCK=0
_LACY_CODE_BLOCK_LANG=""

# Temp buffers for thinking extraction (set by _lacy_extract_thinking)
_LACY_THINKING_CONTENT=""
_LACY_RESPONSE_BODY=""

# ============================================================================
# Feature 3: <thinking> block extraction
#
# Strips <thinking>...</thinking> sections from raw response text.
# Results are stored in _LACY_THINKING_CONTENT and _LACY_RESPONSE_BODY.
# Usage: _lacy_extract_thinking "$raw_text"
# ============================================================================
_lacy_extract_thinking() {
    local raw="$1"

    if [[ "$raw" != *"<thinking>"* ]]; then
        _LACY_THINKING_CONTENT=""
        _LACY_RESPONSE_BODY="$raw"
        return
    fi

    local thinking_parts="" remainder="$raw"
    while [[ "$remainder" == *"<thinking>"* ]]; do
        local before="${remainder%%<thinking>*}"
        local after="${remainder#*<thinking>}"
        local thought="${after%%</thinking>*}"
        local rest="${after#*</thinking>}"
        thinking_parts+="${thought}"$'\n'
        remainder="${before}${rest}"
    done

    _LACY_THINKING_CONTENT="${thinking_parts%$'\n'}"  # strip trailing newline
    _LACY_RESPONSE_BODY="$remainder"
}

# ============================================================================
# Feature 4 + 1: line-level rendering
#
# Priority:
#   4a: fenced code blocks (``` ... ```) — dim fence, track state
#   4b: diff lines inside code blocks — green/red/cyan
#   1:  markdown todo items outside code blocks — ☐/☑
# ============================================================================
_lacy_render_line() {
    local line="$1"

    # 4a: code block fence toggle
    if [[ "$line" == '```'* ]]; then
        if (( _LACY_IN_CODE_BLOCK == 0 )); then
            _LACY_IN_CODE_BLOCK=1
            _LACY_CODE_BLOCK_LANG="${line#'```'}"
        else
            _LACY_IN_CODE_BLOCK=0
            _LACY_CODE_BLOCK_LANG=""
        fi
        lacy_print_color 238 "$line"
        return
    fi

    # 4b: inside a code block — apply diff coloring
    if (( _LACY_IN_CODE_BLOCK == 1 )); then
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

    # 1: markdown todo items (outside code blocks only)
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
# Read agent response from stdin and render it:
#   1. Extract <thinking> blocks → show in dim gray with a border
#   2. Render body line by line (todos, code blocks, diffs)
#
# Usage: printf '%s\n' "$result" | lacy_render_response
# ============================================================================
lacy_render_response() {
    _LACY_IN_CODE_BLOCK=0
    _LACY_CODE_BLOCK_LANG=""

    local raw
    raw=$(cat)

    # Feature 3: extract and display thinking blocks
    _lacy_extract_thinking "$raw"

    if [[ -n "$_LACY_THINKING_CONTENT" ]]; then
        lacy_print_color 238 "╭─ Thinking"
        local t_line
        while IFS= read -r t_line; do
            lacy_print_color 238 "│ ${t_line}"
        done <<< "$_LACY_THINKING_CONTENT"
        lacy_print_color 238 "╰─"
        echo ""
    fi

    # Render body line by line
    local line
    while IFS= read -r line; do
        _lacy_render_line "$line"
    done <<< "$_LACY_RESPONSE_BODY"
}
