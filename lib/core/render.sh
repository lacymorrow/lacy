#!/usr/bin/env bash

# Output rendering for Lacy Shell
# Post-processes agent response text before display.
# Shared across Bash 4+ and ZSH.

# ============================================================================
# Feature 1: Todo list rendering
# Converts markdown checkboxes to terminal symbols with color.
#   - [ ] item  →  ☐ item  (gray/238)
#   - [x] item  →  ☑ item  (green/34)
# ============================================================================

# Render a single line — called inline or from lacy_render_response.
# Usage: _lacy_render_line "line text"
_lacy_render_line() {
    local line="$1"

    # Strip leading whitespace to check prefix (preserves indent for output)
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

# Render agent response from stdin, line by line.
# Usage: printf '%s\n' "$result" | lacy_render_response
lacy_render_response() {
    local line
    while IFS= read -r line; do
        _lacy_render_line "$line"
    done
    # Handle output that doesn't end with a newline
    [[ -n "$line" ]] && _lacy_render_line "$line"
}
