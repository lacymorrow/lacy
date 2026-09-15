#!/usr/bin/env bash

# Regenerate the word lists that the fish adapter carries as copies of
# lib/core/constants.sh. The copies live between BEGIN/END GENERATED markers.
#
# Usage:
#   script/sync-word-lists.sh           rewrite the generated blocks
#   script/sync-word-lists.sh --check   exit 1 (with a diff) if they are stale
#
# Requires Bash 4+.

set -euo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
    echo "sync-word-lists.sh: Bash 4+ required (have ${BASH_VERSION})" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check=false
case "${1:-}" in
    "") ;;
    --check) check=true ;;
    -h|--help)
        sed -n '3,10p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    *)
        echo "sync-word-lists.sh: unknown argument: $1" >&2
        exit 2
        ;;
esac

# constants.sh only assigns variables and defines functions.
set +u
LACY_SHELL_TYPE="bash"
# shellcheck source=../lib/core/constants.sh
source "$ROOT/lib/core/constants.sh"
set -u

# Quote one word for fish: single quotes, with \ and ' escaped.
fish_quote_into() {
    local s="$2"
    s="${s//\\/\\\\}"
    s="${s//\'/\\\'}"
    printf -v "$1" "'%s'" "$s"
}

# Print `set -g NAME 'w1' 'w2' ...` wrapped at 8 words per line.
emit_list() {
    local name="$1"
    shift
    local -a quoted=()
    local w q
    for w in "$@"; do
        fish_quote_into q "$w"
        quoted+=("$q")
    done
    local total=${#quoted[@]} per=8 i
    if (( total == 0 )); then
        printf 'set -g %s\n' "$name"
        return
    fi
    printf 'set -g %s \\\n' "$name"
    local IFS=' '
    for (( i = 0; i < total; i += per )); do
        if (( i + per < total )); then
            printf '    %s \\\n' "${quoted[*]:i:per}"
        else
            printf '    %s\n' "${quoted[*]:i:per}"
        fi
    done
}

word_lists_block() {
    echo "# Generated from lib/core/constants.sh. Do not edit by hand."
    emit_list LACY_AGENT_WORDS "${LACY_AGENT_WORDS[@]}"
    echo ""
    emit_list LACY_SHELL_RESERVED_WORDS "${LACY_SHELL_RESERVED_WORDS[@]}"
    echo ""
    emit_list LACY_NL_MARKERS "${LACY_NL_MARKERS[@]}"
    echo ""
    emit_list LACY_SHELL_OPERATORS "${LACY_SHELL_OPERATORS[@]}"
}

tool_list_block() {
    echo "# Generated from lib/core/constants.sh. Do not edit by hand."
    emit_list LACY_TOOL_LIST "${LACY_TOOL_LIST[@]}"
}

# Write FILE to OUT with the lines between the BEGIN and END markers replaced
# by the output of GENERATOR. Returns 1 if either marker is missing.
render_file() {
    local file="$1" begin="$2" end="$3" generator="$4" out="$5"
    local line state=0
    {
        while IFS= read -r line || [[ -n "$line" ]]; do
            if (( state == 0 )) && [[ "$line" == "$begin"* ]]; then
                printf '%s\n' "$line"
                "$generator"
                state=1
                continue
            fi
            if (( state == 1 )); then
                if [[ "$line" == "$end"* ]]; then
                    printf '%s\n' "$line"
                    state=2
                fi
                continue
            fi
            printf '%s\n' "$line"
        done < "$file"
    } > "$out"
    (( state == 2 ))
}

tmp="$(mktemp "${TMPDIR:-/tmp}/lacy-sync-words.XXXXXX")"
trap 'command rm -f "$tmp"' EXIT

stale=0
sync_one() {
    local rel="$1" begin="$2" end="$3" generator="$4"
    local file="$ROOT/$rel"
    if ! render_file "$file" "$begin" "$end" "$generator" "$tmp"; then
        echo "sync-word-lists.sh: markers '$begin' / '$end' not found in $rel" >&2
        exit 2
    fi
    if cmp -s "$file" "$tmp"; then
        return
    fi
    if [[ "$check" == true ]]; then
        echo "$rel is out of date with lib/core/constants.sh:" >&2
        diff -u "$file" "$tmp" >&2 || true
        stale=1
    else
        # Write through the existing file so permissions and symlinks survive.
        cat "$tmp" > "$file"
        echo "updated $rel"
    fi
}

sync_one lib/fish/detection.fish "# BEGIN GENERATED WORD LISTS" "# END GENERATED WORD LISTS" word_lists_block
sync_one lib/fish/config.fish "# BEGIN GENERATED TOOL LIST" "# END GENERATED TOOL LIST" tool_list_block

if [[ "$check" == true ]]; then
    if (( stale )); then
        echo "Run script/sync-word-lists.sh to regenerate." >&2
        exit 1
    fi
    echo "fish word lists are in sync"
fi
