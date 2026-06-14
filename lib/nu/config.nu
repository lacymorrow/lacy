# Lacy Shell — Nushell configuration

$env.LACY_SHELL_MODE = "auto"     # shell | agent | auto
$env.LACY_ACTIVE_TOOL = ""        # empty = auto-detect
$env.LACY_CUSTOM_TOOL_CMD = ""
$env.LACY_TOOL_LIST = ["lash" "claude" "opencode" "gemini" "codex"]

# Agent words: single words that always route to the AI agent.
# Kept in sync with lib/core/constants.sh LACY_AGENT_WORDS.
$env.LACY_AGENT_WORDS = [
    "yes" "yeah" "yep" "yup" "sure" "ok" "okay" "alright"
    "absolutely" "definitely" "certainly" "indeed" "correct" "right" "exactly"
    "perfect" "agreed" "affirmative" "totally" "clearly" "obviously" "lgtm"
    "no" "nope" "nah" "never" "wrong" "disagree"
    "thanks" "thank" "thx" "ty" "cheers" "appreciated"
    "great" "good" "nice" "cool" "awesome" "amazing" "wonderful" "brilliant"
    "excellent" "fantastic" "sweet" "neat" "beautiful" "gorgeous" "impressive"
    "incredible" "outstanding" "superb" "marvelous" "magnificent" "stellar"
    "phenomenal" "terrific" "splendid" "fine" "solid" "dope" "sick" "fire" "lit" "rad" "legit"
    "hey" "hi" "hello" "howdy" "sup" "yo" "bye" "goodbye" "cya" "later"
    "please" "sorry" "pardon" "hmm" "huh" "wow" "whoa" "oops" "ugh" "yikes"
    "damn" "dang" "shoot" "welp" "well" "anyway" "anyways" "regardless"
    "meanwhile" "honestly" "basically" "literally" "actually" "really"
    "seriously" "obviously" "hopefully" "unfortunately" "apparently"
    "supposedly" "probably" "maybe" "perhaps" "possibly"
    "stop" "hold" "pause" "cancel" "abort" "skip" "continue" "proceed"
    "next" "again" "redo" "undo" "retry"
    "explain" "elaborate" "clarify" "summarize" "describe" "show" "tell"
    "why" "how" "what" "when" "where" "who" "which" "whom" "whose"
    "can" "could" "would" "should" "will" "shall" "may" "might" "must"
    "does" "did" "is" "are" "was" "were" "has" "have" "had"
    "refactor" "optimize" "scaffold"
]

# Shell reserved words that pass command lookup but are never standalone commands.
$env.LACY_SHELL_RESERVED_WORDS = ["do" "done" "then" "else" "elif" "fi" "esac" "in" "select" "function"]

# ============================================================================
# YAML config parser (reads ~/.lacy/config.yaml)
# ============================================================================

def --env _lacy_load_config [] {
    let config_file = ($env.HOME | path join ".lacy" "config.yaml")
    if not ($config_file | path exists) { return }

    let cfg = (open --raw $config_file | from yaml)

    let active = ($cfg | get --optional agent_tools.active | default "" | into string | str trim)
    if $active != "" { $env.LACY_ACTIVE_TOOL = $active }

    let custom = ($cfg | get --optional agent_tools.custom_command | default "" | into string | str trim)
    if $custom != "" { $env.LACY_CUSTOM_TOOL_CMD = $custom }

    let mode = ($cfg | get --optional modes.default | default "" | into string | str trim)
    if $mode != "" { $env.LACY_SHELL_MODE = $mode }
}

_lacy_load_config
