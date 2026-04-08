#!/usr/bin/env python3
"""
generate-image-assets.py - DALL-E based image asset generator

Generates all visual image assets for the GHOSTS NPC Framework Meridia scenario:
  - National flags/logos (1024x1024) via DALL-E 3
  - News media logos (1792x1024) via DALL-E 3
  - Card background images (1792x1024) via DALL-E 3
  - Country-specific official statement variants (Pillow overlay)
  - Media-specific news variants (Pillow overlay)

Usage:
    python3 generate-image-assets.py --api-key sk-... [--output-dir PATH] [--force]
"""

import argparse
import json
import math
import os
import sys
import time
import urllib.request

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow required. Install with: pip3 install Pillow")
    sys.exit(1)

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai required. Install with: pip3 install openai")
    sys.exit(1)


# ---------------------------------------------------------------------------
# DALL-E helper
# ---------------------------------------------------------------------------

def generate_dalle_image(client, prompt, size, output_path, force=False):
    """Generate image with DALL-E and save."""
    if os.path.exists(output_path) and not force:
        print(f"  [SKIP] Already exists: {output_path}")
        return True

    print(f"  Generating: {os.path.basename(output_path)}...")
    try:
        response = client.images.generate(
            model="dall-e-3", size=size, quality="standard", n=1, prompt=prompt
        )
        image_url = response.data[0].url
        req = urllib.request.Request(image_url)
        with urllib.request.urlopen(req, timeout=60) as resp:
            with open(output_path, "wb") as f:
                f.write(resp.read())
        print(f"  [OK] {output_path}")
        time.sleep(1)  # Rate limiting
        return True
    except Exception as e:
        print(f"  [FAIL] {e}")
        return False


# ---------------------------------------------------------------------------
# Logo helper for overlays
# ---------------------------------------------------------------------------

def load_logo_image(logo_path, size):
    """Load a logo image and resize it, return as RGBA."""
    if not os.path.exists(logo_path):
        return None
    logo = Image.open(logo_path).convert("RGBA")
    logo = logo.resize(size, Image.LANCZOS)
    return logo


# ===================================================================
# PART 1: National Flags / Logos (1024x1024)
# ===================================================================

FLAG_PROMPTS = {
    "valdoria.png": (
        "Official national emblem of a fictional democratic republic called "
        "Valdoria. Blue and gold color scheme. Majestic eagle with spread wings "
        "on a heraldic shield with a star at top. Formal coat of arms style on "
        "dark background. No text, no letters, clean design."
    ),
    "krasnovia.png": (
        "Official national emblem of a fictional socialist federation. Red and "
        "black color scheme. Large white five-pointed star with hammer and sickle "
        "motif. Soviet-inspired heraldic style on dark red background. No text, "
        "no letters, clean design."
    ),
    "tarvek.png": (
        "Official national emblem of a fictional revolutionary socialist republic. "
        "Red and yellow color scheme. Raised fist inside a gear/cog wheel. "
        "Communist propaganda poster style on dark red background. No text, no "
        "letters, clean design."
    ),
    "arventa.png": (
        "Official national emblem of a fictional peaceful democratic republic. "
        "Green and white color scheme. Olive branch wreath surrounding a dove. "
        "Diplomatic seal style on dark green background. No text, no letters, "
        "clean design."
    ),
}


def generate_all_flags(client, output_dir, force):
    """Generate national flag/logo images with DALL-E."""
    print("\n=== Part 1: National Flags/Logos ===")
    logos_dir = os.path.join(output_dir, "logos")
    os.makedirs(logos_dir, exist_ok=True)

    for filename, prompt in FLAG_PROMPTS.items():
        path = os.path.join(logos_dir, filename)
        generate_dalle_image(client, prompt, "1024x1024", path, force)


# ===================================================================
# PART 2: News Media Logos (1792x1024)
# ===================================================================

MEDIA_PROMPTS = {
    "vnb.png": (
        "Professional TV news channel logo design. Text 'VNB' in large bold "
        "white letters on dark blue background. Subtitle 'Valdoria National "
        "Broadcasting' below in smaller text. Modern broadcast network style. "
        "Clean graphic design."
    ),
    "elaris_tribune.png": (
        "Classic newspaper masthead logo design. Text 'ELARIS TRIBUNE' in "
        "elegant serif black letters on white background with thin decorative "
        "border. Traditional broadsheet newspaper style. Clean design."
    ),
    "krasnovia_today.png": (
        "State media news channel logo design. Text 'KRASNOVIA TODAY' in bold "
        "white letters on bright red background with yellow accent lines. "
        "Propaganda-inspired but modern broadcast style. Clean design."
    ),
    "mnn.png": (
        "International news network logo design. Text 'MNN' in large bold white "
        "letters on dark gray background. Subtitle 'Meridia News Network' below. "
        "CNN/BBC inspired global news style. Clean design."
    ),
}


def generate_media_logos(client, output_dir, force):
    """Generate news media logo images with DALL-E."""
    print("\n=== Part 2: News Media Logos ===")
    logos_dir = os.path.join(output_dir, "logos")
    os.makedirs(logos_dir, exist_ok=True)

    for filename, prompt in MEDIA_PROMPTS.items():
        path = os.path.join(logos_dir, filename)
        generate_dalle_image(client, prompt, "1792x1024", path, force)


# ===================================================================
# PART 3: Card Background Images (1792x1024, NO TEXT)
# ===================================================================

CARD_PROMPTS = {
    "card_news.png": (
        "Professional TV news broadcast background graphic. Dark blue gradient "
        "with subtle globe wireframe, concentric circles, and news ticker bar "
        "at bottom. Modern broadcast studio style. No text, no logos, no people. "
        "Clean graphic design only."
    ),
    "card_official.png": (
        "Official government press conference backdrop. Dark navy blue gradient "
        "with elegant gold decorative borders, formal podium area, and subtle "
        "geometric patterns. Diplomatic and authoritative atmosphere. No text, "
        "no logos, no people."
    ),
    "card_alert.png": (
        "Cybersecurity alert warning screen background. Dark charcoal background "
        "with glowing orange warning triangle, digital grid lines, and hazard "
        "stripe borders. Urgent and threatening atmosphere. No text, no logos, "
        "no people."
    ),
    "card_ransomware.png": (
        "Ransomware attack screen background. Pure black background with red "
        "glowing skull icon, falling green matrix code effect, and red scan "
        "lines. Dark cyberpunk hacker aesthetic. No text, no logos, no people."
    ),
    "card_breaking.png": (
        "Breaking news broadcast emergency screen background. Bright red "
        "background with dynamic white light burst effects, dramatic lighting, "
        "and news broadcast visual elements. Urgent breaking news atmosphere. "
        "No text, no logos, no people."
    ),
    "card_alliance.png": (
        "Diplomatic alliance ceremony backdrop. Elegant light blue to white "
        "gradient with two podium areas side by side, handshake visual element, "
        "olive branches, and gold accents. Peaceful diplomatic atmosphere. "
        "No text, no logos, no people."
    ),
}


def generate_all_cards(client, output_dir, force):
    """Generate all 6 base card backgrounds with DALL-E."""
    print("\n=== Part 3: Card Background Images (NO TEXT) ===")
    cards_dir = os.path.join(output_dir, "cards")
    os.makedirs(cards_dir, exist_ok=True)

    for filename, prompt in CARD_PROMPTS.items():
        path = os.path.join(cards_dir, filename)
        generate_dalle_image(client, prompt, "1792x1024", path, force)


# ===================================================================
# PART 4: Country-specific and Media-specific Variants (Pillow overlay)
# ===================================================================

def generate_official_variants(output_dir):
    """Generate card_official_<country>.png with country logo overlay."""
    print("\n=== Part 4a: Country-specific Official Statement Variants ===")
    cards_dir = os.path.join(output_dir, "cards")
    base_path = os.path.join(cards_dir, "card_official.png")

    if not os.path.exists(base_path):
        print(f"  [SKIP] Base card not found: {base_path}")
        return

    countries = ["valdoria", "krasnovia", "tarvek", "arventa"]

    for country in countries:
        logo_path = os.path.join(output_dir, "logos", f"{country}.png")
        logo = load_logo_image(logo_path, (120, 120))

        # Start from a copy of the official card
        img = Image.open(base_path).convert("RGBA")

        if logo:
            # Paste logo in top-left corner with padding
            img.paste(logo, (30, 30), logo)

        filename = f"card_official_{country}.png"
        path = os.path.join(cards_dir, filename)
        img.convert("RGB").save(path)
        print(f"  [OK] {path}")


def generate_news_variants(output_dir):
    """Generate card_news_<media>.png with media logo overlay."""
    print("\n=== Part 4b: Media-specific News Variants ===")
    cards_dir = os.path.join(output_dir, "cards")
    base_path = os.path.join(cards_dir, "card_news.png")

    if not os.path.exists(base_path):
        print(f"  [SKIP] Base card not found: {base_path}")
        return

    media_logos = ["vnb", "krasnovia_today", "elaris_tribune", "mnn"]

    for media_key in media_logos:
        logo_path = os.path.join(output_dir, "logos", f"{media_key}.png")
        logo = load_logo_image(logo_path, (300, 80))

        # Start from a copy of the news card
        img = Image.open(base_path).convert("RGBA")

        if logo:
            # Paste logo in top-left corner with padding
            img.paste(logo, (30, 30), logo)

        filename = f"card_news_{media_key}.png"
        path = os.path.join(cards_dir, filename)
        img.convert("RGB").save(path)
        print(f"  [OK] {path}")


# ===================================================================
# Main
# ===================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Generate image assets for GHOSTS NPC Framework using DALL-E 3"
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("OPENAI_API_KEY", ""),
        help="OpenAI API key (or set OPENAI_API_KEY env var)"
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "..", "image-assets"),
        help="Output directory for generated images"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate images even if they already exist"
    )
    args = parser.parse_args()

    if not args.api_key:
        print("ERROR: OpenAI API key required. Use --api-key or set OPENAI_API_KEY.")
        sys.exit(1)

    client = OpenAI(api_key=args.api_key)

    output_dir = os.path.abspath(args.output_dir)
    print(f"Output directory: {output_dir}")
    os.makedirs(output_dir, exist_ok=True)

    # Part 1: National flags/logos (4 images)
    generate_all_flags(client, output_dir, args.force)

    # Part 2: News media logos (4 images)
    generate_media_logos(client, output_dir, args.force)

    # Part 3: Base card backgrounds (6 images)
    generate_all_cards(client, output_dir, args.force)

    # Part 4: Variants with logos overlaid (4 + 4 = 8 images)
    generate_official_variants(output_dir)
    generate_news_variants(output_dir)

    # Count total files
    total = 0
    for root, dirs, files in os.walk(output_dir):
        total += len([f for f in files if f.endswith(".png")])

    print(f"\n=== Done! Generated {total} image assets in {output_dir} ===")


if __name__ == "__main__":
    main()
