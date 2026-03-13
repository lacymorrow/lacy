#!/usr/bin/env python3
"""
Generate frames for Lacy Shell UGC demo video.
Produces a vertical (1080x1920) terminal demo video showing:
1. Hook text
2. Shell command (green indicator)
3. Natural language query (magenta indicator)
4. AI response
5. CTA
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

# === Config ===
W, H = 1080, 1920
FPS = 30
OUT_DIR = "/tmp/ugc-video/frames"

# Colors (RGB)
BG = (13, 13, 15)           # Near-black background
TERM_BG = (22, 22, 28)      # Terminal background
TERM_BORDER = (45, 45, 55)  # Terminal window border
WHITE = (235, 235, 240)
GRAY = (130, 130, 145)
DIM = (80, 80, 95)
GREEN = (52, 211, 153)      # Indicator green
MAGENTA = (216, 100, 240)   # Indicator magenta
BLUE = (96, 165, 250)       # Auto mode blue
HOOK_YELLOW = (250, 204, 21)
CTA_GRADIENT_1 = (139, 92, 246)  # Purple
CTA_GRADIENT_2 = (236, 72, 153)  # Pink
CURSOR_COLOR = (235, 235, 240)

# Fonts
def load_font(size, bold=False):
    paths = [
        "/opt/X11/share/system_fonts/Menlo.ttc",
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/SFNSMono.ttf",
    ]
    for p in paths:
        try:
            idx = 1 if bold else 0
            return ImageFont.truetype(p, size, index=idx)
        except:
            try:
                return ImageFont.truetype(p, size)
            except:
                continue
    return ImageFont.load_default()

def load_sans_font(size, bold=False):
    paths = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size, index=2 if bold else 0)
        except:
            try:
                return ImageFont.truetype(p, size)
            except:
                continue
    return load_font(size, bold)

FONT_MONO = load_font(32)
FONT_MONO_SM = load_font(26)
FONT_MONO_BOLD = load_font(34, bold=True)
FONT_HOOK = load_sans_font(64, bold=True)
FONT_HOOK_SM = load_sans_font(48, bold=True)
FONT_CTA = load_sans_font(56, bold=True)
FONT_CTA_SM = load_sans_font(36)
FONT_LABEL = load_sans_font(28)

# === Drawing Helpers ===

def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = xy
    r = radius
    # Use pieslice for corners
    draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
    draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
    draw.pieslice([x0, y0, x0 + 2*r, y0 + 2*r], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*r, y0, x1, y0 + 2*r], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2*r, x0 + 2*r, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2*r, y1 - 2*r, x1, y1], 0, 90, fill=fill)

def draw_indicator(draw, x, y, color, size=14):
    """Draw the colored dot indicator."""
    draw.ellipse([x - size, y - size, x + size, y + size], fill=color)

def draw_cursor(draw, x, y, font, visible=True):
    """Draw blinking cursor block."""
    if visible:
        bbox = font.getbbox("M")
        ch_w = bbox[2] - bbox[0]
        ch_h = bbox[3] - bbox[1]
        draw.rectangle([x, y - 2, x + ch_w, y + ch_h + 2], fill=CURSOR_COLOR)

def draw_terminal_window(draw, y_top, height, title="lacy ~"):
    """Draw a macOS-style terminal window."""
    margin = 50
    x0, y0 = margin, y_top
    x1, y1 = W - margin, y_top + height

    # Window background
    draw_rounded_rect(draw, (x0, y0, x1, y1), 16, fill=TERM_BG)

    # Title bar
    draw_rounded_rect(draw, (x0, y0, x1, y0 + 44), 16, fill=(35, 35, 45))
    draw.rectangle([x0, y0 + 30, x1, y0 + 44], fill=(35, 35, 45))

    # Traffic lights
    draw.ellipse([x0 + 18, y0 + 14, x0 + 32, y0 + 28], fill=(255, 95, 87))
    draw.ellipse([x0 + 42, y0 + 14, x0 + 56, y0 + 28], fill=(255, 189, 46))
    draw.ellipse([x0 + 66, y0 + 14, x0 + 80, y0 + 28], fill=(39, 201, 63))

    # Title text
    tw = draw.textlength(title, font=FONT_MONO_SM)
    draw.text(((W - tw) / 2, y0 + 11), title, fill=GRAY, font=FONT_MONO_SM)

    return x0 + 24, y0 + 60  # Return content start position


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def ease_out(t):
    return 1 - (1 - t) ** 3

def ease_in_out(t):
    return 3 * t * t - 2 * t * t * t

def text_width(draw, text, font):
    return draw.textlength(text, font=font)


# === Scene Definitions ===

class Scene:
    def __init__(self, duration_sec):
        self.duration = int(duration_sec * FPS)
        self.frames = []

    def render(self, frame_num):
        raise NotImplementedError


class HookScene(Scene):
    """Opening hook: 'What if your shell understood you?'"""
    def __init__(self):
        super().__init__(3.5)

    def render(self, f):
        img = Image.new("RGB", (W, H), BG)
        draw = ImageDraw.Draw(img)
        t = f / self.duration

        # Fade in text word by word
        words = ["What if", "your shell", "understood", "you?"]
        y_start = H // 2 - 140

        for i, word in enumerate(words):
            word_t = max(0, min(1, (t - i * 0.15) / 0.2))
            if word_t <= 0:
                continue
            alpha_t = ease_out(word_t)

            color = HOOK_YELLOW if word == "understood" else WHITE
            c = lerp_color(BG, color, alpha_t)

            font = FONT_HOOK
            tw = draw.textlength(word, font=font)
            x = (W - tw) / 2
            y = y_start + i * 80

            # Slight upward drift
            y_offset = (1 - alpha_t) * 20
            draw.text((x, y + y_offset), word, fill=c, font=font)

        # Subtle "lacy.sh" watermark at bottom
        if t > 0.5:
            wm_t = min(1, (t - 0.5) / 0.3)
            c = lerp_color(BG, DIM, ease_out(wm_t))
            tw = draw.textlength("lacy.sh", font=FONT_LABEL)
            draw.text(((W - tw) / 2, H - 120), "lacy.sh", fill=c, font=FONT_LABEL)

        return img


class TerminalTypingScene(Scene):
    """Shows typing in terminal with indicator color changing."""
    def __init__(self, prompt_user, command, indicator_color, label, response_lines=None, duration_sec=5):
        super().__init__(duration_sec)
        self.prompt_user = prompt_user
        self.command = command
        self.indicator_color = indicator_color
        self.label = label
        self.response_lines = response_lines or []

    def render(self, f):
        img = Image.new("RGB", (W, H), BG)
        draw = ImageDraw.Draw(img)
        t = f / self.duration

        # Label at top
        label_t = min(1, t / 0.1)
        c = lerp_color(BG, self.indicator_color, ease_out(label_t))
        tw = draw.textlength(self.label, font=FONT_LABEL)
        draw.text(((W - tw) / 2, 80), self.label, fill=c, font=FONT_LABEL)

        # Draw terminal window
        term_top = 160
        term_height = min(900, 300 + len(self.response_lines) * 50)
        cx, cy = draw_terminal_window(draw, term_top, term_height)

        # Prompt line
        prompt = f"{self.prompt_user} "
        draw.text((cx, cy), prompt, fill=GREEN, font=FONT_MONO)
        prompt_w = text_width(draw, prompt, FONT_MONO)

        # Indicator dot (left of prompt area, in terminal margin)
        indicator_x = cx - 4
        indicator_y = cy + 18

        # Typing animation (starts at t=0.1, ends at t=0.5)
        type_t = max(0, min(1, (t - 0.1) / 0.4))
        chars_shown = int(len(self.command) * ease_in_out(type_t))
        typed = self.command[:chars_shown]

        # Draw indicator — animate from gray to color as typing progresses
        if chars_shown > 0:
            ind_t = min(1, chars_shown / max(3, len(self.command) * 0.3))
            ind_color = lerp_color(GRAY, self.indicator_color, ease_out(ind_t))
        else:
            ind_color = GRAY
        draw_indicator(draw, indicator_x, indicator_y, ind_color, size=8)

        # Draw typed text
        draw.text((cx + prompt_w, cy), typed, fill=WHITE, font=FONT_MONO)

        # Cursor
        typed_w = text_width(draw, typed, FONT_MONO)
        cursor_visible = (f % (FPS // 2)) < (FPS // 4) or type_t < 1
        if type_t < 1:
            cursor_visible = True
        draw_cursor(draw, cx + prompt_w + typed_w, cy, FONT_MONO, cursor_visible)

        # Response lines (appear after typing done)
        if t > 0.55 and self.response_lines:
            resp_t = (t - 0.55) / 0.35
            lines_to_show = int(len(self.response_lines) * min(1, resp_t * 1.5))
            for i in range(lines_to_show):
                line = self.response_lines[i]
                line_y = cy + 50 + i * 42
                # Determine line color
                if line.startswith("$"):
                    lc = GREEN
                elif line.startswith("#"):
                    lc = GRAY
                    line = line[1:].strip()
                else:
                    lc = WHITE
                draw.text((cx, line_y), line, fill=lc, font=FONT_MONO_SM)

        # Mode badge in lower right of terminal
        mode_text = "AUTO"
        badge_w = text_width(draw, mode_text, FONT_MONO_SM) + 20
        badge_x = W - 50 - badge_w - 10
        badge_y = term_top + term_height - 45
        draw_rounded_rect(draw, (badge_x, badge_y, badge_x + badge_w, badge_y + 30), 6, fill=(30, 30, 42))
        draw.text((badge_x + 10, badge_y + 2), mode_text, fill=BLUE, font=FONT_MONO_SM)

        return img


class SplitComparisonScene(Scene):
    """Side-by-side showing same word routing differently."""
    def __init__(self):
        super().__init__(5)

    def render(self, f):
        img = Image.new("RGB", (W, H), BG)
        draw = ImageDraw.Draw(img)
        t = f / self.duration

        # Title
        title = "Same word. Different intent."
        title_t = min(1, t / 0.15)
        c = lerp_color(BG, WHITE, ease_out(title_t))
        tw = draw.textlength(title, font=FONT_HOOK_SM)
        draw.text(((W - tw) / 2, 100), title, fill=c, font=FONT_HOOK_SM)

        # Top terminal: "install nodejs" → shell (green)
        if t > 0.15:
            t1 = (t - 0.15) / 0.35
            term1_top = 240
            cx, cy = draw_terminal_window(draw, term1_top, 200, "shell command")

            cmd1 = "install nodejs"
            chars1 = int(len(cmd1) * min(1, ease_in_out(max(0, t1))))
            typed1 = cmd1[:chars1]

            draw.text((cx, cy), "~ ", fill=GREEN, font=FONT_MONO)
            pw = text_width(draw, "~ ", FONT_MONO)
            draw.text((cx + pw, cy), typed1, fill=WHITE, font=FONT_MONO)

            # Green indicator
            if chars1 > 0:
                draw_indicator(draw, cx - 4, cy + 18, GREEN, 8)
            else:
                draw_indicator(draw, cx - 4, cy + 18, GRAY, 8)

            # Response
            if t1 > 0.7:
                draw.text((cx, cy + 45), "→ brew install node", fill=GRAY, font=FONT_MONO_SM)
                # Green label
                lbl = "SHELL"
                lw = text_width(draw, lbl, FONT_LABEL)
                draw.text((W - 74 - lw, term1_top + 170), lbl, fill=GREEN, font=FONT_LABEL)

        # Bottom terminal: "install a way to..." → agent (magenta)
        if t > 0.45:
            t2 = (t - 0.45) / 0.4
            term2_top = 520
            cx2, cy2 = draw_terminal_window(draw, term2_top, 250, "natural language")

            cmd2 = "install a way to monitor logs"
            chars2 = int(len(cmd2) * min(1, ease_in_out(max(0, t2))))
            typed2 = cmd2[:chars2]

            draw.text((cx2, cy2), "~ ", fill=GREEN, font=FONT_MONO)
            pw2 = text_width(draw, "~ ", FONT_MONO)
            draw.text((cx2 + pw2, cy2), typed2, fill=WHITE, font=FONT_MONO)

            # Magenta indicator transitions as NL detected
            if chars2 > 10:
                draw_indicator(draw, cx2 - 4, cy2 + 18, MAGENTA, 8)
            elif chars2 > 0:
                draw_indicator(draw, cx2 - 4, cy2 + 18, GREEN, 8)
            else:
                draw_indicator(draw, cx2 - 4, cy2 + 18, GRAY, 8)

            # AI response
            if t2 > 0.7:
                ai_lines = [
                    "→ AI: I'd recommend using",
                    "  'pm2' or 'lnav'. Want me",
                    "  to set one up for you?",
                ]
                for i, line in enumerate(ai_lines):
                    draw.text((cx2, cy2 + 45 + i * 38), line, fill=MAGENTA, font=FONT_MONO_SM)

                lbl = "AGENT"
                lw = text_width(draw, lbl, FONT_LABEL)
                draw.text((W - 74 - lw, term2_top + 218), lbl, fill=MAGENTA, font=FONT_LABEL)

        # Divider line
        if t > 0.4:
            div_t = min(1, (t - 0.4) / 0.1)
            div_w = int(400 * ease_out(div_t))
            div_x = (W - div_w) // 2
            draw.line([(div_x, 490), (div_x + div_w, 490)], fill=DIM, width=2)

        return img


class CTAScene(Scene):
    """Call to action with install command."""
    def __init__(self):
        super().__init__(3.5)

    def render(self, f):
        img = Image.new("RGB", (W, H), BG)
        draw = ImageDraw.Draw(img)
        t = f / self.duration

        # Gradient text effect for "lacy.sh"
        brand_t = min(1, t / 0.25)
        c = lerp_color(BG, WHITE, ease_out(brand_t))
        brand = "lacy.sh"
        tw = draw.textlength(brand, font=FONT_HOOK)
        draw.text(((W - tw) / 2, H // 2 - 200), brand, fill=c, font=FONT_HOOK)

        # Tagline
        if t > 0.15:
            tag_t = min(1, (t - 0.15) / 0.2)
            c = lerp_color(BG, GRAY, ease_out(tag_t))
            tag = "Talk to your shell."
            tw = draw.textlength(tag, font=FONT_CTA_SM)
            draw.text(((W - tw) / 2, H // 2 - 110), tag, fill=c, font=FONT_CTA_SM)

        # Install command box
        if t > 0.3:
            box_t = min(1, (t - 0.3) / 0.2)
            install = "curl -fsSL lacy.sh/install | bash"
            iw = text_width(draw, install, FONT_MONO_SM) + 50
            box_x = (W - iw) / 2
            box_y = H // 2 - 20

            # Box background with border
            box_alpha = ease_out(box_t)
            box_fill = lerp_color(BG, (30, 30, 42), box_alpha)
            border_fill = lerp_color(BG, MAGENTA, box_alpha * 0.5)
            draw_rounded_rect(draw, (box_x - 2, box_y - 2, box_x + iw + 2, box_y + 52), 12, fill=border_fill)
            draw_rounded_rect(draw, (box_x, box_y, box_x + iw, box_y + 50), 10, fill=box_fill)

            ic = lerp_color(BG, WHITE, box_alpha)
            draw.text((box_x + 25, box_y + 10), install, fill=ic, font=FONT_MONO_SM)

        # Bottom features
        if t > 0.5:
            feats = ["ZSH & Bash", "macOS / Linux / WSL", "Works with any AI CLI"]
            for i, feat in enumerate(feats):
                feat_t = min(1, (t - 0.5 - i * 0.08) / 0.2)
                if feat_t <= 0:
                    continue
                fc = lerp_color(BG, DIM, ease_out(feat_t))
                fw = draw.textlength(feat, font=FONT_LABEL)
                fy = H // 2 + 100 + i * 45
                draw.text(((W - fw) / 2, fy), feat, fill=fc, font=FONT_LABEL)

        # Colored dots decorative
        if t > 0.6:
            dot_t = min(1, (t - 0.6) / 0.2)
            dot_alpha = ease_out(dot_t)
            dots = [(GREEN, -60), (MAGENTA, 0), (BLUE, 60)]
            for color, offset in dots:
                dc = lerp_color(BG, color, dot_alpha)
                cx = W // 2 + offset
                cy_pos = H // 2 + 280
                draw.ellipse([cx - 6, cy_pos - 6, cx + 6, cy_pos + 6], fill=dc)

        return img


# === Main Generation ===

def generate_all():
    scenes = [
        HookScene(),                                    # 3.5s - Hook
        TerminalTypingScene(                            # 5s - Shell command
            prompt_user="~",
            command="ls -la",
            indicator_color=GREEN,
            label="SHELL COMMAND → EXECUTES NORMALLY",
            response_lines=[
                "total 48",
                "drwxr-xr-x  12 user  staff   384 Mar 13",
                "-rw-r--r--   1 user  staff  1024 README.md",
                "-rw-r--r--   1 user  staff   512 package.json",
            ],
            duration_sec=4.5,
        ),
        TerminalTypingScene(                            # 5s - NL query
            prompt_user="~",
            command="what files are in this project",
            indicator_color=MAGENTA,
            label="NATURAL LANGUAGE → ROUTES TO AI",
            response_lines=[
                "#AI analyzing your project...",
                "",
                "This is a Node.js project with:",
                "  - 12 source files in src/",
                "  - Jest test suite (8 specs)",
                "  - TypeScript configuration",
            ],
            duration_sec=5.5,
        ),
        SplitComparisonScene(),                         # 5s - Comparison
        TerminalTypingScene(                            # 4s - Auto-reroute demo
            prompt_user="~",
            command="fix the failing tests",
            indicator_color=MAGENTA,
            label="AUTO-REROUTE: FAILS → SENDS TO AI",
            response_lines=[
                "#bash: fix: command not found",
                "#→ Detected NL, routing to AI...",
                "",
                "Found 2 failing tests. Fixing...",
                "  ✓ auth.test.ts — fixed import",
                "  ✓ api.test.ts — updated mock",
            ],
            duration_sec=5.5,
        ),
        CTAScene(),                                     # 3.5s - CTA
    ]

    frame_num = 0
    total_frames = sum(s.duration for s in scenes)
    print(f"Generating {total_frames} frames ({total_frames / FPS:.1f}s at {FPS}fps)")

    for scene_idx, scene in enumerate(scenes):
        print(f"  Scene {scene_idx + 1}/{len(scenes)}: {scene.__class__.__name__} ({scene.duration} frames)")
        for f in range(scene.duration):
            img = scene.render(f)
            img.save(os.path.join(OUT_DIR, f"frame_{frame_num:05d}.png"))
            frame_num += 1

    print(f"Done! {frame_num} frames saved to {OUT_DIR}")
    return frame_num, total_frames / FPS


if __name__ == "__main__":
    n_frames, duration = generate_all()
    print(f"\nTo create video:")
    print(f"  ffmpeg -framerate {FPS} -i {OUT_DIR}/frame_%05d.png -c:v libx264 -pix_fmt yuv420p -crf 18 /tmp/ugc-video/lacy-shell-demo.mp4")
