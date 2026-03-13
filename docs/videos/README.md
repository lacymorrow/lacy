# UGC Video Generation

Programmatically generated UGC (User-Generated Content) demo videos for Lacy Shell marketing.

## Videos

| File | Duration | Format | Description |
|------|----------|--------|-------------|
| `lacy-shell-demo.mp4` | 27.5s | 1080x1920 30fps H.264 | Full demo — 6 scenes covering all key features |
| `lacy-shell-short.mp4` | 15s | 1080x1920 30fps H.264 | Short version — hook + demo + CTA for TikTok/Reels |

Both are vertical format, optimized for TikTok, Instagram Reels, and YouTube Shorts.

## How It Works

Videos are rendered frame-by-frame using Python (Pillow for image generation) and assembled into MP4 with ffmpeg. No external services or accounts needed.

**Pipeline:**
1. Python script generates individual PNG frames with animations (typing, fades, easing)
2. ffmpeg encodes frames into H.264 MP4

## Prerequisites

```bash
# Python 3.10+ with Pillow
python3 -m venv .venv
.venv/bin/pip install Pillow

# ffmpeg
brew install ffmpeg   # macOS
```

## Generating Videos

### Full Demo (27.5s)

```bash
# Generate frames
.venv/bin/python3 docs/videos/generate_frames.py

# Assemble into MP4
ffmpeg -framerate 30 -i /tmp/ugc-video/frames/frame_%05d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 18 \
  -y docs/videos/lacy-shell-demo.mp4
```

### Short Version (15s)

```bash
# Generate frames
.venv/bin/python3 docs/videos/generate_short.py

# Assemble into MP4
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

Edit the scene definitions in the generator scripts. Key areas:

- **`generate_frames.py`**: Each `TerminalTypingScene()` takes `command`, `response_lines`, `label`, and `indicator_color`
- **`generate_short.py`**: Scene functions (`scene_hook`, `scene_demo`, `scene_cta`) contain the text inline

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

Frames are written to `/tmp/ugc-video/frames/` (full) and `/tmp/ugc-video/frames-short/` (short). Final MP4s go to `docs/videos/`.

## Quality Settings

- **CRF 18**: High quality, small file size (~300KB for 27s). Lower = better quality, bigger file. Range: 0-51.
- **30fps**: Smooth typing animations. Can reduce to 24fps for smaller files.
- **H.264 + yuv420p**: Maximum compatibility across all platforms and devices.
