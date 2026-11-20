# Lacy shell: demo storyboard

Demo 1 of recording day 2026-10-11. 60 seconds. Retakeable end to end: nothing publishes, nothing is one-shot. This is the warm-up video and the fallback post if nothing else comes out clean.
Evidence read: README, `lacy doctor` (v1.8.28, all checks pass, active tool lash), git log (v1.8.28 released). Nothing was changed.

## Blocked on

- Nothing. Filmable now.
- Check before record: the terminal prompt must not show the hostname or any tailnet name. Use a short prompt (`%~ ` in zsh is enough).

Length: 1:00 (talk 0:56, 113 words, plus 0:12 of typing and output). DRI: Lacy.

`insanely-great` verdict: SHIP as a 60 second cut. One story: the same prompt sends a line to the shell or to the AI tool, and you can see which before you press Enter. Removed: mode switching, config, the install picker, the context it carries, Bash and fish.

## Package

| | |
|---|---|
| Title candidates | 1. I Made My Shell Answer Questions 2. Type a Command or a Question. Same Prompt. 3. Your Terminal Already Knows Which Lines Are English |
| Picked | 1. A stranger gets it, and it is the one sentence. |
| Thumbnail | Terminal frame grab of two lines: `$ ls` above `? what's the biggest file in here`. Words: SAME PROMPT |
| First five seconds | `ls` runs, then the question is typed and the mark flips from `$` to `?` as the first word lands. No logo, no hello. |

Insider hook that lost, and opens the description: "No model decides where the line goes. A word list does, so it's instant."

## The one sentence

"I made my shell send commands to the shell and questions to my AI tool, from the same prompt."

## Why this cut

- The person: a dev who has claude or codex installed and alt-tabs to it twenty times a day.
- The moment: 10 seconds to decide whether this is a gimmick or something they would install.
- The proof: the mark flipping before Enter, and the failed `make` line being offered to the agent.

## What was removed (and why)

| Cut | Why |
|---|---|
| `mode shell` / `mode agent` / Ctrl+Space | Settings. The default (auto) is the story. |
| Install picker, `tool set` | Nobody configures before they believe it. |
| Context passed to the agent (cwd, branch, last exit code) | True and good, one line in the description. |
| Bash and fish | Said in one breath at the end, not shown. |
| `/new`, `/resume`, `quit` | README material. |
| Face, greeting, logo | Hands and voice only. Start mid-thought. |

## Prep (before hitting record)

1. `cd ~/repo/lacy` (public repo, safe cwd). `clear`.
2. Prompt: short, no hostname. Font 16 to 18. Window about 1200 x 700. Notifications off, Do Not Disturb on.
3. Rehearse the three lines once, off camera, and note what lash answers for "what's the biggest file in here". If it rambles, change the question to "how many files are in lib".
4. Confirm `make sure the tests pass` fails in this directory (no Makefile) and that the gray `@ make sure the tests pass` suggestion appears. If the suggestion does not appear, drop beat 4 and the video is 45 seconds.
5. Read `narration.txt` aloud twice.

## Beat sheet

| Time | Beat | On screen | What you say | Words |
|---|---|---|---|---|
| 0:00 | B01 | Terminal in `~/repo/lacy`. Type `ls`, Enter. Files list. | "This is my shell. I type ls, it runs. Nothing new." | 11 |
| 0:05 | B02 | Type `what's the biggest file in here`. The mark flips from `$` to `?` on the first word. Enter. lash answers. | "Now a question. Same prompt. Watch the mark flip from dollar to question mark as I type. That line went to my AI tool instead of the shell." | 29 |
| 0:18 | B03 | Hold on the answer. | "No model made that call. It checks the first word against a list. ls is a command, what is not. So it's instant, and it never guesses." | 29 |
| 0:28 | B04 | Type `make sure the tests pass`, Enter. make fails. Gray text appears: `@ make sure the tests pass`. Right arrow, Enter. lash takes it. | "Here's the catch. make is a real command, so this runs in the shell, and fails. So it offers the same line to the agent. Right arrow, Enter." | 29 |
| 0:44 | B05 | Type `curl -fsSL https://lacy.sh/install | bash`. Do not run it. Hold. | "Works with claude, codex, opencode, gemini, whatever you have. zsh, bash, fish. One line to install." | 18 |
| 0:52 | B06 | Hold two seconds. Cut to black. | "lacy dot sh." | 3 |

Total 113 words. Fastest beat is B03 at 2.7 words per second.

## Recording rule

Screen first, silent, following the beats. Then voice over it, two or three takes. Pick the take that sounds like talking to a friend. If you would rather talk live, every beat here can be re-run, so just start over.

## Error states

| If this happens | Do this |
|---|---|
| lash takes more than 8 seconds to answer | Keep rolling. Cut the wait in the edit. |
| lash answers something wrong or long | Keep rolling. Say "close enough" in the voice pass, or re-run with the "how many files are in lib" question. |
| The gray suggestion does not appear after make fails | Drop B04. Video is 45 seconds. Do not fake it. |
| Terminal shows a hostname or tailnet name | Stop. Fix the prompt. Start over. |

## Post copy (DRAFT, humanizer before posting)

X: "I got tired of alt-tabbing between my terminal and claude. So my shell sends commands to the shell and questions to the AI tool, from one prompt. It decides by the first word, no model involved, so it's instant. curl -fsSL https://lacy.sh/install | bash"

LinkedIn: same, plus "zsh, bash and fish. Works with claude, codex, opencode, gemini, or any command you point it at. MIT."

## Demo test

1. Ten seconds: `ls` runs, a question is typed, the mark flips.
2. Removed: modes, config, picker, context, other shells, intro. Listed above.
3. One primary action: install line at the end.
4. Defaults: auto mode, the installed tool. No config shown.
5. States: the failed `make` is the designed error state and it is the best beat.
6. Pacing: nothing held past its words; the lash wait is cut in the edit.
7. Seams: lash's answer style is not Lacy's. The narration names it ("my AI tool").
8. Stage test: a shell that routes English to an agent, shown in three lines. Yes.
9. Evidence: the recording. Until it exists this is a plan.
10. DRI: Lacy.
