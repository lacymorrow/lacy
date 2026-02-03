# Releasing Lacy Shell

Step-by-step process for publishing a new version across all distribution channels.

## Prerequisites

Before you start, verify:

```bash
npm whoami          # Must be logged in as lacymorrow
gh auth status      # Must be authenticated with repo + workflow scopes
```

You need push access to:
- `lacymorrow/lacy-shell` (main repo)
- `lacymorrow/homebrew-tap` (Homebrew formula)
- `lacymorrow/lacy-sh` (website — only if updating)

Have your npm 2FA authenticator ready — you'll need a one-time password for `npm publish`.

## Copy-Paste Release Script

Set your version and run each block in order. The entire process takes under 2 minutes.

```bash
# ── Set version ──────────────────────────────────────────────
VERSION="1.3.0"  # ← Change this
```

### 1. Bump versions

Both `package.json` files must stay in sync:

```bash
npm version $VERSION --no-git-tag-version
cd packages/lacy-sh && npm version $VERSION --no-git-tag-version && cd ../..
```

Then update `CHANGELOG.md` — add a section at the top:

```markdown
## [x.y.z] - YYYY-MM-DD

### Added
- ...

### Fixed
- ...
```

### 2. Commit and push

```bash
git add package.json packages/lacy-sh/package.json packages/lacy-sh/package-lock.json CHANGELOG.md
git commit -m "release: v$VERSION"
git push origin main
```

### 3. Create GitHub release

This creates the git tag. Homebrew depends on it.

```bash
gh release create "v$VERSION" \
  --title "v$VERSION" \
  --notes "See CHANGELOG.md for details." \
  --target main
```

### 4. Publish to npm

```bash
cd packages/lacy-sh
npm publish --otp=YOUR_OTP_CODE
cd ../..
```

Verify: `npm view lacy-sh version` → should print the new version.

### 5. Update Homebrew tap

Get the SHA of the release tarball, then update the formula:

```bash
# Get SHA
SHA=$(curl -sL "https://github.com/lacymorrow/lacy-shell/archive/refs/tags/v$VERSION.tar.gz" | shasum -a 256 | cut -d' ' -f1)
echo "SHA: $SHA"

# Clone/update tap
gh repo clone lacymorrow/homebrew-tap /tmp/homebrew-tap 2>/dev/null || git -C /tmp/homebrew-tap pull

# Update formula (url + sha256)
sed -i '' "s|url \".*\"|url \"https://github.com/lacymorrow/lacy-shell/archive/refs/tags/v$VERSION.tar.gz\"|" /tmp/homebrew-tap/Formula/lacy.rb
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA\"|" /tmp/homebrew-tap/Formula/lacy.rb

# Push
cd /tmp/homebrew-tap
git add Formula/lacy.rb
git commit -m "lacy: update to v$VERSION"
git push origin main
cd -
```

### 6. Update the website (if needed)

Only required when install instructions, features, or docs change. The site auto-deploys on push.

```bash
gh repo clone lacymorrow/lacy-sh /tmp/lacy-sh 2>/dev/null || git -C /tmp/lacy-sh pull
# Make changes, then:
cd /tmp/lacy-sh && git add . && git commit -m "update for v$VERSION" && git push origin main && cd -
```

### 7. Verify

```bash
gh release view "v$VERSION"                    # GitHub release exists
npm view lacy-sh version                       # npm shows new version
brew update && brew info lacymorrow/tap/lacy   # Homebrew shows new version
```

## Quick Reference

```
bump versions → commit & push → gh release → npm publish → update homebrew tap → verify
```

## Channels

| Channel | What gets updated | Trigger |
|---------|-------------------|---------|
| GitHub | Release + tag | `gh release create` |
| npm | `lacy-sh` package | `npm publish` in `packages/lacy-sh` |
| Homebrew | `lacymorrow/tap/lacy` formula | Push to `homebrew-tap` repo |
| curl install | `install.sh` | Pulls from git main (automatic) |
| Website | lacy.sh | Push to `lacy-sh` repo (Vercel auto-deploy) |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `npm publish` OTP expired | TOTP codes last ~30s. Get a fresh code and retry. |
| `npm publish` permission denied | Run `npm whoami` — must be `lacymorrow`. |
| Homebrew still shows old version | Run `brew update` to fetch the new tap index. |
| GitHub release tarball 404 | Wait a few seconds after `gh release create` for the tarball to generate. |
| SHA mismatch after Homebrew update | Re-fetch: `curl -sL "...tar.gz" \| shasum -a 256` and update formula. |
| Version mismatch between package.json files | Both root and `packages/lacy-sh/package.json` must match. |
