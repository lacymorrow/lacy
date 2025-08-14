#!/usr/bin/env zsh

# Test script for Smart Auto Mode functionality
# This script demonstrates the new smart auto mode behavior

echo "Testing Smart Auto Mode Implementation"
echo "======================================"
echo

# Source the required files
source lib/execute.zsh
source lib/detection.zsh  
source lib/modes.zsh

echo "1. Testing command existence checks:"
echo "------------------------------------"

test_commands=("ls" "git" "pwd" "nonexistentcmd123" "invalidcommand")

for cmd in "${test_commands[@]}"; do
    if lacy_shell_command_exists "$cmd"; then
        echo "✅ '$cmd' - command exists"
    else
        echo "❌ '$cmd' - command not found"
    fi
done

echo
echo "2. Testing natural language detection:"
echo "--------------------------------------"

test_inputs=(
    "ls -la"
    "what files are here?"
    "git status"
    "how do I install packages?"
    "please help me"
    "show me the logs"
    "cd /home"
    "explain this error"
)

for input in "${test_inputs[@]}"; do
    if lacy_shell_is_obvious_natural_language "$input"; then
        echo "🤖 '$input' - detected as natural language"
    else
        echo "💻 '$input' - detected as command"
    fi
done

echo
echo "3. Smart Auto Mode Behavior:"
echo "----------------------------"
lacy_shell_test_smart_auto

echo
echo "✅ Smart Auto Mode tests completed!"
echo
echo "Key improvements:"
echo "• Commands are tried first before falling back to AI"
echo "• Natural language is detected and sent directly to AI" 
echo "• Command existence is properly checked"
echo "• Better user feedback with clear indicators"
echo "• Fallback strategy when commands fail"
