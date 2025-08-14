#!/usr/bin/env zsh

# Auto-detection logic for determining shell vs agent mode

# Default keywords and commands (can be overridden by config)
LACY_SHELL_AGENT_KEYWORDS=(
    "help" "how" "what" "why" "explain" "show me" "find" "search"
    "tell me" "can you" "please" "list" "describe" "analyze"
    "summarize" "create" "generate" "write" "make" "build"
)

LACY_SHELL_SHELL_COMMANDS=(
    "ls" "cd" "pwd" "cp" "mv" "rm" "mkdir" "rmdir" "chmod" "chown"
    "ps" "kill" "top" "htop" "grep" "sed" "awk" "cat" "less" "more"
    "git" "npm" "yarn" "pip" "cargo" "docker" "kubectl" "ssh" "scp"
    "curl" "wget" "ping" "netstat" "df" "du" "free" "uname" "which"
)

# Determine if input should use agent mode
lacy_shell_should_use_agent() {
    local input="$1"
    local input_lower="${input:l}"  # Convert to lowercase
    
    # Empty input goes to shell
    if [[ -z "$input" ]]; then
        return 1
    fi
    
    # Check if it starts with a known shell command
    local first_word="${input%% *}"
    local first_word_lower="${first_word:l}"
    
    # If it starts with a shell command, use shell mode
    for cmd in "${LACY_SHELL_SHELL_COMMANDS[@]}"; do
        if [[ "$first_word_lower" == "$cmd" ]]; then
            return 1  # Use shell
        fi
    done
    
    # Check for agent keywords
    for keyword in "${LACY_SHELL_AGENT_KEYWORDS[@]}"; do
        if [[ "$input_lower" == *"$keyword"* ]]; then
            return 0  # Use agent
        fi
    done
    
    # Check for question patterns
    if [[ "$input_lower" == \?* || "$input_lower" == *\? ]]; then
        return 0  # Use agent
    fi
    
    # Check for natural language patterns
    if [[ "$input_lower" =~ "^(can|could|would|should|do|does|did|is|are|was|were|have|has|had|will|would)" ]]; then
        return 0  # Use agent
    fi
    
    # Check length and complexity (longer, more complex inputs likely for agent)
    local word_count=$(echo "$input" | wc -w)
    if [[ $word_count -gt 5 ]]; then
        # If it has more than 5 words and doesn't start with a known command,
        # it's probably a natural language query
        return 0  # Use agent
    fi
    
    # Check for file paths or command-like patterns
    if [[ "$input" =~ "^[./~]" || "$input" =~ "^[a-zA-Z0-9_-]+$" ]]; then
        return 1  # Use shell
    fi
    
    # Check for command patterns (contains flags/options)
    if [[ "$input" =~ " -[a-zA-Z]" || "$input" =~ " --[a-zA-Z]" ]]; then
        return 1  # Use shell
    fi
    
    # Default to shell for short, simple inputs
    if [[ $word_count -le 2 ]]; then
        return 1  # Use shell
    fi
    
    # Default to agent for everything else
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
        "help me write a Python script"
        "cd /home/user"
        "how do I install this package?"
        "npm install"
        "show me recent commits"
        "rm file.txt"
        "can you explain this code?"
        "pwd"
        "find all Python files in this project"
        "./run.sh"
        "what is the meaning of life?"
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
