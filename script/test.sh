#!/usr/bin/env bash
#
# Run every lacy test suite in the shells it targets.
#
# Usage: script/test.sh [--shell bash|zsh|fish|all] [--skip NAME]...
#
#   --shell  which shell's suites to run (default: all)
#   --skip   skip a suite by file name, repeatable (e.g. --skip test_installer.sh)
#
# Env:
#   LACY_TEST_BASH  path to a Bash 4+ binary (auto-detected otherwise)
#
# Every suite runs with HOME set to a throwaway directory, so nothing reads or
# writes the real ~/.lacy or shell rc files. A suite whose file does not exist
# yet prints SKIP, as do fish suites when fish is not installed. Any failure,
# or a required shell that cannot be found, makes the script exit 1.
#
# Written for Bash 3.2+ so it runs under macOS /bin/bash.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

usage() { sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; }

want="all"
skips=" "
while [ $# -gt 0 ]; do
    case "$1" in
        --shell)   [ $# -ge 2 ] || { usage >&2; exit 2; }; want="$2"; shift 2 ;;
        --shell=*) want="${1#--shell=}"; shift ;;
        --skip)    [ $# -ge 2 ] || { usage >&2; exit 2; }; skips="$skips$2 "; shift 2 ;;
        --skip=*)  skips="$skips${1#--skip=} "; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

case "$want" in
    bash|zsh|fish|all) ;;
    *) echo "--shell must be bash, zsh, fish, or all (got: $want)" >&2; exit 2 ;;
esac

# Suites: group|interpreter|file|args
#   bash4 = Bash 4+ (resolved below), sysbash = whatever `bash` is on PATH
#   (the installer must keep working on macOS Bash 3.2).
SUITES='
bash|bash4|tests/test_core.sh|
bash|bash4|tests/test_query_agent.sh|
bash|bash4|tests/test_config.sh|
bash|bash4|tests/test_runtime.sh|
bash|bash4|tests/test_gemini.sh|
bash|bash4|tests/test_gemini_mcp.sh|
bash|bash4|tests/test_bash.bash|
bash|bash4|tests/test_bash_adapter.bash|
bash|bash4|script/sync-word-lists.sh|--check
bash|sysbash|tests/test_installer.sh|
zsh|zsh|tests/test_core.sh|
zsh|zsh|tests/test_query_agent.sh|
zsh|zsh|tests/test_config.sh|
zsh|zsh|tests/test_runtime.sh|
zsh|zsh|tests/test_gemini.sh|
zsh|zsh|tests/test_gemini_mcp.sh|
zsh|zsh|tests/test_preheat_server.zsh|
zsh|zsh|tests/test_zsh_adapter.zsh|
fish|fish|tests/test_fish.fish|
'

find_bash4() {
    local c p
    for c in "${LACY_TEST_BASH:-}" bash /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash; do
        [ -n "$c" ] || continue
        p="$(command -v "$c" 2>/dev/null)" || continue
        if "$p" -c '[ "${BASH_VERSINFO[0]}" -ge 4 ]' 2>/dev/null; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

# Defaults that keep suites offline and quiet. Callers can override.
export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
export LACY_NO_NODE="${LACY_NO_NODE:-1}"

BASH4=""
BASH4_LOOKED=0
SANDBOX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lacy-test.XXXXXX")" || exit 1
trap 'command rm -rf "$SANDBOX_ROOT"' EXIT

results=()
n_pass=0
n_fail=0
n_skip=0

record() { # status label file note
    results+=("$(printf '%-4s  %-8s  %-34s  %s' "$1" "$2" "$3" "$4")")
    case "$1" in
        PASS) n_pass=$((n_pass + 1)) ;;
        FAIL) n_fail=$((n_fail + 1)) ;;
        SKIP) n_skip=$((n_skip + 1)) ;;
    esac
}

run_suite() { # group interp file args
    local group="$1" interp="$2" file="$3" args="$4"
    local name bin label start rc home
    name="$(basename "$file")"

    case "$skips" in
        *" $name "*) record SKIP "$group" "$file" "(--skip)"; echo "SKIP [$group] $file (--skip)"; return ;;
    esac
    if [ ! -f "$file" ]; then
        record SKIP "$group" "$file" "(not present)"
        echo "SKIP [$group] $file (not present)"
        return
    fi

    case "$interp" in
        bash4)
            if [ "$BASH4_LOOKED" -eq 0 ]; then
                BASH4="$(find_bash4)" || BASH4=""
                BASH4_LOOKED=1
            fi
            if [ -z "$BASH4" ]; then
                record FAIL "$group" "$file" "(no Bash 4+ found; set LACY_TEST_BASH)"
                echo "FAIL [$group] $file: no Bash 4+ found (macOS: brew install bash)"
                return
            fi
            bin="$BASH4" ;;
        sysbash) bin="$(command -v bash)" ;;
        zsh)
            if ! bin="$(command -v zsh)"; then
                record FAIL "$group" "$file" "(zsh not installed)"
                echo "FAIL [$group] $file: zsh not installed"
                return
            fi ;;
        fish)
            if ! bin="$(command -v fish)"; then
                record SKIP "$group" "$file" "(fish not installed)"
                echo "SKIP [$group] $file (fish not installed)"
                return
            fi ;;
    esac

    label="$group"
    [ "$interp" = sysbash ] && label="bash(sys)"

    home="$(mktemp -d "$SANDBOX_ROOT/home.XXXXXX")"
    printf '\n==> [%s] %s %s %s\n' "$label" "$bin" "$file" "$args"
    start=$SECONDS
    # shellcheck disable=SC2086 # args is intentionally word-split
    (
        export HOME="$home"
        unset ZDOTDIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
        exec "$bin" "$file" $args
    )
    rc=$?
    if [ "$rc" -eq 0 ]; then
        record PASS "$label" "$file" "($((SECONDS - start))s)"
    else
        record FAIL "$label" "$file" "(exit $rc, $((SECONDS - start))s)"
    fi
}

while IFS='|' read -r group interp file args; do
    [ -n "$group" ] || continue
    if [ "$want" = all ] || [ "$want" = "$group" ]; then
        run_suite "$group" "$interp" "$file" "$args"
    fi
done <<EOF
$SUITES
EOF

echo
echo "================================ summary ================================"
# ${arr[@]+...} guards Bash 3.2, where "${arr[@]}" on an empty array trips set -u.
for line in ${results[@]+"${results[@]}"}; do
    echo "$line"
done
echo "-------------------------------------------------------------------------"
echo "passed: $n_pass  failed: $n_fail  skipped: $n_skip"
[ -n "$BASH4" ] && echo "bash 4+: $BASH4"

if [ "$n_fail" -gt 0 ]; then
    exit 1
fi
if [ "$n_pass" -eq 0 ]; then
    echo "warning: no suites ran"
fi
exit 0
