#!/usr/bin/env bash

# Live smoke test: one real query through every installed AI tool.
#
# For each tool in LACY_TOOL_LIST that is on PATH, an interactive shell with
# Lacy loaded runs `tool set <tool>` and asks for the word PONG. A tool that is
# not installed, or not signed in, is skipped; anything else that does not
# answer is a failure.
#
# Auth, CLI login first: a tool runs on its own login with provider API keys
# removed from the environment. When it has no login (known locations, see
# cli_login) it runs with a key from the environment, or is skipped. When its
# login cannot be checked and the run fails for auth, it retries with a key.
#
# Real queries, real tokens. Uses the real HOME for the tools' logins
# (LACY_REAL_HOME when script/test.sh has sandboxed HOME); Lacy's own state
# lives in a throwaway directory. Nothing runs in CI: no tool is installed there.
#
# Usage: bash tests/test_tools_live.sh [--shell zsh|bash] [--tool NAME]...

if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "SKIP: Bash 4+ required (have ${BASH_VERSION})"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

shells=(zsh bash)
only=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --shell) shells=("$2"); shift 2 ;;
        --tool)  only+=("$2"); shift 2 ;;
        *) echo "Usage: $0 [--shell zsh|bash] [--tool NAME]..." >&2; exit 2 ;;
    esac
done

LACY_SHELL_TYPE="bash"
_LACY_ARR_OFFSET=0
source "$REPO_DIR/lib/core/constants.sh"
tools=("${LACY_TOOL_LIST[@]}")
[[ ${#only[@]} -gt 0 ]] && tools=("${only[@]}")

echo "Live tool smoke test (${shells[*]}): ${tools[*]}"
echo "================================================================"

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not found"
    exit 0
fi

REAL_HOME="${LACY_REAL_HOME:-$HOME}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lacy-live.XXXXXX")"
if [[ -n "${LACY_TEST_KEEP:-}" ]]; then
    echo "Keeping test files in $TMP_ROOT"
else
    trap 'command rm -rf "$TMP_ROOT"' EXIT
fi

# Provider keys, per tool. Attempt 1 runs without any of ALL_KEYS.
ALL_KEYS=(ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY CODEX_API_KEY
          GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY AMP_API_KEY
          GH_TOKEN GITHUB_TOKEN COPILOT_GITHUB_TOKEN)
tool_keys() {
    case "$1" in
        claude)  echo "ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN" ;;
        codex)   echo "OPENAI_API_KEY CODEX_API_KEY" ;;
        gemini)  echo "GEMINI_API_KEY GOOGLE_API_KEY" ;;
        amp)     echo "AMP_API_KEY" ;;
        copilot) echo "COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN" ;;
        *)       echo "ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY OPENROUTER_API_KEY" ;;
    esac
}
has_key() {
    local k
    for k in $(tool_keys "$1"); do [[ -n "${!k:-}" ]] && return 0; done
    return 1
}

# Where a tool keeps its CLI login. yes / no / unknown. Checked before running
# because a tool with no login may block on an interactive sign-in instead of
# failing (gemini asks [Y/n] to open a browser; amp starts a login flow).
cli_login() {
    local h="$REAL_HOME"
    case "$1" in
        claude)
            [[ -f "$h/.claude/.credentials.json" ]] && { echo yes; return; }
            if command -v security >/dev/null 2>&1 &&
               security find-generic-password -s 'Claude Code-credentials' >/dev/null 2>&1; then
                echo yes; return
            fi
            echo no ;;
        gemini) [[ -f "$h/.gemini/oauth_creds.json" ]] && echo yes || echo no ;;
        codex)  [[ -f "$h/.codex/auth.json" ]] && echo yes || echo no ;;
        amp)    [[ -f "$h/.local/share/amp/secrets.json" ]] && echo yes || echo no ;;
        *)      echo unknown ;;
    esac
}

# Never inherit the terminal or a parent agent session: Lacy's terminal
# context would script the real terminal window, and CLAUDECODE changes how
# claude behaves.
base_unset=(TERM_PROGRAM TERM_PROGRAM_VERSION TERM_SESSION_ID ITERM_SESSION_ID
            TMUX TMUX_PANE STY KITTY_WINDOW_ID WEZTERM_PANE CLAUDECODE ZDOTDIR)
while IFS= read -r v; do base_unset+=("$v"); done < <(compgen -e | grep '^CLAUDE_CODE_')

# Sandbox for one case: Lacy home, config, rc file, browser stubs
setup_case() { # shell tool port dir
    local sh="$1" tool="$2" port="$3" dir="$4"
    mkdir -p "$dir/lacy" "$dir/work" "$dir/nobrowser"
    # A tool that is not signed in may start a login flow; never let it open
    # a browser on the machine running the tests
    local b
    for b in open xdg-open sensible-browser; do
        printf '#!/bin/sh\nexit 1\n' > "$dir/nobrowser/$b"
        chmod +x "$dir/nobrowser/$b"
    done
    cat > "$dir/lacy/config.yaml" <<EOF
agent_tools:
  active:
modes:
  default: auto
context:
  output: false
preheat:
  server_port: $port
EOF
    # Runs after Lacy's own prompt hook, so a new byte means the query is done
    local hook="_smk() { printf x >> '$dir/prompts'; }"
    local common="export DO_NOT_TRACK=1 LACY_NO_TELEMETRY=1 LACY_SHELL_HOME='$dir/lacy' HISTFILE='$dir/hist'"
    if [[ "$sh" == zsh ]]; then
        mkdir -p "$dir/zdot"
        printf '%s\nPS1="LSMK> "; RPS1=""\nsource "%s/lacy.plugin.zsh"\n%s\nprecmd_functions+=(_smk)\ncd "%s/work"\n' \
            "$common" "$REPO_DIR" "$hook" "$dir" > "$dir/zdot/.zshrc"
    else
        printf '%s\nPS1="LSMK> "\nsource "%s/lacy.plugin.bash"\n%s\n%s\ncd "%s/work"\n' \
            "$common" "$REPO_DIR" "$hook" \
            'if [[ "$(declare -p PROMPT_COMMAND)" == "declare -a"* ]]; then PROMPT_COMMAND+=(_smk); else PROMPT_COMMAND+=$'"'"'\n'"'"'_smk; fi' \
            "$dir" > "$dir/bashrc"
    fi
}

# Stop a preheat server this case left on its port (only a `serve --port N`)
stop_port() {
    local port="$1" p
    for p in $(lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null); do
        ps -o command= -p "$p" 2>/dev/null | grep -q -- "serve --port $port" && kill "$p" 2>/dev/null
    done
}

run_attempt() { # shell tool port dir keep_keys -> STATUS|reason|secs
    local sh="$1" tool="$2" port="$3" dir="$4" keep="$5"
    local -a unset_args=() cmd=()
    local v
    for v in "${base_unset[@]}"; do unset_args+=(-u "$v"); done
    if [[ "$keep" != 1 ]]; then
        for v in "${ALL_KEYS[@]}"; do unset_args+=(-u "$v"); done
    fi
    setup_case "$sh" "$tool" "$port" "$dir"
    if [[ "$sh" == zsh ]]; then
        cmd=(env "${unset_args[@]}" HOME="$REAL_HOME" PATH="$dir/nobrowser:$PATH" BROWSER=false ZDOTDIR="$dir/zdot" TERM=xterm-256color
             "$(command -v zsh)" -i)
    else
        cmd=(env "${unset_args[@]}" HOME="$REAL_HOME" PATH="$dir/nobrowser:$PATH" BROWSER=false INPUTRC=/dev/null TERM=xterm-256color
             "$BASH" --noprofile --rcfile "$dir/bashrc" -i)
    fi
    python3 "$SCRIPT_DIR/tools_live_driver.py" --tool "$tool" --prompts "$dir/prompts" --out "$dir/transcript.txt" -- "${cmd[@]}"
    stop_port "$port"
}

run_case() { # shell tool port -> writes $TMP_ROOT/<shell>-<tool>.res
    local sh="$1" tool="$2" port="$3" res
    case "$(cli_login "$tool")" in
        no)
            if ! has_key "$tool"; then
                echo "SKIP|not signed in|" > "$TMP_ROOT/$sh-$tool.res"
                return
            fi
            # No CLI login, but a key is set: use it
            res=$(run_attempt "$sh" "$tool" "$port" "$TMP_ROOT/$sh-$tool" 1)
            [[ "$res" == PASS\|* ]] && res="PASS|with env API key|${res##*|}"
            printf '%s\n' "$res" > "$TMP_ROOT/$sh-$tool.res"
            return ;;
    esac
    res=$(run_attempt "$sh" "$tool" "$port" "$TMP_ROOT/$sh-$tool" 0)
    if [[ "$res" == AUTH\|* ]] && has_key "$tool"; then
        res=$(run_attempt "$sh" "$tool" "$port" "$TMP_ROOT/$sh-$tool-key" 1)
        [[ "$res" == PASS\|* ]] && res="PASS|with env API key|${res##*|}"
    fi
    printf '%s\n' "$res" > "$TMP_ROOT/$sh-$tool.res"
}

# Run up to 4 cases at once; each gets its own Lacy home and preheat port
# (the port must come from config.yaml: loading config resets it)
port=47300
for sh in "${shells[@]}"; do
    if [[ "$sh" == zsh ]] && ! command -v zsh >/dev/null 2>&1; then
        echo "SKIP: zsh not installed"; continue
    fi
    for tool in "${tools[@]}"; do
        port=$(( port + 1 ))
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "SKIP|not installed|" > "$TMP_ROOT/$sh-$tool.res"
            continue
        fi
        while (( $(jobs -rp | wc -l) >= 4 )); do wait -n; done
        run_case "$sh" "$tool" "$port" &
    done
done
wait

# Table: one row per tool, one column per shell
PASS=0; FAIL=0; SKIP=0
failed=()
printf '\n  %-10s' "tool"; for sh in "${shells[@]}"; do printf '%-36s' "$sh"; done; echo
for tool in "${tools[@]}"; do
    printf '  %-10s' "$tool"
    for sh in "${shells[@]}"; do
        res="$(cat "$TMP_ROOT/$sh-$tool.res" 2>/dev/null || echo "SKIP|not run|")"
        IFS='|' read -r st reason secs <<< "$res"
        case "$st" in
            PASS) PASS=$(( PASS + 1 )) ;;
            AUTH) SKIP=$(( SKIP + 1 )); st=SKIP ;;
            SKIP) SKIP=$(( SKIP + 1 )) ;;
            *)    FAIL=$(( FAIL + 1 )); failed+=("$sh-$tool") ;;
        esac
        cell="$st${secs:+ ${secs}s}${reason:+  $reason}"
        printf '%-36s' "${cell:0:35}"
    done
    echo
done

for f in ${failed[@]+"${failed[@]}"}; do
    echo ""
    echo "--- $f: last lines ---"
    t="$TMP_ROOT/$f-key/transcript.txt"
    [[ -f "$t" ]] || t="$TMP_ROOT/$f/transcript.txt"
    grep -v '^[[:space:]]*$' "$t" 2>/dev/null | tail -15 | sed 's/^/    /'
done

echo ""
echo "================================================================"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
(( FAIL == 0 )) && echo "ALL TESTS PASSED"
exit $(( FAIL > 0 ))
