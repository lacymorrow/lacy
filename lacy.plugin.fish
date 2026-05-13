# Lacy Shell — Fish plugin entry point
# Source this file in ~/.config/fish/conf.d/lacy.fish:
#   source ~/.lacy/lacy.plugin.fish
#
# Or let the installer add it automatically.

# ============================================================================
# Guards
# ============================================================================

# Require Fish 3.1+ for bind --sets-mode and commandline -f
set -l _lacy_fish_major (string match -r 'fish, version (\d+)' -- (fish --version 2>&1) | tail -1)
if test -z "$_lacy_fish_major"; or test "$_lacy_fish_major" -lt 3
    echo "Lacy Shell: Fish 3.1+ is required. You have: "(fish --version 2>&1)"." >&2
    set --erase _lacy_fish_major
    return
end
set --erase _lacy_fish_major

# ============================================================================
# Paths
# ============================================================================

set -gx LACY_SHELL_HOME "$HOME/.lacy"
set -gx LACY_SHELL_TYPE "fish"
set -gx LACY_SHELL_ACTIVE 1
set -gx LACY_SHELL_DIR (dirname (realpath (status filename) 2>/dev/null; or echo "$HOME/.lacy"))

# ============================================================================
# Source Fish modules
# ============================================================================

set -l _lacy_fish_dir "$LACY_SHELL_DIR/lib/fish"

if test -d "$_lacy_fish_dir"
    source "$_lacy_fish_dir/config.fish"
    source "$_lacy_fish_dir/detection.fish"
    source "$_lacy_fish_dir/execute.fish"
    source "$_lacy_fish_dir/keybindings.fish"
    source "$_lacy_fish_dir/prompt.fish"
else
    echo "Lacy Shell: lib/fish not found at $_lacy_fish_dir" >&2
end
