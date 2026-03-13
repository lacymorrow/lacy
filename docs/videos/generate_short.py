#!/usr/bin/env python3
"""
Generate frames for Lacy Shell UGC SHORT video (15s).
Quick hook → single demo → CTA. Maximum shareability.
Vertical 1080x1920 for TikTok/Reels/Shorts.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
FPS = 30
OUT_DIR = "/tmp/ugc-video/frames-short"
os.makedirs(OUT_DIR, exist_ok=True)

# Colors
BG = (13, 13, 15)
TERM_BG = (22, 22, 28)
WHITE = (235, 235, 240)
GRAY = (130, 130, 145)
DIM = (80, 80, 95)
GREEN = (52, 211, 153)
MAGENTA = (216, 100, 240)
BLUE = (96, 165, 250)
YELLOW = (250, 204, 21)

def load_font(size, bold=False):
    paths = ["/opt/X11/share/system_fonts/Menlo.ttc", "/System/Library/Fonts/Menlo.ttc"]
    for p in paths:
        try:
            return ImageFont.truetype(p, size, index=1 if bold else 0)
        except:
            try:
                return ImageFont.truetype(p, size)
            except:
                continue
    return ImageFont.load_default()

def load_sans(size, bold=False):
    for p in ["/System/Library/Fonts/SFNS.ttf"]:
        try:
            return ImageFont.truetype(p, size, index=2 if bold else 0)
        except:
            try:
                return ImageFont.truetype(p, size)
            except:
                continue
    return load_font(size, bold)

FONT_BIG = load_sans(72, True)
FONT_MED = load_sans(48, True)
FONT_SM = load_sans(32)
FONT_MONO = load_font(30)
FONT_MONO_SM = load_font(24)
FONT_MONO_LG = load_font(36, True)

def ease_out(t): return 1 - (1 - min(1, max(0, t))) ** 3
def ease_in_out(t): return 3 * t * t - 2 * t * t * t if t < 1 else 1

def lerp(c1, c2, t):
    t = max(0, min(1, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def rounded_rect(draw, xy, r, fill):
    x0, y0, x1, y1 = xy
    draw.rectangle([x0+r, y0, x1-r, y1], fill=fill)
    draw.rectangle([x0, y0+r, x1, y1-r], fill=fill)
    draw.pieslice([x0, y0, x0+2*r, y0+2*r], 180, 270, fill=fill)
    draw.pieslice([x1-2*r, y0, x1, y0+2*r], 270, 360, fill=fill)
    draw.pieslice([x0, y1-2*r, x0+2*r, y1], 90, 180, fill=fill)
    draw.pieslice([x1-2*r, y1-2*r, x1, y1], 0, 90, fill=fill)

def tw(draw, text, font):
    return draw.textlength(text, font=font)

def center_text(draw, y, text, font, color):
    w = tw(draw, text, font)
    draw.text(((W - w) / 2, y), text, fill=color, font=font)

# === Scenes ===

def scene_hook(f, total):
    """0-2s: Bold hook text"""
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    t = f / total

    # "Stop" - pops in
    if t < 0.5:
        s_t = ease_out(t / 0.15)
        c = lerp(BG, WHITE, s_t)
        center_text(draw, H//2 - 180, "Stop", FONT_BIG, c)

    # "copy-pasting" - slides in
    if t > 0.12:
        c_t = ease_out((t - 0.12) / 0.15)
        c = lerp(BG, WHITE, c_t)
        center_text(draw, H//2 - 80, "copy-pasting", FONT_BIG, c)

    # "into ChatGPT" — in yellow
    if t > 0.25:
        g_t = ease_out((t - 0.25) / 0.15)
        c = lerp(BG, YELLOW, g_t)
        center_text(draw, H//2 + 20, "into ChatGPT.", FONT_BIG, c)

    # Subtext
    if t > 0.55:
        sub_t = ease_out((t - 0.55) / 0.2)
        c = lerp(BG, GRAY, sub_t)
        center_text(draw, H//2 + 160, "Just talk to your shell.", FONT_MED, c)

    return img


def scene_demo(f, total):
    """2-10s: Terminal demo — type command, then type NL query"""
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    t = f / total

    margin = 50
    term_top = 250
    term_h = 1100

    # Terminal window
    rounded_rect(draw, (margin, term_top, W-margin, term_top+term_h), 16, TERM_BG)
    # Title bar
    rounded_rect(draw, (margin, term_top, W-margin, term_top+44), 16, (35, 35, 45))
    draw.rectangle([margin, term_top+30, W-margin, term_top+44], fill=(35, 35, 45))
    draw.ellipse([margin+18, term_top+14, margin+32, term_top+28], fill=(255, 95, 87))
    draw.ellipse([margin+42, term_top+14, margin+56, term_top+28], fill=(255, 189, 46))
    draw.ellipse([margin+66, term_top+14, margin+80, term_top+28], fill=(39, 201, 63))

    title = "lacy ~"
    ttw = tw(draw, title, FONT_MONO_SM)
    draw.text(((W-ttw)/2, term_top+12), title, fill=GRAY, font=FONT_MONO_SM)

    cx, cy = margin + 24, term_top + 65

    # Phase 1 (0-0.35): Type "git status" → green indicator → shell output
    cmd1 = "git status"
    type1_t = min(1, t / 0.2)
    chars1 = int(len(cmd1) * ease_in_out(type1_t))

    # Indicator
    if chars1 > 0:
        ind_c = GREEN
    else:
        ind_c = GRAY
    draw.ellipse([cx-2, cy+8, cx+12, cy+22], fill=ind_c)

    prompt_text = "~ "
    draw.text((cx + 20, cy), prompt_text, fill=GREEN, font=FONT_MONO)
    pw = tw(draw, prompt_text, FONT_MONO)
    draw.text((cx + 20 + pw, cy), cmd1[:chars1], fill=WHITE, font=FONT_MONO)

    # Cursor for cmd1
    if t < 0.25:
        cw = tw(draw, cmd1[:chars1], FONT_MONO)
        if (f % 15) < 10 or type1_t < 1:
            bbox = FONT_MONO.getbbox("M")
            draw.rectangle([cx+20+pw+cw, cy-1, cx+20+pw+cw+(bbox[2]-bbox[0]), cy+bbox[3]-bbox[1]+1], fill=WHITE)

    # Shell output for git status
    if t > 0.25:
        out_t = min(1, (t - 0.25) / 0.08)
        lines = [
            ("On branch main", WHITE),
            ("Changes not staged:", YELLOW),
            ("  modified:   src/app.ts", (255, 130, 100)),
            ("  modified:   src/utils.ts", (255, 130, 100)),
        ]
        n_show = int(len(lines) * ease_out(out_t))
        for i in range(n_show):
            draw.text((cx + 20, cy + 44 + i * 36), lines[i][0], fill=lines[i][1], font=FONT_MONO_SM)

        # Green "SHELL" label
        if out_t > 0.5:
            lb_t = ease_out((out_t - 0.5) / 0.5)
            lc = lerp(BG, GREEN, lb_t)
            lbl = "→ Shell"
            lw = tw(draw, lbl, FONT_SM)
            draw.text((W - margin - lw - 20, cy + 2), lbl, fill=lc, font=FONT_SM)

    # Phase 2 (0.4-0.75): Type NL query → magenta indicator → AI response
    line2_y = cy + 230
    if t > 0.38:
        t2 = (t - 0.38) / 0.35
        cmd2 = "explain what changed and why"
        chars2 = int(len(cmd2) * min(1, ease_in_out(t2)))

        # Magenta indicator (transitions from green)
        if chars2 > 5:
            ind2_c = MAGENTA
        elif chars2 > 0:
            blend = chars2 / 5
            ind2_c = lerp(GREEN, MAGENTA, blend)
        else:
            ind2_c = GRAY
        draw.ellipse([cx-2, line2_y+8, cx+12, line2_y+22], fill=ind2_c)

        draw.text((cx+20, line2_y), "~ ", fill=GREEN, font=FONT_MONO)
        draw.text((cx+20+pw, line2_y), cmd2[:chars2], fill=WHITE, font=FONT_MONO)

        # Cursor
        if t2 < 1:
            cw2 = tw(draw, cmd2[:chars2], FONT_MONO)
            if (f % 15) < 10:
                bbox = FONT_MONO.getbbox("M")
                draw.rectangle([cx+20+pw+cw2, line2_y-1, cx+20+pw+cw2+(bbox[2]-bbox[0]), line2_y+bbox[3]-bbox[1]+1], fill=WHITE)

        # Magenta "AGENT" label
        if t2 > 0.5:
            lb2_t = ease_out((t2 - 0.5) / 0.5)
            lc2 = lerp(BG, MAGENTA, lb2_t)
            draw.text((W - margin - tw(draw, "→ Agent", FONT_SM) - 20, line2_y + 2), "→ Agent", fill=lc2, font=FONT_SM)

    # AI response
    if t > 0.78:
        ai_t = (t - 0.78) / 0.2
        ai_lines = [
            "The changes in src/app.ts add a",
            "new authentication middleware that",
            "validates JWT tokens before routing.",
            "",
            "src/utils.ts was updated to export",
            "a new `verifyToken()` helper that",
            "the middleware depends on.",
        ]
        n_ai = int(len(ai_lines) * min(1, ease_out(ai_t * 1.3)))
        for i in range(n_ai):
            lc_ai = lerp(TERM_BG, MAGENTA, ease_out(ai_t))
            draw.text((cx + 20, line2_y + 44 + i * 36), ai_lines[i], fill=lc_ai, font=FONT_MONO_SM)

    # Mode badge
    rounded_rect(draw, (W-margin-90, term_top+term_h-42, W-margin-10, term_top+term_h-14), 6, (30, 30, 42))
    draw.text((W-margin-82, term_top+term_h-40), "AUTO", fill=BLUE, font=FONT_MONO_SM)

    # Top label
    if t < 0.38:
        lbl_text = "Commands run in your shell"
        lbl_c = GREEN
    else:
        lbl_text = "Questions go to AI"
        lbl_c = MAGENTA
    ltw = tw(draw, lbl_text, FONT_SM)
    center_text(draw, 170, lbl_text, FONT_SM, lbl_c)

    return img


def scene_cta(f, total):
    """10-15s: CTA"""
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    t = f / total

    # Brand
    b_t = ease_out(t / 0.2)
    center_text(draw, H//2 - 220, "lacy.sh", FONT_BIG, lerp(BG, WHITE, b_t))

    # Tagline
    if t > 0.1:
        tg_t = ease_out((t - 0.1) / 0.2)
        center_text(draw, H//2 - 120, "Talk to your shell.", FONT_MED, lerp(BG, GRAY, tg_t))

    # Install box
    if t > 0.25:
        bx_t = ease_out((t - 0.25) / 0.2)
        install = "curl -fsSL lacy.sh/install | bash"
        iw = tw(draw, install, FONT_MONO_SM) + 50
        bx = (W - iw) / 2
        by = H//2 - 20
        rounded_rect(draw, (bx-2, by-2, bx+iw+2, by+52), 12, lerp(BG, MAGENTA, bx_t * 0.4))
        rounded_rect(draw, (bx, by, bx+iw, by+50), 10, lerp(BG, (30, 30, 42), bx_t))
        draw.text((bx+25, by+12), install, fill=lerp(BG, WHITE, bx_t), font=FONT_MONO_SM)

    # "or" + npx
    if t > 0.4:
        or_t = ease_out((t - 0.4) / 0.15)
        center_text(draw, H//2 + 60, "or", FONT_SM, lerp(BG, DIM, or_t))
        center_text(draw, H//2 + 105, "npx lacy", FONT_MONO, lerp(BG, GRAY, or_t))

    # Features
    if t > 0.55:
        feats = ["ZSH & Bash", "macOS · Linux · WSL", "Works with Claude, Gemini, Codex..."]
        for i, feat in enumerate(feats):
            ft = ease_out((t - 0.55 - i * 0.06) / 0.15)
            if ft > 0:
                center_text(draw, H//2 + 200 + i * 50, feat, FONT_SM, lerp(BG, DIM, ft))

    # Colored dots
    if t > 0.7:
        dt = ease_out((t - 0.7) / 0.15)
        for color, ox in [(GREEN, -60), (MAGENTA, 0), (BLUE, 60)]:
            dc = lerp(BG, color, dt)
            draw.ellipse([W//2+ox-6, H//2+380, W//2+ox+6, H//2+392], fill=dc)

    return img


# === Generate ===

def generate():
    scenes = [
        (scene_hook, 2.0),    # 0-2s
        (scene_demo, 8.0),    # 2-10s
        (scene_cta, 5.0),     # 10-15s
    ]

    frame_num = 0
    total_frames = int(sum(d for _, d in scenes) * FPS)
    print(f"Generating {total_frames} frames ({total_frames/FPS:.1f}s at {FPS}fps)")

    for i, (fn, dur) in enumerate(scenes):
        n = int(dur * FPS)
        print(f"  Scene {i+1}/{len(scenes)}: {fn.__name__} ({n} frames)")
        for f in range(n):
            img = fn(f, n)
            img.save(os.path.join(OUT_DIR, f"frame_{frame_num:05d}.png"))
            frame_num += 1

    print(f"Done! {frame_num} frames")


if __name__ == "__main__":
    generate()
