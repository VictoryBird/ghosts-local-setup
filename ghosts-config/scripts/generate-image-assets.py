#!/usr/bin/env python3
"""
generate-image-assets.py

Generates all visual image assets for the GHOSTS NPC Framework Meridia scenario:
  - National flags/logos (512x512)
  - News media logos (800x200)
  - Card background images (1200x630, NO text)
  - Country-specific official statement variants
  - Media-specific news variants

Uses Pillow (PIL) only. No external APIs needed.

Usage:
    python3 generate-image-assets.py [--output-dir PATH]
"""

import argparse
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow is required. Install with: pip3 install Pillow")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Font loading
# ---------------------------------------------------------------------------

def load_font(size, bold=False):
    """Load a font with Korean support, falling back gracefully."""
    candidates = [
        # Korean fonts (Ubuntu / common locations)
        "/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf" if bold
        else "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
        "/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf",
        "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
        # DejaVu fallback
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        # macOS fallback
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    # Final fallback: Pillow default
    try:
        return ImageFont.truetype("DejaVuSans.ttf", size)
    except Exception:
        return ImageFont.load_default()


def text_bbox(draw, text, font):
    """Get text bounding box width and height."""
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


# ---------------------------------------------------------------------------
# Color palettes
# ---------------------------------------------------------------------------

COLORS = {
    "valdoria": {"primary": (30, 60, 140), "accent": (218, 175, 50), "bg": (20, 45, 100)},
    "krasnovia": {"primary": (180, 20, 20), "accent": (255, 255, 255), "bg": (160, 15, 15)},
    "tarvek": {"primary": (180, 20, 20), "accent": (255, 210, 40), "bg": (160, 15, 15)},
    "arventa": {"primary": (30, 120, 55), "accent": (255, 255, 255), "bg": (25, 100, 45)},
}


# ===================================================================
# PART 1: National Flags / Logos (512x512)
# ===================================================================

def draw_star(draw, cx, cy, r_outer, r_inner, points, fill):
    """Draw a star polygon."""
    coords = []
    for i in range(points * 2):
        angle = math.pi / 2 + math.pi * i / points
        r = r_outer if i % 2 == 0 else r_inner
        coords.append((cx + r * math.cos(angle), cy - r * math.sin(angle)))
    draw.polygon(coords, fill=fill)


def generate_valdoria_flag(output_dir):
    """Blue/gold shield with star."""
    img = Image.new("RGB", (512, 512), COLORS["valdoria"]["bg"])
    draw = ImageDraw.Draw(img)

    # Shield shape (pentagon-ish)
    shield = [
        (156, 80), (356, 80),
        (380, 120), (380, 300),
        (256, 380),
        (132, 300), (132, 120),
    ]
    draw.polygon(shield, fill=COLORS["valdoria"]["primary"], outline=COLORS["valdoria"]["accent"])
    # Inner shield border
    inner = [
        (170, 95), (342, 95),
        (364, 132), (364, 288),
        (256, 362),
        (148, 288), (148, 132),
    ]
    draw.polygon(inner, outline=COLORS["valdoria"]["accent"], width=3)

    # Star in center
    draw_star(draw, 256, 220, 60, 25, 5, fill=COLORS["valdoria"]["accent"])

    # Text
    font = load_font(42, bold=True)
    tw, th = text_bbox(draw, "VALDORIA", font)
    draw.text(((512 - tw) / 2, 430), "VALDORIA", fill=COLORS["valdoria"]["accent"], font=font)

    path = os.path.join(output_dir, "logos", "valdoria.png")
    img.save(path)
    print(f"  [OK] {path}")


def generate_krasnovia_flag(output_dir):
    """Red background with large white star."""
    img = Image.new("RGB", (512, 512), COLORS["krasnovia"]["bg"])
    draw = ImageDraw.Draw(img)

    # Large white star
    draw_star(draw, 256, 220, 120, 50, 5, fill=(255, 255, 255))

    # Text
    font = load_font(38, bold=True)
    tw, th = text_bbox(draw, "KRASNOVIA", font)
    draw.text(((512 - tw) / 2, 430), "KRASNOVIA", fill=(255, 255, 255), font=font)

    path = os.path.join(output_dir, "logos", "krasnovia.png")
    img.save(path)
    print(f"  [OK] {path}")


def generate_tarvek_flag(output_dir):
    """Red background with yellow fist symbol."""
    img = Image.new("RGB", (512, 512), COLORS["tarvek"]["bg"])
    draw = ImageDraw.Draw(img)
    yellow = COLORS["tarvek"]["accent"]

    # Simple geometric fist: forearm + fist block
    # Forearm (vertical bar)
    draw.rectangle([240, 260, 272, 380], fill=yellow)
    # Fist (wider block on top)
    draw.rectangle([210, 150, 302, 270], fill=yellow)
    # Knuckle bumps
    for x in range(210, 303, 23):
        draw.ellipse([x, 140, x + 22, 165], fill=yellow)
    # Thumb
    draw.rectangle([302, 220, 325, 270], fill=yellow)
    draw.ellipse([302, 210, 330, 240], fill=yellow)

    # Text
    font = load_font(42, bold=True)
    tw, th = text_bbox(draw, "TARVEK", font)
    draw.text(((512 - tw) / 2, 430), "TARVEK", fill=yellow, font=font)

    path = os.path.join(output_dir, "logos", "tarvek.png")
    img.save(path)
    print(f"  [OK] {path}")


def generate_arventa_flag(output_dir):
    """Green background with white olive branch."""
    img = Image.new("RGB", (512, 512), COLORS["arventa"]["bg"])
    draw = ImageDraw.Draw(img)
    white = (255, 255, 255)

    # Simple olive branch: curved stem with leaf pairs
    # Stem (arc approximated by line segments)
    stem_pts = []
    for i in range(20):
        t = i / 19
        x = 200 + 112 * t
        y = 330 - 180 * t + 80 * math.sin(t * math.pi)
        stem_pts.append((x, y))
    for i in range(len(stem_pts) - 1):
        draw.line([stem_pts[i], stem_pts[i + 1]], fill=white, width=4)

    # Leaves along the stem
    for i in range(2, len(stem_pts) - 2, 3):
        cx, cy = stem_pts[i]
        # Left leaf
        draw.ellipse([cx - 28, cy - 8, cx - 4, cy + 8], fill=white)
        # Right leaf
        draw.ellipse([cx + 4, cy - 8, cx + 28, cy + 8], fill=white)

    # Small circle at top (olive fruit)
    tx, ty = stem_pts[-1]
    draw.ellipse([tx - 8, ty - 8, tx + 8, ty + 8], fill=white)

    # Text
    font = load_font(42, bold=True)
    tw, th = text_bbox(draw, "ARVENTA", font)
    draw.text(((512 - tw) / 2, 430), "ARVENTA", fill=white, font=font)

    path = os.path.join(output_dir, "logos", "arventa.png")
    img.save(path)
    print(f"  [OK] {path}")


def generate_all_flags(output_dir):
    print("\n=== Part 1: National Flags/Logos ===")
    os.makedirs(os.path.join(output_dir, "logos"), exist_ok=True)
    generate_valdoria_flag(output_dir)
    generate_krasnovia_flag(output_dir)
    generate_tarvek_flag(output_dir)
    generate_arventa_flag(output_dir)


# ===================================================================
# PART 2: News Media Logos (800x200)
# ===================================================================

def generate_media_logos(output_dir):
    print("\n=== Part 2: News Media Logos ===")
    logos_dir = os.path.join(output_dir, "logos")
    os.makedirs(logos_dir, exist_ok=True)

    # VNB
    img = Image.new("RGB", (800, 200), (15, 35, 100))
    draw = ImageDraw.Draw(img)
    font_big = load_font(80, bold=True)
    font_sm = load_font(24)
    tw, th = text_bbox(draw, "VNB", font_big)
    draw.text(((800 - tw) / 2, 20), "VNB", fill=(255, 255, 255), font=font_big)
    sub = "Valdoria National Broadcasting"
    tw2, _ = text_bbox(draw, sub, font_sm)
    draw.text(((800 - tw2) / 2, 120), sub, fill=(180, 200, 255), font=font_sm)
    path = os.path.join(logos_dir, "vnb.png")
    img.save(path)
    print(f"  [OK] {path}")

    # Elaris Tribune
    img = Image.new("RGB", (800, 200), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    draw.rectangle([4, 4, 795, 195], outline=(40, 40, 40), width=2)
    font_big = load_font(60, bold=True)
    text = "ELARIS TRIBUNE"
    tw, th = text_bbox(draw, text, font_big)
    draw.text(((800 - tw) / 2, (200 - th) / 2 - 10), text, fill=(30, 30, 30), font=font_big)
    # Decorative line
    draw.line([(100, 155), (700, 155)], fill=(30, 30, 30), width=2)
    path = os.path.join(logos_dir, "elaris_tribune.png")
    img.save(path)
    print(f"  [OK] {path}")

    # Krasnovia Today
    img = Image.new("RGB", (800, 200), (180, 20, 20))
    draw = ImageDraw.Draw(img)
    # Yellow accent line at top
    draw.rectangle([0, 0, 800, 8], fill=(255, 210, 40))
    font_big = load_font(56, bold=True)
    text = "KRASNOVIA TODAY"
    tw, th = text_bbox(draw, text, font_big)
    draw.text(((800 - tw) / 2, (200 - th) / 2), text, fill=(255, 255, 255), font=font_big)
    # Yellow accent line at bottom
    draw.rectangle([0, 192, 800, 200], fill=(255, 210, 40))
    path = os.path.join(logos_dir, "krasnovia_today.png")
    img.save(path)
    print(f"  [OK] {path}")

    # MNN
    img = Image.new("RGB", (800, 200), (50, 50, 55))
    draw = ImageDraw.Draw(img)
    font_big = load_font(80, bold=True)
    tw, th = text_bbox(draw, "MNN", font_big)
    draw.text(((800 - tw) / 2, 20), "MNN", fill=(255, 255, 255), font=font_big)
    sub = "Meridia News Network"
    font_sm = load_font(24)
    tw2, _ = text_bbox(draw, sub, font_sm)
    draw.text(((800 - tw2) / 2, 120), sub, fill=(180, 180, 185), font=font_sm)
    path = os.path.join(logos_dir, "mnn.png")
    img.save(path)
    print(f"  [OK] {path}")


# ===================================================================
# PART 3: Card Background Images (1200x630, NO TEXT)
# ===================================================================

def gradient_bg(width, height, color_top, color_bottom):
    """Create a vertical gradient image."""
    img = Image.new("RGB", (width, height))
    for y in range(height):
        r = int(color_top[0] + (color_bottom[0] - color_top[0]) * y / height)
        g = int(color_top[1] + (color_bottom[1] - color_top[1]) * y / height)
        b = int(color_top[2] + (color_bottom[2] - color_top[2]) * y / height)
        ImageDraw.Draw(img).line([(0, y), (width, y)], fill=(r, g, b))
    return img


def generate_card_news(output_dir):
    """News broadcast background - CNN/BBC breaking news screen style."""
    W, H = 1200, 630
    # Dark blue/navy gradient background
    img = gradient_bg(W, H, (12, 30, 80), (5, 15, 50))
    draw = ImageDraw.Draw(img)

    # World map watermark - draw simple continent outlines with circles/dots
    map_color = (18, 40, 95)
    import random
    rng = random.Random(42)  # deterministic
    # Scattered dots suggesting a world map
    for _ in range(300):
        x = rng.randint(50, W - 50)
        y = rng.randint(80, H - 80)
        sz = rng.randint(1, 3)
        draw.ellipse([x, y, x + sz, y + sz], fill=map_color)
    # Globe circle outlines (watermark)
    for r in [120, 160, 200]:
        draw.ellipse([W // 2 - r, H // 2 - r, W // 2 + r, H // 2 + r],
                     outline=(15, 35, 90), width=1)
    # Latitude/longitude lines through globe
    for offset in [-80, -40, 0, 40, 80]:
        draw.line([(W // 2 - 200, H // 2 + offset), (W // 2 + 200, H // 2 + offset)],
                  fill=(15, 35, 90), width=1)
        draw.ellipse([W // 2 - 50 + offset, H // 2 - 200,
                      W // 2 + 50 + offset, H // 2 + 200],
                     outline=(15, 35, 90), width=1)

    # Large red header bar across the top
    draw.rectangle([0, 0, W, 70], fill=(200, 20, 25))
    # "BREAKING NEWS" text in the header bar
    font_header = load_font(42, bold=True)
    tw, th = text_bbox(draw, "BREAKING NEWS", font_header)
    draw.text(((W - tw) / 2, (70 - th) / 2), "BREAKING NEWS",
              fill=(255, 255, 255), font=font_header)

    # Thin white separator lines
    draw.rectangle([0, 70, W, 73], fill=(60, 100, 180))
    draw.rectangle([0, 73, W, 74], fill=(255, 255, 255))

    # Horizontal info bars at different levels
    draw.rectangle([0, 76, W, 78], fill=(40, 70, 140))

    # Bottom ticker bar
    draw.rectangle([0, H - 60, W, H], fill=(20, 20, 25))
    draw.rectangle([0, H - 62, W, H - 60], fill=(200, 20, 25))
    draw.rectangle([0, H - 63, W, H - 62], fill=(255, 255, 255))
    # Ticker dots
    font_ticker = load_font(18)
    for i in range(12):
        x = 30 + i * 100
        draw.rectangle([x, H - 48, x + 60, H - 46], fill=(80, 80, 90))
    # "LIVE" indicator in red box
    draw.rectangle([W - 120, H - 55, W - 30, H - 30], fill=(200, 20, 25))
    font_live = load_font(18, bold=True)
    draw.text((W - 105, H - 53), "LIVE", fill=(255, 255, 255), font=font_live)

    # Side info panel accent lines
    draw.rectangle([0, 80, 4, H - 65], fill=(200, 20, 25))
    draw.rectangle([W - 4, 80, W, H - 65], fill=(30, 60, 130))

    # Thin horizontal separator lines in the content area
    for y in range(130, H - 80, 60):
        draw.line([(40, y), (W - 40, y)], fill=(20, 40, 100), width=1)

    # Small decorative rectangles (data readout feel)
    for y in range(140, H - 90, 60):
        draw.rectangle([50, y + 5, 90, y + 8], fill=(40, 80, 160))
        draw.rectangle([100, y + 5, 180, y + 8], fill=(30, 60, 130))

    path = os.path.join(output_dir, "cards", "card_news.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_official(output_dir):
    """Government official statement - presidential/formal style."""
    W, H = 1200, 630
    # Dark navy to black gradient
    img = gradient_bg(W, H, (10, 20, 55), (3, 5, 20))
    draw = ImageDraw.Draw(img)

    # Seal/watermark pattern in background - repeating small diamonds
    pattern_color = (15, 25, 60)
    for row in range(0, H, 30):
        for col in range(0, W, 30):
            cx, cy = col + 15, row + 15
            sz = 5
            draw.polygon([(cx, cy - sz), (cx + sz, cy),
                          (cx, cy + sz), (cx - sz, cy)], outline=pattern_color)

    gold = (218, 175, 50)
    gold_dim = (140, 110, 30)

    # Large gold decorative double-line border frame (all 4 sides)
    # Outer border
    draw.rectangle([20, 20, W - 20, H - 20], outline=gold, width=3)
    # Inner border
    draw.rectangle([32, 32, W - 32, H - 32], outline=gold_dim, width=2)
    # Corner accents (small squares at corners)
    for cx, cy in [(20, 20), (W - 20, 20), (20, H - 20), (W - 20, H - 20)]:
        draw.rectangle([cx - 8, cy - 8, cx + 8, cy + 8], fill=gold)

    # Gold horizontal lines above and below center emblem area
    draw.rectangle([80, 180, W - 80, 183], fill=gold)
    draw.rectangle([80, 450, W - 80, 453], fill=gold)
    # Thinner accent lines
    draw.rectangle([120, 175, W - 120, 176], fill=gold_dim)
    draw.rectangle([120, 456, W - 120, 457], fill=gold_dim)

    # Centered gold emblem: large shield shape
    cx, cy = W // 2, H // 2
    # Shield outline
    shield = [
        (cx - 80, cy - 100), (cx + 80, cy - 100),
        (cx + 95, cy - 70), (cx + 95, cy + 40),
        (cx, cy + 110),
        (cx - 95, cy + 40), (cx - 95, cy - 70),
    ]
    draw.polygon(shield, fill=(20, 35, 70), outline=gold, width=3)
    # Inner shield border
    inner_shield = [
        (cx - 65, cy - 85), (cx + 65, cy - 85),
        (cx + 78, cy - 58), (cx + 78, cy + 30),
        (cx, cy + 92),
        (cx - 78, cy + 30), (cx - 78, cy - 58),
    ]
    draw.polygon(inner_shield, outline=gold_dim, width=2)

    # Star in center of shield
    draw_star(draw, cx, cy - 15, 40, 18, 5, fill=gold)

    # "OFFICIAL STATEMENT" text below the shield
    font_title = load_font(28, bold=True)
    tw, th = text_bbox(draw, "OFFICIAL STATEMENT", font_title)
    draw.text(((W - tw) / 2, 468), "OFFICIAL STATEMENT", fill=gold, font=font_title)

    # Decorative gold dots along the top and bottom horizontal lines
    for x in range(100, W - 100, 40):
        draw.ellipse([x - 2, 177, x + 2, 181], fill=gold)
        draw.ellipse([x - 2, 452, x + 2, 456], fill=gold)

    # Vertical gold accent lines on sides
    draw.rectangle([50, 50, 53, H - 50], fill=gold_dim)
    draw.rectangle([W - 53, 50, W - 50, H - 50], fill=gold_dim)

    path = os.path.join(output_dir, "cards", "card_official.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_alert(output_dir):
    """Security alert/warning - military/CERT warning screen."""
    W, H = 1200, 630
    # Dark background with orange/amber gradient at edges
    img = Image.new("RGB", (W, H), (25, 20, 15))
    draw = ImageDraw.Draw(img)

    # Orange/amber vignette at edges
    for i in range(80):
        intensity = int(60 * (1 - i / 80))
        edge_color = (intensity, int(intensity * 0.5), 0)
        draw.rectangle([0, i, W, i + 1], fill=edge_color)
        draw.rectangle([0, H - 1 - i, W, H - i], fill=edge_color)
        draw.rectangle([i, 0, i + 1, H], fill=edge_color)
        draw.rectangle([W - 1 - i, 0, W - i, H], fill=edge_color)

    orange = (230, 140, 20)
    black = (15, 12, 8)

    # Diagonal hazard stripes across top bar
    bar_h = 45
    draw.rectangle([0, 0, W, bar_h], fill=black)
    stripe_w = 30
    for i in range(-bar_h, W + bar_h, stripe_w * 2):
        draw.polygon([(i, 0), (i + stripe_w, 0),
                      (i + stripe_w + bar_h, bar_h), (i + bar_h, bar_h)],
                     fill=orange)

    # Diagonal hazard stripes across bottom bar
    draw.rectangle([0, H - bar_h, W, H], fill=black)
    for i in range(-bar_h, W + bar_h, stripe_w * 2):
        draw.polygon([(i, H - bar_h), (i + stripe_w, H - bar_h),
                      (i + stripe_w + bar_h, H), (i + bar_h, H)],
                     fill=orange)

    # "SECURITY ALERT" text at top in orange
    font_alert = load_font(36, bold=True)
    alert_text = "SECURITY ALERT"
    tw, th = text_bbox(draw, alert_text, font_alert)
    # Black backing rectangle for text
    text_y = bar_h + 12
    draw.rectangle([W // 2 - tw // 2 - 20, text_y - 4,
                    W // 2 + tw // 2 + 20, text_y + th + 8], fill=(20, 15, 10))
    draw.text(((W - tw) / 2, text_y), alert_text, fill=orange, font=font_alert)

    # Concentric circles (pulsing effect) around center
    ccx, ccy = W // 2, H // 2 + 15
    for r in [200, 170, 140, 110]:
        draw.ellipse([ccx - r, ccy - r, ccx + r, ccy + r],
                     outline=(80, 50, 10), width=1)
    for r in [185, 155, 125]:
        draw.ellipse([ccx - r, ccy - r, ccx + r, ccy + r],
                     outline=(50, 30, 5), width=1)

    # Large warning triangle in center
    tri_cx, tri_cy = ccx, ccy - 10
    tri_size = 130
    triangle = [
        (tri_cx, tri_cy - tri_size),
        (tri_cx - int(tri_size * 1.15), tri_cy + tri_size),
        (tri_cx + int(tri_size * 1.15), tri_cy + tri_size),
    ]
    draw.polygon(triangle, fill=(240, 160, 20), outline=(255, 200, 40), width=3)
    # Inner triangle (dark fill for contrast)
    inner_size = 105
    inner_offset = 20
    inner_tri = [
        (tri_cx, tri_cy - inner_size + inner_offset),
        (tri_cx - int(inner_size * 1.0), tri_cy + inner_size),
        (tri_cx + int(inner_size * 1.0), tri_cy + inner_size),
    ]
    draw.polygon(inner_tri, fill=(30, 25, 10))

    # Exclamation mark inside triangle (rectangle + circle)
    bang_x = tri_cx
    bang_top = tri_cy - 30
    # Vertical bar of !
    draw.rectangle([bang_x - 10, bang_top, bang_x + 10, bang_top + 100],
                   fill=(240, 160, 20))
    # Dot of !
    draw.ellipse([bang_x - 12, bang_top + 115, bang_x + 12, bang_top + 139],
                 fill=(240, 160, 20))

    # Side accent lines
    draw.rectangle([8, bar_h + 5, 12, H - bar_h - 5], fill=orange)
    draw.rectangle([W - 12, bar_h + 5, W - 8, H - bar_h - 5], fill=orange)

    path = os.path.join(output_dir, "cards", "card_alert.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_ransomware(output_dir):
    """GORGON ransomware background - hacker lock screen aesthetic."""
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), (0, 0, 0))
    draw = ImageDraw.Draw(img)

    import random
    rng = random.Random(99)

    # Matrix-style falling green characters scattered across background
    matrix_chars = "01ABCDEFabcdef@#$%^&*{}[]<>/?|"
    font_matrix = load_font(14)
    for _ in range(500):
        x = rng.randint(0, W)
        y = rng.randint(0, H)
        ch = rng.choice(matrix_chars)
        brightness = rng.randint(20, 120)
        draw.text((x, y), ch, fill=(0, brightness, 0), font=font_matrix)

    # Red scan lines effect across entire image
    for y in range(0, H, 4):
        draw.line([(0, y), (W, y)], fill=(30, 0, 0), width=1)

    # Red border frame
    border_w = 4
    draw.rectangle([0, 0, W - 1, H - 1], outline=(200, 0, 0), width=border_w)
    draw.rectangle([border_w + 2, border_w + 2,
                    W - border_w - 3, H - border_w - 3],
                   outline=(120, 0, 0), width=1)

    # Large red skull in center
    skull_color = (200, 15, 15)
    skull_dark = (0, 0, 0)
    cx, cy = W // 2, H // 2 - 60

    # Head (large ellipse) - bigger: 120x130
    head_rx, head_ry = 120, 130
    draw.ellipse([cx - head_rx, cy - head_ry, cx + head_rx, cy + head_ry],
                 fill=skull_color)
    # Slight highlight on top of skull
    draw.ellipse([cx - 90, cy - head_ry + 10, cx + 90, cy - 20],
                 fill=(220, 25, 25))

    # Eye sockets (large dark holes)
    eye_r = 32
    eye_y = cy - 20
    # Left eye
    draw.ellipse([cx - 52 - eye_r, eye_y - eye_r,
                  cx - 52 + eye_r, eye_y + eye_r], fill=skull_dark)
    # Right eye
    draw.ellipse([cx + 52 - eye_r, eye_y - eye_r,
                  cx + 52 + eye_r, eye_y + eye_r], fill=skull_dark)
    # Red glow inside eyes
    glow_r = 10
    draw.ellipse([cx - 52 - glow_r, eye_y - glow_r,
                  cx - 52 + glow_r, eye_y + glow_r], fill=(255, 0, 0))
    draw.ellipse([cx + 52 - glow_r, eye_y - glow_r,
                  cx + 52 + glow_r, eye_y + glow_r], fill=(255, 0, 0))

    # Nose (inverted triangle hole)
    nose_y = cy + 25
    draw.polygon([(cx - 15, nose_y), (cx + 15, nose_y), (cx, nose_y + 25)],
                 fill=skull_dark)

    # Jaw / teeth area
    jaw_top = cy + head_ry - 50
    jaw_bot = cy + head_ry + 30
    draw.rectangle([cx - 70, jaw_top, cx + 70, jaw_bot], fill=skull_color)
    # Teeth lines (vertical dark lines)
    for tx in range(cx - 60, cx + 61, 20):
        draw.rectangle([tx - 1, jaw_top + 5, tx + 1, jaw_bot - 5],
                       fill=skull_dark)
    # Horizontal line separating upper/lower teeth
    draw.rectangle([cx - 65, jaw_top + 18, cx + 65, jaw_top + 22],
                   fill=skull_dark)

    # "GORGON" text in large red letters below skull
    font_gorgon = load_font(72, bold=True)
    gorgon_text = "GORGON"
    tw, th = text_bbox(draw, gorgon_text, font_gorgon)
    text_y = cy + head_ry + 50
    # Slight glow effect behind text
    draw.text(((W - tw) / 2 + 2, text_y + 2), gorgon_text,
              fill=(100, 0, 0), font=font_gorgon)
    draw.text(((W - tw) / 2, text_y), gorgon_text,
              fill=(220, 0, 0), font=font_gorgon)

    # Additional green matrix characters in the corners (denser)
    for _ in range(100):
        x = rng.randint(0, 150)
        y = rng.randint(0, H)
        ch = rng.choice(matrix_chars)
        draw.text((x, y), ch, fill=(0, rng.randint(60, 160), 0), font=font_matrix)
    for _ in range(100):
        x = rng.randint(W - 150, W)
        y = rng.randint(0, H)
        ch = rng.choice(matrix_chars)
        draw.text((x, y), ch, fill=(0, rng.randint(60, 160), 0), font=font_matrix)

    path = os.path.join(output_dir, "cards", "card_ransomware.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_breaking(output_dir):
    """Breaking news - emergency broadcast style."""
    W, H = 1200, 630
    # Solid red background
    img = Image.new("RGB", (W, H), (210, 15, 15))
    draw = ImageDraw.Draw(img)

    # Slightly varied red fill to avoid flat look
    for y in range(H):
        shade = int(210 - 30 * abs(y - H // 2) / (H // 2))
        draw.line([(0, y), (W, y)], fill=(shade, 10, 10))

    # White starburst lines radiating from center
    center_x, center_y = W // 2, H // 2
    num_rays = 36
    for i in range(num_rays):
        angle = 2 * math.pi * i / num_rays
        end_x = center_x + int(700 * math.cos(angle))
        end_y = center_y + int(400 * math.sin(angle))
        draw.line([(center_x, center_y), (end_x, end_y)],
                  fill=(255, 255, 255, 80), width=2)
    # Second layer of fainter rays
    for i in range(num_rays):
        angle = 2 * math.pi * (i + 0.5) / num_rays
        end_x = center_x + int(700 * math.cos(angle))
        end_y = center_y + int(400 * math.sin(angle))
        draw.line([(center_x, center_y), (end_x, end_y)],
                  fill=(230, 100, 100), width=1)

    # Top and bottom black bars (cinematic widescreen)
    draw.rectangle([0, 0, W, 70], fill=(10, 10, 10))
    draw.rectangle([0, H - 70, W, H], fill=(10, 10, 10))
    # Red accent lines at bar edges
    draw.rectangle([0, 68, W, 72], fill=(255, 50, 50))
    draw.rectangle([0, H - 72, W, H - 68], fill=(255, 50, 50))

    # Large "BREAKING NEWS" text centered
    font_breaking = load_font(96, bold=True)
    bt = "BREAKING NEWS"
    tw, th = text_bbox(draw, bt, font_breaking)
    # Shadow
    draw.text(((W - tw) / 2 + 3, (H - th) / 2 + 3), bt,
              fill=(80, 0, 0), font=font_breaking)
    # Main text
    draw.text(((W - tw) / 2, (H - th) / 2), bt,
              fill=(255, 255, 255), font=font_breaking)

    # Small clock/timestamp decorative element in top bar
    font_time = load_font(20, bold=True)
    draw.text((30, 25), "LIVE", fill=(255, 50, 50), font=font_time)
    # Blinking dot next to LIVE
    draw.ellipse([90, 30, 102, 42], fill=(255, 50, 50))
    # Fake timestamp on right side of top bar
    draw.text((W - 180, 25), "00:00 UTC", fill=(180, 180, 180), font=font_time)

    # Decorative elements in bottom bar
    font_sm = load_font(16)
    for i in range(8):
        x = 40 + i * 145
        draw.rectangle([x, H - 50, x + 100, H - 48], fill=(80, 80, 80))

    path = os.path.join(output_dir, "cards", "card_breaking.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_alliance(output_dir):
    """Alliance/support - diplomatic event backdrop style."""
    W, H = 1200, 630
    # Blue to white gradient
    img = gradient_bg(W, H, (40, 80, 160), (200, 220, 245))
    draw = ImageDraw.Draw(img)

    # Thin gold border
    gold = (200, 170, 50)
    draw.rectangle([8, 8, W - 8, H - 8], outline=gold, width=3)

    # Two large flag placeholder rectangles side by side
    flag_w, flag_h = 250, 170
    flag_y = 120
    gap = 100
    left_x = W // 2 - gap // 2 - flag_w
    right_x = W // 2 + gap // 2

    # Valdoria blue flag placeholder (semi-transparent fill)
    draw.rectangle([left_x, flag_y, left_x + flag_w, flag_y + flag_h],
                   fill=(30, 60, 140, 180), outline=(50, 80, 160), width=3)
    # Inner accent
    draw.rectangle([left_x + 8, flag_y + 8,
                    left_x + flag_w - 8, flag_y + flag_h - 8],
                   outline=(80, 110, 190), width=1)
    # Small star in Valdoria flag
    draw_star(draw, left_x + flag_w // 2, flag_y + flag_h // 2,
              30, 12, 5, fill=(218, 175, 50))

    # Arventa green flag placeholder
    draw.rectangle([right_x, flag_y, right_x + flag_w, flag_y + flag_h],
                   fill=(30, 120, 55, 180), outline=(40, 140, 65), width=3)
    draw.rectangle([right_x + 8, flag_y + 8,
                    right_x + flag_w - 8, flag_y + flag_h - 8],
                   outline=(60, 160, 85), width=1)
    # Small olive branch in Arventa flag
    stem_cx = right_x + flag_w // 2
    stem_cy = flag_y + flag_h // 2
    for i in range(8):
        t = i / 7
        sx = stem_cx - 20 + 40 * t
        sy = stem_cy + 15 - 30 * t + 10 * math.sin(t * math.pi)
        draw.ellipse([int(sx) - 6, int(sy) - 3, int(sx) + 6, int(sy) + 3],
                     fill=(255, 255, 255))

    # Handshake symbol in center between flags
    hx, hy = W // 2, flag_y + flag_h // 2
    # Left arm (angled rectangle)
    arm_pts_l = [(hx - 50, hy - 15), (hx - 10, hy - 25),
                 (hx - 5, hy - 10), (hx - 45, hy)]
    draw.polygon(arm_pts_l, fill=(60, 90, 150))
    # Right arm
    arm_pts_r = [(hx + 50, hy - 15), (hx + 10, hy - 25),
                 (hx + 5, hy - 10), (hx + 45, hy)]
    draw.polygon(arm_pts_r, fill=(40, 130, 65))
    # Hands meeting (overlapping area)
    draw.ellipse([hx - 18, hy - 25, hx + 18, hy - 5], fill=(220, 200, 140))

    # Olive branch elements at bottom
    branch_y = H - 140
    branch_cx = W // 2
    # Left branch
    for i in range(12):
        t = i / 11
        bx = branch_cx - 200 + 200 * t
        by = branch_y + 40 * math.sin(t * math.pi)
        draw.ellipse([int(bx) - 8, int(by) - 4, int(bx) + 8, int(by) + 4],
                     fill=(50, 130, 70))
        if i < 11:
            bx2 = branch_cx - 200 + 200 * ((i + 1) / 11)
            by2 = branch_y + 40 * math.sin(((i + 1) / 11) * math.pi)
            draw.line([(int(bx), int(by)), (int(bx2), int(by2))],
                      fill=(40, 100, 55), width=2)
    # Right branch (mirrored)
    for i in range(12):
        t = i / 11
        bx = branch_cx + 200 * t
        by = branch_y + 40 * math.sin(t * math.pi)
        draw.ellipse([int(bx) - 8, int(by) - 4, int(bx) + 8, int(by) + 4],
                     fill=(50, 130, 70))
        if i < 11:
            bx2 = branch_cx + 200 * ((i + 1) / 11)
            by2 = branch_y + 40 * math.sin(((i + 1) / 11) * math.pi)
            draw.line([(int(bx), int(by)), (int(bx2), int(by2))],
                      fill=(40, 100, 55), width=2)

    # Bottom decorative bar
    draw.rectangle([40, H - 60, W - 40, H - 57], fill=gold)

    path = os.path.join(output_dir, "cards", "card_alliance.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_all_cards(output_dir):
    """Generate all 6 base card backgrounds."""
    print("\n=== Part 3: Card Background Images (NO TEXT) ===")
    cards_dir = os.path.join(output_dir, "cards")
    os.makedirs(cards_dir, exist_ok=True)

    cards = {}
    cards["news"] = generate_card_news(output_dir)
    cards["official"] = generate_card_official(output_dir)
    cards["alert"] = generate_card_alert(output_dir)
    cards["ransomware"] = generate_card_ransomware(output_dir)
    cards["breaking"] = generate_card_breaking(output_dir)
    cards["alliance"] = generate_card_alliance(output_dir)
    return cards


# ===================================================================
# PART 4: Country-specific and Media-specific Variants
# ===================================================================

def load_logo_image(logo_path, size):
    """Load a logo image and resize it, return as RGBA."""
    if not os.path.exists(logo_path):
        return None
    logo = Image.open(logo_path).convert("RGBA")
    logo = logo.resize(size, Image.LANCZOS)
    return logo


def generate_official_variants(output_dir, card_official):
    """Generate card_official_<country>.png with country logo and accent line."""
    print("\n=== Part 4a: Country-specific Official Statement Variants ===")
    countries = {
        "valdoria": COLORS["valdoria"]["primary"],
        "krasnovia": COLORS["krasnovia"]["primary"],
        "tarvek": COLORS["tarvek"]["primary"],
        "arventa": COLORS["arventa"]["primary"],
    }
    for country, accent_color in countries.items():
        logo_path = os.path.join(output_dir, "logos", f"{country}.png")
        logo = load_logo_image(logo_path, (100, 100))

        # Start from a copy of the official card
        img = card_official.copy()
        draw = ImageDraw.Draw(img)

        # Thin accent line at the top in the country's primary color
        draw.rectangle([0, 0, img.width, 6], fill=accent_color)

        if logo:
            # Paste logo in top-left corner
            img.paste(logo, (30, 30), logo)

        filename = f"card_official_{country}.png"
        path = os.path.join(output_dir, "cards", filename)
        img.save(path)
        print(f"  [OK] {path}")


def generate_news_variants(output_dir, card_news):
    """Generate card_news_<media>.png with media logo and brand tinting."""
    print("\n=== Part 4b: Media-specific News Variants ===")
    media_map = {
        "vnb": {"logo": "vnb.png", "color": (15, 35, 100)},
        "krasnovia_today": {"logo": "krasnovia_today.png", "color": (180, 20, 20)},
        "elaris_tribune": {"logo": "elaris_tribune.png", "color": (40, 40, 40)},
        "mnn": {"logo": "mnn.png", "color": (50, 50, 55)},
    }
    for media_key, info in media_map.items():
        logo_path = os.path.join(output_dir, "logos", info["logo"])
        # Bigger logo: 300x75
        logo = load_logo_image(logo_path, (300, 75))

        # Start from a copy of the news card
        img = card_news.copy()
        draw = ImageDraw.Draw(img)

        # Tint the header bar to match the media's brand color
        draw.rectangle([0, 0, img.width, 70], fill=info["color"])
        # Re-draw the separator lines
        draw.rectangle([0, 70, img.width, 73], fill=(60, 100, 180))
        draw.rectangle([0, 73, img.width, 74], fill=(255, 255, 255))

        if logo:
            # Paste logo in top-left corner (overlaying the header bar)
            img.paste(logo, (20, -2), logo)

        filename = f"card_news_{media_key}.png"
        path = os.path.join(output_dir, "cards", filename)
        img.save(path)
        print(f"  [OK] {path}")


# ===================================================================
# Main
# ===================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Generate image assets for GHOSTS NPC Framework"
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "..", "image-assets"),
        help="Output directory for generated images"
    )
    args = parser.parse_args()

    output_dir = os.path.abspath(args.output_dir)
    print(f"Output directory: {output_dir}")
    os.makedirs(output_dir, exist_ok=True)

    # Part 1: National flags/logos (4 images)
    generate_all_flags(output_dir)

    # Part 2: News media logos (4 images)
    generate_media_logos(output_dir)

    # Part 3: Base card backgrounds (6 images)
    cards = generate_all_cards(output_dir)

    # Part 4: Variants with logos overlaid (4 + 4 = 8 images)
    generate_official_variants(output_dir, cards["official"])
    generate_news_variants(output_dir, cards["news"])

    # Count total files
    total = 0
    for root, dirs, files in os.walk(output_dir):
        total += len([f for f in files if f.endswith(".png")])

    print(f"\n=== Done! Generated {total} image assets in {output_dir} ===")


if __name__ == "__main__":
    main()
