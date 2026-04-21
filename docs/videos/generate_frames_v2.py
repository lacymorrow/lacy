#!/usr/bin/env python3
"""
Generate frames for Lacy Shell UGC demo video — V2 Enhanced.

Improvements over v1:
  - 60fps for smoother motion
  - Gradient background (deep dark purple-black)
  - Glow/bloom effect on colored indicators using GaussianBlur compositing
  - Drop shadow on terminal windows
  - CRT scan-line overlay (subtle, every 3px)
  - Variable speed typing with natural micro-pauses
  - Scene fade-in/fade-out transitions
  - Progress bar at bottom
  - Accessibility captions overlay
  - Floating code particle background
  - Elastic spring animation on key text reveals
  - Thumbnail export at CTA peak
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# === Config ===
W, H = 1080, 1920
FPS = 60
OUT_DIR = "/tmp/ugc-video/frames-v2"
THUMBNAIL_PATH = "/tmp/ugc-video/lacy-shell-thumbnail.png"
FADE_FRAMES = 18  # 0.3s fade envelope at scene edges

# Colors (RGB)
BG  = (10,  8, 20)            # Deep dark purple-black (top)
BG2 = (16, 12, 30)            # Gradient end (bottom)
TERM_BG = (20, 20, 30)        # Terminal background
WHITE  = (235, 235, 240)
GRAY   = (130, 130, 145)
DIM    = (60,  60,  80)
GREEN   = (52,  211, 153)     # Indicator green
MAGENTA = (216, 100, 240)     # Indicator magenta
BLUE    = (96,  165, 250)     # Auto mode blue
HOOK_YELLOW = (250, 204, 21)
CURSOR_COLOR = (235, 235, 240)

# === Pre-computed assets ===

_GRADIENT_BG = None

def get_gradient_bg():
    global _GRADIENT_BG
    if _GRADIENT_BG is None:
        strip = Image.new("RGB", (1, H))
        for y in range(H):
            t = y / H
            r = int(BG[0] + (BG2[0] - BG[0]) * t)
            g = int(BG[1] + (BG2[1] - BG[1]) * t)
            b = int(BG[2] + (BG2[2] - BG[2]) * t)
            strip.putpixel((0, y), (r, g, b))
        _GRADIENT_BG = strip.resize((W, H), Image.NEAREST)
    return _GRADIENT_BG.copy()


_SCANLINE_OVERLAY = None

def get_scanline_overlay():
    global _SCANLINE_OVERLAY
    if _SCANLINE_OVERLAY is None:
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(overlay)
        for y in range(0, H, 3):
            d.line([(0, y), (W, y)], fill=(0, 0, 0, 15))
        _SCANLINE_OVERLAY = overlay
    return _SCANLINE_OVERLAY


def apply_scanlines(img):
    rgba = img.convert("RGBA")
    result = Image.alpha_composite(rgba, get_scanline_overlay())
    return result.convert("RGB")


def new_frame():
    return get_gradient_bg()


# === Math helpers ===

def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3

def ease_in_out(t):
    t = max(0.0, min(1.0, t))
    return 3 * t * t - 2 * t * t * t

def ease_out_elastic(t):
    """Springy overshoot — useful for title pop-in."""
    if t <= 0: return 0.0
    if t >= 1: return 1.0
    c4 = (2 * math.pi) / 3
    return pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1.0


# === Fonts ===

def load_font(size, bold=False):
    paths = [
        "/opt/X11/share/system_fonts/Menlo.ttc",
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/SFNSMono.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size, index=1 if bold else 0)
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

FONT_MONO      = load_font(32)
FONT_MONO_SM   = load_font(26)
FONT_MONO_BOLD = load_font(34, bold=True)
FONT_HOOK      = load_sans_font(64, bold=True)
FONT_HOOK_SM   = load_sans_font(48, bold=True)
FONT_CTA       = load_sans_font(56, bold=True)
FONT_CTA_SM    = load_sans_font(36)
FONT_LABEL     = load_sans_font(28)
FONT_CAPTION   = load_sans_font(30)


# === Drawing helpers ===

def text_width(draw, text, font):
    return draw.textlength(text, font=font)

def draw_rounded_rect(draw, xy, radius, fill=None):
    x0, y0, x1, y1 = xy
    r = radius
    draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
    draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
    draw.pieslice([x0,           y0,           x0 + 2*r, y0 + 2*r], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*r,     y0,           x1,       y0 + 2*r], 270, 360, fill=fill)
    draw.pieslice([x0,           y1 - 2*r,     x0 + 2*r, y1      ], 90,  180, fill=fill)
    draw.pieslice([x1 - 2*r,     y1 - 2*r,     x1,       y1      ], 0,   90,  fill=fill)

def draw_glow_indicator(img, x, y, color, inner_size=10, glow_size=40):
    """Composite a glowing indicator dot onto img. Returns new RGB image."""
    r, g, b = color
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for radius, alpha in [(glow_size, 25), (int(glow_size * 0.65), 50), (int(glow_size * 0.35), 80)]:
        gd.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(r, g, b, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=12))
    # Solid centre over the blurred halo
    gd2 = ImageDraw.Draw(glow)
    gd2.ellipse([x - inner_size, y - inner_size, x + inner_size, y + inner_size],
                fill=(r, g, b, 255))
    rgba = img.convert("RGBA")
    result = Image.alpha_composite(rgba, glow)
    return result.convert("RGB")

def draw_drop_shadow(img, rect, radius=16, offset=(10, 14), blur_r=20):
    """Composite a blurred drop-shadow behind rect. Returns new RGB image."""
    x0, y0, x1, y1 = rect
    ox, oy = offset
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    draw_rounded_rect(sd, (x0 + ox, y0 + oy, x1 + ox, y1 + oy), radius, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur_r))
    rgba = img.convert("RGBA")
    return Image.alpha_composite(rgba, shadow).convert("RGB")

def draw_particles(img, t, opacity_mult=1.0):
    """Floating code-snippet particles drifting upward."""
    snippets = ["if [", "&&", "| grep", "$(", "zsh", "bash", "$PATH",
                "~/.zshrc", "export", "alias", "git", "| head", ">>",
                "2>&1", "eval", "source", "lash", "claude"]
    rng = random.Random(42)
    draw = ImageDraw.Draw(img)
    for _ in range(18):
        px       = rng.randint(20, W - 80)
        base_py  = rng.randint(0, H)
        speed    = rng.uniform(15, 45)
        py       = int((base_py - t * speed) % H)
        snippet  = rng.choice(snippets)
        alpha    = rng.randint(8, 22)
        alpha_sc = int(alpha * opacity_mult)
        c = lerp_color(BG, GRAY, alpha_sc / 100)
        try:
            draw.text((px, py), snippet, fill=c, font=FONT_MONO_SM)
        except Exception:
            pass
    return img

def draw_progress_bar(draw, progress, color=MAGENTA):
    """Thin 6px progress bar at the very bottom of the frame."""
    y = H - 12
    bar_w = int(W * max(0.0, min(1.0, progress)))
    draw.rectangle([0, y, W, y + 6], fill=(30, 30, 45))
    if bar_w > 0:
        draw.rectangle([0, y, bar_w, y + 6], fill=color)
    if bar_w > 10:
        draw.ellipse([bar_w - 6, y - 3, bar_w + 6, y + 9], fill=color)

def draw_caption(draw, text, t_in=1.0, y_base=None):
    """Semi-transparent caption pill near bottom of frame."""
    if t_in <= 0:
        return
    alpha = min(1.0, t_in)
    if y_base is None:
        y_base = H - 220
    tw = text_width(draw, text, FONT_CAPTION)
    pad_x, pad_y = 24, 12
    bx = (W - tw - pad_x * 2) / 2
    bg_c   = lerp_color(BG, (25, 25, 40),  alpha)
    bord_c = lerp_color(BG, (60, 60, 80),  alpha * 0.5)
    draw_rounded_rect(draw, (bx - 2, y_base - 2, bx + tw + pad_x * 2 + 2, y_base + 46), 10, fill=bord_c)
    draw_rounded_rect(draw, (bx,     y_base,     bx + tw + pad_x * 2,     y_base + 44),  8, fill=bg_c)
    tc = lerp_color(BG, WHITE, ease_out(alpha))
    draw.text((bx + pad_x, y_base + 7), text, fill=tc, font=FONT_CAPTION)

def draw_terminal_window(img, y_top, height, title="lacy ~"):
    """Draw macOS-style terminal with drop shadow. Returns (new_img, cx, cy)."""
    margin = 50
    x0, y0 = margin, y_top
    x1, y1 = W - margin, y_top + height
    # Drop shadow first (operates on img)
    img = draw_drop_shadow(img, (x0, y0, x1, y1))
    draw = ImageDraw.Draw(img)
    # Window body
    draw_rounded_rect(draw, (x0, y0, x1, y1), 16, fill=TERM_BG)
    # Subtle top edge highlight
    draw.line([(x0 + 16, y0), (x1 - 16, y0)], fill=(50, 50, 65), width=1)
    # Title bar
    draw_rounded_rect(draw, (x0, y0, x1, y0 + 44), 16, fill=(32, 32, 44))
    draw.rectangle([x0, y0 + 28, x1, y0 + 44], fill=(32, 32, 44))
    # Traffic lights
    draw.ellipse([x0 + 18, y0 + 14, x0 + 32, y0 + 28], fill=(255, 95,  87))
    draw.ellipse([x0 + 42, y0 + 14, x0 + 56, y0 + 28], fill=(255, 189, 46))
    draw.ellipse([x0 + 66, y0 + 14, x0 + 80, y0 + 28], fill=(39,  201, 63))
    # Title text
    tw = draw.textlength(title, font=FONT_MONO_SM)
    draw.text(((W - tw) / 2, y0 + 11), title, fill=GRAY, font=FONT_MONO_SM)
    return img, x0 + 24, y0 + 60

def draw_cursor(draw, x, y, font, f, always_on=False):
    visible = always_on or (f % (FPS // 2)) < (FPS // 4)
    if visible:
        bbox  = font.getbbox("M")
        ch_w  = bbox[2] - bbox[0]
        ch_h  = bbox[3] - bbox[1]
        draw.rectangle([x, y - 2, x + ch_w, y + ch_h + 2], fill=CURSOR_COLOR)

def variable_typing_chars(t, command, start_t=0.08, duration=0.42):
    """Natural typing — eased progress with a brief settle at the end."""
    if t < start_t:
        return 0
    t_adj = max(0.0, min(1.0, (t - start_t) / duration))
    return min(int(len(command) * ease_in_out(t_adj)), len(command))


# === Scene base ===

class Scene:
    def __init__(self, duration_sec, caption=""):
        self.duration = int(duration_sec * FPS)
        self.caption  = caption

    def render(self, f, global_progress=0.0):
        raise NotImplementedError

    def fade_alpha(self, f):
        if f < FADE_FRAMES:
            return ease_out(f / FADE_FRAMES)
        frames_from_end = self.duration - f
        if frames_from_end < FADE_FRAMES:
            return ease_out(frames_from_end / FADE_FRAMES)
        return 1.0

    def apply_fade(self, img, f):
        alpha = self.fade_alpha(f)
        if alpha >= 0.99:
            return img
        overlay = Image.new("RGB", (W, H), BG)
        return Image.blend(img, overlay, 1.0 - alpha)


# === Scenes ===

class HookScene(Scene):
    def __init__(self):
        super().__init__(3.5, caption="What if your shell understood you?")

    def render(self, f, global_progress=0.0):
        img  = new_frame()
        img  = draw_particles(img, f / FPS, opacity_mult=0.6)
        draw = ImageDraw.Draw(img)
        t    = f / self.duration

        words   = ["What if", "your shell", "understood", "you?"]
        y_start = H // 2 - 160
        for i, word in enumerate(words):
            word_t  = max(0.0, min(1.0, (t - i * 0.12) / 0.18))
            if word_t <= 0:
                continue
            alpha_t = ease_out(word_t)
            # Elastic spring on the last word
            spring  = (1.0 - ease_out_elastic(word_t)) * 25 if word == "you?" else (1.0 - alpha_t) * 18
            color   = HOOK_YELLOW if word == "understood" else WHITE
            c       = lerp_color(BG, color, alpha_t)
            font    = FONT_HOOK
            tw      = draw.textlength(word, font=font)
            draw.text(((W - tw) / 2, y_start + i * 90 + spring), word, fill=c, font=font)

        # Watermark fade-in
        if t > 0.5:
            wm_t = min(1.0, (t - 0.5) / 0.3)
            c    = lerp_color(BG, DIM, ease_out(wm_t))
            tw   = draw.textlength("lacy.sh", font=FONT_LABEL)
            draw.text(((W - tw) / 2, H - 140), "lacy.sh", fill=c, font=FONT_LABEL)

        draw_progress_bar(draw, global_progress, color=GREEN)
        draw_caption(draw, self.caption, t_in=max(0.0, (t - 0.6) / 0.3))
        img = apply_scanlines(img)
        return self.apply_fade(img, f)


class TerminalTypingScene(Scene):
    def __init__(self, prompt_user, command, indicator_color, label,
                 response_lines=None, duration_sec=5, caption=""):
        super().__init__(duration_sec, caption=caption)
        self.prompt_user    = prompt_user
        self.command        = command
        self.indicator_color = indicator_color
        self.label          = label
        self.response_lines = response_lines or []

    def render(self, f, global_progress=0.0):
        t   = f / self.duration
        img = new_frame()
        img = draw_particles(img, f / FPS, opacity_mult=0.4)

        # Label banner
        draw    = ImageDraw.Draw(img)
        label_t = min(1.0, t / 0.08)
        c       = lerp_color(BG, self.indicator_color, ease_out(label_t))
        tw      = draw.textlength(self.label, font=FONT_LABEL)
        draw.text(((W - tw) / 2, 80), self.label, fill=c, font=FONT_LABEL)

        # Terminal window (modifies img)
        term_top    = 160
        term_height = min(900, 300 + len(self.response_lines) * 50)
        img, cx, cy = draw_terminal_window(img, term_top, term_height)
        draw = ImageDraw.Draw(img)

        # Prompt
        prompt   = f"{self.prompt_user} "
        draw.text((cx, cy), prompt, fill=GREEN, font=FONT_MONO)
        prompt_w = text_width(draw, prompt, FONT_MONO)

        # Typing
        chars_shown = variable_typing_chars(t, self.command)
        typed       = self.command[:chars_shown]

        # Indicator
        ind_x, ind_y = cx - 4, cy + 18
        if chars_shown > 0:
            ind_t    = min(1.0, chars_shown / max(3, len(self.command) * 0.3))
            ind_color = lerp_color(GRAY, self.indicator_color, ease_out(ind_t))
        else:
            ind_color = GRAY

        if chars_shown > 3:
            glow_prog = min(1.0, (chars_shown - 3) / 10)
            img  = draw_glow_indicator(img, ind_x, ind_y, ind_color,
                                       inner_size=8,
                                       glow_size=int(20 + glow_prog * 15))
            draw = ImageDraw.Draw(img)
        else:
            draw.ellipse([ind_x - 8, ind_y - 8, ind_x + 8, ind_y + 8], fill=ind_color)

        draw.text((cx + prompt_w, cy), typed, fill=WHITE, font=FONT_MONO)
        typed_w = text_width(draw, typed, FONT_MONO)
        draw_cursor(draw, cx + prompt_w + typed_w, cy, FONT_MONO, f,
                    always_on=(chars_shown < len(self.command)))

        # Response lines — slide in from right
        if t > 0.55 and self.response_lines:
            resp_t     = (t - 0.55) / 0.35
            lines_show = int(len(self.response_lines) * min(1.0, resp_t * 1.5))
            for i in range(lines_show):
                line    = self.response_lines[i]
                line_y  = cy + 50 + i * 42
                slide_t = min(1.0, (resp_t * 1.5 - i * 0.15))
                x_off   = int((1.0 - ease_out(slide_t)) * 20)
                if line.startswith("$"):
                    lc = GREEN
                elif line.startswith("#"):
                    lc   = GRAY
                    line = line[1:].strip()
                else:
                    lc = WHITE
                draw.text((cx + x_off, line_y), line, fill=lc, font=FONT_MONO_SM)

        # AUTO mode badge
        mode_text = "AUTO"
        badge_w   = text_width(draw, mode_text, FONT_MONO_SM) + 20
        badge_x   = W - 50 - badge_w - 10
        badge_y   = term_top + term_height - 45
        draw_rounded_rect(draw, (badge_x, badge_y, badge_x + badge_w, badge_y + 30), 6, fill=(28, 28, 42))
        draw.text((badge_x + 10, badge_y + 2), mode_text, fill=BLUE, font=FONT_MONO_SM)

        draw_progress_bar(draw, global_progress, color=self.indicator_color)
        draw_caption(draw, self.caption, t_in=min(1.0, t / 0.2))
        img = apply_scanlines(img)
        return self.apply_fade(img, f)


class SplitComparisonScene(Scene):
    def __init__(self):
        super().__init__(5, caption="Same word. Different intent.")

    def render(self, f, global_progress=0.0):
        t   = f / self.duration
        img = new_frame()
        img = draw_particles(img, f / FPS, opacity_mult=0.4)
        draw = ImageDraw.Draw(img)

        # Title with elastic pop
        title   = "Same word. Different intent."
        title_t = min(1.0, t / 0.12)
        c       = lerp_color(BG, WHITE, ease_out_elastic(title_t))
        tw      = draw.textlength(title, font=FONT_HOOK_SM)
        spring  = (1.0 - ease_out_elastic(title_t)) * 15
        draw.text(((W - tw) / 2, 100 + spring), title, fill=c, font=FONT_HOOK_SM)

        # ── Top terminal: "install nodejs" → SHELL (green) ──
        if t > 0.12:
            t1       = (t - 0.12) / 0.35
            t1_top   = 240
            img      = draw_drop_shadow(img, (50, t1_top, W - 50, t1_top + 200))
            draw     = ImageDraw.Draw(img)
            draw_rounded_rect(draw, (50, t1_top,      W-50, t1_top+200), 16, fill=TERM_BG)
            draw_rounded_rect(draw, (50, t1_top,      W-50, t1_top+44 ), 16, fill=(32,32,44))
            draw.rectangle([50, t1_top+28, W-50, t1_top+44], fill=(32,32,44))
            draw.ellipse([68, t1_top+14, 82, t1_top+28], fill=(255, 95, 87))
            draw.ellipse([92, t1_top+14,106, t1_top+28], fill=(255,189, 46))
            draw.ellipse([116,t1_top+14,130, t1_top+28], fill=( 39,201, 63))
            ttl = "shell command"
            tw2 = draw.textlength(ttl, font=FONT_MONO_SM)
            draw.text(((W - tw2) / 2, t1_top + 11), ttl, fill=GRAY, font=FONT_MONO_SM)

            cx, cy   = 74, t1_top + 65
            cmd1     = "install nodejs"
            chars1   = int(len(cmd1) * min(1.0, ease_in_out(max(0.0, t1))))
            draw.text((cx, cy), "~ ", fill=GREEN, font=FONT_MONO)
            pw       = text_width(draw, "~ ", FONT_MONO)
            draw.text((cx + pw, cy), cmd1[:chars1], fill=WHITE, font=FONT_MONO)
            if chars1 > 0:
                img  = draw_glow_indicator(img, cx - 4, cy + 18, GREEN, 8, 22)
                draw = ImageDraw.Draw(img)
            else:
                draw.ellipse([cx-12, cy+10, cx+4, cy+26], fill=GRAY)

            if t1 > 0.7:
                draw.text((cx, cy + 45), "→ brew install node", fill=GRAY, font=FONT_MONO_SM)
                lbl = "SHELL"
                lw  = text_width(draw, lbl, FONT_LABEL)
                lc  = lerp_color(BG, GREEN, min(1.0, (t1 - 0.7) / 0.2))
                draw.text((W - 74 - lw, t1_top + 170), lbl, fill=lc, font=FONT_LABEL)

        # Divider
        if t > 0.4:
            div_t = min(1.0, (t - 0.4) / 0.1)
            div_w = int(400 * ease_out(div_t))
            div_x = (W - div_w) // 2
            draw.line([(div_x, 490), (div_x + div_w, 490)], fill=DIM, width=2)

        # ── Bottom terminal: "install a way to..." → AGENT (magenta) ──
        if t > 0.4:
            t2      = (t - 0.4) / 0.45
            t2_top  = 520
            img     = draw_drop_shadow(img, (50, t2_top, W - 50, t2_top + 260))
            draw    = ImageDraw.Draw(img)
            draw_rounded_rect(draw, (50, t2_top,      W-50, t2_top+260), 16, fill=TERM_BG)
            draw_rounded_rect(draw, (50, t2_top,      W-50, t2_top+44 ), 16, fill=(32,32,44))
            draw.rectangle([50, t2_top+28, W-50, t2_top+44], fill=(32,32,44))
            draw.ellipse([68, t2_top+14, 82, t2_top+28], fill=(255, 95, 87))
            draw.ellipse([92, t2_top+14,106, t2_top+28], fill=(255,189, 46))
            draw.ellipse([116,t2_top+14,130, t2_top+28], fill=( 39,201, 63))
            ttl2 = "natural language"
            tw3  = draw.textlength(ttl2, font=FONT_MONO_SM)
            draw.text(((W - tw3) / 2, t2_top + 11), ttl2, fill=GRAY, font=FONT_MONO_SM)

            cx2, cy2 = 74, t2_top + 65
            cmd2     = "install a way to monitor logs"
            chars2   = int(len(cmd2) * min(1.0, ease_in_out(max(0.0, t2))))
            draw.text((cx2, cy2), "~ ", fill=GREEN, font=FONT_MONO)
            pw2      = text_width(draw, "~ ", FONT_MONO)
            draw.text((cx2 + pw2, cy2), cmd2[:chars2], fill=WHITE, font=FONT_MONO)

            if chars2 > 10:
                img  = draw_glow_indicator(img, cx2 - 4, cy2 + 18, MAGENTA, 8, 24)
                draw = ImageDraw.Draw(img)
            elif chars2 > 0:
                blend_c = lerp_color(GREEN, MAGENTA, chars2 / 10)
                draw.ellipse([cx2-12, cy2+10, cx2+4, cy2+26], fill=blend_c)
            else:
                draw.ellipse([cx2-12, cy2+10, cx2+4, cy2+26], fill=GRAY)

            if t2 > 0.7:
                ai_lines = [
                    "→ AI: I'd recommend using",
                    "  'pm2' or 'lnav'. Want me",
                    "  to set one up for you?",
                ]
                for i, line in enumerate(ai_lines):
                    slide_t = min(1.0, (t2 - 0.7 - i * 0.08) / 0.2)
                    if slide_t <= 0:
                        continue
                    lc = lerp_color(BG, MAGENTA, ease_out(slide_t))
                    draw.text((cx2, cy2 + 45 + i * 38), line, fill=lc, font=FONT_MONO_SM)

                lbl = "AGENT"
                lw  = text_width(draw, lbl, FONT_LABEL)
                lc2 = lerp_color(BG, MAGENTA, min(1.0, (t2 - 0.7) / 0.2))
                draw.text((W - 74 - lw, t2_top + 228), lbl, fill=lc2, font=FONT_LABEL)

        draw_progress_bar(draw, global_progress)
        draw_caption(draw, self.caption, t_in=min(1.0, t / 0.2))
        img = apply_scanlines(img)
        return self.apply_fade(img, f)


class CTAScene(Scene):
    def __init__(self):
        super().__init__(4.0, caption="curl -fsSL lacy.sh/install | bash")

    def render(self, f, global_progress=0.0):
        t   = f / self.duration
        img = new_frame()
        img = draw_particles(img, f / FPS, opacity_mult=1.2)
        draw = ImageDraw.Draw(img)

        # Brand — elastic pop-in
        brand_t = min(1.0, t / 0.2)
        c       = lerp_color(BG, WHITE, ease_out_elastic(brand_t))
        brand   = "lacy.sh"
        tw      = draw.textlength(brand, font=FONT_HOOK)
        spring  = (1.0 - ease_out_elastic(brand_t)) * 30
        draw.text(((W - tw) / 2, H // 2 - 200 + spring), brand, fill=c, font=FONT_HOOK)

        # Tagline
        if t > 0.15:
            tag_t = min(1.0, (t - 0.15) / 0.2)
            c     = lerp_color(BG, GRAY, ease_out(tag_t))
            tag   = "Talk to your shell."
            tw    = draw.textlength(tag, font=FONT_CTA_SM)
            draw.text(((W - tw) / 2, H // 2 - 110), tag, fill=c, font=FONT_CTA_SM)

        # Install command box with magenta glow border
        if t > 0.3:
            box_t   = min(1.0, (t - 0.3) / 0.2)
            install = "curl -fsSL lacy.sh/install | bash"
            iw      = text_width(draw, install, FONT_MONO_SM) + 50
            box_x   = (W - iw) / 2
            box_y   = H // 2 - 20
            ba      = ease_out(box_t)
            glow_c  = lerp_color(BG, MAGENTA, ba * 0.5)
            draw_rounded_rect(draw, (box_x - 3, box_y - 3, box_x + iw + 3, box_y + 53), 13, fill=glow_c)
            draw_rounded_rect(draw, (box_x,     box_y,     box_x + iw,     box_y + 50), 10,
                              fill=lerp_color(BG, (28, 28, 42), ba))
            draw.text((box_x + 25, box_y + 10), install,
                      fill=lerp_color(BG, WHITE, ba), font=FONT_MONO_SM)

        # Feature bullets
        if t > 0.5:
            feats = ["ZSH & Bash", "macOS / Linux / WSL", "Works with any AI CLI"]
            for i, feat in enumerate(feats):
                feat_t = min(1.0, (t - 0.5 - i * 0.08) / 0.2)
                if feat_t <= 0:
                    continue
                fc = lerp_color(BG, DIM, ease_out(feat_t))
                fw = draw.textlength(feat, font=FONT_LABEL)
                draw.text(((W - fw) / 2, H // 2 + 100 + i * 50), feat, fill=fc, font=FONT_LABEL)

        # Three indicator dots with glow
        if t > 0.6:
            dot_t = min(1.0, (t - 0.6) / 0.25)
            da    = ease_out_elastic(dot_t)
            for color, offset in [(GREEN, -70), (MAGENTA, 0), (BLUE, 70)]:
                cx_d   = W // 2 + offset
                cy_d   = H // 2 + 295
                if da > 0.5:
                    img  = draw_glow_indicator(img, cx_d, cy_d, color, inner_size=8, glow_size=28)
                    draw = ImageDraw.Draw(img)
                else:
                    dc = lerp_color(BG, color, da)
                    draw.ellipse([cx_d - 8, cy_d - 8, cx_d + 8, cy_d + 8], fill=dc)

        draw_progress_bar(draw, global_progress, color=MAGENTA)
        draw_caption(draw, self.caption, t_in=max(0.0, (t - 0.4) / 0.3))
        img = apply_scanlines(img)
        return self.apply_fade(img, f)


# === Main generation ===

def generate_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(THUMBNAIL_PATH), exist_ok=True)

    scenes = [
        HookScene(),
        TerminalTypingScene(
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
            caption="Shell commands run as normal",
        ),
        TerminalTypingScene(
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
            caption="Natural language routes to AI",
        ),
        SplitComparisonScene(),
        TerminalTypingScene(
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
            caption="Failed command? Auto-routes to AI",
        ),
        CTAScene(),
    ]

    total_frames   = sum(s.duration for s in scenes)
    thumbnail_saved = False
    print(f"Generating {total_frames} frames ({total_frames / FPS:.1f}s at {FPS}fps)")

    frame_num = 0
    for scene_idx, scene in enumerate(scenes):
        print(f"  Scene {scene_idx + 1}/{len(scenes)}: {scene.__class__.__name__} "
              f"({scene.duration} frames, {scene.duration / FPS:.1f}s)")
        for f in range(scene.duration):
            global_progress = (frame_num + 1) / total_frames
            img = scene.render(f, global_progress)
            img.save(os.path.join(OUT_DIR, f"frame_{frame_num:05d}.png"))

            # Thumbnail: CTA scene at ~40% in
            if not thumbnail_saved and isinstance(scene, CTAScene) and f == int(scene.duration * 0.4):
                img.save(THUMBNAIL_PATH)
                print(f"  → Thumbnail saved: {THUMBNAIL_PATH}")
                thumbnail_saved = True

            frame_num += 1

    print(f"\nDone! {frame_num} frames saved to {OUT_DIR}")
    print(f"\n── Encode commands ──")
    print(f"# Full demo (60fps):")
    print(f"ffmpeg -framerate {FPS} -i {OUT_DIR}/frame_%05d.png \\")
    print(f"  -c:v libx264 -pix_fmt yuv420p -crf 18 \\")
    print(f"  -y docs/videos/lacy-shell-demo-v2.mp4")
    print(f"\n# TikTok/Reels/Shorts variant (keep 9:16, embed safe-zone):")
    print(f"ffmpeg -i docs/videos/lacy-shell-demo-v2.mp4 \\")
    print(f"  -vf 'scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2' \\")
    print(f"  -c:v libx264 -pix_fmt yuv420p -crf 20 \\")
    print(f"  -y docs/videos/lacy-shell-demo-v2-tiktok.mp4")
    print(f"\n# YouTube Shorts (same file works — 9:16 ✓)")
    print(f"\n# Twitter/X square crop:")
    print(f"ffmpeg -i docs/videos/lacy-shell-demo-v2.mp4 \\")
    print(f"  -vf 'crop=1080:1080:0:420' \\")
    print(f"  -c:v libx264 -pix_fmt yuv420p -crf 20 \\")
    print(f"  -y docs/videos/lacy-shell-demo-v2-square.mp4")

    return frame_num, total_frames / FPS


if __name__ == "__main__":
    n_frames, duration = generate_all()
