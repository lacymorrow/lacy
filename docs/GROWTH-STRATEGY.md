# Lacy Shell — Growth strategy

Last updated: 2026-04-17

## Current state

- Pre-launch prep complete (demo GIFs, README, analytics, videos, all copy)
- Dev.to article drafted and polished
- 5 SEO comparison pages on lacy.sh (vs Warp, ShellGPT, GitHub Copilot CLI, AI Shell, Amazon Q)
- Launch copy ready for HN, Twitter/X, Reddit, Dev.to
- No launch date set yet

## Phase 1: Launch week

**Goal:** First 500 GitHub stars, establish presence on HN and Twitter.

### Day 1 (Tuesday or Wednesday)
- 9am ET: Post Show HN (copy in MARKETING.md)
- 10:30am ET: Post Twitter thread (after HN settles)
- Monitor and respond to every HN comment within 30 min
- Monitor Twitter replies

### Day 2
- Post r/commandline
- Post r/zsh
- Respond to all Day 1 engagement

### Day 3-4
- Publish Dev.to article (docs/articles/)
- Cross-post to Hashnode
- Submit first awesome-list PR (awesome-zsh-plugins)

### Day 5-7
- Submit remaining awesome-list PRs (awesome-cli-apps, awesome-shell, awesome-ai-tools, terminals-are-sexy)
- Compile engagement data and iterate messaging

## Phase 2: SEO and content (weeks 2-4)

**Goal:** Rank for comparison and category search terms.

### Comparison pages (done)
- lacy.sh/vs/warp
- lacy.sh/vs/shell-gpt
- lacy.sh/vs/github-copilot-cli
- lacy.sh/vs/ai-shell
- lacy.sh/vs/amazon-q

### Additional comparison pages to create
- lacy.sh/vs/aider (popular AI coding tool, different category but high search volume)
- lacy.sh/vs/cursor (IDE-based AI — Lacy is terminal-native, different workflow)

### Category pages to create
- lacy.sh/best-ai-terminal-tools (roundup — position Lacy in the space, link to comparison pages)
- lacy.sh/how-it-works (deep technical explainer for the detection algorithm)

### Blog posts for lacy.sh
- "Why I didn't use AI to classify AI input" — technical post about the lexical approach
- "Shell reserved words are trickier than they look" — deep dive on the `do`/`then`/`in` problem
- "The post-execution reroute pattern" — how Lacy catches failed commands with NL arguments

## Phase 3: Community and developer advocacy (weeks 4-8)

**Goal:** Build a contributor community and get organic mentions.

### Actions
- Open "good first issue" labels on GitHub for easy contributions
- Create a CONTRIBUTING.md with clear guidelines
- Respond to every GitHub issue within 24 hours
- Share interesting edge cases on Twitter (the detection boundary is inherently interesting)
- Write about Lacy in the context of other projects (shell scripting tips, ZSH plugin development)
- Engage in r/commandline, r/zsh, r/neovim discussions where Lacy is relevant (don't spam — only when genuinely useful)

### Conference and meetup talks
- Submit CFP to terminal/DevTools meetups (ShellCon, local DevTools meetups)
- Record a 5-minute lightning talk version for async submission

## Phase 4: Product Hunt and broader press (weeks 8-12)

**Goal:** Product Hunt launch, dev newsletter features.

### Product Hunt prep
- Maker profile with backstory
- 4-5 screenshots/GIFs showing the indicator, detection, reroute
- Short tagline: "Talk to your shell. Commands run, questions go to AI."
- Hunter outreach: find a hunter with DevTools audience (2-3 weeks before launch)
- Schedule for Tuesday, midnight PT

### Newsletter and press outreach
- Changelog (changelog.com) — submit
- Console.dev — submit
- TLDR Newsletter — submit
- Hacker Newsletter — submit (if HN post does well, this may happen automatically)
- Dev.to trending — aim for front page with the article

## Metrics to track

| Metric | Tool | Target (90 days) |
|--------|------|-------------------|
| GitHub stars | GitHub | 1,000+ |
| npm weekly downloads | npm | 500+ |
| Homebrew installs | brew analytics | 200+ |
| lacy.sh monthly visitors | Plausible/Umami | 5,000+ |
| Comparison page organic traffic | Plausible/Umami | 1,000+ visits/month |
| Twitter followers (project account) | Twitter | 500+ |
| GitHub issues (engagement proxy) | GitHub | 50+ |

## Ongoing cadence

- Weekly: Share one interesting edge case or detection improvement on Twitter
- Biweekly: Publish a blog post or technical writeup
- Monthly: Review analytics, adjust comparison page copy for ranking
- Per release: Tweet the changelog with a short "what's new" summary

## Content pillars

1. **The detection problem** — the boundary between command and question is fascinating. Lean into it. Share edge cases, tricky inputs, surprising classifications.
2. **Tool-agnostic philosophy** — Lacy doesn't compete with Claude Code or Gemini. It makes them better. This is the positioning.
3. **Terminal culture** — engage with the shell/terminal community genuinely. Lacy is a shell plugin first. The AI routing is the feature, but the audience is terminal users.
4. **Open source transparency** — share the decision-making, the tradeoffs, the bugs. Devs trust projects that show their work.
