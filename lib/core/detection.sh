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
# Returns 0 (true) if 3+ bare words exist after the first word AND at least
# one is a strong NL marker. Used to flag reroute candidates.
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

    # Need 3+ bare words to be considered NL
    (( ${#bare_words[@]} < 3 )) && return 1

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
    local first_word="${input%% *}"
    local first_word_lower
    first_word_lower=$(_lacy_lowercase "$first_word")

    # Hard agent indicators — always route to agent
    local indicator
    for indicator in "${LACY_HARD_AGENT_INDICATORS[@]}"; do
        if [[ "$first_word_lower" == "$indicator" ]]; then
            echo "agent"
            return
        fi
    done

    # Layer 1: Shell reserved words pass `command -v` but are never valid
    # standalone commands. Route to agent. (see NATURAL_LANGUAGE_DETECTION.md)
    if _lacy_in_list "$first_word_lower" "${LACY_SHELL_RESERVED_WORDS[@]}"; then
        echo "agent"
        return
    fi

    # Check if it's a valid command (cached)
    if lacy_shell_is_valid_command "$first_word"; then
        echo "shell"
        return
    fi

    # Single word that's not a command = probably a typo -> shell
    # Multiple words with non-command first word = natural language -> agent
    if [[ "$input" != *" "* ]]; then
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

# Determine the appropriate mode for input
lacy_shell_detect_mode() {
    local input="$1"

    case "$LACY_SHELL_CURRENT_MODE" in
        "shell")
            echo "shell"
            ;;
        "agent")
            echo "agent"
            ;;
        "auto")
            echo "auto"
            ;;
        *)
            echo "shell"  # Default fallback
            ;;
    esac
}

# Initialize detection cache (call at startup)
lacy_shell_init_detection_cache() {
    LACY_CMD_CACHE_WORD=""
    LACY_CMD_CACHE_RESULT=""
}

# Layer 2: Post-execution natural language detection.
# Analyzes a failed shell command's output to determine if the user
# typed natural language. Returns 0 (true) if NL detected, 1 otherwise.
# Sets LACY_NL_HINT with a message if detected.
# See NATURAL_LANGUAGE_DETECTION.md for the full algorithm.
#
# Usage: lacy_shell_detect_natural_language "input" "output" exit_code
lacy_shell_detect_natural_language() {
    local input="$1"
    local output="$2"
    local exit_code="$3"
    LACY_NL_HINT=""

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

    # Very short inputs are probably real commands
    (( ${#words[@]} < 3 )) && return 1

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
        LACY_NL_HINT="This looks like a question for the agent. Try again without shell mode, or press Ctrl+Space to switch to Agent mode."
        return 0
    fi

    # B2: 5+ words and a parse/syntax error
    if (( ${#words[@]} >= 5 )); then
        if [[ "$output_lower" == *"parse error"* || "$output_lower" == *"syntax error"* || "$output_lower" == *"unexpected token"* ]]; then
            LACY_NL_HINT="This looks like a question for the agent. Try again without shell mode, or press Ctrl+Space to switch to Agent mode."
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
