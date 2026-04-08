#!/usr/bin/env python3
"""
generate-dalle-assets.py

Generates non-portrait image assets using DALL-E:
  - National flags/logos (4)
  - News media logos (4)
  - Card backgrounds (6)
  - Organization avatars (government/institutional accounts)

Does NOT generate human portrait avatars (use generate-avatars.py for those).

Usage:
    export OPENAI_API_KEY="your-key"
    python3 generate-dalle-assets.py [--output-dir PATH] [--force]
"""

import argparse
import os
import sys
import time
import urllib.request

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package required. Install: sudo apt install python3-openai")
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    print("WARNING: Pillow not installed. Logo overlay variants will be skipped.")
    Image = None


def generate_dalle_image(client, prompt, size, output_path, force=False):
    """Generate a single image with DALL-E 3 and save to disk."""
    if os.path.exists(output_path) and not force:
        print(f"  [SKIP] {os.path.basename(output_path)}")
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
        print(f"  [OK] {os.path.basename(output_path)}")
        time.sleep(1)
        return True
    except Exception as e:
        print(f"  [FAIL] {os.path.basename(output_path)}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Generate DALL-E image assets")
    parser.add_argument("--api-key", default=os.environ.get("OPENAI_API_KEY", ""))
    parser.add_argument("--output-dir",
                        default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                             "..", "image-assets"))
    parser.add_argument("--force", action="store_true", help="Regenerate existing files")
    args = parser.parse_args()

    if not args.api_key:
        print("ERROR: OpenAI API key required. Set OPENAI_API_KEY or use --api-key")
        sys.exit(1)

    client = OpenAI(api_key=args.api_key)
    output_dir = os.path.abspath(args.output_dir)
    force = args.force

    logos_dir = os.path.join(output_dir, "logos")
    cards_dir = os.path.join(output_dir, "cards")
    avatars_dir = os.path.join(output_dir, "avatars")
    os.makedirs(logos_dir, exist_ok=True)
    os.makedirs(cards_dir, exist_ok=True)
    os.makedirs(avatars_dir, exist_ok=True)

    generated = 0
    failed = 0
    skipped = 0

    # =========================================================================
    # 1. National Flags/Logos (4 images, 1024x1024)
    # =========================================================================
    print("\n=== 1. National Flags/Logos ===")

    flags = {
        "valdoria.png": (
            "Official national emblem of a fictional democratic republic. "
            "Blue and gold color scheme. Majestic eagle with spread wings on a "
            "heraldic shield with a star at top. Formal coat of arms style on "
            "dark background. No text, no letters, clean design."
        ),
        "krasnovia.png": (
            "Official national emblem of a fictional socialist federation. "
            "Red and black color scheme. Large white five-pointed star with "
            "hammer and sickle motif. Soviet-inspired heraldic style on dark "
            "red background. No text, no letters, clean design."
        ),
        "tarvek.png": (
            "Official national emblem of a fictional revolutionary socialist republic. "
            "Red and yellow color scheme. Raised fist inside a gear wheel. "
            "Communist propaganda poster style on dark red background. "
            "No text, no letters, clean design."
        ),
        "arventa.png": (
            "Official national emblem of a fictional peaceful democratic republic. "
            "Green and white color scheme. Olive branch wreath surrounding a dove. "
            "Diplomatic seal style on dark green background. "
            "No text, no letters, clean design."
        ),
    }

    for filename, prompt in flags.items():
        path = os.path.join(logos_dir, filename)
        result = generate_dalle_image(client, prompt, "1024x1024", path, force)
        if result and not (os.path.exists(path) and not force):
            generated += 1
        elif not result:
            failed += 1
        else:
            skipped += 1

    # =========================================================================
    # 2. News Media Logos (4 images, 1792x1024)
    # =========================================================================
    print("\n=== 2. News Media Logos ===")

    media_logos = {
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
            "International news network logo design. Text 'MNN' in large bold "
            "white letters on dark gray background. Subtitle 'Meridia News Network' "
            "below. CNN/BBC inspired global news style. Clean design."
        ),
    }

    for filename, prompt in media_logos.items():
        path = os.path.join(logos_dir, filename)
        result = generate_dalle_image(client, prompt, "1792x1024", path, force)
        if result and not (os.path.exists(path) and not force):
            generated += 1
        elif not result:
            failed += 1
        else:
            skipped += 1

    # =========================================================================
    # 3. Card Backgrounds (6 images, 1792x1024)
    # =========================================================================
    print("\n=== 3. Card Backgrounds ===")

    cards = {
        "card_news.png": (
            "Professional TV news broadcast background graphic. Dark blue gradient "
            "with subtle globe wireframe, concentric circles, and news ticker bar "
            "at bottom. Modern broadcast studio style. No text, no logos, no people. "
            "Clean graphic design only."
        ),
        "card_official.png": (
            "Official government press conference backdrop. Dark navy blue gradient "
            "with elegant gold decorative borders, formal podium area, and subtle "
            "geometric patterns. Diplomatic and authoritative atmosphere. "
            "No text, no logos, no people."
        ),
        "card_alert.png": (
            "Cybersecurity alert warning screen background. Dark charcoal background "
            "with glowing orange warning triangle, digital grid lines, and hazard "
            "stripe borders. Urgent and threatening atmosphere. "
            "No text, no logos, no people."
        ),
        "card_ransomware.png": (
            "Ransomware attack screen background. Pure black background with red "
            "glowing skull icon, falling green matrix code effect, and red scan lines. "
            "Dark cyberpunk hacker aesthetic. No text, no logos, no people."
        ),
        "card_breaking.png": (
            "Breaking news broadcast emergency screen background. Bright red background "
            "with dynamic white light burst effects, dramatic lighting, and news "
            "broadcast visual elements. Urgent breaking news atmosphere. "
            "No text, no logos, no people."
        ),
        "card_alliance.png": (
            "Diplomatic alliance ceremony backdrop. Elegant light blue to white "
            "gradient with two podium areas side by side, handshake visual element, "
            "olive branches, and gold accents. Peaceful diplomatic atmosphere. "
            "No text, no logos, no people."
        ),
    }

    for filename, prompt in cards.items():
        path = os.path.join(cards_dir, filename)
        result = generate_dalle_image(client, prompt, "1792x1024", path, force)
        if result and not (os.path.exists(path) and not force):
            generated += 1
        elif not result:
            failed += 1
        else:
            skipped += 1

    # =========================================================================
    # 4. Organization Avatars (6 images, 1024x1024)
    #    Government/institutional accounts use emblem-style avatars
    # =========================================================================
    print("\n=== 4. Organization Avatars ===")

    org_avatars = {
        "vgovernment.png": (
            "Official government social media profile icon. Blue and gold circular "
            "emblem with eagle and shield motif. Formal government seal style on "
            "dark blue background. Clean, professional, suitable as profile picture. "
            "No text."
        ),
        "kgovernment.png": (
            "Official government social media profile icon. Red circular emblem "
            "with white star and socialist motifs. Soviet-style government seal on "
            "dark red background. Clean, professional, suitable as profile picture. "
            "No text."
        ),
        "sscc.png": (
            "Cyber command military unit social media profile icon. Dark circular "
            "emblem with digital shield, binary code motif, and red star. Military "
            "cyber operations unit badge style on black background. "
            "Clean, suitable as profile picture. No text."
        ),
        "ktoday.png": (
            "State media news channel profile icon. Red circular emblem with "
            "broadcast tower or globe motif. Bold propaganda media style on "
            "bright red background. Clean, suitable as profile picture. No text."
        ),
        "tgovernment.png": (
            "Revolutionary government social media profile icon. Red and yellow "
            "circular emblem with raised fist and gear motif. Revolutionary "
            "socialist style on dark red background. Clean, suitable as profile "
            "picture. No text."
        ),
        "agovernment.png": (
            "Democratic government social media profile icon. Green and white "
            "circular emblem with dove and olive branch motif. Peaceful diplomatic "
            "style on dark green background. Clean, suitable as profile picture. "
            "No text."
        ),
    }

    for filename, prompt in org_avatars.items():
        path = os.path.join(avatars_dir, filename)
        result = generate_dalle_image(client, prompt, "1024x1024", path, force)
        if result and not (os.path.exists(path) and not force):
            generated += 1
        elif not result:
            failed += 1
        else:
            skipped += 1

    # =========================================================================
    # 5. Logo Overlay Variants (Pillow, 8 images)
    # =========================================================================
    if Image:
        print("\n=== 5. Logo Overlay Variants ===")

        # Official card + country logo
        official_base = os.path.join(cards_dir, "card_official.png")
        if os.path.exists(official_base):
            for country in ["valdoria", "krasnovia", "tarvek", "arventa"]:
                variant_path = os.path.join(cards_dir, f"card_official_{country}.png")
                if os.path.exists(variant_path) and not force:
                    print(f"  [SKIP] {os.path.basename(variant_path)}")
                    skipped += 1
                    continue
                logo_path = os.path.join(logos_dir, f"{country}.png")
                if os.path.exists(logo_path):
                    base = Image.open(official_base).convert("RGBA")
                    logo = Image.open(logo_path).convert("RGBA").resize((120, 120), Image.LANCZOS)
                    base.paste(logo, (30, 30), logo)
                    base.save(variant_path)
                    print(f"  [OK] {os.path.basename(variant_path)}")
                    generated += 1
                else:
                    print(f"  [SKIP] Logo not found: {country}.png")

        # News card + media logo
        news_base = os.path.join(cards_dir, "card_news.png")
        if os.path.exists(news_base):
            media_map = {
                "vnb": "vnb.png",
                "krasnovia_today": "krasnovia_today.png",
                "elaris_tribune": "elaris_tribune.png",
                "mnn": "mnn.png",
            }
            for key, logo_file in media_map.items():
                variant_path = os.path.join(cards_dir, f"card_news_{key}.png")
                if os.path.exists(variant_path) and not force:
                    print(f"  [SKIP] {os.path.basename(variant_path)}")
                    skipped += 1
                    continue
                logo_path = os.path.join(logos_dir, logo_file)
                if os.path.exists(logo_path):
                    base = Image.open(news_base).convert("RGBA")
                    logo = Image.open(logo_path).convert("RGBA").resize((300, 80), Image.LANCZOS)
                    base.paste(logo, (30, 30), logo)
                    base.save(variant_path)
                    print(f"  [OK] {os.path.basename(variant_path)}")
                    generated += 1
                else:
                    print(f"  [SKIP] Logo not found: {logo_file}")
    else:
        print("\n=== 5. Logo Overlay Variants (SKIPPED - Pillow not installed) ===")

    # =========================================================================
    # Summary
    # =========================================================================
    print(f"\n{'='*50}")
    print(f" Image Asset Generation Complete")
    print(f"  Generated: {generated}")
    print(f"  Skipped:   {skipped}")
    print(f"  Failed:    {failed}")
    print(f"  Output:    {output_dir}")
    print(f"{'='*50}")


if __name__ == "__main__":
    main()
