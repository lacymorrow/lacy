## Shell natural language detection

Route natural language input away from the shell and toward the agent.

---

### Summary

Users sometimes type natural language where the first word happens to be a valid command or shell keyword. Lacy handles this with three pieces:

1. A pre-execution filter: shell reserved words and common English words route to the agent before the shell sees them.
2. Shell-syntax rules that keep real one-liners (paths, redirects, env assignments) in the shell.
3. A reroute suggestion: a command with natural-language arguments that fails is offered to the agent with an `@` prefix. It is never sent automatically.

This spec is shared by lash (opencode) and Lacy Shell. The algorithm is pure string matching with no dependencies.

In Lacy Shell every list below lives in `lib/core/constants.sh`. The fish adapter carries generated copies in `lib/fish/`, rewritten by `script/sync-word-lists.sh` (CI runs it with `--check`). Counts in this document match the code as of this version.

---

### Prefixes

Checked first, in every mode:

- `!` forces the shell. Glued (`!rm -rf x`) the `!` is stripped before execution. With a space (`! true`) it is the shell's own negation and is left intact.
- `@` forces the agent. The `@` and any whitespace after it are stripped before the query is sent.

---

### Layer 1: Filter reserved words before execution

Shell reserved words like `do`, `done`, `then`, `else` are recognized by `command -v` (exit 0) but are never valid as standalone invocations. They only make sense inside compound constructs (`if/then/fi`, `for/do/done`, etc.).

When the first token is a reserved word, skip the `command -v` check and route to the agent.

`LACY_SHELL_RESERVED_WORDS` (11 entries):

```
do  done  then  else  elif  fi  esac  in  select  }  !
```

`if`, `for`, `while`, `until`, `case`, and `time` are excluded because they start real commands or have standalone uses.

`function`, `coproc`, `{`, and `[[` are also excluded: each opens a real one-liner that people type at the prompt (`function f() { :; }`, `coproc cat`, `{ ls; } > out`, `[[ -f x ]] && echo yes`). `{` and `[[` are also caught by the shell-syntax first-token rule below.

Examples caught by this layer:

- `do We already have an easy way to uninstall lacy?`
- `in the codebase where is the auth module?`
- `then what should I do next?`

---

### Shell-syntax first tokens

Some first tokens are shell syntax no matter what follows, and the shell should get them even when the target does not exist (it will print the error). Before any word-list lookup, route to shell when the first token:

- contains `/` (`./run.sh`, `~/bin/x`, `/usr/bin/x`)
- starts with `\` (alias bypass: `\ls -la`)
- starts with `(`, `{`, or `[[` (subshell, group, test)
- starts with `<` or `>`, or matches `[0-9]>` / `&>` (redirect-first: `< file cat`, `> out ls`, `2>/dev/null ls`)

Related first-token rules:

- A leading `#` is a comment line: shell.
- An unterminated quote (`"unterminated`) is treated as a plain token running to the next whitespace, so a single such token is shell.
- Only the first line of a multi-line buffer is classified, and words split on any whitespace (tab, newline), not just space.

---

### Agent words

`LACY_AGENT_WORDS` (209 entries): affirmations, negations, thanks, reactions, greetings, question words (`what`, `why`, `how`, `can`, `should`, ...), and conversational verbs (`explain`, `refactor`, `debug`, ...). When the first word is one of these, the input routes to the agent, even as a single word, with these exceptions:

- A single word that is a user alias or shell function routes to the shell. Builtins and external commands do not get this pass. With `alias stop='kill -STOP'`, `stop` is shell; without it, agent.
- If the word is also a valid command and the arguments look like shell syntax, route to shell: any operator (`|`, `&&`, `||`, `;`, `>`), no bare-word arguments (`which -a git`), or exactly one bare word that is not a natural language marker (`which python`).

Otherwise (`which version should I install`, `nice work`, `yes lets go`) the input goes to the agent.

---

### Inline environment variable assignments

Shell syntax like `VAR=value command args` prepends environment variables to a command. The first token (`VAR=value`) is not a command and fails `command -v`, but the input is shell syntax, not natural language.

When the first token contains `=`, skip past all `VAR=value` tokens to find the actual command. If that command passes `command -v`, route to shell. Two shortcuts while skipping: a right-hand side that starts with a quote or `$(` is shell (the whitespace split cannot follow it), and an assignment followed by an operator (`&&`, `||`, `;`, `|`, `&`) is shell. If no valid command follows, fall through to the multi-word rule.

Examples:

- `RUST_LOG=debug cargo run`: `cargo` is valid, shell
- `FOO=bar BAZ=qux node index.js`: skip both assignments, `node` is valid, shell
- `CC=gcc make -j4`: `make` is valid, shell
- `FOO="a b" ls`: quoted right-hand side, shell
- `x=$(ls) && echo hi`: `$(` right-hand side, shell
- `FOO=1 && ls`: operator after assignment, shell
- `FOO=bar unknown_thing here`: `unknown_thing` is not valid, falls through to agent

---

### Remaining rules

- First word is a valid command: shell.
- Single word that is not a command: shell (a typo; let the shell report it), unless it holds an odd
  number of apostrophes (`what's`, `don't`, `let's`). Those go to the agent: the shell would read the
  apostrophe as an open quote and answer with a continuation prompt. A double quote is left alone,
  since that is usually deliberate shell quoting.
- Multiple words and the first is not a command: agent.

---

### Trailing punctuation

Trailing punctuation (`?`, `!`, `.`, `,`, `;`, `:`) is stripped from the first word before matching against agent words and reserved words, so `why?` routes like `why` and `do?` matches `do`.

Punctuation is only stripped for word-list lookups. The original token is still used for `command -v`, so real commands are unaffected.

---

### Reroute suggestion

A line that passed the rules above as a valid command can still be natural language (`make sure the tests pass`). Lacy lets the shell run it, then offers it to the agent if it fails.

**Candidate.** In auto mode only, a shell line is a reroute candidate when `lacy_shell_has_nl_markers` is true:

- the input has more than one word and contains no shell operator (`|`, `&&`, `||`, `;`, `>`)
- at least one bare word after the first word (not a flag, path, number, or `$variable`) is in `LACY_NL_MARKERS`

**Trigger.** The candidate exits with a code from 1 to 127. Success, and exit codes 128 and above (signals, Ctrl+C), do nothing.

**What the user sees.**

- zsh: `@ <command>` appears as gray ghost text on the next empty prompt. Right arrow or Tab puts it on the command line; Enter then sends it to the agent. Typing anything else, or Enter on the empty line, dismisses it.
- Bash: a hint line `? @ <command>` is printed above the next prompt. The user types it to send it.
- fish: no suggestion.

Nothing is sent to the agent automatically, and the suggestion never appears in shell mode or agent mode.

Examples:

| Input                                | Candidate | Result                                          |
| ------------------------------------ | --------- | ----------------------------------------------- |
| `kill the process on localhost:3000` | yes       | fails, suggestion offered                       |
| `make sure the tests pass`           | yes       | `No rule to make target 'sure'`, suggestion     |
| `go ahead and fix the tests`         | yes       | `unknown command`, suggestion                   |
| `kill -9 my baby`                    | yes       | suggestion only if `kill` fails                 |
| `echo the quick brown fox`           | yes       | succeeds, nothing                               |
| `git push origin main`               | no        | no marker words                                 |
| `echo hello \| grep the`             | no        | contains an operator                            |

---

### Natural language markers

`LACY_NL_MARKERS` (315 entries, 313 distinct; `her` and `however` appear twice): common English words that are unusual as shell arguments. Categories: articles and determiners, pronouns, prepositions, conjunctions, auxiliary and common verbs, adverbs, question words, quantifiers and other sentence words (`if`, `there`, `sure`, `ahead`, `back`), conversational reactions, indefinite pronouns, and nouns common in developer conversation (`bug`, `error`, `fix`, `file`, `code`, `repo`, `tests`). See `lib/core/constants.sh` for the exact list.

---

### Error patterns and `lacy_shell_detect_natural_language`

`LACY_SHELL_ERROR_PATTERNS` (17 entries, matched case-insensitively):

```
parse error
syntax error
unexpected token
unexpected end of file
command not found
no such file or directory
invalid option
unrecognized option
illegal option
unknown option
no rule to make target
unknown primary or operator
missing argument to
invalid regular expression
is not a git command
unknown command
no such command
```

`lacy_shell_detect_natural_language(input, output, exit_code)` in `lib/core/detection.sh` implements the lash post-execution check. Lacy Shell does not call it from any adapter (the reroute suggestion above uses the marker check and exit code only); it is kept for parity with lash and covered by `tests/test_core.sh`.

```
function detectNaturalLanguage(input, output, exitCode):
  if exitCode == 0 or exitCode == null: return false
  if wordCount(input) < 2: return false
  if not matchesAnyErrorPattern(output): return false

  secondWord = lowercase(words(input)[1])
  if secondWord in NATURAL_LANGUAGE_MARKERS:
    return true

  if wordCount(input) >= 4 and output matches /parse error|syntax error|unexpected token/:
    return true

  return false
```

---

### Reference examples

| Input                                    | First token  | Rule            | Result                                     |
| ---------------------------------------- | ------------ | --------------- | ------------------------------------------ |
| `do We already have a way to uninstall?` | `do`         | reserved word   | agent                                      |
| `in the codebase where is auth?`         | `in`         | reserved word   | agent                                      |
| `why?`                                   | `why?`       | agent word      | agent (`?` stripped)                       |
| `which python`                           | `which`      | agent word      | shell (valid command, one non-marker arg)  |
| `nice work`                              | `nice`       | agent word      | agent (`work` is a marker)                 |
| `stop` (with `alias stop=...`)           | `stop`       | agent word      | shell (user alias)                         |
| `fix the bug`                            | `fix`        | multi-word      | agent (`fix` is not a command)             |
| `make sure the tests pass`               | `make`       | valid command   | shell, then suggestion if it fails         |
| `./nonexistent.sh --flag`                | `./non...`   | shell syntax    | shell (shell reports the error)            |
| `2>/dev/null ls`                         | `2>/dev...`  | shell syntax    | shell                                      |
| `[[ -f x ]] && echo yes`                 | `[[`         | shell syntax    | shell                                      |
| `RUST_LOG=debug cargo run`               | `RUST_LOG=`  | env assignment  | shell                                      |
| `@ make sure the tests pass`             | `@`          | prefix          | agent                                      |
| `!rm -rf node_modules`                   | `!rm`        | prefix          | shell, `!` stripped                        |
| `ls -la`                                 | `ls`         | valid command   | shell                                      |

---

### Implementation in lash (opencode)

| File                                    | Role                                                                      |
| --------------------------------------- | ------------------------------------------------------------------------- |
| `plugin/shell-mode/command-check.ts`    | `SHELL_RESERVED_WORDS`, `AGENT_WORDS`, checked before `command -v`        |
| `plugin/shell-mode/natural-language.ts` | `detectNaturalLanguage()` function                                        |
| `src/session/prompt.ts`                 | Captures exit code, calls `detectNaturalLanguage`, reroutes to agent loop |
| `test/plugin/shell-mode.test.ts`        | Tests for both layers                                                     |

---

### Implementation in Lacy Shell

| File                        | Role                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| `lib/core/constants.sh`     | `LACY_SHELL_RESERVED_WORDS`, `LACY_AGENT_WORDS`, `LACY_NL_MARKERS`, `LACY_SHELL_ERROR_PATTERNS` |
| `lib/core/detection.sh`     | `lacy_shell_classify_input()`, `lacy_shell_has_nl_markers()`, `lacy_shell_detect_natural_language()` |
| `lib/zsh/execute.zsh`       | Reroute candidate in accept-line, ghost text suggestion in `lacy_shell_precmd()`          |
| `lib/bash/execute.bash`     | Reroute candidate in the Enter handler, hint line in `lacy_shell_precmd_bash()`           |
| `lib/fish/detection.fish`   | Classifier port with generated word lists (no reroute)                                  |
| `script/sync-word-lists.sh` | Regenerates the fish lists from `constants.sh`                                          |
| `tests/test_core.sh`        | Classification and marker tests (Bash and zsh)                                          |
| `tests/test_fish.fish`      | Runs the core probe inputs against the fish port                                        |

The word lists in lash and Lacy Shell are maintained separately. Change both when a word moves.
