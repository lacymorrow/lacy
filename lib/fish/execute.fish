# Lacy Shell — Fish execution routing
#
# Intercepts Enter to route input to either the shell or the AI agent.
# Handles session commands, bypass prefixes, and post-execution reroute.

# ============================================================================
# Tool Resolution
# ============================================================================

function _lacy_tool_cmd --description "Return the command template for a tool"
    switch $argv[1]
        case lash;     echo "lash run -c"
        case claude;   echo "claude -p"
        case opencode; echo "opencode run -c"
        case gemini;   echo "gemini --resume -p"
        case codex;    echo "codex exec resume --last"
        case hermes;   echo "hermes chat -q"
        case copilot;  echo "copilot -p"
        case goose;    echo "goose run -t"
        case amp;      echo "amp -x"
        case aider;    echo "aider --no-auto-commits --message"
        case '*';      echo ""
    end
end

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

# ============================================================================
# Agent Execution
# ============================================================================

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

    _lacy_log_query $tool $query

    printf '\e[38;5;200m  ▌\e[0m %s\n' "$query"
    eval $cmd_str (string escape -- $query)
    printf '\n'
end

# ============================================================================
# Query Logging
# ============================================================================

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
        set -l size (wc -c < "$log_file" 2>/dev/null | string trim; or echo 0)
        if test $size -gt 1048576
            set -l tmp (mktemp)
            tail -n 1000 "$log_file" > $tmp; and mv $tmp "$log_file" 2>/dev/null
        end
    end
end

# ============================================================================
# Accept Line (Enter key handler)
# ============================================================================

function _lacy_accept_line --description "Classify and execute current commandline"
    set -l buffer (commandline)

    # Empty — just execute (prints new prompt)
    if test -z "$buffer"
        commandline -f execute
        return
    end

    set -l trimmed (string trim -- "$buffer")

    # Intercept slash-prefixed session commands
    switch $trimmed
        case '/new' '/reset' '/clear'
            commandline ""
            commandline -f execute
            _lacy_session_new
            return
        case '/resume'
            commandline ""
            commandline -f execute
            _lacy_session_resume
            return
    end

    # Emergency bypass: leading ! — strip and execute directly
    if string match -qr '^\s*!' -- "$buffer"
        set -l stripped (string replace -r '^\s*!' '' -- "$buffer")
        commandline -- "$stripped"
        commandline -f execute
        return
    end

    # Classify input
    set -l route (_lacy_classify_input "$buffer")

    switch $route
        case agent
            # Strip @ agent bypass prefix if present
            set -l agent_input $trimmed
            if string match -qr '^\s*@' -- "$agent_input"
                set agent_input (string replace -r '^\s*@\s*' '' -- "$agent_input")
            end
            commandline ""
            commandline -f execute
            _lacy_query_agent "$agent_input"
        case '*'
            # shell (or neutral) — normal execution
            commandline -f execute
    end
end

# ============================================================================
# Session Management
# ============================================================================

function _lacy_session_new --description "Start a new AI conversation session"
    set -g _LACY_SESSION_ID ""
    printf '\e[38;5;75m  ▌\e[0m New session started\n'
end

function _lacy_session_resume --description "Resume previous AI conversation session"
    printf '\e[38;5;75m  ▌\e[0m Resuming previous session\n'
end

# ============================================================================
# User-Facing Commands (Fish functions available at prompt)
# ============================================================================

function mode --description "Lacy: switch or show current mode"
    switch $argv[1]
        case shell s
            set -g LACY_SHELL_MODE shell
            printf '\n\e[38;5;34m  ▌\e[0m SHELL mode - all commands execute directly\n\n'
        case agent a
            set -g LACY_SHELL_MODE agent
            printf '\n\e[38;5;200m  ▌\e[0m AGENT mode - all input goes to AI\n\n'
        case auto u
            set -g LACY_SHELL_MODE auto
            printf '\n\e[38;5;75m  ▌\e[0m AUTO mode - smart detection\n\n'
        case toggle t
            _lacy_toggle_mode
        case status
            printf '\nCurrent mode: '
            switch $LACY_SHELL_MODE
                case shell; printf '\e[38;5;34mSHELL\e[0m'
                case agent; printf '\e[38;5;200mAGENT\e[0m'
                case auto;  printf '\e[38;5;75mAUTO\e[0m'
            end
            printf '\n\n'
        case '*'
            printf '\nUsage: mode [shell|agent|auto|toggle|status]\n\n'
            printf 'Current: '
            switch $LACY_SHELL_MODE
                case shell; printf '\e[38;5;34mSHELL\e[0m'
                case agent; printf '\e[38;5;200mAGENT\e[0m'
                case auto;  printf '\e[38;5;75mAUTO\e[0m'
            end
            printf '\n\nColors:\n'
            printf '  \e[38;5;34m▌\e[0m Green   = shell command\n'
            printf '  \e[38;5;200m▌\e[0m Magenta = agent query\n\n'
    end
end

function tool --description "Lacy: show or set the active AI tool"
    switch $argv[1]
        case ''
            printf '\n'
            if test "$LACY_ACTIVE_TOOL" = custom
                printf 'Active tool: custom (%s)\n' "$LACY_CUSTOM_TOOL_CMD"
            else if test -z "$LACY_ACTIVE_TOOL"
                set -l detected (_lacy_detect_tool)
                if test -n "$detected"
                    printf 'Active tool: auto-detect (using %s)\n' "$detected"
                else
                    printf 'Active tool: auto-detect (no tools found)\n'
                end
            else
                printf 'Active tool: %s\n' "$LACY_ACTIVE_TOOL"
            end
            printf '\nAvailable tools:\n'
            for t in $LACY_TOOL_LIST
                if command -q $t 2>/dev/null
                    printf '  \e[38;5;34m✓\e[0m %s\n' $t
                else
                    printf '  \e[38;5;238m○\e[0m %s (not installed)\n' $t
                end
            end
            printf '\nUsage: tool set <name>\n       tool set custom "command -flags"\n\n'
        case set
            if test -z "$argv[2]"
                printf 'Usage: tool set <name>\nOptions: lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, custom, auto\n'
                return 1
            end
            if test "$argv[2]" = auto
                set -gx LACY_ACTIVE_TOOL ""
                printf 'Tool set to: auto-detect\n'
            else if test "$argv[2]" = custom
                if test -z "$argv[3]"
                    printf 'Usage: tool set custom "command -flags"\n'
                    return 1
                end
                set -gx LACY_ACTIVE_TOOL custom
                set -gx LACY_CUSTOM_TOOL_CMD "$argv[3]"
                printf 'Tool set to: custom (%s)\n' "$argv[3]"
            else
                set -gx LACY_ACTIVE_TOOL "$argv[2]"
                printf 'Tool set to: %s\n' "$argv[2]"
            end
        case '*'
            printf 'Usage: tool [set <name>]\nOptions: lash, claude, opencode, gemini, codex, hermes, copilot, goose, amp, aider, custom, auto\n'
    end
end

function ask --description "Lacy: send a query directly to the AI agent"
    _lacy_query_agent "$argv"
end

function quit --description "Lacy: exit the shell plugin"
    _lacy_cleanup
end

function stop --description "Lacy: exit the shell plugin"
    _lacy_cleanup
end

# ============================================================================
# Cleanup / Quit
# ============================================================================

function _lacy_cleanup --description "Disable Lacy Shell and restore defaults"
    set --erase LACY_SHELL_ACTIVE
    set -g LACY_SHELL_MODE auto

    printf '\n\e[38;5;238m  Exiting Lacy Shell...\e[0m\n\n'

    # Remove keybindings
    bind --erase \n 2>/dev/null
    bind --erase \r 2>/dev/null
    bind --erase \c@ 2>/dev/null
    bind --erase \e\[32~ 2>/dev/null

    # Remove user-facing command functions
    functions --erase mode 2>/dev/null
    functions --erase tool 2>/dev/null
    functions --erase ask 2>/dev/null
    functions --erase quit 2>/dev/null
    functions --erase stop 2>/dev/null

    # Restore original right prompt if we wrapped it
    if functions -q _lacy_original_right_prompt
        functions -c _lacy_original_right_prompt fish_right_prompt
        functions --erase _lacy_original_right_prompt
    else
        functions --erase fish_right_prompt 2>/dev/null
    end
end
