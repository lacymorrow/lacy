# lacy.sh Design System

Reference for reproducing this visual language across lacy.sh, lash.lacy.sh, and related properties.

## Philosophy

**Terminal-native editorial.** The product lives in a terminal, so the site should feel like one — monospaced type as the dominant voice, extreme restraint, content density over whitespace fluff. Color is functional, not decorative. Every saturated element maps to something real in the product.

No ambient blobs. No gradient buttons. No icon grids. No card hover glows. No pills with pulsing dots. No fake terminal windows with traffic light dots. If a design element doesn't exist in a terminal, question whether it belongs on the page.

## Typography

| Role | Font | Weight | Source |
|------|------|--------|--------|
| Display headings | Instrument Serif | 400 regular, 400 italic | Google Fonts |
| Everything else | DM Mono | 300, 400, 500 | Google Fonts |

```
https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=DM+Mono:wght@300;400;500&display=swap
```

**Rules:**
- Mono is the default. All body text, labels, nav, code, data — everything is DM Mono.
- Serif only appears in section headings (h1, h2) and the closing CTA. It provides contrast through rarity.
- Headings use `font-weight: 400` — never bold. The size does the work.
- The italic serif (`em` inside headings) carries the brand accent color (violet).
- Section labels are 11px, uppercase, 0.12em letter-spacing, `--fg-3` color.
- Body text is 13-14px. Never larger for prose.
- No sans-serif anywhere.

## Color

### Palette

```css
--black:    #09090b;   /* page background */
--surface:  #111113;   /* raised surfaces (install block, mode cells) */
--raised:   #19191d;   /* active tab backgrounds */
--line:     #27272a;   /* borders, dividers */
--line-dim: #1c1c1f;   /* subtle dividers (section rules, nav border) */
--fg:       #fafafa;   /* primary text */
--fg-2:     #a1a1aa;   /* secondary text (descriptions, body) */
--fg-3:     #52525b;   /* tertiary (labels, commands, muted) */
--fg-4:     #3f3f46;   /* quaternary (prompts, metadata) */
```

This is the Zinc scale from Tailwind, shifted dark. The entire grayscale vocabulary comes from six values.

### Accent colors

These map directly to the ANSI 256-color codes used in the ZSH plugin:

```css
--green:    #4ade80;   /* shell indicator (ANSI 34) */
--magenta:  #d946ef;   /* agent indicator (ANSI 200) */
--violet:   #a78bfa;   /* brand accent, code highlights (ANSI 141) */
--blue:     #60a5fa;   /* auto mode (ANSI 75) */
```

**Rules:**
- Green and magenta are reserved for shell/agent distinction. They only appear as indicator bars (3px wide, rounded 1px) and tag badges.
- Violet is the primary brand color. It appears in: code URLs/highlights, the italic heading word, the nav indicator bar, and tool dots.
- Blue is for auto mode only.
- No gradients. No glows. No rgba() color washes on cards. Colors appear at full saturation in small, precise doses.
- Background tinting for tags uses 8% opacity max: `rgba(74,222,128,0.08)` for shell, `rgba(217,70,239,0.08)` for agent.

## Layout

- Max width: **680px**. Narrow, document-like. Not a marketing-width 1200px layout.
- Padding: **24px** horizontal on the wrap container.
- Content is **left-aligned** by default. Only the closing CTA section is centered.
- Sections are separated by `<hr>` elements with `1px solid var(--line-dim)`.
- Section vertical padding: **80px** top and bottom.
- No border-radius on structural elements. Install block, grid cells, mode cells — all sharp corners. The only radius is `1px` on indicator bars.
- Grid gaps use `1px` with background color showing through as dividers (see modes-row).

## Components

### Install block

Flat border, `var(--surface)` background. Tabs are separated by 1px right borders, not floating pills. Active tab gets `var(--raised)` background and `var(--fg)` color. Code inside uses syntax coloring: `.cmd` for commands (fg-2), `.url` for URLs (violet), `.flag` for flags/args (fg-3), `.p` for the prompt character (fg-4, user-select: none).

### Demo lines

Not a fake terminal. Just lines on the page. Each line is a CSS grid: `6px 14px 1fr auto` — a 3px colored bar, a prompt character, the input text, and an optional tag. Output lines span columns 3-end in fg-3.

### Data rows (tools)

Simple grid: `100px 1fr auto`. Separated by `var(--line-dim)` bottom borders. A 4px colored dot before the name. Command in fg-3, notes in fg-4. No hover effects.

### Section labels

Every section starts with a label: 11px, uppercase, 0.12em tracking, fg-3. This is the wayfinding system. Examples: "zsh plugin", "what it looks like", "how it works", "supported tools", "modes".

### Indicator bars

The defining visual motif. 3px wide, 14-20px tall, border-radius 1px. They appear in: the nav brand, demo lines, mode cells. They always correspond to a real indicator color from the product.

## Texture

Subtle SVG noise grain overlay on `body::after`, fixed position, pointer-events none, opacity 0.025. Uses `feTurbulence` with `baseFrequency="0.9"`, 4 octaves, 200px tile size. Just enough to prevent the background from reading as pure digital black.

```css
body::after {
  content: '';
  position: fixed;
  inset: 0;
  z-index: 9999;
  pointer-events: none;
  opacity: 0.025;
  background-image: url("data:image/svg+xml,...");
  background-repeat: repeat;
  background-size: 200px;
}
```

## Motion

Minimal. Page load gets a staggered fade-up on hero elements (0.6s ease, 8px translateY, delays of 0.05s increments). Everything else uses 0.15s transitions on color and border-color. No scale transforms, no parallax, no scroll-triggered animations. `prefers-reduced-motion` disables everything.

## Responsive

Single breakpoint at 640px. Grids collapse to single column. Tool notes column hides. Demo tags hide. Nav links collapse to just "GitHub". The narrow max-width means the page already reads well on tablets without changes.

## Anti-patterns (do not use)

- Gradient text or gradient backgrounds
- Rounded pill shapes (buttons, badges, tabs)
- Card hover effects (scale, glow, border color change)
- Ambient/radial background blobs
- Fake terminal windows with macOS traffic light dots
- Icon grids with colored icon backgrounds
- "Get started" / "Learn more" pill buttons
- Badge pills with pulsing dots ("ZSH Plugin" style)
- Sans-serif fonts anywhere
- Section headers centered with centered subtext beneath
- Decorative SVG icons in feature cards
- Any element wider than 680px

## Applying to other properties

**lash.lacy.sh:** Same system, swap the nav indicator bar to violet (lash brand). Headings can use "lash" in italic serif. Install commands change. Everything else stays.

**Docs/subpages:** Same narrow column, same type system, same color palette. Content pages can use the mono for body text at 14px with 1.7 line-height. Code blocks use `var(--surface)` background with `var(--line)` border, no border-radius.

**Emails/social cards:** Black background (#09090b), Instrument Serif italic for the headline, mono for supporting text, violet for the brand accent.
