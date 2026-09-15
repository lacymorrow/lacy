# Lacy Shell: Fish execution routing
#
# Enter runs _lacy_accept_line. An agent query is rewritten to `ask '<query>'`
# and executed like any other command, so Ctrl+C reaches the tool, $status is
# set, and the typed text is what lands in history.

# Resolve the active AI tool command string.
function _lacy_tool_cmd --description "Return the command template for a tool"
    switch $argv[1]
        case lash
            echo "lash run -c"
        case claude
            echo "claude -p"
        case opencode
            echo "opencode run -c"
        case gemini
            echo "gemini -p"
        case codex
            echo "codex exec resume --last"
        case hermes
            echo "hermes chat -q"
        case copilot
            echo "copilot -p"
        case goose
            echo "goose run -t"
        case amp
            echo "amp -x"
        case aider
            echo "aider --no-auto-commits --message"
        case custom
            echo "$LACY_CUSTOM_TOOL_CMD"
        case '*'
            echo ""
    end
end

# Print the configured tool, or the first installed one from LACY_TOOL_LIST.
function _lacy_detect_tool --description "Return the AI tool to use"
    if test -n "$LACY_ACTIVE_TOOL"; and test "$LACY_ACTIVE_TOOL" != auto
        echo $LACY_ACTIVE_TOOL
        return
    end
    for t in $LACY_TOOL_LIST
        if command -q $t
            echo $t
            return
        end
    end
    return 1
end

function _lacy_print_no_tool --description "Explain that no AI tool is installed"
    set -l red (_lacy_sgr '38;5;196')
    set -l bold (_lacy_sgr 1)
    set -l green (_lacy_sgr '38;5;34')
    set -l dim (_lacy_sgr '38;5;238')
    set -l blue (_lacy_sgr '38;5;75')
    set -l off (_lacy_sgr 0)
    printf '\n%s  No AI tool detected.%s Lacy needs an AI CLI to handle queries.\n\n' "$red" "$off"
    printf '%s  Supported tools:%s\n\n' "$bold" "$off"
    printf '    %s%-12s%s %s\n' "$green" lash "$off" "npm install -g lashcode        (recommended)"
    printf '    %s%-12s%s %s\n' "$dim" claude "$off" "brew install claude"
    printf '    %s%-12s%s %s\n' "$dim" opencode "$off" "brew install opencode"
    printf '    %s%-12s%s %s\n' "$dim" gemini "$off" "brew install gemini"
    printf '    %s%-12s%s %s\n' "$dim" codex "$off" "npm install -g @openai/codex"
    printf '\n  %sThen run:%s  lacy setup\n' "$blue" "$off"
    printf '  %sDocs:%s      https://lacy.sh/docs\n\n' "$blue" "$off"
end

# Send a query to the AI agent. Returns the tool's exit status.
function _lacy_query_agent --description "Route a query to the AI agent"
    set -l query "$argv[1]"
    set -l tool (_lacy_detect_tool)

    if test -z "$tool"
        _lacy_print_no_tool
        return 1
    end

    set -l cmd_str (_lacy_tool_cmd $tool)
    if test -z "$cmd_str"
        if test "$tool" = custom
            echo "Lacy: tool is custom but agent_tools.custom_command is empty." >&2
        else
            echo "Lacy: unknown tool: $tool" >&2
        end
        return 1
    end
    if test "$tool" != custom; and not command -q $tool
        echo "Lacy: $tool is set as your tool but is not installed." >&2
        return 127
    end

    _lacy_log_query $tool "$query"

    printf '\n'
    eval $cmd_str (string escape -- "$query")
    set -l rc $status
    printf '\n'
    return $rc
end

# Append a query to the query log (owner-readable only).
function _lacy_log_query --description "Append query to the Lacy query log"
    set -l tool $argv[1]
    set -l query $argv[2]
    set -l log_dir "$LACY_SHELL_HOME/logs"
    set -l log_file "$log_dir/queries.log"

    mkdir -p "$log_dir" 2>/dev/null
    set -l ts (date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null; or echo unknown)
    set -l escaped_query (string replace -a \n '\\n' -- "$query")
    printf '%s\t%s\t%s\n' "$ts" "$tool" "$escaped_query" >> "$log_file" 2>/dev/null
    chmod 600 "$log_file" 2>/dev/null

    # Rotate if over 1 MB
    if test -f "$log_file"
        set -l size (wc -c < "$log_file" 2>/dev/null; or echo 0)
        if test $size -gt 1048576
            set -l tmp (mktemp)
            tail -n 1000 "$log_file" > $tmp; and command mv $tmp "$log_file" 2>/dev/null
        end
    end
end

# ============================================================================
# Commands
# ============================================================================

function ask --description "Send a query to the AI agent"
    if test (count $argv) -eq 0
        echo "Usage: ask \"your question\"" >&2
        return 2
    end
    _lacy_query_agent (string join ' ' -- $argv)
end

function mode --description "Show or set the Lacy mode: shell, agent, auto"
    switch "$argv[1]"
        case shell s
            _lacy_set_mode shell; and _lacy_print_mode_line
        case agent a
            _lacy_set_mode agent; and _lacy_print_mode_line
        case auto u
            _lacy_set_mode auto; and _lacy_print_mode_line
        case toggle t
            _lacy_next_mode; and _lacy_print_mode_line
        case ''
            _lacy_print_mode_line
            echo "Usage: mode [shell|agent|auto|toggle]"
        case '*'
            echo "Usage: mode [shell|agent|auto|toggle]" >&2
            return 2
    end
end

function quit --description "Leave Lacy Shell; the shell keeps running"
    _lacy_quit
end

function _lacy_quit --description "Turn Lacy Shell off in this session"
    set -l dim (_lacy_sgr '38;5;238')
    set -l off (_lacy_sgr 0)
    printf '\n%sExiting Lacy Shell...%s\n\n' "$dim" "$off"

    _lacy_remove_bindings
    _lacy_restore_right_prompt
    functions -e ask mode quit _lacy_forget_rewrite
    set -e LACY_SHELL_ACTIVE
    set -e _LACY_FISH_LOADED

    # Typing `lacy` with no arguments turns Lacy back on
    set -l plugin "$LACY_SHELL_DIR/lacy.plugin.fish"
    function lacy --inherit-variable plugin --description "Re-enable Lacy Shell, or run the lacy CLI"
        if test (count $argv) -eq 0
            functions -e lacy
            source $plugin
        else
            command lacy $argv
        end
    end
end

# ============================================================================
# Enter
# ============================================================================

# Fish keeps a space-prefixed command in the session history until later, so
# the ` ask '<query>'` rewrite is dropped once it has run. The typed text,
# added with `history append`, stays.
function _lacy_forget_rewrite --on-event fish_postexec --description "Drop the ask rewrite from history"
    set -q _LACY_FISH_REWRITE; or return
    builtin history delete --exact --case-sensitive -- "$_LACY_FISH_REWRITE" 2>/dev/null
    set -e _LACY_FISH_REWRITE
end

function _lacy_accept_line --description "Classify the commandline and route it"
    # Pager (completions) and history search keep Enter's usual meaning
    if commandline --paging-mode; or commandline --search-mode
        commandline -f execute
        return
    end

    set -l buffer (string join \n -- (commandline))
    set -l trimmed (string trim -- "$buffer")
    if test -z "$trimmed"
        commandline -f execute
        return
    end

    # exit always leaves the shell and quit always leaves Lacy, in every mode
    set -l first_word (string match -r -- '^\S+' "$trimmed")
    if contains -- "$first_word" exit quit
        commandline -f execute
        return
    end

    switch (_lacy_classify_input "$buffer")
        case agent
            set -l query "$trimmed"
            if string match -q -- '@*' "$query"
                set query (string trim -l -- (string sub -s 2 -- "$query"))
            end
            set -l cmd "ask "(string escape -- "$query")
            # Save the typed text, not the rewrite. The leading space keeps
            # fish from saving the rewrite too. Fish 3 has no `history append`
            # (`history <word>` searches), so there the rewrite is saved.
            if test "$_LACY_FISH_MAJOR" -ge 4; and builtin history append -- "$buffer" 2>/dev/null
                set cmd " $cmd"
                set -g _LACY_FISH_REWRITE $cmd
            end
            commandline -r -- $cmd
            commandline -f execute
        case shell
            # Emergency bypass: `!cmd` runs cmd. `! cmd` with a space is negation.
            if string match -qr -- '^!\S' "$trimmed"
                set -l lead (math (string length -- "$buffer") - (string length -- (string trim -l -- "$buffer")))
                commandline -C $lead
                commandline -f delete-char
            end
            commandline -f execute
        case '*'
            commandline -f execute
    end
end
