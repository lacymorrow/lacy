#!/usr/bin/env bash

# Lacy Shell Constants — shared across Bash 4+ and ZSH
# Sourced by lib/zsh/init.zsh and lib/bash/init.bash

# === Runtime State ===
LACY_SHELL_ENABLED=true
LACY_SHELL_DEFER_QUIT=false

# === Shell Type (set by entry point before sourcing) ===
# LACY_SHELL_TYPE — "zsh" or "bash"
# _LACY_ARR_OFFSET — 1 for ZSH (1-based), 0 for Bash (0-based)

# === Paths ===
: "${LACY_SHELL_HOME:="${HOME}/.lacy"}"

: "${LACY_SHELL_CONFIG_FILE:="${LACY_SHELL_HOME}/config.yaml"}"

: "${LACY_SHELL_MODE_FILE:="${LACY_SHELL_HOME}/current_mode"}"

: "${LACY_SHELL_CONVERSATION_FILE:="${LACY_SHELL_HOME}/conversation.log"}"

: "${LACY_SHELL_MCP_DIR:="${LACY_SHELL_HOME}/mcp"}"

# === Defaults ===
: "${LACY_SHELL_DEFAULT_MODE:="auto"}"

: "${LACY_SHELL_DEFAULT_INDICATOR_STYLE:="top"}"

: "${LACY_SHELL_DEFAULT_CONFIDENCE_THRESHOLD:="0.7"}"

: "${LACY_SHELL_DEFAULT_PROVIDER:="openai"}"

: "${LACY_SHELL_DEFAULT_MODEL:="gpt-4o-mini"}"

# === Timeouts (in milliseconds) ===
: "${LACY_SHELL_EXIT_TIMEOUT_MS:=1000}"

: "${LACY_SHELL_EXIT_TIMEOUT_SEC:="1.0"}"

: "${LACY_SHELL_MESSAGE_DURATION_SEC:="1.0"}"

: "${LACY_SHELL_MCP_TIMEOUT_SEC:=5}"

# === UI ===
: "${LACY_SHELL_TOP_BAR_HEIGHT:=1}"

# === Preheat ===
: "${LACY_PREHEAT_EAGER:="false"}"
: "${LACY_PREHEAT_SERVER_PORT:="4096"}"

# === Colors (256-color palette) ===
LACY_COLOR_SHELL=34        # Green - shell commands
LACY_COLOR_AGENT=200       # Magenta - agent queries
LACY_COLOR_AUTO=75         # Blue - auto mode
LACY_COLOR_NEUTRAL=238     # Dark gray - neutral/dim
LACY_COLOR_SHIMMER=(255 219 213 200 141)  # Spinner shimmer gradient

# === Detection ===
# (LACY_HARD_AGENT_INDICATORS removed — replaced by LACY_AGENT_WORDS below)

# Shell reserved words — pass `command -v` but are never valid standalone commands.
# Used by Layer 1 of natural language detection (see docs/NATURAL_LANGUAGE_DETECTION.md).
LACY_SHELL_RESERVED_WORDS=("do" "done" "then" "else" "elif" "fi" "esac" "in" "select" "function" "coproc" "{" "}" "!" "[[")

# Agent words — common English words that always route to agent, even as
# single-word input. Some (yes, nice, cancel) exist as real commands but are
# almost never typed standalone intentionally.
# Kept in sync with lash plugin/shell-mode/command-check.ts AGENT_WORDS.
LACY_AGENT_WORDS=(
    # affirmations
    "yes" "yeah" "yep" "yup" "sure" "ok" "okay" "alright"
    "absolutely" "definitely" "certainly" "indeed" "correct" "right" "exactly"
    "perfect" "agreed" "affirmative" "totally" "clearly" "obviously" "lgtm"
    # negations
    "no" "nope" "nah" "never" "wrong" "disagree"
    # gratitude
    "thanks" "thank" "thx" "ty" "cheers" "appreciated"
    # reactions
    "great" "good" "nice" "cool" "awesome" "amazing" "wonderful" "brilliant"
    "excellent" "fantastic" "sweet" "neat" "beautiful" "gorgeous" "impressive"
    "incredible" "outstanding" "superb" "marvelous" "magnificent" "stellar"
    "phenomenal" "terrific" "splendid" "fine" "solid" "dope" "sick" "fire" "lit" "rad" "legit"
    # greetings/closings
    "hey" "hi" "hello" "howdy" "sup" "yo" "bye" "goodbye" "cya" "later"
    # conversational
    "please" "sorry" "pardon" "hmm" "huh" "wow" "whoa" "oops" "ugh" "yikes"
    "damn" "dang" "shoot" "welp" "well" "anyway" "anyways" "regardless"
    "meanwhile" "honestly" "basically" "literally" "actually" "really"
    "seriously" "obviously" "hopefully" "unfortunately" "apparently"
    "supposedly" "probably" "maybe" "perhaps" "possibly"
    # action/intent
    "stop" "hold" "pause" "cancel" "abort" "skip" "continue" "proceed"
    "next" "again" "redo" "undo" "retry"
    "explain" "elaborate" "clarify" "summarize" "describe" "show" "tell"
    # question words
    "why" "how" "what" "when" "where" "who" "which"
    "can" "could" "would" "should" "will" "shall" "may" "might" "must"
    "does" "did" "is" "are" "was" "were" "has" "have" "had"
)

# Natural language markers — common English words unusual as shell arguments.
# Used by has_nl_markers (reroute candidates) and Layer 2 detection.
# Kept in sync with lash plugin/shell-mode/natural-language.ts.
LACY_NL_MARKERS=(
    # articles/determiners
    "a" "an" "the" "this" "that" "these" "those" "my" "our" "your" "its" "their" "his" "her"
    # pronouns
    "i" "we" "you" "it" "they" "me" "us" "him" "her" "them"
    "myself" "yourself" "itself" "ourselves" "themselves"
    # prepositions
    "to" "of" "about" "with" "from" "for" "into" "through" "between" "after" "before"
    "during" "without" "within" "against" "above" "below" "under" "upon" "across"
    "toward" "towards" "beside" "besides" "beyond" "except" "inside" "outside"
    "behind" "near" "among" "along" "around"
    # conjunctions
    "and" "but" "or" "so" "because" "since" "although" "though" "unless" "while"
    "whereas" "whether" "however" "therefore" "moreover" "furthermore"
    "nevertheless" "otherwise" "instead"
    # verbs
    "is" "are" "was" "were" "be" "been" "being" "have" "has" "had" "having"
    "can" "could" "would" "should" "will" "shall" "may" "might" "must" "need" "want"
    "know" "think" "believe" "understand" "remember" "forget" "seem" "appear"
    "look" "feel" "sound" "mean" "try" "keep" "let" "begin" "start" "stop"
    "continue" "happen" "work" "run" "give" "take" "bring" "send" "put" "get"
    "got" "went" "going" "done" "doing" "made" "making"
    # adverbs
    "not" "already" "also" "just" "still" "even" "really" "actually" "probably" "maybe"
    "perhaps" "always" "never" "sometimes" "often" "usually" "only" "very" "too"
    "enough" "quite" "rather" "pretty" "almost" "nearly" "completely" "entirely"
    "definitely" "certainly" "obviously" "clearly" "honestly" "basically" "literally"
    "seriously" "hopefully" "unfortunately" "apparently" "absolutely" "simply" "merely"
    "exactly" "roughly"
    # question words
    "how" "what" "when" "where" "why" "who" "which" "whom" "whose"
    # other common sentence words
    "if" "there" "here" "all" "any" "some" "every" "no" "each"
    "does" "do" "did" "sure" "out" "up" "down" "ahead" "back" "over" "away" "off"
    "on" "now" "then" "again" "once" "twice" "first" "last" "next"
    "new" "old" "same" "other" "another" "both" "either" "neither"
    "much" "many" "more" "most" "less" "least" "few" "several" "own" "such" "whole" "entire"
    # conversational/reactions
    "please" "thanks" "thank" "sorry" "yes" "yeah" "yep" "ok" "okay" "alright"
    "right" "correct" "wrong" "perfect" "great" "good" "nice" "cool" "awesome"
    "amazing" "wonderful" "excellent" "fantastic" "brilliant" "fine"
    "terrible" "horrible" "awful" "bad" "worse" "worst" "better" "best"
    # indefinite pronouns
    "anyone" "someone" "everyone" "anything" "something" "everything"
    "nobody" "nothing" "nowhere" "wherever" "whatever" "whoever" "whenever" "however"
    # common nouns used in conversation
    "way" "thing" "things" "stuff" "part" "place" "point" "fact"
    "issue" "problem" "question" "answer" "idea" "reason" "example"
    "change" "error" "bug" "fix" "feature" "code" "file" "files" "repo" "project" "app" "test" "tests"
)

# Error patterns that suggest the shell tried to interpret natural language.
# Case-insensitive matching. Used by Layer 2 detection.
# Kept in sync with lash plugin/shell-mode/natural-language.ts.
LACY_SHELL_ERROR_PATTERNS=(
    "parse error"
    "syntax error"
    "unexpected token"
    "unexpected end of file"
    "command not found"
    "no such file or directory"
    "invalid option"
    "unrecognized option"
    "illegal option"
    "unknown option"
    "no rule to make target"
    "unknown primary or operator"
    "missing argument to"
    "invalid regular expression"
    "is not a git command"
    "unknown command"
    "no such command"
)

LACY_SHELL_OPERATORS=('|' '&&' '||' ';' '>')

# === UI ===
LACY_INDICATOR_CHAR="▌"
LACY_SPINNER_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
: "${LACY_SPINNER_STYLE:="braille"}"
LACY_SPINNER_TEXT='Thinking'

# === Timing (seconds) ===
LACY_SPINNER_FRAME_DELAY=0.05
LACY_TERMINAL_FLUSH_DELAY=0.02
LACY_HEALTH_CHECK_ATTEMPTS=30
LACY_HEALTH_CHECK_INTERVAL=0.1
LACY_SESSION_CREATE_TIMEOUT=10
LACY_SESSION_MESSAGE_TIMEOUT=120

# === Thresholds ===
LACY_SIGNAL_EXIT_THRESHOLD=128  # Exit codes >= this are signal-based

# === API Models (fallback only) ===
LACY_API_MODEL_OPENAI="gpt-4o-mini"
LACY_API_MODEL_ANTHROPIC="claude-3-5-sonnet-20241022"

# === Dangerous Commands ===
LACY_DANGEROUS_PATTERNS=("rm -rf" "sudo rm" "mkfs" "dd if=" ">" "truncate")

# === Performance Optimization: Caching ===
LACY_CONFIG_CACHE_VALID=false
declare -A LACY_CACHED_CONFIG 2>/dev/null || true
: "${LACY_SHELL_CONFIG_CACHE_FILE:="${LACY_SHELL_HOME}/.config_cache"}"

# Async health check cache
LACY_PREHEAT_HEALTH_CACHE=false
LACY_PREHEAT_HEALTH_CHECK_PID=""
: "${LACY_SHELL_HEALTH_CACHE_FILE:="${LACY_SHELL_HOME}/.health_cache"}"

# === Portable Helpers ===

# Print colored text — dispatches to shell-appropriate method
# Usage: lacy_print_color <color_code> <text>
lacy_print_color() {
    local color="$1"
    shift
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        print -P "%F{${color}}$*%f"
    else
        printf '\e[38;5;%dm%s\e[0m\n' "$color" "$*"
    fi
}

# Print colored text without trailing newline
# Usage: lacy_print_color_n <color_code> <text>
lacy_print_color_n() {
    local color="$1"
    shift
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        print -Pn "%F{${color}}$*%f"
    else
        printf '\e[38;5;%dm%s\e[0m' "$color" "$*"
    fi
}

# Check if a value is in a list (portable array membership)
# Usage: _lacy_in_list "value" "item1" "item2" ...
_lacy_in_list() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Portable lowercase — works in Bash 4+, ZSH, and falls back to tr
# Usage: result=$(_lacy_lowercase "STRING")
_lacy_lowercase() {
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        echo "${1:l}"
    elif (( BASH_VERSINFO[0] >= 4 )) 2>/dev/null; then
        echo "${1,,}"
    else
        # Bash 3 fallback (macOS default) — only used in test/core contexts
        echo "$1" | tr '[:upper:]' '[:lower:]'
    fi
}

# Portable pipe status — get exit code of first command in pipeline
# Must be called immediately after a pipeline
# Usage: local exit_code=$(_lacy_pipe_status)
_lacy_pipe_status() {
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        echo "${pipestatus[1]}"
    else
        echo "${PIPESTATUS[0]}"
    fi
}

# Portable job control off/on
_lacy_jobctl_off() {
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        [[ -o monitor ]] && LACY_JOBCTL_WAS_SET=1 || LACY_JOBCTL_WAS_SET=""
        setopt NO_MONITOR 2>/dev/null
    else
        LACY_JOBCTL_WAS_SET=""
        case "$-" in *m*) LACY_JOBCTL_WAS_SET=1 ;; esac
        set +m 2>/dev/null
    fi
}

_lacy_jobctl_on() {
    if [[ -n "$LACY_JOBCTL_WAS_SET" ]]; then
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            setopt MONITOR 2>/dev/null
        else
            set -m 2>/dev/null
        fi
        LACY_JOBCTL_WAS_SET=""
    fi
}
