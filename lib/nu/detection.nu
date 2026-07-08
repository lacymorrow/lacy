# Lacy Shell — Nushell input classification
#
# Ports the core detection logic from lib/core/detection.sh to Nushell syntax.
# Returns: "shell" | "agent" | "neutral"

# Classify a line of input.
# Usage: let route = (_lacy_classify_input "some input")
def _lacy_classify_input [input: string] -> string {
    let trimmed = ($input | str trim)

    # Empty input — return mode color signal
    if $trimmed == "" {
        return (match $env.LACY_SHELL_MODE {
            "shell" => "shell"
            "agent" => "agent"
            _ => "neutral"
        })
    }

    # Locked modes
    if $env.LACY_SHELL_MODE == "shell" { return "shell" }
    if $env.LACY_SHELL_MODE == "agent" { return "agent" }

    # Emergency bypass: leading !
    if ($trimmed | str starts-with "!") { return "shell" }

    let words = ($trimmed | split row ' ' | where { |w| $w != "" })
    let first_word = ($words | first | str downcase)
    let word_count = ($words | length)

    # Agent word check (single words that always route to agent)
    if $first_word in $env.LACY_AGENT_WORDS { return "agent" }

    # Shell reserved words that look like natural language
    if $first_word in $env.LACY_SHELL_RESERVED_WORDS { return "agent" }

    # Valid command → shell (use `which` since Nushell has no `command -v`)
    if (which $first_word | length) > 0 { return "shell" }

    # Single unknown word → shell (let it fail naturally — likely a typo)
    if $word_count == 1 { return "shell" }

    # Multi-word, first word not a command → agent (natural language)
    "agent"
}
