# Lacy Shell: Fish input classification
#
# Port of lacy_shell_classify_input in lib/core/detection.sh. Keep the two in
# step: tests/test_fish.fish runs the core probe inputs against this file.
# Returns: "shell" | "agent" | "neutral"
#
# The word lists below are copies of lib/core/constants.sh. Edit them there,
# then run script/sync-word-lists.sh (CI runs it with --check).

# BEGIN GENERATED WORD LISTS
# Generated from lib/core/constants.sh. Do not edit by hand.
set -g LACY_AGENT_WORDS \
    'yes' 'yeah' 'yep' 'yup' 'sure' 'ok' 'okay' 'alright' \
    'absolutely' 'definitely' 'certainly' 'indeed' 'correct' 'right' 'exactly' 'perfect' \
    'agreed' 'affirmative' 'totally' 'clearly' 'obviously' 'lgtm' 'roger' 'understood' \
    'acknowledged' 'gotcha' 'no' 'nope' 'nah' 'never' 'wrong' 'disagree' \
    'nay' 'meh' 'thanks' 'thank' 'thx' 'ty' 'cheers' 'appreciated' \
    'kudos' 'congrats' 'bravo' 'great' 'good' 'nice' 'cool' 'awesome' \
    'amazing' 'wonderful' 'brilliant' 'excellent' 'fantastic' 'sweet' 'neat' 'beautiful' \
    'gorgeous' 'impressive' 'incredible' 'outstanding' 'superb' 'marvelous' 'magnificent' 'stellar' \
    'phenomenal' 'terrific' 'splendid' 'fine' 'solid' 'dope' 'sick' 'fire' \
    'lit' 'rad' 'legit' 'noice' 'yay' 'hooray' 'woah' 'hey' \
    'hi' 'hello' 'howdy' 'sup' 'yo' 'bye' 'goodbye' 'cya' \
    'later' 'please' 'sorry' 'pardon' 'hmm' 'huh' 'wow' 'whoa' \
    'oops' 'ugh' 'yikes' 'damn' 'dang' 'shoot' 'welp' 'well' \
    'anyway' 'anyways' 'regardless' 'meanwhile' 'honestly' 'basically' 'literally' 'actually' \
    'really' 'seriously' 'hopefully' 'unfortunately' 'apparently' 'supposedly' 'probably' 'maybe' \
    'perhaps' 'possibly' 'sheesh' 'geez' 'oof' 'ouch' 'bummer' 'duh' \
    'lol' 'haha' 'heh' 'omg' 'wtf' 'idk' 'fyi' 'btw' \
    'imho' 'imo' 'tbh' 'pls' 'plz' 'stop' 'hold' 'pause' \
    'cancel' 'abort' 'skip' 'continue' 'proceed' 'next' 'again' 'redo' \
    'undo' 'retry' 'explain' 'elaborate' 'clarify' 'summarize' 'describe' 'show' \
    'tell' 'suggest' 'recommend' 'consider' 'imagine' 'suppose' 'why' 'how' \
    'what' 'when' 'where' 'who' 'which' 'whom' 'whose' 'can' \
    'could' 'would' 'should' 'will' 'shall' 'may' 'might' 'must' \
    'does' 'did' 'is' 'are' 'was' 'were' 'has' 'have' \
    'had' 'refactor' 'optimize' 'scaffold' 'debug' 'deploy' 'implement' 'migrate' \
    'lint' 'render' 'integrate' 'iterate' 'diagnose' 'troubleshoot' 'hotfix' 'rollback' \
    'revert'

set -g LACY_SHELL_RESERVED_WORDS \
    'do' 'done' 'then' 'else' 'elif' 'fi' 'esac' 'in' \
    'select' '}' '!'

set -g LACY_NL_MARKERS \
    'a' 'an' 'the' 'this' 'that' 'these' 'those' 'my' \
    'our' 'your' 'its' 'their' 'his' 'her' 'i' 'we' \
    'you' 'it' 'they' 'me' 'us' 'him' 'them' 'myself' \
    'yourself' 'itself' 'ourselves' 'themselves' 'to' 'of' 'about' 'with' \
    'from' 'for' 'into' 'through' 'between' 'after' 'before' 'during' \
    'without' 'within' 'against' 'above' 'below' 'under' 'upon' 'across' \
    'toward' 'towards' 'beside' 'besides' 'beyond' 'except' 'inside' 'outside' \
    'behind' 'near' 'among' 'along' 'around' 'and' 'but' 'or' \
    'so' 'because' 'since' 'although' 'though' 'unless' 'while' 'whereas' \
    'whether' 'however' 'therefore' 'moreover' 'furthermore' 'nevertheless' 'otherwise' 'instead' \
    'is' 'are' 'was' 'were' 'be' 'been' 'being' 'have' \
    'has' 'had' 'having' 'can' 'could' 'would' 'should' 'will' \
    'shall' 'may' 'might' 'must' 'need' 'want' 'know' 'think' \
    'believe' 'understand' 'remember' 'forget' 'seem' 'appear' 'look' 'feel' \
    'sound' 'mean' 'try' 'keep' 'let' 'begin' 'start' 'stop' \
    'continue' 'happen' 'work' 'run' 'give' 'take' 'bring' 'send' \
    'put' 'get' 'got' 'went' 'going' 'done' 'doing' 'made' \
    'making' 'not' 'already' 'also' 'just' 'still' 'even' 'really' \
    'actually' 'probably' 'maybe' 'perhaps' 'always' 'never' 'sometimes' 'often' \
    'usually' 'only' 'very' 'too' 'enough' 'quite' 'rather' 'pretty' \
    'almost' 'nearly' 'completely' 'entirely' 'definitely' 'certainly' 'obviously' 'clearly' \
    'honestly' 'basically' 'literally' 'seriously' 'hopefully' 'unfortunately' 'apparently' 'absolutely' \
    'simply' 'merely' 'exactly' 'roughly' 'how' 'what' 'when' 'where' \
    'why' 'who' 'which' 'whom' 'whose' 'if' 'there' 'here' \
    'all' 'any' 'some' 'every' 'no' 'each' 'does' 'do' \
    'did' 'sure' 'out' 'up' 'down' 'ahead' 'back' 'over' \
    'away' 'off' 'on' 'now' 'then' 'again' 'once' 'twice' \
    'first' 'last' 'next' 'new' 'old' 'same' 'other' 'another' \
    'both' 'either' 'neither' 'much' 'many' 'more' 'most' 'less' \
    'least' 'few' 'several' 'own' 'such' 'whole' 'entire' 'please' \
    'thanks' 'thank' 'sorry' 'yes' 'yeah' 'yep' 'ok' 'okay' \
    'alright' 'right' 'correct' 'wrong' 'perfect' 'great' 'good' 'nice' \
    'cool' 'awesome' 'amazing' 'wonderful' 'excellent' 'fantastic' 'brilliant' 'fine' \
    'terrible' 'horrible' 'awful' 'bad' 'worse' 'worst' 'better' 'best' \
    'anyone' 'someone' 'everyone' 'anything' 'something' 'everything' 'nobody' 'nothing' \
    'nowhere' 'wherever' 'whatever' 'whoever' 'whenever' 'way' 'thing' 'things' \
    'stuff' 'part' 'place' 'point' 'fact' 'issue' 'problem' 'question' \
    'answer' 'idea' 'reason' 'example' 'change' 'error' 'bug' 'fix' \
    'feature' 'code' 'file' 'files' 'repo' 'project' 'app' 'test' \
    'tests'

set -g LACY_SHELL_OPERATORS \
    '|' '&&' '||' ';' '>'
# END GENERATED WORD LISTS

# True if the word runs as something: function, builtin or external command.
function _lacy_is_valid_command --description "True if the word is a runnable command"
    test -n "$argv[1]"; and type -q -- "$argv[1]"
end

# Classify a line of input.
# Usage: set result (_lacy_classify_input "some input")
function _lacy_classify_input --description "Classify input as shell/agent/neutral"
    # Multi-line buffers: only the first line drives the decision.
    set -l lines (string split -- \n "$argv[1]")
    set -l input (string trim -- "$lines[1]")

    # Empty input: mode colour in locked modes, neutral in auto
    if test -z "$input"
        switch "$LACY_SHELL_MODE"
            case shell agent
                echo $LACY_SHELL_MODE
            case '*'
                echo neutral
        end
        return
    end

    # Emergency bypass (!) = shell, agent bypass (@) = agent, in every mode
    if string match -q -- '!*' "$input"
        echo shell
        return
    end
    if string match -q -- '@*' "$input"
        echo agent
        return
    end

    # Locked modes
    switch "$LACY_SHELL_MODE"
        case shell agent
            echo $LACY_SHELL_MODE
            return
    end

    # Auto mode from here on.

    # Comment line: let the shell swallow it
    if string match -q -- '#*' "$input"
        echo shell
        return
    end

    # First token, respecting "double quotes", 'single quotes' and
    # backslash-escaped spaces. first_word keeps the quoting; first_word_cmd
    # is the unquoted form used for command lookups. An unterminated quote
    # falls through to the whitespace split.
    set -l first_word
    set -l first_word_cmd
    if set first_word (string match -r -- '^"[^"]*"' "$input")
        set first_word_cmd (string sub -s 2 -e -1 -- "$first_word")
    else if set first_word (string match -r -- "^'[^']*'" "$input")
        set first_word_cmd (string sub -s 2 -e -1 -- "$first_word")
    else
        set first_word (string match -r -- '^(?:\\\\ |\S)+' "$input")
        set first_word_cmd (string replace -a -- '\\ ' ' ' "$first_word")
    end

    # Everything after the first token, leading whitespace removed
    set -l rest (string sub -s (math (string length -- "$first_word") + 1) -- "$input")
    set rest (string trim -l -- "$rest")

    # Path-shaped or redirect-first tokens are shell syntax whether or not the
    # target exists: ./run.sh, ~/bin/x, \ls, (subshell), { group, [[ test,
    # < file, > out, 2>/dev/null, &>log.
    if string match -qr -- '/|^\\\\|^\(|^\{|^\[\[|^<|^>|^[0-9]>|^&>' "$first_word_cmd"
        echo shell
        return
    end

    # Lowercase and strip trailing punctuation for word-list lookups (why? to why)
    set -l stripped (string replace -r -- '[?.,;:!]+$' '' (string lower -- "$first_word_cmd"))

    # Layer 1a: shell reserved words are never standalone commands
    if contains -- "$stripped" $LACY_SHELL_RESERVED_WORDS
        echo agent
        return
    end

    # Layer 1b: common English words go to the agent, except
    #   - a single word the user defined as a function or alias (fish aliases
    #     are functions): `deploy`, `lint`
    #   - a real command whose arguments look like shell: operators present,
    #     or at most one bare argument that is not an NL marker
    #     (`which python`, `yes | head`, but `which version to use` is agent)
    if contains -- "$stripped" $LACY_AGENT_WORDS
        if test -z "$rest"; and functions -q -- "$first_word_cmd"
            echo shell
            return
        end
        if test -n "$rest"; and _lacy_is_valid_command "$first_word_cmd"
            for op in $LACY_SHELL_OPERATORS
                if string match -q -- "*$op*" "$input"
                    echo shell
                    return
                end
            end
            set -l bare_count 0
            set -l bare_word ""
            for tok in (string match -ar -- '\S+' "$rest")
                string match -q -- '-*' "$tok"; and continue
                string match -qr -- '^(/|\./|~/)' "$tok"; and continue
                string match -qr -- '^[0-9]+$' "$tok"; and continue
                string match -q -- '$*' "$tok"; and continue
                set bare_word (string lower -- "$tok")
                set bare_count (math $bare_count + 1)
                test $bare_count -ge 2; and break
            end
            if test $bare_count -eq 0
                echo shell
                return
            end
            if test $bare_count -eq 1; and not contains -- "$bare_word" $LACY_NL_MARKERS
                echo shell
                return
            end
        end
        echo agent
        return
    end

    # Inline env var assignment: VAR=value command args
    if string match -q -- '*=*' "$first_word"
        for w in (string match -ar -- '\S+' "$input")
            if string match -q -- '*=*' "$w"
                # A quoted or $( ) right-hand side is syntax the whitespace
                # split cannot follow: FOO="a b" ls, x=$(ls) && echo
                set -l rhs (string split -m1 -- = "$w")
                if string match -qr -- '^("|\'|\$\()' "$rhs[2]"
                    echo shell
                    return
                end
                continue
            end
            switch "$w"
                case '&&' '||' ';' '|' '&'
                    echo shell
                    return
            end
            if _lacy_is_valid_command "$w"
                echo shell
                return
            end
            break
        end
    end

    if _lacy_is_valid_command "$first_word_cmd"
        echo shell
        return
    end

    # Single unknown word: probably a typo, let the shell report it.
    # Several words with an unknown first word: natural language.
    if test -z "$rest"
        # One word with an odd apostrophe is speech, not a typo: what's,
        # don't, let's. Same rule as lib/core/detection.sh.
        set -l quotes (string replace -a -r -- "[^']" "" "$first_word_cmd")
        if test (math (string length -- "$quotes") % 2) -eq 1
            echo agent
        else
            echo shell
        end
    else
        echo agent
    end
end
