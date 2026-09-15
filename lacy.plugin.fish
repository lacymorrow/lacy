# Lacy Shell: Fish plugin entry point
# Source this file in ~/.config/fish/conf.d/lacy.fish:
#   source ~/.lacy/lacy.plugin.fish
#
# Or let the installer add it automatically.

# ============================================================================
# Guards
# ============================================================================

# Key bindings and prompts only matter in an interactive shell
status is-interactive; or return

# Load once per session (`quit` clears this so `lacy` can load it again)
if set -q _LACY_FISH_LOADED
    return
end

# Require Fish 3.1+ for bind -M and commandline -f
set -l _lacy_fish_v (string match -r -- '^(\d+)\.(\d+)' $version)
if not set -q _lacy_fish_v[3]; or test $_lacy_fish_v[2] -lt 3; or test $_lacy_fish_v[2] -eq 3 -a $_lacy_fish_v[3] -lt 1
    echo "Lacy Shell: Fish 3.1+ is required. You have: $version." >&2
    return
end
set -g _LACY_FISH_MAJOR $_lacy_fish_v[2]
set -g _LACY_FISH_LOADED 1

# ============================================================================
# Paths
# ============================================================================

set -q LACY_SHELL_HOME; or set -gx LACY_SHELL_HOME "$HOME/.lacy"
set -gx LACY_SHELL_TYPE "fish"
set -gx LACY_SHELL_ACTIVE 1
set -l _lacy_plugin (realpath (status filename) 2>/dev/null)
or set _lacy_plugin "$LACY_SHELL_HOME/lacy.plugin.fish"
set -g LACY_SHELL_DIR (dirname $_lacy_plugin)

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
    set -e _LACY_FISH_LOADED
end
