#!/usr/bin/env python3
"""
Generate frames for Lacy Shell UGC SHORT video — V2 Enhanced (15s).

Quick hook → single demo → CTA. Maximum shareability.
Vertical 1080x1920 for TikTok / Instagram Reels / YouTube Shorts.

V2 improvements over v1:
  - 60fps
  - Gradient dark-purple background
  - Glow/bloom on colored indicators
  - Drop shadow on terminal window
  - CRT scan-line overlay
  - Variable typing speed
  - Scene fade-in/out transitions
  - Progress bar
  - Accessibility captions
  - Floating code particles
  - Elastic spring animation on hook text
  - Thumbnail export
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H   = 1080, 1920
FPS    = 60
OUT_DIR        = "/tmp/ugc-video/frames-short-v2"
THUMBNAIL_PATH = "/tmp/ugc-video/lacy-shell-short-thumbnail.png"
FADE_FRAMES    = 15  # 0.25s

# Colors
BG      = (10,  8, 20)
BG2     = (16, 12, 30)
TERM_BG = (20, 20, 30)
WHITE   = (235, 235, 240)
GRAY    = (130, 130, 145)
DIM     = ( 60,  60,  80)
GREEN   = ( 52, 211, 153)
MAGENTA = (216, 100, 240)
BLUE    = ( 96, 165, 250)
YELLOW  = (250, 204,  21)


# ── Pre-computed assets ──────────────────────────────────────────────────────

_GRADIENT_BG     = None
_SCANLINE_OVERLAY = None

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

def get_scanline_overlay():
    global _SCANLINE_OVERLAY
    if _SCANLINE_OVERLAY is None:
        ol = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d  = ImageDraw.Draw(ol)
        for y in range(0, H, 3):
            d.line([(0, y), (W, y)], fill=(0, 0, 0, 15))
        _SCANLINE_OVERLAY = ol
    return _SCANLINE_OVERLAY

def apply_scanlines(img):
    rgba   = img.convert("RGBA")
    result = Image.alpha_composite(rgba, get_scanline_overlay())
    return result.convert("RGB")

def new_frame():
    return get_gradient_bg()


# ── Math ─────────────────────────────────────────────────────────────────────

def lerp(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3

def ease_in_out(t):
    t = max(0.0, min(1.0, t))
    return 3 * t * t - 2 * t * t * t

def ease_out_elastic(t):
    if t <= 0: return 0.0
    if t >= 1: return 1.0
    c4 = (2 * math.pi) / 3
    return pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1.0


# ── Fonts ────────────────────────────────────────────────────────────────────

def load_font(size, bold=False):
    for p in ["/opt/X11/share/system_fonts/Menlo.ttc", "/System/Library/Fonts/Menlo.ttc"]:
        try:
            return ImageFont.truetype(p, size, index=1 if bold else 0)
        except:
            try:
                return ImageFont.truetype(p, size)
            except:
                continue
    return ImageFont.load_default()

def load_sans(size, bold=False):
    for p in ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(p, size, index=2 if bold else 0)
        except:
            try:
                return ImageFont.truetype(p, size)
            except:
                continue
    return load_font(size, bold)

FONT_BIG     = load_sans(72, True)
FONT_MED     = load_sans(48, True)
FONT_SM      = load_sans(32)
FONT_CAPTION = load_sans(30)
FONT_MONO    = load_font(30)
FONT_MONO_SM = load_font(24)
FONT_MONO_LG = load_font(36, True)


# ── Drawing helpers ───────────────────────────────────────────────────────────

def tw(draw, text, font):
    return draw.textlength(text, font=font)

def center_text(draw, y, text, font, color):
    w = tw(draw, text, font)
    draw.text(((W - w) / 2, y), text, fill=color, font=font)

def rounded_rect(draw, xy, r, fill):
    x0, y0, x1, y1 = xy
    draw.rectangle([x0+r, y0, x1-r, y1], fill=fill)
    draw.rectangle([x0, y0+r, x1, y1-r], fill=fill)
    draw.pieslice([x0,       y0,       x0+2*r, y0+2*r], 180, 270, fill=fill)
    draw.pieslice([x1-2*r,   y0,       x1,     y0+2*r], 270, 360, fill=fill)
    draw.pieslice([x0,       y1-2*r,   x0+2*r, y1    ], 90,  180, fill=fill)
    draw.pieslice([x1-2*r,   y1-2*r,   x1,     y1    ], 0,   90,  fill=fill)

def draw_glow_indicator(img, x, y, color, inner_size=10, glow_size=36):
    r, g, b = color
    glow    = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd      = ImageDraw.Draw(glow)
    for radius, alpha in [(glow_size, 25), (int(glow_size * 0.65), 50), (int(glow_size * 0.35), 80)]:
        gd.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(r, g, b, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=10))
    gd2  = ImageDraw.Draw(glow)
    gd2.ellipse([x - inner_size, y - inner_size, x + inner_size, y + inner_size], fill=(r, g, b, 255))
    rgba   = img.convert("RGBA")
    result = Image.alpha_composite(rgba, glow)
    return result.convert("RGB")

def draw_drop_shadow(img, rect, blur_r=18):
    x0, y0, x1, y1 = rect
    ox, oy = 10, 14
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd     = ImageDraw.Draw(shadow)
    rounded_rect(sd, (x0+ox, y0+oy, x1+ox, y1+oy), 16, (0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur_r))
    rgba   = img.convert("RGBA")
    return Image.alpha_composite(rgba, shadow).convert("RGB")

def draw_particles(img, t, opacity_mult=1.0):
    snippets = ["if [", "&&", "| grep", "$(", "zsh", "bash", "$PATH",
                "~/.zshrc", "export", "alias", "git", "| head", "2>&1",
                "eval", "source", "lash", "claude"]
    rng  = random.Random(99)
    draw = ImageDraw.Draw(img)
    for _ in range(15):
        px      = rng.randint(20, W - 80)
        base_py = rng.randint(0, H)
        speed   = rng.uniform(15, 40)
        py      = int((base_py - t * speed) % H)
        snippet = rng.choice(snippets)
        alpha   = rng.randint(8, 20)
        c       = lerp(BG, GRAY, int(alpha * opacity_mult) / 100)
        try:
            draw.text((px, py), snippet, fill=c, font=FONT_MONO_SM)
        except Exception:
            pass
    return img

def draw_progress_bar(draw, progress, color=MAGENTA):
    y     = H - 12
    bar_w = int(W * max(0.0, min(1.0, progress)))
    draw.rectangle([0, y, W, y + 6], fill=(30, 30, 45))
    if bar_w > 0:
        draw.rectangle([0, y, bar_w, y + 6], fill=color)
    if bar_w > 10:
        draw.ellipse([bar_w - 6, y - 3, bar_w + 6, y + 9], fill=color)

def draw_caption(draw, text, t_in=1.0):
    if t_in <= 0:
        return
    alpha  = min(1.0, t_in)
    y_base = H - 220
    text_w = tw(draw, text, FONT_CAPTION)
    pad    = 24
    bx     = (W - text_w - pad * 2) / 2
    bg_c   = lerp(BG, (25, 25, 40), alpha)
    brd_c  = lerp(BG, (60, 60, 80), alpha * 0.5)
    rounded_rect(draw, (bx-2, y_base-2, bx+text_w+pad*2+2, y_base+46), 10, brd_c)
    rounded_rect(draw, (bx,   y_base,   bx+text_w+pad*2,   y_base+44),  8, bg_c)
    tc = lerp(BG, WHITE, ease_out(alpha))
    draw.text((bx + pad, y_base + 7), text, fill=tc, font=FONT_CAPTION)

def fade_envelope(f, total, fade=FADE_FRAMES):
    if f < fade:
        return ease_out(f / fade)
    remaining = total - f
    if remaining < fade:
        return ease_out(remaining / fade)
    return 1.0

def apply_fade(img, f, total):
    alpha = fade_envelope(f, total)
    if alpha >= 0.99:
        return img
    overlay = Image.new("RGB", (W, H), BG)
    return Image.blend(img, overlay, 1.0 - alpha)


# ── Scenes ────────────────────────────────────────────────────────────────────

def scene_hook(f, total, global_progress):
    """0-2s: Bold hook text with elastic pop-in."""
    img  = new_frame()
    img  = draw_particles(img, f / FPS, opacity_mult=0.6)
    draw = ImageDraw.Draw(img)
    t    = f / total

    lines = [
        ("Stop",           WHITE,  0.00, FONT_BIG, H//2 - 180),
        ("copy-pasting",   WHITE,  0.12, FONT_BIG, H//2 -  80),
        ("into ChatGPT.",  YELLOW, 0.25, FONT_BIG, H//2 +  20),
    ]
    for text, color, delay, font, y in lines:
        lt = max(0.0, min(1.0, (t - delay) / 0.14))
        if lt <= 0:
            continue
        spring = (1.0 - ease_out_elastic(lt)) * 22
        c      = lerp(BG, color, ease_out(lt))
        center_text(draw, y + spring, text, font, c)

    if t > 0.55:
        sub_t = ease_out((t - 0.55) / 0.2)
        c     = lerp(BG, GRAY, sub_t)
        center_text(draw, H//2 + 165, "Just talk to your shell.", FONT_MED, c)

    draw_progress_bar(draw, global_progress, color=GREEN)
    draw_caption(draw, "Stop copy-pasting into ChatGPT.", t_in=max(0.0, (t - 0.5) / 0.25))
    img = apply_scanlines(img)
    return apply_fade(img, f, total)


def scene_demo(f, total, global_progress):
    """2-10s: Terminal demo — git status (green) → explain… (magenta)."""
    img  = new_frame()
    img  = draw_particles(img, f / FPS, opacity_mult=0.4)
    t    = f / total

    margin   = 50
    term_top = 250
    term_h   = 1100

    # Drop shadow
    img  = draw_drop_shadow(img, (margin, term_top, W - margin, term_top + term_h))
    draw = ImageDraw.Draw(img)

    # Terminal window
    rounded_rect(draw, (margin, term_top, W-margin, term_top+term_h), 16, TERM_BG)
    rounded_rect(draw, (margin, term_top, W-margin, term_top+44),     16, (32, 32, 44))
    draw.rectangle([margin, term_top+28, W-margin, term_top+44], fill=(32, 32, 44))
    draw.ellipse([margin+18, term_top+14, margin+32, term_top+28], fill=(255, 95, 87))
    draw.ellipse([margin+42, term_top+14, margin+56, term_top+28], fill=(255, 189, 46))
    draw.ellipse([margin+66, term_top+14, margin+80, term_top+28], fill=(39,  201, 63))
    title_t = "lacy ~"
    ttw     = tw(draw, title_t, FONT_MONO_SM)
    draw.text(((W - ttw) / 2, term_top + 12), title_t, fill=GRAY, font=FONT_MONO_SM)

    cx, cy = margin + 24, term_top + 65

    # ── Phase 1 (0–0.35): "git status" → green ──
    cmd1      = "git status"
    type1_t   = min(1.0, t / 0.2)
    chars1    = int(len(cmd1) * ease_in_out(type1_t))
    ind1_c    = GREEN if chars1 > 0 else GRAY
    prompt_t  = "~ "
    pw        = tw(draw, prompt_t, FONT_MONO)

    if chars1 > 0:
        img  = draw_glow_indicator(img, cx - 2, cy + 14, ind1_c, inner_size=7, glow_size=22)
        draw = ImageDraw.Draw(img)
    else:
        draw.ellipse([cx - 9, cy + 7, cx + 5, cy + 21], fill=ind1_c)

    draw.text((cx + 18, cy), prompt_t, fill=GREEN, font=FONT_MONO)
    draw.text((cx + 18 + pw, cy), cmd1[:chars1], fill=WHITE, font=FONT_MONO)

    # Cursor phase 1
    if t < 0.25:
        cw = tw(draw, cmd1[:chars1], FONT_MONO)
        if (f % 15) < 10 or type1_t < 1:
            bbox = FONT_MONO.getbbox("M")
            draw.rectangle([cx+18+pw+cw, cy-1,
                            cx+18+pw+cw+(bbox[2]-bbox[0]), cy+bbox[3]-bbox[1]+1], fill=WHITE)

    # Shell output
    if t > 0.25:
        out_t = min(1.0, (t - 0.25) / 0.08)
        lines = [
            ("On branch main",          WHITE),
            ("Changes not staged:",     YELLOW),
            ("  modified:   src/app.ts",  (255, 130, 100)),
            ("  modified:   src/utils.ts",(255, 130, 100)),
        ]
        n_show = int(len(lines) * ease_out(out_t))
        for i in range(n_show):
            x_off = int((1.0 - ease_out(min(1.0, out_t * 2 - i * 0.2))) * 18)
            draw.text((cx + 18 + x_off, cy + 44 + i * 36), lines[i][0], fill=lines[i][1], font=FONT_MONO_SM)
        if out_t > 0.5:
            lb_t = ease_out((out_t - 0.5) / 0.5)
            lc   = lerp(BG, GREEN, lb_t)
            lbl  = "→ Shell"
            lw   = tw(draw, lbl, FONT_SM)
            draw.text((W - margin - lw - 20, cy + 2), lbl, fill=lc, font=FONT_SM)

    # ── Phase 2 (0.38–0.75): "explain what changed and why" → magenta ──
    line2_y = cy + 230
    if t > 0.38:
        t2    = (t - 0.38) / 0.35
        cmd2  = "explain what changed and why"
        chars2 = int(len(cmd2) * min(1.0, ease_in_out(t2)))

        if chars2 > 5:
            img  = draw_glow_indicator(img, cx - 2, line2_y + 14, MAGENTA, inner_size=7, glow_size=24)
            draw = ImageDraw.Draw(img)
        elif chars2 > 0:
            blend_c = lerp(GREEN, MAGENTA, chars2 / 5)
            draw.ellipse([cx-9, line2_y+7, cx+5, line2_y+21], fill=blend_c)
        else:
            draw.ellipse([cx-9, line2_y+7, cx+5, line2_y+21], fill=GRAY)

        draw.text((cx + 18, line2_y), "~ ", fill=GREEN, font=FONT_MONO)
        draw.text((cx + 18 + pw, line2_y), cmd2[:chars2], fill=WHITE, font=FONT_MONO)

        if t2 < 1:
            cw2 = tw(draw, cmd2[:chars2], FONT_MONO)
            if (f % 15) < 10:
                bbox = FONT_MONO.getbbox("M")
                draw.rectangle([cx+18+pw+cw2, line2_y-1,
                                cx+18+pw+cw2+(bbox[2]-bbox[0]), line2_y+bbox[3]-bbox[1]+1], fill=WHITE)
        if t2 > 0.5:
            lb2_t = ease_out((t2 - 0.5) / 0.5)
            lc2   = lerp(BG, MAGENTA, lb2_t)
            lbl2  = "→ Agent"
            lw2   = tw(draw, lbl2, FONT_SM)
            draw.text((W - margin - lw2 - 20, line2_y + 2), lbl2, fill=lc2, font=FONT_SM)

    # AI response
    if t > 0.78:
        ai_t   = (t - 0.78) / 0.2
        ai_lines = [
            "The changes in src/app.ts add a",
            "new authentication middleware that",
            "validates JWT tokens before routing.",
            "",
            "src/utils.ts was updated to export",
            "a new `verifyToken()` helper.",
        ]
        n_ai = int(len(ai_lines) * min(1.0, ease_out(ai_t * 1.3)))
        for i in range(n_ai):
            x_off = int((1.0 - ease_out(min(1.0, ai_t * 2 - i * 0.15))) * 20)
            lc_ai = lerp(TERM_BG, MAGENTA, ease_out(ai_t))
            draw.text((cx + 18 + x_off, line2_y + 44 + i * 36), ai_lines[i],
                      fill=lc_ai, font=FONT_MONO_SM)

    # AUTO badge
    rounded_rect(draw, (W - margin - 90, term_top + term_h - 42,
                         W - margin - 10, term_top + term_h - 14), 6, (30, 30, 42))
    draw.text((W - margin - 82, term_top + term_h - 40), "AUTO", fill=BLUE, font=FONT_MONO_SM)

    # Top label
    if t < 0.38:
        lbl_text = "Commands run in your shell"
        lbl_c    = GREEN
    else:
        lbl_text = "Questions go to AI"
        lbl_c    = MAGENTA
    center_text(draw, 170, lbl_text, FONT_SM, lbl_c)

    draw_progress_bar(draw, global_progress, color=lbl_c)
    draw_caption(draw, lbl_text, t_in=min(1.0, t / 0.2))
    img = apply_scanlines(img)
    return apply_fade(img, f, total)


def scene_cta(f, total, global_progress):
    """10-15s: CTA — brand, tagline, install command, feature bullets."""
    img  = new_frame()
    img  = draw_particles(img, f / FPS, opacity_mult=1.1)
    draw = ImageDraw.Draw(img)
    t    = f / total

    # Brand — elastic pop-in
    b_t    = min(1.0, t / 0.2)
    spring = (1.0 - ease_out_elastic(b_t)) * 28
    center_text(draw, H//2 - 220 + spring, "lacy.sh", FONT_BIG, lerp(BG, WHITE, ease_out(b_t)))

    # Tagline
    if t > 0.1:
        tg_t = ease_out((t - 0.1) / 0.2)
        center_text(draw, H//2 - 120, "Talk to your shell.", FONT_MED, lerp(BG, GRAY, tg_t))

    # Install box with glow border
    if t > 0.25:
        bx_t    = ease_out((t - 0.25) / 0.2)
        install = "curl -fsSL lacy.sh/install | bash"
        iw      = tw(draw, install, FONT_MONO_SM) + 50
        bx      = (W - iw) / 2
        by      = H // 2 - 20
        glow_c  = lerp(BG, MAGENTA, bx_t * 0.45)
        rounded_rect(draw, (bx-3, by-3, bx+iw+3, by+53), 13, glow_c)
        rounded_rect(draw, (bx,   by,   bx+iw,   by+50), 10, lerp(BG, (28, 28, 42), bx_t))
        draw.text((bx + 25, by + 12), install, fill=lerp(BG, WHITE, bx_t), font=FONT_MONO_SM)

    # "or" + npx
    if t > 0.4:
        or_t = ease_out((t - 0.4) / 0.15)
        center_text(draw, H//2 + 60, "or",       FONT_SM,   lerp(BG, DIM,  or_t))
        center_text(draw, H//2 +105, "npx lacy", FONT_MONO, lerp(BG, GRAY, or_t))

    # Feature bullets
    if t > 0.55:
        feats = ["ZSH & Bash", "macOS · Linux · WSL", "Works with Claude, Gemini, Codex..."]
        for i, feat in enumerate(feats):
            ft = ease_out(max(0.0, (t - 0.55 - i * 0.06) / 0.15))
            if ft > 0:
                center_text(draw, H//2 + 200 + i * 52, feat, FONT_SM, lerp(BG, DIM, ft))

    # Three colored dots with glow
    if t > 0.7:
        dt = min(1.0, (t - 0.7) / 0.15)
        da = ease_out_elastic(dt)
        for color, ox in [(GREEN, -65), (MAGENTA, 0), (BLUE, 65)]:
            cx_d = W // 2 + ox
            cy_d = H // 2 + 390
            if da > 0.5:
                img  = draw_glow_indicator(img, cx_d, cy_d, color, inner_size=7, glow_size=24)
                draw = ImageDraw.Draw(img)
            else:
                dc = lerp(BG, color, da)
                draw.ellipse([cx_d - 7, cy_d - 7, cx_d + 7, cy_d + 7], fill=dc)

    draw_progress_bar(draw, global_progress, color=MAGENTA)
    draw_caption(draw, "curl -fsSL lacy.sh/install | bash", t_in=max(0.0, (t - 0.4) / 0.3))
    img = apply_scanlines(img)
    return apply_fade(img, f, total)


# ── Main generation ───────────────────────────────────────────────────────────

def generate():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(THUMBNAIL_PATH), exist_ok=True)

    scenes = [
        (scene_hook, 2.0),   # 0-2s
        (scene_demo, 8.0),   # 2-10s
        (scene_cta,  5.0),   # 10-15s
    ]

    total_frames    = int(sum(d for _, d in scenes) * FPS)
    thumbnail_saved = False
    print(f"Generating {total_frames} frames ({total_frames / FPS:.1f}s at {FPS}fps)")

    frame_num = 0
    for i, (fn, dur) in enumerate(scenes):
        n = int(dur * FPS)
        print(f"  Scene {i+1}/{len(scenes)}: {fn.__name__} ({n} frames, {dur:.1f}s)")
        for f in range(n):
            global_progress = (frame_num + 1) / total_frames
            img = fn(f, n, global_progress)
            img.save(os.path.join(OUT_DIR, f"frame_{frame_num:05d}.png"))

            # Thumbnail at CTA ~40%
            if not thumbnail_saved and fn == scene_cta and f == int(n * 0.4):
                img.save(THUMBNAIL_PATH)
                print(f"  → Thumbnail saved: {THUMBNAIL_PATH}")
                thumbnail_saved = True

            frame_num += 1

    print(f"\nDone! {frame_num} frames saved to {OUT_DIR}")
    print(f"\n── Encode commands ──")
    print(f"# Short (60fps):")
    print(f"ffmpeg -framerate {FPS} -i {OUT_DIR}/frame_%05d.png \\")
    print(f"  -c:v libx264 -pix_fmt yuv420p -crf 18 \\")
    print(f"  -y docs/videos/lacy-shell-short-v2.mp4")
    print(f"\n# TikTok/Reels/Shorts (1080x1920 9:16 ✓ — same file works):")
    print(f"# Just rename or copy: lacy-shell-short-v2.mp4")
    print(f"\n# Instagram square variant:")
    print(f"ffmpeg -i docs/videos/lacy-shell-short-v2.mp4 \\")
    print(f"  -vf 'crop=1080:1080:0:420' \\")
    print(f"  -c:v libx264 -pix_fmt yuv420p -crf 20 \\")
    print(f"  -y docs/videos/lacy-shell-short-v2-square.mp4")


if __name__ == "__main__":
    generate()
