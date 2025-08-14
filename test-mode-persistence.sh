#!/usr/bin/env zsh

# Test script for mode persistence functionality

echo "🧪 Testing Lacy Shell Mode Persistence"
echo "======================================"

echo ""
echo "📋 Test 1: Setting agent mode"
zsh -c "
source lacy-shell.plugin.zsh
echo 'Initial mode:' \$LACY_SHELL_CURRENT_MODE
lacy_shell_set_mode 'agent'
echo 'Set to agent mode'
lacy_shell_mode_status
"

echo ""
echo "📋 Test 2: Verifying persistence in new shell"
zsh -c "
source lacy-shell.plugin.zsh
echo 'Mode loaded in fresh shell:' \$LACY_SHELL_CURRENT_MODE
lacy_shell_mode_status
"

echo ""
echo "📋 Test 3: Testing mode toggle"
zsh -c "
source lacy-shell.plugin.zsh
echo 'Current mode:' \$LACY_SHELL_CURRENT_MODE
lacy_shell_toggle_mode
echo 'After toggle:' \$LACY_SHELL_CURRENT_MODE
lacy_shell_mode_status
"

echo ""
echo "📋 Test 4: Final persistence check"
zsh -c "
source lacy-shell.plugin.zsh
echo 'Final mode in new shell:' \$LACY_SHELL_CURRENT_MODE
lacy_shell_mode_status
"

echo ""
echo "✅ Mode Persistence Test Complete!"
echo ""
echo "Expected behavior:"
echo "- Mode changes should be saved automatically"
echo "- Fresh shells should load the last saved mode" 
echo "- Mode status should show current, default, and saved modes"
