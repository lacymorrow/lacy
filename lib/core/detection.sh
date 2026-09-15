#!/usr/bin/env bash

# Auto-detection logic for determining shell vs agent mode
# Shared across Bash 4+ and ZSH

# Cache for command -v lookups (avoids repeated PATH walks while typing)
LACY_CMD_CACHE_WORD=""
LACY_CMD_CACHE_RESULT=""

# Result of the last lacy_shell_classify_input call ("neutral", "shell", "agent").
# Hot-path consumers (indicator, highlight, accept-line) read this instead of
# capturing stdout, which would cost a fork per keystroke.
_LACY_CLASSIFY_RESULT=""

# Space-delimited copies of the word lists, built once at load time so that
# membership is a single pattern match instead of a loop over ~150 entries.
# Local IFS guarantees a space join whatever the caller's IFS is.
_lacy_build_word_strs() {
    local IFS=' '
    _LACY_AGENT_WORDS_STR=" ${LACY_AGENT_WORDS[*]} "
    _LACY_RESERVED_WORDS_STR=" ${LACY_SHELL_RESERVED_WORDS[*]} "
    _LACY_NL_MARKERS_STR=" ${LACY_NL_MARKERS[*]} "
}
_lacy_build_word_strs

# Lowercase without a fork: sets the named variable instead of echoing.
# Usage: _lacy_lower_into VARNAME "STRING"
_lacy_lower_into() {
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        printf -v "$1" '%s' "${2:l}"
    else
        printf -v "$1" '%s' "${2,,}"
    fi
}

# True if the word is a user alias or shell function (not a builtin or
# external command). Builtins only, no fork.
_lacy_is_alias_or_function() {
    local word="$1"
    alias "$word" >/dev/null 2>&1 && return 0
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        functions "$word" >/dev/null 2>&1 && return 0
    else
        declare -F "$word" >/dev/null 2>&1 && return 0
    fi
    return 1
}

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
# NL marker. Used to flag reroute candidates: the reroute only fires when
# the command also fails, so this can be fairly aggressive.
lacy_shell_has_nl_markers() {
    local input="$1"

    # Bail if single word (no spaces)
    [[ "$input" != *" "* ]] && return 1

    # Bail if input contains shell operators: clearly shell syntax
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
        # Skip paths (/foo, ./bar, ~/dir). The tilde pattern is quoted so the
        # shell does not expand it to $HOME before matching.
        [[ "$token" == /* || "$token" == ./* || "$token" == "~/"* ]] && continue
        # Skip pure numbers
        [[ "$token" =~ ^[0-9]+$ ]] && continue
        # Skip variables ($VAR, ${VAR})
        [[ "$token" == \$* ]] && continue
        _lacy_lower_into lower_token "$token"
        bare_words+=( "$lower_token" )
    done

    # Need at least 1 bare word after the first word
    (( ${#bare_words[@]} < 1 )) && return 1

    # Check for strong NL markers
    local word
    for word in "${bare_words[@]}"; do
        [[ "$_LACY_NL_MARKERS_STR" == *" $word "* ]] && return 0
    done

    return 1
}

# Canonical detection function. Prints "neutral", "shell", or "agent" and
# also stores the answer in _LACY_CLASSIFY_RESULT so hot-path callers can
# discard stdout and read the variable (no subshell fork per keystroke):
#
#     lacy_shell_classify_input "$BUFFER" >/dev/null
#     case "$_LACY_CLASSIFY_RESULT" in ...
#
# All detection flows (indicator, highlight, execution) must go through here.
lacy_shell_classify_input() {
    _lacy_classify_impl "$1"
    printf '%s\n' "$_LACY_CLASSIFY_RESULT"
}

# Body of lacy_shell_classify_input. Sets _LACY_CLASSIFY_RESULT, prints nothing.
_lacy_classify_impl() {
    local input="$1"
    _LACY_CLASSIFY_RESULT="neutral"

    # Trim leading whitespace (POSIX-compatible, no extendedglob)
    input="${input#"${input%%[^[:space:]]*}"}"
    # Multi-line buffers: only the first line drives the decision. A pasted
    # script or a heredoc starts with a command; classify that, not the blob.
    local _lacy_nl=$'\n'
    input="${input%%$_lacy_nl*}"
    # Trim trailing whitespace
    input="${input%"${input##*[^[:space:]]}"}"

    # Empty input - show mode color in shell/agent, neutral in auto
    if [[ -z "$input" ]]; then
        case "$LACY_SHELL_CURRENT_MODE" in
            "shell") _LACY_CLASSIFY_RESULT="shell" ;;
            "agent") _LACY_CLASSIFY_RESULT="agent" ;;
        esac
        return
    fi

    # Emergency bypass prefix (!) = shell. Covers both `!rm -rf x` (bypass,
    # prefix stripped by the accept-line widget) and `! true` (shell negation).
    if [[ "$input" == !* ]]; then
        _LACY_CLASSIFY_RESULT="shell"
        return
    fi

    # Agent bypass prefix (@) = agent
    if [[ "$input" == @* ]]; then
        _LACY_CLASSIFY_RESULT="agent"
        return
    fi

    # In shell mode, everything goes to shell
    if [[ "$LACY_SHELL_CURRENT_MODE" == "shell" ]]; then
        _LACY_CLASSIFY_RESULT="shell"
        return
    fi

    # In agent mode, everything goes to agent
    if [[ "$LACY_SHELL_CURRENT_MODE" == "agent" ]]; then
        _LACY_CLASSIFY_RESULT="agent"
        return
    fi

    # Auto mode from here on.

    # Comment line: let the shell swallow it
    if [[ "$input" == \#* ]]; then
        _LACY_CLASSIFY_RESULT="shell"
        return
    fi

    # Extract first token respecting:
    #   - backslash-escaped spaces: /path/to/Google\ Chrome
    #   - double-quoted paths: "/Applications/Google Chrome.app/..."
    #   - single-quoted paths: '/Applications/Google Chrome.app/...'
    # first_word keeps the quoting (it is a literal prefix of input);
    # first_word_cmd is the unquoted form used for command -v lookups.
    local first_word="" first_word_cmd="" _after=""
    if [[ "$input" == \"* && "${input#\"}" == *\"* ]]; then
        # Double-quoted first token: extract up to closing quote
        _after="${input#\"}"
        first_word="\"${_after%%\"*}\""
        first_word_cmd="${_after%%\"*}"
    elif [[ "$input" == \'* && "${input#\'}" == *\'* ]]; then
        # Single-quoted first token: extract up to closing quote
        _after="${input#\'}"
        first_word="'${_after%%\'*}'"
        first_word_cmd="${_after%%\'*}"
    else
        # Backslash-escaped spaces: use a variable for the placeholder so that
        # $'\x01' is processed by ANSI-C quoting at assignment time. In ZSH,
        # $'\x01' inside ${var//pattern/replacement} is NOT expanded; it is
        # treated as the literal 6-char string $'\x01', breaking the round-trip.
        # An unterminated quote also lands here: the token runs to whitespace.
        local _lacy_bsp=$'\x01'
        local _esc_input="${input//\\ /$_lacy_bsp}"
        first_word="${_esc_input%%[[:space:]]*}"
        first_word="${first_word//$_lacy_bsp/\\ }"
        # Un-escaped version for command -v lookups (backslash-space to space)
        first_word_cmd="${first_word//\\ / }"
    fi

    # Everything after the first token, leading whitespace removed.
    # Empty means single-token input.
    local _rest="${input#"$first_word"}"
    _rest="${_rest#"${_rest%%[^[:space:]]*}"}"

    # Path-shaped or redirect-first tokens are shell syntax regardless of
    # whether the target exists: ./run.sh, ~/bin/x, /usr/bin/x, \ls (alias
    # bypass), (subshell), { group, [[ test, < file, > out, 2>/dev/null, &>log.
    # Let the shell report the error if the path is missing.
    case "$first_word_cmd" in
        */*|\\*|\(*|\{*|\[\[*|\<*|\>*|[0-9]\>*|\&\>*)
            _LACY_CLASSIFY_RESULT="shell"
            return
            ;;
    esac

    local first_word_lower
    _lacy_lower_into first_word_lower "$first_word_cmd"

    # Strip trailing punctuation for word-list lookups (e.g., "why?" to "why")
    local first_word_stripped="$first_word_lower"
    while [[ -n "$first_word_stripped" && "$first_word_stripped" == *[?.,\;:!] ]]; do
        first_word_stripped="${first_word_stripped%?}"
    done

    # Layer 1a: Shell reserved words pass `command -v` but are never valid
    # standalone commands. Route to agent. (see docs/NATURAL_LANGUAGE_DETECTION.md)
    if [[ "$_LACY_RESERVED_WORDS_STR" == *" $first_word_stripped "* ]]; then
        _LACY_CLASSIFY_RESULT="agent"
        return
    fi

    # Layer 1b: Common English words almost always route to agent.
    # Exceptions:
    #   - A single word the user aliased or defined as a function (`stop`,
    #     `deploy`, `lint`) is an intentional command. Builtins and external
    #     commands do not get this pass, so `yes` and `no` still go to agent.
    #   - If the word is also a valid shell command AND the arguments look
    #     like shell syntax, defer to shell. Heuristic is conservative: only
    #     shell when operators are present OR there is at most one bare word
    #     argument (after flags/paths/numbers) that is not an NL marker.
    # Examples: `which python` to shell, `yes | cmd` to shell
    #           `which version to use` to agent, `yes lets go` to agent
    if [[ "$_LACY_AGENT_WORDS_STR" == *" $first_word_stripped "* ]]; then
        if [[ -z "$_rest" ]] && _lacy_is_alias_or_function "$first_word_cmd"; then
            _LACY_CLASSIFY_RESULT="shell"
            return
        fi
        if [[ -n "$_rest" ]] && lacy_shell_is_valid_command "$first_word_cmd"; then
            # Shell operators anywhere to shell
            local _op
            for _op in "${LACY_SHELL_OPERATORS[@]}"; do
                if [[ "$input" == *"$_op"* ]]; then
                    _LACY_CLASSIFY_RESULT="shell"
                    return
                fi
            done
            # Count bare words (non-flag, non-path, non-number, non-variable).
            # Stop counting at 2: that is already enough to decide.
            local -a _tokens
            if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
                _tokens=( ${=_rest} )
            else
                read -ra _tokens <<< "$_rest"
            fi
            local _tok _ltok _bare_count=0 _bare_word=""
            for _tok in "${_tokens[@]}"; do
                [[ "$_tok" == -* ]] && continue
                [[ "$_tok" == /* || "$_tok" == ./* || "$_tok" == "~/"* ]] && continue
                [[ "$_tok" =~ ^[0-9]+$ ]] && continue
                [[ "$_tok" == \$* ]] && continue
                _lacy_lower_into _ltok "$_tok"
                _bare_word="$_ltok"
                (( _bare_count++ ))
                (( _bare_count >= 2 )) && break
            done
            # 0 bare words (flags only) to shell
            if (( _bare_count == 0 )); then
                _LACY_CLASSIFY_RESULT="shell"
                return
            fi
            # Exactly 1 bare word that is not an NL marker to shell
            if (( _bare_count == 1 )) && [[ "$_LACY_NL_MARKERS_STR" != *" $_bare_word "* ]]; then
                _LACY_CLASSIFY_RESULT="shell"
                return
            fi
            # 2+ bare words, or the single bare word is an NL marker: agent
        fi
        _LACY_CLASSIFY_RESULT="agent"
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
        local _w _rhs
        for _w in "${_words[@]}"; do
            if [[ "$_w" == *=* ]]; then
                # A quoted or $( ) right-hand side is shell syntax the naive
                # whitespace split cannot follow (FOO="a b" ls, x=$(ls) && ...)
                _rhs="${_w#*=}"
                if [[ "$_rhs" == \"* || "$_rhs" == \'* || "$_rhs" == \$\(* ]]; then
                    _LACY_CLASSIFY_RESULT="shell"
                    return
                fi
                continue
            fi
            # Assignment followed by an operator: FOO=1 && ls
            case "$_w" in
                '&&'|'||'|';'|'|'|'&')
                    _LACY_CLASSIFY_RESULT="shell"
                    return
                    ;;
            esac
            # Found the actual command after env var(s)
            if lacy_shell_is_valid_command "$_w"; then
                _LACY_CLASSIFY_RESULT="shell"
                return
            fi
            break
        done
    fi

    # Check if it's a valid command (cached)
    if lacy_shell_is_valid_command "$first_word_cmd"; then
        _LACY_CLASSIFY_RESULT="shell"
        return
    fi

    # Single word that's not a command = probably a typo, shell
    # Multiple words with non-command first word = natural language, agent
    if [[ -z "$_rest" ]]; then
        _LACY_CLASSIFY_RESULT="shell"
    else
        _LACY_CLASSIFY_RESULT="agent"
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
    _lacy_lower_into output_lower "$output"
    local pattern pattern_lower matched=false
    for pattern in "${LACY_SHELL_ERROR_PATTERNS[@]}"; do
        _lacy_lower_into pattern_lower "$pattern"
        if [[ "$output_lower" == *"$pattern_lower"* ]]; then
            matched=true
            break
        fi
    done
    [[ "$matched" == false ]] && return 1

    # Criterion B: check for natural language signal
    local second_word
    _lacy_lower_into second_word "${words[$_LACY_ARR_OFFSET + 1]}"

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
        # Agent words that are also valid commands: should use heuristics
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
