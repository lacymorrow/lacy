# UGC Video Generation

Programmatically generated UGC (User-Generated Content) demo videos for Lacy Shell marketing.

## Videos

### V2 (current — enhanced production value)

| File | Duration | Format | Description |
|------|----------|--------|-------------|
| `lacy-shell-demo-v2.mp4` | 28s | 1080x1920 **60fps** H.264 | Full demo — 6 scenes, gradient BG, glow effects, drop shadows |
| `lacy-shell-short-v2.mp4` | 15s | 1080x1920 **60fps** H.264 | Short — hook + demo + CTA, same V2 enhancements |

### V1 (archived)

| File | Duration | Format | Description |
|------|----------|--------|-------------|
| `lacy-shell-demo.mp4` | 27.5s | 1080x1920 30fps H.264 | Full demo — 6 scenes covering all key features |
| `lacy-shell-short.mp4` | 15s | 1080x1920 30fps H.264 | Short version — hook + demo + CTA for TikTok/Reels |

Both formats are vertical (9:16), optimized for TikTok, Instagram Reels, and YouTube Shorts.

## How It Works

Videos are rendered frame-by-frame using Python (Pillow for image generation) and assembled into MP4 with ffmpeg. No external services or accounts needed.

**Pipeline:**
1. Python script generates individual PNG frames with animations (typing, fades, easing, glow compositing)
2. ffmpeg encodes frames into H.264 MP4

## V2 Visual Enhancements

| Feature | Detail |
|---------|--------|
| **60fps** | Doubled frame rate for premium smoothness |
| **Gradient background** | Deep purple-black gradient instead of flat black |
| **Glow/bloom on indicators** | GaussianBlur compositing creates soft halo on green/magenta dots |
| **Drop shadows** | Blurred shadow beneath every terminal window |
| **CRT scan-lines** | Subtle 3px scan-line overlay for retro terminal feel |
| **Variable typing speed** | Eased typing with natural acceleration |
| **Scene fade transitions** | 0.3s fade-in/out at each scene boundary |
| **Progress bar** | Thin colored bar tracks overall video progress |
| **Accessibility captions** | Semi-transparent caption pills explain each scene |
| **Floating particles** | Faint code snippets drift upward in background |
| **Elastic spring animations** | Key text reveals use overshoot easing for punch |
| **Thumbnail export** | Best CTA frame auto-saved as PNG for social previews |

## Prerequisites

```bash
# Python 3.10+ with Pillow
python3 -m venv .venv
.venv/bin/pip install Pillow

# ffmpeg
brew install ffmpeg   # macOS
```

## Generating Videos

### V2 Full Demo (28s, 60fps)

```bash
# Generate frames
.venv/bin/python3 docs/videos/generate_frames_v2.py

# Assemble into MP4
ffmpeg -framerate 60 -i /tmp/ugc-video/frames-v2/frame_%05d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 18 \
  -y docs/videos/lacy-shell-demo-v2.mp4
```

### V2 Short (15s, 60fps)

```bash
# Generate frames
.venv/bin/python3 docs/videos/generate_short_v2.py

# Assemble into MP4
ffmpeg -framerate 60 -i /tmp/ugc-video/frames-short-v2/frame_%05d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 18 \
  -y docs/videos/lacy-shell-short-v2.mp4
```

### Platform-specific exports

```bash
# TikTok/Reels/Shorts — 9:16 native, no extra crop needed
# Use lacy-shell-short-v2.mp4 directly

# Twitter/X — square crop
ffmpeg -i docs/videos/lacy-shell-demo-v2.mp4 \
  -vf 'crop=1080:1080:0:420' \
  -c:v libx264 -pix_fmt yuv420p -crf 20 \
  -y docs/videos/lacy-shell-demo-v2-square.mp4

# Instagram square (short)
ffmpeg -i docs/videos/lacy-shell-short-v2.mp4 \
  -vf 'crop=1080:1080:0:420' \
  -c:v libx264 -pix_fmt yuv420p -crf 20 \
  -y docs/videos/lacy-shell-short-v2-square.mp4
```

### V1 (legacy — 30fps, flat black BG)

```bash
# Full demo (v1)
.venv/bin/python3 docs/videos/generate_frames.py
ffmpeg -framerate 30 -i /tmp/ugc-video/frames/frame_%05d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 18 \
  -y docs/videos/lacy-shell-demo.mp4

# Short (v1)
.venv/bin/python3 docs/videos/generate_short.py
ffmpeg -framerate 30 -i /tmp/ugc-video/frames-short/frame_%05d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 18 \
  -y docs/videos/lacy-shell-short.mp4
```

## Scene Breakdown

### Full Demo (`generate_frames.py`)

| Scene | Duration | Description |
|-------|----------|-------------|
| Hook | 3.5s | "What if your shell understood you?" — word-by-word fade-in |
| Shell Command | 4.5s | `ls -la` with green indicator, file listing output |
| NL Query | 5.5s | "what files are in this project" with magenta indicator, AI response |
| Split Comparison | 5s | "Same word. Different intent." — `install nodejs` (shell) vs `install a way to monitor logs` (agent) |
| Auto-Reroute | 5.5s | "fix the failing tests" — fails in shell, auto-routes to AI |
| CTA | 3.5s | lacy.sh branding, install command, platform features |

### Short Version (`generate_short.py`)

| Scene | Duration | Description |
|-------|----------|-------------|
| Hook | 2s | "Stop copy-pasting into ChatGPT." |
| Demo | 8s | `git status` (green/shell) then "explain what changed and why" (magenta/agent) |
| CTA | 5s | lacy.sh + install command + features |

## Customizing

### Changing text/commands

Edit the scene definitions in the V2 generator scripts. Key areas:

- **`generate_frames_v2.py`**: Each `TerminalTypingScene()` takes `command`, `response_lines`, `label`, `indicator_color`, and `caption`
- **`generate_short_v2.py`**: Scene functions (`scene_hook`, `scene_demo`, `scene_cta`) contain the text inline

### Changing colors

Color constants are at the top of each script:

```python
GREEN = (52, 211, 153)      # Shell indicator
MAGENTA = (216, 100, 240)   # Agent indicator
BLUE = (96, 165, 250)       # Auto mode badge
```

### Changing duration

Adjust `duration_sec` on each scene (full demo) or the duration tuple (short version). Frame count = duration * FPS.

### Changing resolution

Modify `W, H` at the top. Current: `1080, 1920` (9:16 vertical). For landscape: `1920, 1080`.

### Font

Scripts use Menlo (macOS default monospace). Falls back to SF NS Mono or system default. To use a different font, update the `load_font()` function paths.

## Output

| Path | Contents |
|------|----------|
| `/tmp/ugc-video/frames-v2/` | V2 full demo PNG frames |
| `/tmp/ugc-video/frames-short-v2/` | V2 short PNG frames |
| `/tmp/ugc-video/lacy-shell-thumbnail.png` | Full demo CTA thumbnail |
| `/tmp/ugc-video/lacy-shell-short-thumbnail.png` | Short CTA thumbnail |
| `/tmp/ugc-video/frames/` | V1 full demo frames (legacy) |
| `/tmp/ugc-video/frames-short/` | V1 short frames (legacy) |

Final MP4s go to `docs/videos/`.

## Quality Settings

- **CRF 18**: High quality. Lower = better quality, bigger file. Range: 0-51.
- **60fps (V2)**: Premium smoothness for easing animations and glow effects. Use 30fps to halve file size.
- **H.264 + yuv420p**: Maximum compatibility across all platforms and devices.
