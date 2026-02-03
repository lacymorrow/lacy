# lacymorrow Style Guide

Style reference for all open-source repositories under [github.com/lacymorrow](https://github.com/lacymorrow). Pass this document to anyone working on a repo, README, website, or social asset.

---

## Voice

**Short, direct, declarative.** Write like a man page, not a blog post. Lead with what it does, not what it is. No exclamation marks. No "easily" or "simply" or "just works." No emoji unless the project literally involves emoji.

- Good: "Talk to your shell."
- Bad: "An amazing AI-powered shell plugin that lets you easily interact with your terminal using natural language!"

One-liner descriptions follow the pattern: **verb + object + differentiator.**

```
Talk to your shell.                          (lacy)
AI coding agent for the terminal.            (lash)
Graceful degradation for missing images.     (crosshatch)
```

## README Structure

Every repo README follows the same skeleton. Omit sections that don't apply, but keep the order.

```
# Project Name                    ← plain name, no tagline in the heading
                                  ← one-sentence description
                                  ← hero image (if available)

## Install                        ← primary method first, others in <details>
## How It Works / Usage           ← the meat — images, tables, code
## API / Commands / Options       ← reference material
## Configuration                  ← if applicable
## Uninstall                      ← if applicable (CLI tools)
## Troubleshooting                ← inline, not a separate doc
## License                        ← one line
```

### Rules

- **No badges.** No build status, npm version, download count, or coverage badges. They add noise and age poorly.
- **No "Table of Contents" section.** GitHub generates one. Don't duplicate it.
- **No "Contributing" section in the README.** Use CONTRIBUTING.md if needed.
- **No "Acknowledgements" or "Credits" sections.** Use package.json or a separate file.
- **Images over colored text.** GitHub markdown can't render colored text. Use generated images (dark background, monospaced font, accent colors) for anything that needs color.
- **`<details>` for secondary content.** Alternative install methods, full API reference, verbose config examples — collapse them.
- **Tables for structured data.** Commands, options, comparisons. Left-aligned, no unnecessary columns.
- **One install command above the fold.** The most common method, in a bash code block, before anything else. No prose before the install block.

### Image Guidelines

When generating images for READMEs (via Gemini, Midjourney, or any tool):

- **Background:** `#09090b` (near-black, matches GitHub dark mode)
- **Text:** Monospaced, white (`#fafafa`) for primary, gray (`#a1a1aa`) for secondary
- **Accent colors:** Use the palette below — small, precise doses only
- **No window chrome.** No title bars, no traffic light dots, no drop shadows
- **No rounded corners** on containers or cards
- **Width:** Generate at 2x resolution, display at `width="680"` max in markdown
- **Centered:** Wrap in `<p align="center"><img ... /></p>`

## Color Palette

Six grays and four accents. Use these exact values everywhere.

### Grays (Zinc scale)

| Token | Hex | Use |
|-------|-----|-----|
| black | `#09090b` | Page/card backgrounds |
| surface | `#111113` | Raised surfaces, code blocks |
| raised | `#19191d` | Active states |
| line | `#27272a` | Borders, dividers |
| line-dim | `#1c1c1f` | Subtle dividers |
| fg | `#fafafa` | Primary text |
| fg-2 | `#a1a1aa` | Secondary text, descriptions |
| fg-3 | `#52525b` | Tertiary text, labels, muted |
| fg-4 | `#3f3f46` | Metadata, prompts |

### Accents

| Token | Hex | Use |
|-------|-----|-----|
| green | `#4ade80` | Success, shell, active |
| magenta | `#d946ef` | Agent, AI, attention |
| violet | `#a78bfa` | Brand accent, links, highlights |
| blue | `#60a5fa` | Info, auto mode |

**Rules:**
- Colors appear at full saturation in small doses — dots, bars, single words. Never as backgrounds.
- Background tinting uses 8% opacity max: `rgba(74,222,128,0.08)`
- No gradients. No glows. No shadows with color.

## Typography

### Websites

| Role | Font | Weight |
|------|------|--------|
| Display headings | Instrument Serif | 400 regular, 400 italic |
| Everything else | DM Mono | 300, 400, 500 |

```
https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=DM+Mono:wght@300;400;500&display=swap
```

- Mono is the default voice. Serif is rare — headings and CTAs only.
- No sans-serif anywhere.
- Body text: 13–14px. Headings: let the size do the work, never bold (weight 400).
- The italic serif word in a heading carries the violet accent color.

### READMEs and Markdown

GitHub renders markdown in its own fonts, so typography control is limited. Compensate with structure:

- Use `##` headings, not `###` or deeper. Two levels of hierarchy is enough.
- Use code blocks (`bash`, `yaml`, etc.) aggressively. They're the closest thing to the mono aesthetic.
- Use tables instead of bullet lists when data has structure.
- Bold (`**text**`) sparingly — for the first mention of a key term, not for emphasis.

## Website Layout

- Max width: **680px**. Narrow, document-like.
- Padding: **24px** horizontal.
- Left-aligned by default. Only closing CTAs are centered.
- Sections separated by `1px solid #1c1c1f` horizontal rules.
- Section padding: **80px** vertical.
- No border-radius on structural elements. Sharp corners everywhere.
- Single responsive breakpoint at **640px**.

## Components

### Install block

Tabbed interface (curl / brew / npx / git). Flat border, `#111113` background. Tabs separated by 1px borders, not floating pills. Active tab: `#19191d` background. Code uses syntax coloring: commands in `#a1a1aa`, URLs in `#a78bfa`, flags in `#52525b`.

### Indicator bars

The defining visual motif across all properties. 3px wide, 14–20px tall, 1px border-radius. Color maps to function (green=shell, magenta=agent, violet=brand). They appear in navs, demo lines, and mode cells.

### Data rows

Simple grid with colored dot, name, description, and optional note. Separated by `#1c1c1f` bottom borders. No hover effects.

### Section labels

11px, uppercase, 0.12em letter-spacing, `#52525b` color. Every section starts with one. Examples: "install", "how it works", "supported tools".

## GitHub Repository Settings

### Topics

Use lowercase, hyphenated terms. Lead with what users search for, not implementation details.

```
ai ai-agent ai-terminal cli developer-tools terminal open-source
```

Add project-specific topics after the common ones. Don't list languages or frameworks as topics unless the project is specifically about that language.

### Description

Same one-liner from the README. No period at the end. No emoji.

### Social Preview

If creating a social preview image (1280x640):

- Background: `#09090b`
- Project name in Instrument Serif italic, large, centered
- One-line description in DM Mono below, `#a1a1aa`
- Violet (`#a78bfa`) accent on a keyword or indicator bar
- No logos, no avatars, no screenshots

## Anti-Patterns

Do not use any of the following in websites, READMEs, or assets:

- Gradient text or gradient backgrounds
- Rounded pill shapes (buttons, badges, tabs)
- Card hover effects (scale, glow, border color change)
- Ambient/radial background blobs
- Fake terminal windows with macOS traffic light dots
- Icon grids with colored icon backgrounds
- "Get started" / "Learn more" pill buttons
- Badge rows at the top of READMEs (build passing, npm version, etc.)
- Sans-serif fonts on websites
- Centered section headers with centered subtext
- Decorative SVG icons
- Any element wider than 680px on websites
- Emoji in headings or descriptions
- Exclamation marks in copy

## Applying to a New Repo

1. Write the one-liner description
2. Structure the README using the skeleton above
3. Generate images if the project has visual concepts (use the image guidelines)
4. Set GitHub topics and description
5. If the project has a website, use the typography + color palette + layout rules from this document
6. Reference `STYLE.md` in any contributor-facing docs
