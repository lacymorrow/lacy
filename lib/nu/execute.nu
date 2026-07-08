# Lacy Shell — Nushell execution routing
#
# Routes input to either the shell or the AI agent.
# Alt+Enter sends the current buffer to the agent.
# Normal Enter executes as-is in Nushell.

def _lacy_detect_tool [] -> string {
    let active = ($env.LACY_ACTIVE_TOOL? | default "")
    if $active != "" and $active != "auto" { return $active }
    for tool in $env.LACY_TOOL_LIST {
        if (which $tool | length) > 0 { return $tool }
    }
    ""
}

def _lacy_no_tool_error [] {
    print $"\n\e[38;5;196m  No AI tool detected.\e[0m Lacy needs an AI CLI to handle queries.\n"
    print $"\e[1m  Supported tools:\e[0m\n"
    print $"    \e[38;5;34mlash\e[0m        npm install -g lashcode        (recommended)"
    print $"    \e[38;5;238mclaude\e[0m      brew install claude"
    print $"    \e[38;5;238mopencode\e[0m    brew install opencode"
    print $"    \e[38;5;238mgemini\e[0m      brew install gemini"
    print $"    \e[38;5;238mcodex\e[0m       npm install -g @openai/codex"
    print $"\n  \e[38;5;75mThen run:\e[0m  lacy setup"
    print $"  \e[38;5;75mDocs:\e[0m      https://lacy.sh/docs\n"
}

# Send a query to the active AI agent.
def _lacy_query_agent [query: string] {
    let tool = (_lacy_detect_tool)

    if $tool == "" { _lacy_no_tool_error; return }

    print ""
    match $tool {
        "lash"     => { ^lash run -c $query }
        "claude"   => { ^claude -p $query }
        "opencode" => { ^opencode run -c $query }
        "gemini"   => { ^gemini -p $query }
        "codex"    => { ^codex exec resume --last $query }
        "custom"   => {
            let cmd = ($env.LACY_CUSTOM_TOOL_CMD? | default "")
            if $cmd == "" {
                print --stderr "Lacy: custom tool set but LACY_CUSTOM_TOOL_CMD is empty"
                return
            }
            let parts = ($cmd | split row ' ')
            ^($parts | first) ...($parts | skip 1) $query
        }
        _ => { print --stderr $"Lacy: unknown tool '($tool)'" }
    }
    print ""
}

# Send the current commandline buffer to the agent.
# Bound to Alt+Enter via keybindings.nu.
def _lacy_send_to_agent [] {
    let buf = (commandline)
    if ($buf | str trim) == "" { return }

    let route = (_lacy_classify_input $buf)
    if $route != "agent" {
        # Not natural language — let the user decide; show a hint and exit
        print $"\n\e[38;5;238m  (Lacy: looks like a shell command — press Enter to execute normally)\e[0m"
        return
    }

    commandline edit --replace ""
    _lacy_query_agent $buf
}

# Public `lacy` command for manual agent queries.
# Usage: lacy "why does this build fail?"
export def lacy [query?: string] {
    let q = if $query != null { $query } else {
        input "Query: "
    }
    _lacy_query_agent $q
}
