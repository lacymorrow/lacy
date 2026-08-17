# Lacy Shell — Fish input classification
#
# Ports the core detection logic from lib/core/detection.sh to Fish syntax.
# Returns: "shell" | "agent" | "neutral"

# Agent words: single words that always route to the AI agent.
# Kept in sync with lib/core/constants.sh LACY_AGENT_WORDS.
set -g LACY_AGENT_WORDS \
    yes yeah yep yup sure ok okay alright \
    absolutely definitely certainly indeed correct right exactly \
    perfect agreed affirmative totally clearly obviously lgtm \
    roger understood acknowledged gotcha \
    no nope nah never wrong disagree nay meh \
    thanks thank thx ty cheers appreciated kudos congrats bravo \
    great good nice cool awesome amazing wonderful brilliant \
    excellent fantastic sweet neat beautiful gorgeous impressive \
    incredible outstanding superb marvelous magnificent stellar \
    phenomenal terrific splendid fine solid dope sick fire lit rad legit \
    noice yay hooray woah \
    hey hi hello howdy sup yo bye goodbye cya later \
    please sorry pardon hmm huh wow whoa oops ugh yikes \
    damn dang shoot welp well anyway anyways regardless \
    meanwhile honestly basically literally actually really \
    seriously hopefully unfortunately apparently \
    supposedly probably maybe perhaps possibly \
    sheesh geez oof ouch bummer duh \
    lol haha heh omg wtf idk fyi btw imho imo tbh pls plz \
    stop hold pause cancel abort skip continue proceed \
    next again redo undo retry \
    explain elaborate clarify summarize describe show tell \
    suggest recommend consider imagine suppose \
    why how what when where who which whom whose \
    can could would should will shall may might must \
    does did is are was were has have had \
    refactor optimize scaffold debug deploy implement \
    migrate lint render integrate iterate \
    diagnose troubleshoot hotfix rollback revert

# Shell reserved words that pass `command -v` but are never standalone commands.
set -g LACY_SHELL_RESERVED_WORDS \
    do done then else elif fi esac in select function coproc

# Classify a line of input.
# Usage: set result (_lacy_classify_input "some input")
# Returns: shell | agent | neutral
function _lacy_classify_input --description "Classify input as shell/agent/neutral"
    set -l input $argv[1]

    # Trim leading/trailing whitespace
    set input (string trim -- "$input")

    # Empty input — return mode color signal
    if test -z "$input"
        switch $LACY_SHELL_MODE
            case shell;  echo shell;  return
            case agent;  echo agent;  return
            case '*';    echo neutral; return
        end
    end

    # Emergency bypass: leading !
    if string match -qr '^\!' -- "$input"
        echo shell; return
    end

    # Agent bypass: leading @
    if string match -qr '^@' -- "$input"
        echo agent; return
    end

    # Locked modes
    switch $LACY_SHELL_MODE
        case shell; echo shell; return
        case agent; echo agent; return
    end

    # Auto mode — apply heuristics
    # Split into words
    set -l words (string split ' ' -- "$input")
    set -l word_count (count $words)
    set -l first_word $words[1]
    set -l lower_first (string lower -- "$first_word")

    # Strip trailing punctuation for word-list lookups
    set -l stripped_first (string replace -ra '[?.,;:!]+$' '' -- "$lower_first")

    # Shell reserved words → agent (never valid standalone)
    if contains -- $stripped_first $LACY_SHELL_RESERVED_WORDS
        echo agent; return
    end

    # Agent word check
    if contains -- $stripped_first $LACY_AGENT_WORDS
        # If it's also a valid command, check for shell-like arguments
        if command -q $first_word 2>/dev/null
            # Shell operators → shell
            if string match -qr '[|&;><]' -- "$input"
                echo shell; return
            end
            # Single word or just flags → shell
            if test $word_count -le 1
                echo shell; return
            end
            # Count bare words (skip flags, paths, numbers, variables)
            set -l bare_count 0
            for w in $words[2..-1]
                string match -qr '^-' -- "$w"; and continue
                string match -qr '^[/~.]' -- "$w"; and continue
                string match -qr '^\d+$' -- "$w"; and continue
                string match -qr '^\$' -- "$w"; and continue
                set bare_count (math $bare_count + 1)
            end
            # 0 bare words (flags only) → shell
            if test $bare_count -eq 0
                echo shell; return
            end
            # Exactly 1 bare word → shell (e.g. "which python")
            if test $bare_count -eq 1
                echo shell; return
            end
        end
        echo agent; return
    end

    # Inline env var assignment: VAR=value command args
    if string match -qr '=' -- "$first_word"
        for w in $words[2..-1]
            if not string match -qr '=' -- "$w"
                if command -q $w 2>/dev/null
                    echo shell; return
                end
                break
            end
        end
    end

    # Valid command → shell
    if command -q $first_word 2>/dev/null
        echo shell; return
    end

    # Single unknown word → shell (let it fail naturally — typo)
    if test $word_count -eq 1
        echo shell; return
    end

    # Multi-word, first word not a command → agent (natural language)
    echo agent
end
