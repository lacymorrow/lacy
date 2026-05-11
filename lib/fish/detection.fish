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
    no nope nah never wrong disagree \
    thanks thank thx ty cheers appreciated \
    great good nice cool awesome amazing wonderful brilliant \
    excellent fantastic sweet neat beautiful gorgeous impressive \
    incredible outstanding superb marvelous magnificent stellar \
    phenomenal terrific splendid fine solid dope sick fire lit rad legit \
    hey hi hello howdy sup yo bye goodbye cya later \
    please sorry pardon hmm huh wow whoa oops ugh yikes \
    damn dang shoot welp well anyway anyways regardless \
    meanwhile honestly basically literally actually really \
    seriously obviously hopefully unfortunately apparently \
    supposedly probably maybe perhaps possibly \
    stop hold pause cancel abort skip continue proceed \
    next again redo undo retry \
    explain elaborate clarify summarize describe show tell \
    why how what when where who which whom whose \
    can could would should will shall may might must \
    does did is are was were has have had \
    refactor optimize scaffold

# Shell reserved words that pass `command -v` but are never standalone commands.
set -g LACY_SHELL_RESERVED_WORDS \
    do done then else elif fi esac in select function

# Classify a line of input.
# Usage: set result (_lacy_classify_input "some input")
# Returns: shell | agent | neutral
function _lacy_classify_input --description "Classify input as shell/agent/neutral"
    set -l input $argv[1]

    # Empty input — return mode color signal
    if test -z "$input"
        switch $LACY_SHELL_MODE
            case shell;  echo shell;  return
            case agent;  echo agent;  return
            case '*';    echo neutral; return
        end
    end

    # Locked modes
    switch $LACY_SHELL_MODE
        case shell; echo shell; return
        case agent; echo agent; return
    end

    # Emergency bypass: leading !
    if string match -qr '^\!' -- "$input"
        echo shell; return
    end

    # Split on first word
    set -l first_word (string split -m1 ' ' -- (string trim -- "$input") | head -1)
    set -l word_count (string split ' ' -- (string trim -- "$input") | count)

    set -l lower_first (string lower -- "$first_word")

    # Agent word check (single words that always route to agent)
    if contains -- $lower_first $LACY_AGENT_WORDS
        echo agent; return
    end

    # Shell reserved words that look like NL
    if contains -- $lower_first $LACY_SHELL_RESERVED_WORDS
        echo agent; return
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
