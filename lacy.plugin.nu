# Lacy Shell — Nushell plugin entry point
# Source this file in ~/.config/nushell/config.nu:
#   source ~/.lacy/lacy.plugin.nu
#
# Or let the installer add it automatically.
#
# Requires Nushell 0.87+.

# ============================================================================
# Guards
# ============================================================================

# Prevent multiple sourcing
if ($env.LACY_SHELL_LOADED? | default false) == true { return }

let _nu_ver = (version).version | split row '.' | each { into int }
if ($_nu_ver | first) == 0 and ($_nu_ver | get 1) < 87 {
    print --stderr $"Lacy Shell: Nushell 0.87+ is required. You have: (version).version"
    return
}

# ============================================================================
# Paths
# ============================================================================

$env.LACY_SHELL_HOME = ($env.HOME | path join ".lacy")
$env.LACY_SHELL_TYPE = "nushell"
$env.LACY_SHELL_ACTIVE = 1
$env.LACY_SHELL_LOADED = true

# ============================================================================
# Source Nushell modules
# ============================================================================

# Note: `source` requires literal paths in Nushell.
# The plugin is assumed to be installed at ~/.lacy/.
source ~/.lacy/lib/nu/config.nu
source ~/.lacy/lib/nu/detection.nu
source ~/.lacy/lib/nu/execute.nu
source ~/.lacy/lib/nu/keybindings.nu
source ~/.lacy/lib/nu/prompt.nu
