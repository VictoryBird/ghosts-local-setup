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
    """News article background - white/light gray with red ticker bar."""
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), (245, 245, 248))
    draw = ImageDraw.Draw(img)

    # Thin red banner at top (news ticker bar)
    draw.rectangle([0, 0, W, 12], fill=(200, 25, 25))

    # Subtle grid/line pattern for newspaper feel
    grid_color = (230, 230, 233)
    # Horizontal lines
    for y in range(40, H - 40, 30):
        draw.line([(60, y), (W - 60, y)], fill=grid_color, width=1)
    # Vertical column dividers
    for x in [400, 800]:
        draw.line([(x, 40), (x, H - 40)], fill=grid_color, width=1)

    # Bottom thin gray bar
    draw.rectangle([0, H - 14, W, H], fill=(200, 200, 205))

    path = os.path.join(output_dir, "cards", "card_news.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_official(output_dir):
    """Official statement background - dark navy/blue gradient."""
    W, H = 1200, 630
    img = gradient_bg(W, H, (15, 25, 70), (5, 10, 40))
    draw = ImageDraw.Draw(img)

    # Subtle geometric pattern (diamond watermark grid)
    pattern_color = (20, 35, 80)
    spacing = 60
    for row in range(0, H, spacing):
        for col in range(0, W, spacing):
            cx, cy = col + spacing // 2, row + spacing // 2
            size = 8
            diamond = [(cx, cy - size), (cx + size, cy),
                       (cx, cy + size), (cx - size, cy)]
            draw.polygon(diamond, outline=pattern_color)

    # Gold/yellow horizontal accent line near bottom
    draw.rectangle([80, H - 80, W - 80, H - 76], fill=(218, 175, 50))

    path = os.path.join(output_dir, "cards", "card_official.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_alert(output_dir):
    """Security alert background - dark charcoal with warning triangle."""
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), (35, 35, 40))
    draw = ImageDraw.Draw(img)

    # Orange horizontal stripes at top (hazard style)
    stripe_color = (230, 140, 20)
    for i in range(0, W, 40):
        draw.polygon([(i, 0), (i + 20, 0), (i + 20, 16), (i, 16)],
                     fill=stripe_color)

    # Orange horizontal stripes at bottom (hazard style)
    for i in range(0, W, 40):
        draw.polygon([(i + 10, H - 16), (i + 30, H - 16),
                      (i + 30, H), (i, H)],
                     fill=stripe_color)

    # Large yellow/orange warning triangle centered
    tri_cx, tri_cy = W // 2, H // 2 - 20
    tri_size = 160
    triangle = [
        (tri_cx, tri_cy - tri_size),
        (tri_cx - int(tri_size * 1.15), tri_cy + tri_size),
        (tri_cx + int(tri_size * 1.15), tri_cy + tri_size),
    ]
    draw.polygon(triangle, fill=(240, 180, 20), outline=(255, 200, 40))
    # Inner triangle (hollow effect)
    inner_size = 130
    inner_tri = [
        (tri_cx, tri_cy - inner_size + 15),
        (tri_cx - int(inner_size * 1.0), tri_cy + inner_size),
        (tri_cx + int(inner_size * 1.0), tri_cy + inner_size),
    ]
    draw.polygon(inner_tri, fill=(35, 35, 40))

    path = os.path.join(output_dir, "cards", "card_alert.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_ransomware(output_dir):
    """GORGON ransomware background - black with red vignette and skull."""
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), (10, 10, 10))
    draw = ImageDraw.Draw(img)

    # Dark red vignette edges (approximate with rectangles fading from edges)
    for i in range(40):
        alpha = int(60 * (1 - i / 40))
        r_val = alpha
        edge_color = (r_val, 0, 0)
        # Top edge
        draw.rectangle([0, i, W, i + 1], fill=edge_color)
        # Bottom edge
        draw.rectangle([0, H - 1 - i, W, H - i], fill=edge_color)
        # Left edge
        draw.rectangle([i, 0, i + 1, H], fill=edge_color)
        # Right edge
        draw.rectangle([W - 1 - i, 0, W - i, H], fill=edge_color)

    # Simple skull drawn with circles/ellipses in red, centered
    skull_color = (180, 20, 20)
    cx, cy = W // 2, H // 2 - 40

    # Head (large ellipse)
    head_rx, head_ry = 80, 90
    draw.ellipse([cx - head_rx, cy - head_ry, cx + head_rx, cy + head_ry],
                 fill=skull_color)

    # Eye circles (dark holes)
    eye_r = 22
    eye_y = cy - 15
    draw.ellipse([cx - 40 - eye_r, eye_y - eye_r,
                  cx - 40 + eye_r, eye_y + eye_r], fill=(10, 10, 10))
    draw.ellipse([cx + 40 - eye_r, eye_y - eye_r,
                  cx + 40 + eye_r, eye_y + eye_r], fill=(10, 10, 10))

    # Jaw arc (lower part of skull)
    jaw_top = cy + head_ry - 30
    draw.arc([cx - 60, jaw_top, cx + 60, jaw_top + 70],
             start=0, end=180, fill=skull_color, width=12)

    # Red accent lines at top and bottom
    draw.rectangle([0, 0, W, 5], fill=(200, 20, 20))
    draw.rectangle([0, H - 5, W, H], fill=(200, 20, 20))

    path = os.path.join(output_dir, "cards", "card_ransomware.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_breaking(output_dir):
    """Breaking news background - bright red with white center bar."""
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), (200, 15, 15))
    draw = ImageDraw.Draw(img)

    # Subtle diagonal lines pattern
    line_color = (185, 10, 10)
    for i in range(-H, W + H, 30):
        draw.line([(i, 0), (i + H, H)], fill=line_color, width=1)

    # White horizontal bar across the center
    bar_y = H // 2 - 50
    bar_h = 100
    draw.rectangle([0, bar_y, W, bar_y + bar_h], fill=(255, 255, 255))

    path = os.path.join(output_dir, "cards", "card_breaking.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_card_alliance(output_dir):
    """Alliance/support background - light blue to white gradient."""
    W, H = 1200, 630
    img = gradient_bg(W, H, (180, 215, 245), (245, 248, 255))
    draw = ImageDraw.Draw(img)

    # Two rectangular placeholder areas side by side at top (flag space outlines)
    box_w, box_h = 180, 120
    box_y = 80
    left_x = W // 2 - box_w - 80
    right_x = W // 2 + 80

    draw.rectangle([left_x, box_y, left_x + box_w, box_y + box_h],
                   outline=(60, 100, 160), width=3)
    draw.rectangle([right_x, box_y, right_x + box_w, box_y + box_h],
                   outline=(60, 100, 160), width=3)

    # Horizontal line connecting them (symbolizing alliance)
    line_y = box_y + box_h // 2
    draw.line([(left_x + box_w, line_y), (right_x, line_y)],
              fill=(60, 100, 160), width=3)

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
    """Generate card_official_<country>.png with country logo overlaid."""
    print("\n=== Part 4a: Country-specific Official Statement Variants ===")
    countries = ["valdoria", "krasnovia", "tarvek", "arventa"]
    for country in countries:
        logo_path = os.path.join(output_dir, "logos", f"{country}.png")
        logo = load_logo_image(logo_path, (100, 100))

        # Start from a copy of the official card
        img = card_official.copy()

        if logo:
            # Paste logo in top-left corner
            img.paste(logo, (30, 30), logo)

        filename = f"card_official_{country}.png"
        path = os.path.join(output_dir, "cards", filename)
        img.save(path)
        print(f"  [OK] {path}")


def generate_news_variants(output_dir, card_news):
    """Generate card_news_<media>.png with media logo overlaid."""
    print("\n=== Part 4b: Media-specific News Variants ===")
    media_map = {
        "vnb": "vnb.png",
        "krasnovia_today": "krasnovia_today.png",
        "elaris_tribune": "elaris_tribune.png",
        "mnn": "mnn.png",
    }
    for media_key, logo_file in media_map.items():
        logo_path = os.path.join(output_dir, "logos", logo_file)
        # Media logos are 800x200, scale down to fit top-left (200x50)
        logo = load_logo_image(logo_path, (200, 50))

        # Start from a copy of the news card
        img = card_news.copy()

        if logo:
            # Paste logo in top-left corner (below the red banner)
            img.paste(logo, (20, 20), logo)

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
