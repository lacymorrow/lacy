#!/usr/bin/env zsh

# Auto-detection logic for determining shell vs agent mode

# Determine if input should use agent mode
lacy_shell_should_use_agent() {
    local input="$1"

    # Empty input goes to shell
    if [[ -z "$input" ]]; then
        return 1
    fi

    local first_word="${input%% *}"
    local first_word_lower="${first_word:l}"

    # "what" triggers agent mode
    if [[ "$first_word_lower" == "what" ]]; then
        return 0  # Use agent
    fi

    # If first word is a valid command, use shell
    if command -v "$first_word" &>/dev/null; then
        return 1  # Use shell
    fi

    # Default to agent for anything else
    return 0  # Use agent
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
    )

    echo "Testing auto-detection logic:"
    echo "============================="

    for test_case in "${test_cases[@]}"; do
        if lacy_shell_should_use_agent "$test_case"; then
            mode="agent"
        else
            mode="shell"
        fi
        printf "%-40s -> %s\n" "$test_case" "$mode"
    done
}
