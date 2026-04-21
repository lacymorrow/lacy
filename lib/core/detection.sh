#!/usr/bin/env bash

# Auto-detection logic for determining shell vs agent mode
# Shared across Bash 4+ and ZSH

# Cache for command -v lookups (avoids repeated PATH walks while typing)
LACY_CMD_CACHE_WORD=""
LACY_CMD_CACHE_RESULT=""

# Check if a word is a valid command, with single-entry cache
lacy_shell_is_valid_command() {
    local word="$1"
    if [[ "$word" == "$LACY_CMD_CACHE_WORD" ]]; then
        return $LACY_CMD_CACHE_RESULT
    fi
    LACY_CMD_CACHE_WORD="$word"
    if command -v "$word" &>/dev/null; then
        LACY_CMD_CACHE_RESULT=0
    else
        LACY_CMD_CACHE_RESULT=1
    fi
    return $LACY_CMD_CACHE_RESULT
}

# Check if input starting with a valid command has natural language markers.
# Returns 0 (true) if at least one bare word after the first word is a strong
# NL marker. Used to flag reroute candidates — the reroute only fires when
# the command also fails, so this can be fairly aggressive.
lacy_shell_has_nl_markers() {
    local input="$1"

    # Bail if single word (no spaces)
    [[ "$input" != *" "* ]] && return 1

    # Bail if input contains shell operators — clearly shell syntax
    local op
    for op in "${LACY_SHELL_OPERATORS[@]}"; do
        [[ "$input" == *"$op"* ]] && return 1
    done

    # Extract tokens after the first word
    local rest="${input#* }"
    local -a tokens
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        tokens=( ${=rest} )
    else
        # Bash: IFS word splitting
        read -ra tokens <<< "$rest"
    fi

    # Filter to bare words only (skip flags, paths, numbers, variables)
    local -a bare_words=()
    local token lower_token
    for token in "${tokens[@]}"; do
        # Skip flags (-x, --flag)
        [[ "$token" == -* ]] && continue
        # Skip paths (/foo, ./bar, ~/dir)
        [[ "$token" == /* || "$token" == ./* || "$token" == ~/* ]] && continue
        # Skip pure numbers
        [[ "$token" =~ ^[0-9]+$ ]] && continue
        # Skip variables ($VAR, ${VAR})
        [[ "$token" == \$* ]] && continue
        lower_token=$(_lacy_lowercase "$token")
        bare_words+=( "$lower_token" )
    done

    # Need at least 1 bare word after the first word
    (( ${#bare_words[@]} < 1 )) && return 1

    # Check for strong NL markers
    local word marker
    for word in "${bare_words[@]}"; do
        for marker in "${LACY_NL_MARKERS[@]}"; do
            [[ "$word" == "$marker" ]] && return 0
        done
    done

    return 1
}

# Canonical detection function. Prints "neutral", "shell", or "agent".
# All detection flows (indicator, execution) must go through this function.
lacy_shell_classify_input() {
    local input="$1"

    # Trim leading whitespace (POSIX-compatible, no extendedglob)
    input="${input#"${input%%[^[:space:]]*}"}"
    # Trim trailing whitespace
    input="${input%"${input##*[^[:space:]]}"}"

    # Empty input - show mode color in shell/agent, neutral in auto
    if [[ -z "$input" ]]; then
        case "$LACY_SHELL_CURRENT_MODE" in
            "shell") echo "shell" ;;
            "agent") echo "agent" ;;
            *) echo "neutral" ;;
        esac
        return
    fi

    # Emergency bypass prefix (!) = shell
    if [[ "$input" == !* ]]; then
        echo "shell"
        return
    fi

    # Agent bypass prefix (@) = agent
    if [[ "$input" == @* ]]; then
        echo "agent"
        return
    fi

    # In shell mode, everything goes to shell
    if [[ "$LACY_SHELL_CURRENT_MODE" == "shell" ]]; then
        echo "shell"
        return
    fi

    # In agent mode, everything goes to agent
    if [[ "$LACY_SHELL_CURRENT_MODE" == "agent" ]]; then
        echo "agent"
        return
    fi

    # Auto mode: check special cases and commands
    # Extract first token respecting:
    #   - backslash-escaped spaces: /path/to/Google\ Chrome
    #   - double-quoted paths: "/Applications/Google Chrome.app/..."
    #   - single-quoted paths: '/Applications/Google Chrome.app/...'
    local first_word first_word_cmd
    if [[ "$input" == \"* ]]; then
        # Double-quoted first token: extract up to closing quote
        local _after="${input#\"}"
        first_word="\"${_after%%\"*}\""
        # Strip quotes for command -v lookup
        first_word_cmd="${_after%%\"*}"
    elif [[ "$input" == \'* ]]; then
        # Single-quoted first token: extract up to closing quote
        local _after="${input#\'}"
        first_word="'${_after%%\'*}'"
        first_word_cmd="${_after%%\'*}"
    else
        # Backslash-escaped spaces
        local _esc_input="${input//\\ /$'\x01'}"
        first_word="${_esc_input%% *}"
        first_word="${first_word//$'\x01'/\\ }"
        # Un-escaped version for command -v lookups (backslash-space → space)
        first_word_cmd="${first_word//\\ / }"
    fi
    local first_word_lower
    first_word_lower=$(_lacy_lowercase "$first_word_cmd")

    # Layer 1a: Shell reserved words pass `command -v` but are never valid
    # standalone commands. Route to agent. (see docs/NATURAL_LANGUAGE_DETECTION.md)
    if _lacy_in_list "$first_word_lower" "${LACY_SHELL_RESERVED_WORDS[@]}"; then
        echo "agent"
        return
    fi

    # Layer 1b: Common English words almost always route to agent.
    # Exception: if the word is also a valid shell command AND the arguments
    # look like shell syntax, defer to shell. Heuristic is conservative:
    # only shell when operators are present OR there is at most one bare word
    # argument (after flags/paths/numbers) that is not an NL marker.
    # Examples: `which python` → shell, `yes | cmd` → shell
    #           `which version to use` → agent, `yes lets go` → agent
    if _lacy_in_list "$first_word_lower" "${LACY_AGENT_WORDS[@]}"; then
        if lacy_shell_is_valid_command "$first_word_cmd"; then
            # Shell operators anywhere → shell
            local _op
            for _op in "${LACY_SHELL_OPERATORS[@]}"; do
                [[ "$input" == *"$_op"* ]] && { echo "shell"; return; }
            done
            # Count bare words (non-flag, non-path, non-number, non-variable)
            if [[ "$input" == *" "* ]]; then
                local _rest="${input#* }"
                local -a _tokens
                if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
                    _tokens=( ${=_rest} )
                else
                    read -ra _tokens <<< "$_rest"
                fi
                local -a _bare=()
                local _tok _ltok
                for _tok in "${_tokens[@]}"; do
                    [[ "$_tok" == -* ]] && continue
                    [[ "$_tok" == /* || "$_tok" == ./* || "$_tok" == ~/* ]] && continue
                    [[ "$_tok" =~ ^[0-9]+$ ]] && continue
                    [[ "$_tok" == \$* ]] && continue
                    _ltok=$(_lacy_lowercase "$_tok")
                    _bare+=( "$_ltok" )
                done
                # 0 bare words (flags only) → shell
                if (( ${#_bare[@]} == 0 )); then
                    echo "shell"
                    return
                fi
                # Exactly 1 bare word that is not an NL marker → shell
                if (( ${#_bare[@]} == 1 )); then
                    if ! _lacy_in_list "${_bare[${_LACY_ARR_OFFSET}]}" "${LACY_NL_MARKERS[@]}"; then
                        echo "shell"
                        return
                    fi
                fi
                # 2+ bare words, or the single bare word is an NL marker → agent
            fi
        fi
        echo "agent"
        return
    fi

    # Inline env var assignment: VAR=value command args
    # Skip past any VAR=value prefixes to find the actual command
    if [[ "$first_word" == *=* ]]; then
        local -a _words
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            _words=( ${=input} )
        else
            read -ra _words <<< "$input"
        fi
        local _w
        for _w in "${_words[@]}"; do
            if [[ "$_w" == *=* ]]; then
                continue
            fi
            # Found the actual command after env var(s)
            if lacy_shell_is_valid_command "$_w"; then
                echo "shell"
                return
            fi
            break
        done
    fi

    # Check if it's a valid command (cached)
    if lacy_shell_is_valid_command "$first_word_cmd"; then
        echo "shell"
        return
    fi

    # Single word that's not a command = probably a typo -> shell
    # Multiple words with non-command first word = natural language -> agent
    # Check if there's anything after the first token
    local _rest_after_first="${input#"$first_word"}"
    _rest_after_first="${_rest_after_first#"${_rest_after_first%%[^[:space:]]*}"}"
    if [[ -z "$_rest_after_first" ]]; then
        echo "shell"
    else
        echo "agent"
    fi
}

# Backward-compatible wrapper: returns 0 (agent) or 1 (shell/neutral)
lacy_shell_should_use_agent() {
    local result
    result=$(lacy_shell_classify_input "$1")
    if [[ "$result" == "agent" ]]; then
        return 0
    else
        return 1
    fi
}

# Initialize detection cache (call at startup)
lacy_shell_init_detection_cache() {
    LACY_CMD_CACHE_WORD=""
    LACY_CMD_CACHE_RESULT=""
}

# Layer 2: Post-execution natural language detection.
# Analyzes a failed shell command's output to determine if the user
# typed natural language. Returns 0 (true) if NL detected, 1 otherwise.
# See docs/NATURAL_LANGUAGE_DETECTION.md for the full algorithm.
#
# Usage: lacy_shell_detect_natural_language "input" "output" exit_code
lacy_shell_detect_natural_language() {
    local input="$1"
    local output="$2"
    local exit_code="$3"

    # Only check failed commands
    (( exit_code == 0 )) && return 1
    [[ -z "$exit_code" ]] && return 1

    # Count words
    local -a words
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        words=( ${=input} )
    else
        read -ra words <<< "$input"
    fi

    # Single-word inputs are probably real commands
    (( ${#words[@]} < 2 )) && return 1

    # Criterion A: output must match at least one error pattern (case-insensitive)
    local output_lower
    output_lower=$(_lacy_lowercase "$output")
    local pattern pattern_lower matched=false
    for pattern in "${LACY_SHELL_ERROR_PATTERNS[@]}"; do
        pattern_lower=$(_lacy_lowercase "$pattern")
        if [[ "$output_lower" == *"$pattern_lower"* ]]; then
            matched=true
            break
        fi
    done
    [[ "$matched" == false ]] && return 1

    # Criterion B: check for natural language signal
    local second_word
    second_word=$(_lacy_lowercase "${words[$_LACY_ARR_OFFSET + 1]}")

    # B1: second word is a natural language marker
    if [[ -n "$second_word" ]] && _lacy_in_list "$second_word" "${LACY_NL_MARKERS[@]}"; then
        return 0
    fi

    # B2: 4+ words and a parse/syntax error
    if (( ${#words[@]} >= 4 )); then
        if [[ "$output_lower" == *"parse error"* || "$output_lower" == *"syntax error"* || "$output_lower" == *"unexpected token"* ]]; then
            return 0
        fi
    fi

    return 1
}

# Test the detection logic (for debugging)
lacy_shell_test_detection() {
    local test_cases=(
        "ls -la"
        "what files are in this directory?"
        "git status"
        "cd /home/user"
        "npm install"
        "rm file.txt"
        "pwd"
        "./run.sh"
        "what is the meaning of life?"
        "hello there"
        "nonexistent_command foo"
        "  ls -la"
        "  what files"
        "  !rm /tmp/test"
        "yes lets go"
        "no I dont want that"
        "yes"
        "RUST_LOG=debug cargo run"
        "FOO=bar BAZ=qux node index.js"
        "CC=gcc make -j4"
        # Agent words that are also valid commands — should use heuristics
        "which python"
        "which -a git"
        "which version should I install"
        "which"
        "yes | apt-get install -y"
        "nice -n 10 make"
        "nice work"
        "who"
        "who root"
        "who am I"
        # Backslash-escaped spaces in paths
        "/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome --remote-debugging-port=9222"
        "./my\\ script.sh --flag"
        # Quoted paths with spaces
        '"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222'
        "'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --flag"
        '"/usr/local/bin/my tool"'
        # @ agent bypass
        "@ make sure the tests pass"
        "@fix the bug in auth"
    )

    echo "Testing auto-detection logic:"
    echo "============================="

    local test_case result
    for test_case in "${test_cases[@]}"; do
        result=$(lacy_shell_classify_input "$test_case")
        printf "%-40s -> %s\n" "$test_case" "$result"
    done

    echo ""
    echo "Testing NL marker detection:"
    echo "============================="

    local nl_tests=(
        "kill the process on localhost:3000"
        "kill -9 my baby"
        "kill -9 my baby girl"
        "kill -9"
        "echo the quick brown fox"
        "echo hello | grep the"
        "find my large files"
        "make the tests pass"
        "git push origin main"
        "docker run -it ubuntu"
    )

    for test_case in "${nl_tests[@]}"; do
        if lacy_shell_has_nl_markers "$test_case"; then
            printf "%-40s -> nl_markers: YES\n" "$test_case"
        else
            printf "%-40s -> nl_markers: NO\n" "$test_case"
        fi
    done
}
