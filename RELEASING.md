# Releasing Lacy Shell

One command. [shipx](https://github.com/lacymorrow/shipx) runs the whole pipeline from `shipx.config.ts`.

## Prerequisites

```bash
npm whoami          # lacymorrow
gh auth status      # authenticated, repo scope
ls ../homebrew-tap  # sibling checkout of lacymorrow/homebrew-tap on main
```

Have your npm authenticator ready. `npm publish` asks for a one-time password, and shipx retries in a loop if it fails.

## Release

From a clean tree on `main`:

```bash
bun run release            # prompts for patch / minor / major
bun run release patch      # 1.8.21 -> 1.8.22
bun run release minor      # 1.8.21 -> 1.9.0
bun run release 2.0.0      # explicit
bun run release:beta       # 1.8.22-beta.0, npm tag beta, Homebrew skipped
bun run release -- --dry-run   # print every step, change nothing
```

What runs, in order:

1. **Preflight.** Refuses a dirty tree or a branch other than `main`.
2. **Tests.** The `test` script in package.json: core, query-agent, and preheat suites in bash and zsh. A failure stops the release.
3. **Bump.** `package.json`, `packages/lacy/package.json`, `bin/lacy` (`VERSION_FALLBACK`), and the two root `version` keys in `packages/lacy/package-lock.json`.
4. **Changelog** from commit subjects since the last tag.
5. **Commit and tag** as `release: vX.Y.Z` / `vX.Y.Z`.
6. **Push.** If the push fails, shipx rolls back the local commit and tag.
7. **GitHub release.** Notes are passed as an argument, never through a shell, so commit subjects cannot inject.
8. **npm publish** from `packages/lacy`, public access.
9. **Homebrew.** Downloads the tag tarball with `curl -f`, writes the sha into `../homebrew-tap/Formula/lacy.rb`, commits, pushes.

## After the release

`CHANGELOG.md` is not updated automatically. Add a section at the top if the release is worth a human summary; the GitHub release already has the commit list.

The website (lacy.sh) is a separate repo and only needs a change when install instructions or features change:

```bash
gh repo clone lacymorrow/lacy-sh /tmp/lacy-sh 2>/dev/null || git -C /tmp/lacy-sh pull
```

## Verify

```bash
gh release view vX.Y.Z
npm view lacy version
brew update && brew info lacymorrow/tap/lacy
lacy update && lacy version
```

## Channels

| Channel | What updates | How |
|---|---|---|
| GitHub | release + tag | shipx step 7 |
| npm | `lacy` package | shipx step 8 |
| Homebrew | `lacymorrow/tap/lacy` | shipx step 9 |
| curl install | `install.sh` | clones git main, nothing to do |
| Website | lacy.sh | push to `lacy-sh`, Vercel deploys |

## Troubleshooting

| Problem | Fix |
|---|---|
| Preflight: dirty tree | Commit or stash. Do not use `--any-branch` on a stable release. |
| Tests fail | Fix them. `--no-tests` exists for emergencies only. |
| npm OTP expired | Codes last about 30 s. Enter a fresh one at the retry prompt. |
| npm asks for browser auth | Complete the link it prints, then choose retry. |
| Push rejected | shipx rolled back locally. `git pull --rebase origin main` and run again. |
| Homebrew step failed after npm published | Do not rerun shipx; that would bump again. Finish by hand in `../homebrew-tap`: `curl -fsSL <tag tarball> \| shasum -a 256`, put the sha and URL in `Formula/lacy.rb`, commit, push. |
| Version drift between files | Run `bun run release -- --dry-run` and check the bump list; all four files must show the same version. |
