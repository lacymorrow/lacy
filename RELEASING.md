# Releasing Lacy Shell

Step-by-step process for publishing a new version across all distribution channels.

## Prerequisites

- `npm` logged in (`npm whoami`)
- `gh` CLI authenticated (`gh auth status`)
- Push access to `lacymorrow/lacy-shell`, `lacymorrow/homebrew-tap`, and `lacymorrow/lacy-sh`

## Release Checklist

### 1. Bump the version

Update the version in **both** package.json files (keep them in sync):

```bash
# Pick your new version (e.g. 1.2.0)
VERSION="1.2.0"

# Root
cd ~/repo/lacy-shell
npm version $VERSION --no-git-tag-version

# npm package
cd packages/lacy-sh
npm version $VERSION --no-git-tag-version
cd ../..
```

Update `CHANGELOG.md` with the new version and changes.

### 2. Commit and push to GitHub

```bash
git add package.json packages/lacy-sh/package.json CHANGELOG.md
git commit -m "release: v$VERSION"
git push origin main
```

### 3. Create a GitHub release + tag

The Homebrew formula pulls a tarball from a GitHub tag, so this step is required.

```bash
gh release create "v$VERSION" \
  --title "v$VERSION" \
  --notes "See CHANGELOG.md for details." \
  --target main
```

### 4. Publish to npm

```bash
cd packages/lacy-sh
npm publish
cd ../..
```

Verify: `npm view lacy-sh version` should show the new version.

### 5. Update the Homebrew tap

The formula at `lacymorrow/homebrew-tap` points to a tagged tarball. You need to update the URL and SHA.

```bash
# Get the new tarball SHA
curl -sL "https://github.com/lacymorrow/lacy-shell/archive/refs/tags/v$VERSION.tar.gz" | shasum -a 256
```

Then update the formula:

```bash
gh repo clone lacymorrow/homebrew-tap /tmp/homebrew-tap 2>/dev/null || git -C /tmp/homebrew-tap pull
```

Edit `/tmp/homebrew-tap/Formula/lacy.rb`:
- Set `url` to `https://github.com/lacymorrow/lacy-shell/archive/refs/tags/v$VERSION.tar.gz`
- Set `sha256` to the hash from above

```bash
cd /tmp/homebrew-tap
git add Formula/lacy.rb
git commit -m "lacy: update to v$VERSION"
git push origin main
```

Verify: `brew update && brew upgrade lacy`

### 6. Update the website

The website lives at `lacymorrow/lacy-sh` (Next.js, likely deployed on Vercel).

If the release includes changes that affect the website (install instructions, feature announcements, etc.):

```bash
gh repo clone lacymorrow/lacy-sh /tmp/lacy-sh 2>/dev/null || git -C /tmp/lacy-sh pull
# Make your changes, then:
cd /tmp/lacy-sh
git add .
git commit -m "update for v$VERSION"
git push origin main
```

Vercel auto-deploys from main, so pushing is enough.

### 7. Verify all channels

| Channel | How to verify |
|---------|---------------|
| GitHub | `gh release view v$VERSION` |
| npm | `npm view lacy-sh version` |
| Homebrew | `brew info lacymorrow/tap/lacy` |
| curl install | `curl -fsSL https://lacy.sh/install \| bash` (pulls latest from git) |
| Website | Visit https://lacy.sh |

## Quick Reference

```
bump versions  ->  commit & push  ->  gh release  ->  npm publish  ->  update homebrew tap  ->  update website
```
