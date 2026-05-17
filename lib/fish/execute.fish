# Lacy Shell — Fish execution routing
#
# Intercepts Enter to route input to either the shell or the AI agent.

# Resolve the active AI tool command string.
function _lacy_tool_cmd --description "Return the command template for a tool"
    switch $argv[1]
        case lash;     echo "lash run -c"
        case claude;   echo "claude -p"
        case opencode; echo "opencode run -c"
        case gemini;   echo "gemini -p"
        case codex;    echo "codex exec resume --last"
        case '*';      echo ""
    end
end

# Auto-detect the first installed tool from LACY_TOOL_LIST.
function _lacy_detect_tool --description "Return first installed AI tool"
    if test -n "$LACY_ACTIVE_TOOL"; and test "$LACY_ACTIVE_TOOL" != auto
        echo $LACY_ACTIVE_TOOL; return
    end
    for t in $LACY_TOOL_LIST
        if command -q $t 2>/dev/null
            echo $t; return
        end
    end
    echo ""
end

# Send a query to the AI agent.
function _lacy_query_agent --description "Route a query to the AI agent"
    set -l query $argv[1]
    set -l tool (_lacy_detect_tool)

    if test -z "$tool"
        printf '\n\e[38;5;196m  No AI tool detected.\e[0m Lacy needs an AI CLI to handle queries.\n\n'
        printf '\e[1m  Supported tools:\e[0m\n\n'
        printf '    \e[38;5;34m%-12s\e[0m %s\n' "lash"     "npm install -g lashcode        (recommended)"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "claude"   "brew install claude"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "opencode" "brew install opencode"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "gemini"   "brew install gemini"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "codex"    "npm install -g @openai/codex"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "hermes"   "curl -fsSL .../install.sh | bash"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "copilot"  "gh extension install github/gh-copilot"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "goose"    "brew install goose"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "amp"      "npm install -g @sourcegraph/amp"
        printf '    \e[38;5;238m%-12s\e[0m %s\n' "aider"    "pipx install aider-chat"
        printf '\n  \e[38;5;75mThen run:\e[0m  lacy setup\n'
        printf '  \e[38;5;75mDocs:\e[0m      https://lacy.sh/docs\n\n'
        return 1
    end

    set -l cmd_str (_lacy_tool_cmd $tool)
    if test -z "$cmd_str"
        echo "Error: unknown tool: $tool" >&2; return 1
    end

    # Log the query
    _lacy_log_query $tool $query

    printf '\n'
    eval $cmd_str (string escape -- $query)
    printf '\n'
end

# Append a query to the query log.
function _lacy_log_query --description "Append query to ~/.lacy/logs/queries.log"
    set -l tool $argv[1]
    set -l query $argv[2]
    set -l log_dir "$LACY_SHELL_HOME/logs"
    set -l log_file "$log_dir/queries.log"

    mkdir -p "$log_dir" 2>/dev/null
    set -l ts (date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null; or echo unknown)
    set -l escaped_query (string replace -a \n '\\n' -- "$query")
    printf '%s\t%s\t%s\n' "$ts" "$tool" "$escaped_query" >> "$log_file" 2>/dev/null

    # Rotate if over 1 MB
    if test -f "$log_file"
        set -l size (wc -c < "$log_file" 2>/dev/null; or echo 0)
        if test $size -gt 1048576
            set -l tmp (mktemp)
            tail -n 1000 "$log_file" > $tmp; and mv $tmp "$log_file" 2>/dev/null
        end
    end
end

# Custom Enter binding — classify input and route accordingly.
function _lacy_accept_line --description "Classify and execute current commandline"
    set -l buffer (commandline)

    set -l route (_lacy_classify_input "$buffer")

    switch $route
        case agent
            commandline -f repaint
            set -l query $buffer
            commandline ""
            commandline -f execute
            _lacy_query_agent $query
        case '*'
            # shell (or neutral) — normal execution
            commandline -f execute
    end
end
