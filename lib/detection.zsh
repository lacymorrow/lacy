#!/usr/bin/env zsh

# Auto-detection logic for determining shell vs agent mode

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

# Canonical detection function. Prints "neutral", "shell", or "agent".
# All detection flows (indicator, execution) must go through this function.
lacy_shell_classify_input() {
    local input="$1"

    # Trim leading whitespace (POSIX-compatible, no extendedglob)
    input="${input#"${input%%[^[:space:]]*}"}"
    # Trim trailing whitespace
    input="${input%"${input##*[^[:space:]]}"}"

    # Empty input = neutral
    if [[ -z "$input" ]]; then
        echo "neutral"
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
    local first_word_lower="${first_word:l}"

    # "what" always goes to agent (hardcoded override)
    if [[ "$first_word_lower" == "what" ]]; then
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
            # In auto mode, use smart auto execution
            echo "auto"
            ;;
        *)
            echo "shell"  # Default fallback
            ;;
    esac
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
    )

    echo "Testing auto-detection logic:"
    echo "============================="

    for test_case in "${test_cases[@]}"; do
        local result=$(lacy_shell_classify_input "$test_case")
        printf "%-40s -> %s\n" "$test_case" "$result"
    done
}
