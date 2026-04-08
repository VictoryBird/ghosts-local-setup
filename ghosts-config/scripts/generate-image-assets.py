#!/usr/bin/env python3
"""
generate-image-assets.py

Generates all visual image assets for the GHOSTS NPC Framework Meridia scenario:
  - National flags/logos (512x512)
  - News media logos (800x200)
  - Image card templates (1200x630)
  - Phase-specific image cards with Korean text

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
# PART 3: Image Card Templates (1200x630)
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


def template_official_statement(output_dir):
    """Dark blue gradient, flag placeholder, watermark."""
    img = gradient_bg(1200, 630, (15, 25, 70), (5, 10, 40))
    draw = ImageDraw.Draw(img)
    font_sm = load_font(20)
    font_md = load_font(28)

    # Flag placeholder box
    draw.rectangle([50, 30, 170, 150], outline=(100, 130, 200), width=2)
    tw, _ = text_bbox(draw, "[국기 위치]", font_sm)
    draw.text(((220 - tw) / 2, 80), "[국기 위치]", fill=(100, 130, 200), font=font_sm)

    # Center text area border
    draw.rectangle([80, 180, 1120, 500], outline=(60, 90, 160), width=1)

    # Watermark
    font_wm = load_font(36, bold=True)
    tw, _ = text_bbox(draw, "공식 성명", font_wm)
    draw.text(((1200 - tw) / 2, 560), "공식 성명", fill=(50, 70, 130), font=font_wm)

    path = os.path.join(output_dir, "cards", "template_official_statement.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def template_news_article(output_dir):
    """White bg, red breaking news banner."""
    img = Image.new("RGB", (1200, 630), (245, 245, 248))
    draw = ImageDraw.Draw(img)

    # Red banner at top
    draw.rectangle([0, 0, 1200, 70], fill=(200, 25, 25))
    font_banner = load_font(32, bold=True)
    tw, _ = text_bbox(draw, "BREAKING NEWS", font_banner)
    draw.text(((1200 - tw) / 2, 18), "BREAKING NEWS", fill=(255, 255, 255), font=font_banner)

    # Headline area
    draw.rectangle([60, 120, 1140, 450], outline=(200, 200, 205), width=1)

    # Media logo placeholder at bottom
    draw.rectangle([40, 530, 260, 610], outline=(180, 180, 185), width=1)
    font_sm = load_font(16)
    draw.text((55, 560), "[media logo]", fill=(160, 160, 165), font=font_sm)

    path = os.path.join(output_dir, "cards", "template_news_article.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def template_security_alert(output_dir):
    """Dark bg with warning triangle."""
    img = Image.new("RGB", (1200, 630), (25, 25, 30))
    draw = ImageDraw.Draw(img)

    # Warning triangle
    tri = [(600, 40), (530, 140), (670, 140)]
    draw.polygon(tri, fill=(240, 180, 20), outline=(255, 200, 40))
    # Exclamation mark inside triangle
    font_exc = load_font(60, bold=True)
    draw.text((585, 55), "!", fill=(25, 25, 30), font=font_exc)

    # Header
    font_hdr = load_font(36, bold=True)
    hdr_text = "보안 경고"
    tw, _ = text_bbox(draw, hdr_text, font_hdr)
    draw.text(((1200 - tw) / 2, 155), hdr_text, fill=(240, 180, 20), font=font_hdr)

    # Alert text area
    draw.rectangle([60, 220, 1140, 550], outline=(80, 70, 20), width=1)

    path = os.path.join(output_dir, "cards", "template_security_alert.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def template_ransomware(output_dir):
    """Black bg with red accents and skull."""
    img = Image.new("RGB", (1200, 630), (10, 10, 10))
    draw = ImageDraw.Draw(img)

    # Skull (simple geometric)
    # Head (ellipse)
    draw.ellipse([530, 30, 670, 180], fill=(200, 200, 200))
    # Eyes
    draw.ellipse([555, 80, 590, 115], fill=(10, 10, 10))
    draw.ellipse([610, 80, 645, 115], fill=(10, 10, 10))
    # Nose
    draw.polygon([(595, 120), (605, 120), (600, 140)], fill=(10, 10, 10))
    # Jaw / teeth area
    draw.rectangle([555, 150, 645, 175], fill=(200, 200, 200))
    for x in range(560, 645, 14):
        draw.line([(x, 150), (x, 175)], fill=(10, 10, 10), width=2)
    # Crossbones
    draw.line([(490, 140), (710, 210)], fill=(200, 200, 200), width=6)
    draw.line([(710, 140), (490, 210)], fill=(200, 200, 200), width=6)
    for bx, by in [(490, 140), (710, 140), (490, 210), (710, 210)]:
        draw.ellipse([bx - 8, by - 8, bx + 8, by + 8], fill=(200, 200, 200))

    # GORGON text
    font_gorgon = load_font(64, bold=True)
    tw, _ = text_bbox(draw, "GORGON", font_gorgon)
    draw.text(((1200 - tw) / 2, 230), "GORGON", fill=(200, 20, 20), font=font_gorgon)

    # Red accent lines
    draw.rectangle([0, 0, 1200, 5], fill=(200, 20, 20))
    draw.rectangle([0, 625, 1200, 630], fill=(200, 20, 20))

    # Countdown area
    draw.rectangle([350, 480, 850, 570], outline=(200, 20, 20), width=2)
    font_count = load_font(28)
    ct = "[COUNTDOWN]"
    tw, _ = text_bbox(draw, ct, font_count)
    draw.text(((1200 - tw) / 2, 510), ct, fill=(200, 20, 20), font=font_count)

    path = os.path.join(output_dir, "cards", "template_ransomware.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def template_alliance_support(output_dir):
    """Light blue gradient, two flag placeholders."""
    img = gradient_bg(1200, 630, (180, 215, 245), (140, 185, 225))
    draw = ImageDraw.Draw(img)

    # Two flag placeholders side by side
    draw.rectangle([200, 80, 400, 280], outline=(60, 100, 160), width=2)
    draw.rectangle([800, 80, 1000, 280], outline=(60, 100, 160), width=2)

    font_sm = load_font(20)
    draw.text((250, 170), "[국기 1]", fill=(60, 100, 160), font=font_sm)
    draw.text((850, 170), "[국기 2]", fill=(60, 100, 160), font=font_sm)

    # Handshake / connector
    draw.line([(400, 180), (800, 180)], fill=(60, 100, 160), width=3)

    # Text
    font_hdr = load_font(40, bold=True)
    tw, _ = text_bbox(draw, "연대 성명", font_hdr)
    draw.text(((1200 - tw) / 2, 340), "연대 성명", fill=(30, 60, 120), font=font_hdr)

    # Text area
    draw.rectangle([100, 400, 1100, 580], outline=(60, 100, 160), width=1)

    path = os.path.join(output_dir, "cards", "template_alliance_support.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def template_breaking_news(output_dir):
    """Red banner with ticker bar."""
    img = Image.new("RGB", (1200, 630), (240, 240, 245))
    draw = ImageDraw.Draw(img)

    # Red banner at top
    draw.rectangle([0, 0, 1200, 90], fill=(200, 15, 15))
    font_banner = load_font(52, bold=True)
    tw, _ = text_bbox(draw, "속보", font_banner)
    draw.text(((1200 - tw) / 2, 16), "속보", fill=(255, 255, 255), font=font_banner)

    # White text area center
    draw.rectangle([50, 120, 1150, 500], fill=(255, 255, 255), outline=(220, 220, 225), width=1)

    # Ticker bar at bottom
    draw.rectangle([0, 560, 1200, 630], fill=(30, 30, 35))
    draw.rectangle([0, 558, 1200, 562], fill=(200, 15, 15))
    font_ticker = load_font(22)
    draw.text((20, 580), "BREAKING  |  LIVE  |  속보", fill=(200, 200, 205), font=font_ticker)

    path = os.path.join(output_dir, "cards", "template_breaking_news.png")
    img.save(path)
    print(f"  [OK] {path}")
    return img


def generate_all_templates(output_dir):
    print("\n=== Part 3: Image Card Templates ===")
    os.makedirs(os.path.join(output_dir, "cards"), exist_ok=True)
    templates = {}
    templates["official_statement"] = template_official_statement(output_dir)
    templates["news_article"] = template_news_article(output_dir)
    templates["security_alert"] = template_security_alert(output_dir)
    templates["ransomware"] = template_ransomware(output_dir)
    templates["alliance_support"] = template_alliance_support(output_dir)
    templates["breaking_news"] = template_breaking_news(output_dir)
    return templates


# ===================================================================
# PART 4: Phase-specific Image Cards
# ===================================================================

# Card definitions: (phase, index, template_type, text, source_label_or_none)
PHASE_CARDS = [
    # Phase 2
    (2, 1, "news_article",
     "시로스 해협 인근 군사훈련 개시 — 긴장 고조", None),
    (2, 2, "news_article",
     "발도리아 정부 IT 시스템 접속 장애 발생", None),
    (2, 3, "official_statement",
     "[크라스노비아 국방위원회]\n자위권 차원의 정례 군사훈련", "krasnovia"),

    # Phase 3
    (3, 1, "news_article",
     "발도리아 사이버 보안 예산 30% 삭감 의혹", None),
    (3, 2, "security_alert",
     "수도권 정수 시설 이상 징후 감지", None),
    (3, 3, "official_statement",
     "[타르벡 인민위원회]\n크라스노비아의 정당한 주권 행사 지지", "tarvek"),
    (3, 4, "news_article",
     "산업제어시스템 취약점 다수 발견 — 전문가 경고", None),

    # Phase 4
    (4, 1, "breaking_news",
     "속보: 발도리아 정부 이메일 서버 해킹 확인", None),
    (4, 2, "official_statement",
     "[크라스노비아 정부]\n시로스 해협 군사훈련 확대 성명", "krasnovia"),
    (4, 3, "ransomware",
     "GORGON — 발도리아 정부 데이터 확보 완료", None),
    (4, 4, "official_statement",
     "[아르벤타 정부]\n동맹국 발도리아에 전폭적 지지", "arventa"),
    (4, 5, "news_article",
     "개인정보 대량 유출 우려 — 시민 불안 확산", None),
    (4, 6, "security_alert",
     "국가 사이버 위기 경보 상향 조정", None),

    # Phase 5
    (5, 1, "breaking_news",
     "속보: 군사 기밀 대량 유출, 국방력 심각한 타격", None),
    (5, 2, "official_statement",
     "[가짜] 국방장관 긴급 성명\n— 보안 체계 전면 실패 인정", "valdoria"),
    (5, 3, "news_article",
     "내부 고발자: 군 보안 시스템 수년간 방치", None),
    (5, 4, "official_statement",
     "[크라스노비아 정부]\n사이버 공격 관여 전면 부인", "krasnovia"),
    (5, 5, "security_alert",
     "군 내부 정보 유출 사건 긴급 조사 착수", None),
    (5, 6, "news_article",
     "Krasnovia Today: 발도리아 국방력 와해, 동맹 신뢰 흔들려", None),

    # Phase 6
    (6, 1, "ransomware",
     "GORGON — 48시간 내 몸값 미지불 시\n전체 데이터 공개", None),
    (6, 2, "breaking_news",
     "속보: 발도리아 전 정부 시스템 마비", None),
    (6, 3, "official_statement",
     "[크라스노비아 정부]\n발도리아는 국민 보호 능력 상실. 항복 권고", "krasnovia"),
    (6, 4, "official_statement",
     "[SCC]\n발도리아의 사이버 보안 실패는 자초한 결과", None),
    (6, 5, "official_statement",
     "[타르벡 정부]\n발도리아의 도발이 이 사태를 초래", "tarvek"),
    (6, 6, "news_article",
     "Krasnovia Today: 국가 기능 정지, 시민 대피 시작", None),
    (6, 7, "breaking_news",
     "정부 고위층 비상 대피 계획 유출", None),
    (6, 8, "ransomware",
     "GORGON — 카운트다운 시작. Tick Tock.", None),
]


def load_country_logo(output_dir, country):
    """Load a country logo if it exists, return resized copy."""
    if not country:
        return None
    path = os.path.join(output_dir, "logos", f"{country}.png")
    if os.path.exists(path):
        logo = Image.open(path).convert("RGBA")
        logo = logo.resize((100, 100), Image.LANCZOS)
        return logo
    return None


def render_card_official_statement(output_dir, text, country):
    """Render official_statement card with text and optional country logo."""
    img = gradient_bg(1200, 630, (15, 25, 70), (5, 10, 40))
    draw = ImageDraw.Draw(img)

    # Country logo
    logo = load_country_logo(output_dir, country)
    if logo:
        # Paste logo (need to handle RGBA)
        img.paste(logo, (50, 30), logo)
    else:
        # Flag placeholder
        draw.rectangle([50, 30, 150, 130], outline=(100, 130, 200), width=2)

    # Main text
    font_text = load_font(38, bold=True)
    lines = text.split("\n")
    y = 200
    for line in lines:
        tw, th = text_bbox(draw, line, font_text)
        draw.text(((1200 - tw) / 2, y), line, fill=(220, 230, 255), font=font_text)
        y += th + 20

    # Watermark
    font_wm = load_font(30, bold=True)
    tw, _ = text_bbox(draw, "공식 성명", font_wm)
    draw.text(((1200 - tw) / 2, 565), "공식 성명", fill=(40, 55, 110), font=font_wm)

    return img


def render_card_news_article(output_dir, text, country):
    """Render news_article card."""
    img = Image.new("RGB", (1200, 630), (245, 245, 248))
    draw = ImageDraw.Draw(img)

    # Red banner
    draw.rectangle([0, 0, 1200, 70], fill=(200, 25, 25))
    font_banner = load_font(32, bold=True)
    tw, _ = text_bbox(draw, "BREAKING NEWS", font_banner)
    draw.text(((1200 - tw) / 2, 18), "BREAKING NEWS", fill=(255, 255, 255), font=font_banner)

    # Headline text
    font_text = load_font(36, bold=True)
    lines = text.split("\n")
    y = 200
    for line in lines:
        # Word-wrap long lines
        words = list(line)
        current = ""
        for ch in line:
            test = current + ch
            tw, _ = text_bbox(draw, test, font_text)
            if tw > 1040:
                ctw, cth = text_bbox(draw, current, font_text)
                draw.text(((1200 - ctw) / 2, y), current, fill=(30, 30, 35), font=font_text)
                y += cth + 10
                current = ch
            else:
                current = test
        if current:
            ctw, cth = text_bbox(draw, current, font_text)
            draw.text(((1200 - ctw) / 2, y), current, fill=(30, 30, 35), font=font_text)
            y += cth + 20

    # Bottom line
    draw.line([(40, 540), (1160, 540)], fill=(200, 200, 205), width=1)

    # Media logo placeholder
    font_sm = load_font(18)
    draw.text((50, 560), "MNN | Meridia News Network", fill=(140, 140, 145), font=font_sm)

    return img


def render_card_security_alert(output_dir, text, country):
    """Render security_alert card."""
    img = Image.new("RGB", (1200, 630), (25, 25, 30))
    draw = ImageDraw.Draw(img)

    # Warning triangle
    tri = [(600, 30), (540, 120), (660, 120)]
    draw.polygon(tri, fill=(240, 180, 20), outline=(255, 200, 40))
    font_exc = load_font(50, bold=True)
    draw.text((585, 48), "!", fill=(25, 25, 30), font=font_exc)

    # Header
    font_hdr = load_font(34, bold=True)
    hdr = "보안 경고"
    tw, _ = text_bbox(draw, hdr, font_hdr)
    draw.text(((1200 - tw) / 2, 140), hdr, fill=(240, 180, 20), font=font_hdr)

    # Alert text
    font_text = load_font(34, bold=True)
    lines = text.split("\n")
    y = 260
    for line in lines:
        tw, th = text_bbox(draw, line, font_text)
        draw.text(((1200 - tw) / 2, y), line, fill=(255, 220, 100), font=font_text)
        y += th + 20

    # Bottom warning bars
    for yy in [560, 575, 590]:
        draw.rectangle([100, yy, 1100, yy + 5], fill=(240, 180, 20))

    return img


def render_card_ransomware(output_dir, text, country):
    """Render ransomware card."""
    img = Image.new("RGB", (1200, 630), (10, 10, 10))
    draw = ImageDraw.Draw(img)

    # Red accent lines
    draw.rectangle([0, 0, 1200, 5], fill=(200, 20, 20))
    draw.rectangle([0, 625, 1200, 630], fill=(200, 20, 20))

    # Skull
    draw.ellipse([545, 20, 655, 130], fill=(180, 180, 180))
    draw.ellipse([565, 55, 590, 80], fill=(10, 10, 10))
    draw.ellipse([610, 55, 635, 80], fill=(10, 10, 10))
    draw.polygon([(597, 85), (603, 85), (600, 100)], fill=(10, 10, 10))
    draw.rectangle([565, 108, 635, 128], fill=(180, 180, 180))
    for x in range(570, 635, 11):
        draw.line([(x, 108), (x, 128)], fill=(10, 10, 10), width=2)

    # GORGON
    font_gorgon = load_font(50, bold=True)
    tw, _ = text_bbox(draw, "GORGON", font_gorgon)
    draw.text(((1200 - tw) / 2, 150), "GORGON", fill=(200, 20, 20), font=font_gorgon)

    # Main text
    font_text = load_font(32, bold=True)
    lines = text.split("\n")
    y = 280
    for line in lines:
        tw, th = text_bbox(draw, line, font_text)
        draw.text(((1200 - tw) / 2, y), line, fill=(220, 50, 50), font=font_text)
        y += th + 18

    # Glitch effect lines
    import random
    random.seed(42)
    for _ in range(15):
        gy = random.randint(0, 630)
        gw = random.randint(50, 300)
        gx = random.randint(0, 1200 - gw)
        draw.rectangle([gx, gy, gx + gw, gy + 2], fill=(200, 20, 20, 60))

    return img


def render_card_breaking_news(output_dir, text, country):
    """Render breaking_news card."""
    img = Image.new("RGB", (1200, 630), (240, 240, 245))
    draw = ImageDraw.Draw(img)

    # Red banner
    draw.rectangle([0, 0, 1200, 90], fill=(200, 15, 15))
    font_banner = load_font(52, bold=True)
    tw, _ = text_bbox(draw, "속보", font_banner)
    draw.text(((1200 - tw) / 2, 16), "속보", fill=(255, 255, 255), font=font_banner)

    # White card area
    draw.rectangle([50, 120, 1150, 500], fill=(255, 255, 255), outline=(220, 220, 225), width=1)

    # Text
    font_text = load_font(38, bold=True)
    lines = text.split("\n")
    # Filter out "속보:" prefix if it starts with it (already in banner)
    y = 220
    for line in lines:
        display = line
        if display.startswith("속보: ") or display.startswith("속보:"):
            display = display.replace("속보: ", "").replace("속보:", "")
        if not display.strip():
            continue
        # Simple word wrap for long text
        current = ""
        for ch in display:
            test = current + ch
            tw_test, _ = text_bbox(draw, test, font_text)
            if tw_test > 1020:
                ctw, cth = text_bbox(draw, current, font_text)
                draw.text(((1200 - ctw) / 2, y), current, fill=(30, 30, 35), font=font_text)
                y += cth + 10
                current = ch
            else:
                current = test
        if current:
            ctw, cth = text_bbox(draw, current, font_text)
            draw.text(((1200 - ctw) / 2, y), current, fill=(30, 30, 35), font=font_text)
            y += cth + 20

    # Ticker bar
    draw.rectangle([0, 560, 1200, 630], fill=(30, 30, 35))
    draw.rectangle([0, 558, 1200, 562], fill=(200, 15, 15))
    font_ticker = load_font(22)
    draw.text((20, 580), "BREAKING  |  LIVE  |  속보", fill=(200, 200, 205), font=font_ticker)

    return img


RENDERERS = {
    "official_statement": render_card_official_statement,
    "news_article": render_card_news_article,
    "security_alert": render_card_security_alert,
    "ransomware": render_card_ransomware,
    "breaking_news": render_card_breaking_news,
}


def generate_phase_cards(output_dir):
    print("\n=== Part 4: Phase-specific Image Cards ===")

    for phase, idx, tpl_type, text, country in PHASE_CARDS:
        phase_dir = os.path.join(output_dir, "cards", f"phase{phase}")
        os.makedirs(phase_dir, exist_ok=True)

        renderer = RENDERERS.get(tpl_type)
        if not renderer:
            print(f"  [SKIP] Unknown template type: {tpl_type}")
            continue

        img = renderer(output_dir, text, country)
        filename = f"{idx:03d}_{tpl_type}.png"
        path = os.path.join(phase_dir, filename)
        img.save(path)
        print(f"  [OK] phase{phase}/{filename}")


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

    generate_all_flags(output_dir)
    generate_media_logos(output_dir)
    generate_all_templates(output_dir)
    generate_phase_cards(output_dir)

    # Count total files
    total = 0
    for root, dirs, files in os.walk(output_dir):
        total += len([f for f in files if f.endswith(".png")])

    print(f"\n=== Done! Generated {total} image assets in {output_dir} ===")


if __name__ == "__main__":
    main()
