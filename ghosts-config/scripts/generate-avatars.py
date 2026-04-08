#!/usr/bin/env python3
"""
generate-avatars.py

Generates NPC avatar images for the GHOSTS NPC Framework using OpenAI DALL-E API.
For bot/gorgon accounts, generates geometric avatars locally with Pillow.

Usage:
    python3 generate-avatars.py \\
        --api-key <OPENAI_KEY> \\
        --ghosts-url http://localhost:5000 \\
        --mastodon-url http://localhost:8000 \\
        --token-file ../mastodon/npc-data/npc_tokens.json \\
        [--output-dir ../image-assets/avatars] \\
        [--force] \\
        [--skip-upload]
"""

import argparse
import json
import math
import os
import sys
import time
import urllib.request
import urllib.error

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow is required. Install with: pip3 install Pillow")
    sys.exit(1)

try:
    from openai import OpenAI
except ImportError:
    print("WARNING: openai package not installed. DALL-E generation will fail.")
    print("Install with: pip3 install openai")
    OpenAI = None


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Organization/institutional accounts — use country logo instead of portrait
# Maps username -> country (for logo lookup)
ORGANIZATION_ACCOUNTS = {
    "vgovernment": "valdoria",
    "kgovernment": "krasnovia",
    "sscc": "krasnovia",
    "ktoday": "krasnovia",
    "tgovernment": "tarvek",
    "agovernment": "arventa",
}

# Keywords in NPC names that indicate an organization, not a person
ORGANIZATION_KEYWORDS = [
    "government", "command", "today", "ministry", "department",
    "agency", "commission", "council", "bureau",
]

KOREAN_SURNAMES = [
    "Kim", "Park", "Lee", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang",
    "Lim", "Han", "Oh", "Seo", "Shin", "Kwon", "Hwang", "Ahn", "Song",
    "Yoo", "Hong", "Moon", "Yang", "Bae", "Baek", "Noh", "Ha", "Ryu",
    "Jeon", "Ko", "Woo", "Nam", "Min",
]

SLAVIC_SUFFIXES = [
    "ov", "ova", "ev", "eva", "sky", "ska", "ski", "enko", "uk", "chuk",
    "ovich", "evich", "ovna", "evna", "in", "ina",
]

HISPANIC_SURNAMES = [
    "Garcia", "Rodriguez", "Martinez", "Lopez", "Gonzalez", "Hernandez",
    "Perez", "Sanchez", "Ramirez", "Torres", "Flores", "Rivera", "Gomez",
    "Diaz", "Cruz", "Reyes", "Morales", "Ortiz", "Gutierrez", "Chavez",
    "Castillo", "Romero", "Mendoza", "Ruiz", "Alvarez", "Vargas",
]

PROGRESS_FILE = "avatar_progress.json"


# ---------------------------------------------------------------------------
# Font loading
# ---------------------------------------------------------------------------

def load_font(size):
    """Load a font for geometric avatar generation."""
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Ethnicity / clothing detection
# ---------------------------------------------------------------------------

def detect_ethnicity(first_name, last_name):
    """Determine ethnicity hint from name patterns."""
    # Check Korean surnames
    for surname in KOREAN_SURNAMES:
        if last_name and last_name.lower() == surname.lower():
            return "Korean"
        if first_name and first_name.lower() == surname.lower():
            return "Korean"

    # Check Slavic name patterns
    if last_name:
        lower_last = last_name.lower()
        for suffix in SLAVIC_SUFFIXES:
            if lower_last.endswith(suffix):
                return "Eastern European"

    # Check Hispanic surnames
    for surname in HISPANIC_SURNAMES:
        if last_name and last_name.lower() == surname.lower():
            return "Hispanic"

    return "mixed ethnicity"


def clothing_and_background(role):
    """Determine clothing and background from NPC role."""
    role_lower = (role or "").lower()
    styles = {
        "official": {
            "clothing": "wearing a dark formal business suit with tie",
            "background": "in a modern government office with blurred bookshelves and wooden desk in background",
        },
        "military": {
            "clothing": "wearing a military uniform with insignia",
            "background": "at a military facility with blurred barracks and equipment in background",
        },
        "citizen": {
            "clothing": "wearing casual everyday clothes",
            "background": "at a cafe or urban street with warm natural lighting and blurred city in background",
        },
        "media": {
            "clothing": "wearing smart casual attire with a press badge lanyard",
            "background": "in a newsroom studio with blurred monitors and broadcast equipment in background",
        },
        "disguised": {
            "clothing": "wearing casual everyday clothes",
            "background": "at a park or coffee shop with soft natural lighting and blurred trees in background",
        },
    }
    default = {
        "clothing": "wearing casual clothes",
        "background": "with a softly blurred urban background",
    }
    return styles.get(role_lower, default)


def age_decade(birthdate_str):
    """Estimate age decade from birthdate string (YYYY-MM-DD)."""
    if not birthdate_str:
        return "30"
    try:
        year = int(birthdate_str[:4])
        age = 2026 - year
        decade = (age // 10) * 10
        if decade < 20:
            decade = 20
        if decade > 70:
            decade = 60
        return str(decade)
    except (ValueError, IndexError):
        return "30"


# ---------------------------------------------------------------------------
# NPC data extraction
# ---------------------------------------------------------------------------

def fetch_npcs(ghosts_url):
    """Fetch all NPCs from the GHOSTS API."""
    url = f"{ghosts_url}/api/npcs"
    print(f"Fetching NPCs from {url}...")

    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot reach GHOSTS API at {ghosts_url}: {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON response from GHOSTS API: {e}")
        sys.exit(1)

    # The API may return a list directly or a wrapper object
    if isinstance(data, list):
        npcs = data
    elif isinstance(data, dict) and "items" in data:
        npcs = data["items"]
    elif isinstance(data, dict) and "npcs" in data:
        npcs = data["npcs"]
    else:
        npcs = data if isinstance(data, list) else [data]

    print(f"  Found {len(npcs)} NPCs")
    return npcs


def extract_npc_info(npc):
    """Extract relevant fields from an NPC record."""
    # Handle npcProfile wrapper or flat fields
    profile = npc.get("npcProfile", npc)
    name_obj = profile.get("name", {})
    if isinstance(name_obj, dict):
        first = name_obj.get("first", "")
        last = name_obj.get("last", "")
    elif isinstance(name_obj, str):
        parts = name_obj.split()
        first = parts[0] if parts else ""
        last = " ".join(parts[1:]) if len(parts) > 1 else ""
    else:
        first = npc.get("firstName", "")
        last = npc.get("lastName", "")

    full_name = f"{first} {last}".strip()
    email = profile.get("email", npc.get("email", ""))

    # Derive username: first initial + last name, lowercase, alphanum only
    if first and last:
        username = (first[0] + last).lower().replace("'", "").replace(" ", "")
        username = "".join(c for c in username if c.isalnum() or c == "_")
    else:
        username = email.split("@")[0] if email else full_name.lower().replace(" ", ".")

    # Attributes (check npcProfile.attributes or top-level)
    attrs = profile.get("attributes", {}) or npc.get("attributes", {}) or {}
    role = attrs.get("role", "citizen")
    country = attrs.get("country", "")

    gender = profile.get("biologicalSex", npc.get("biologicalSex", ""))
    birthdate = profile.get("birthdate", npc.get("birthdate", ""))

    return {
        "first_name": first,
        "last_name": last,
        "full_name": full_name,
        "username": username,
        "email": email,
        "gender": gender,
        "birthdate": birthdate,
        "role": role,
        "country": country,
    }


# ---------------------------------------------------------------------------
# Avatar generation: DALL-E
# ---------------------------------------------------------------------------

def generate_dalle_avatar(client, npc_info):
    """Generate a portrait avatar using DALL-E 3."""
    ethnicity = detect_ethnicity(npc_info["first_name"], npc_info["last_name"])
    gender = npc_info["gender"].lower() if npc_info["gender"] else "person"
    if gender not in ("male", "female"):
        gender = "person"
    age_dec = age_decade(npc_info["birthdate"])
    style = clothing_and_background(npc_info["role"])

    prompt = (
        f"Professional portrait photo of a {ethnicity} {gender} "
        f"in their {age_dec}s {style['clothing']}, {style['background']}. "
        f"Realistic photography style, natural pose, looking at camera, "
        f"upper body shot. No watermarks, no text, no split images."
    )

    print(f"    DALL-E prompt: {prompt[:80]}...")

    try:
        response = client.images.generate(
            model="dall-e-3",
            size="1024x1024",
            quality="standard",
            n=1,
            prompt=prompt,
        )
        image_url = response.data[0].url
        return image_url
    except Exception as e:
        print(f"    ERROR generating avatar: {e}")
        return None


def download_image(url, output_path):
    """Download an image from a URL and save it."""
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=60) as resp:
            with open(output_path, "wb") as f:
                f.write(resp.read())
        return True
    except Exception as e:
        print(f"    ERROR downloading image: {e}")
        return False


# ---------------------------------------------------------------------------
# Avatar generation: Geometric (for bots and gorgon)
# ---------------------------------------------------------------------------

def generate_bot_avatar(username, output_path):
    """Generate a simple geometric avatar with colored circle and initials."""
    img = Image.new("RGB", (1024, 1024), (240, 240, 245))
    draw = ImageDraw.Draw(img)

    # Deterministic color from username hash
    h = hash(username) & 0xFFFFFF
    r = 60 + (h & 0xFF) % 140
    g = 60 + ((h >> 8) & 0xFF) % 140
    b = 60 + ((h >> 16) & 0xFF) % 140

    # Large circle
    draw.ellipse([112, 112, 912, 912], fill=(r, g, b))

    # Initials
    initials = "".join(
        p[0].upper() for p in username.replace(".", " ").replace("_", " ").split()[:2]
    )
    if not initials:
        initials = username[0].upper() if username else "?"

    font = load_font(280)
    bbox = draw.textbbox((0, 0), initials, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((1024 - tw) / 2, (1024 - th) / 2 - 40), initials,
              fill=(255, 255, 255), font=font)

    # Small "BOT" badge
    draw.rectangle([700, 800, 950, 920], fill=(60, 60, 65))
    font_sm = load_font(80)
    draw.text((720, 810), "BOT", fill=(200, 200, 205), font=font_sm)

    img.save(output_path)


def generate_gorgon_avatar(username, output_path):
    """Generate a dark hacker-themed avatar with skull/mask icon."""
    img = Image.new("RGB", (1024, 1024), (15, 15, 18))
    draw = ImageDraw.Draw(img)

    # Dark circle background
    draw.ellipse([62, 62, 962, 962], fill=(25, 25, 30))

    # Skull / mask shape
    # Head
    draw.ellipse([340, 200, 684, 580], fill=(50, 50, 55))
    # Eyes (red glowing)
    draw.ellipse([400, 330, 480, 410], fill=(200, 20, 20))
    draw.ellipse([544, 330, 624, 410], fill=(200, 20, 20))
    # Eye inner glow
    draw.ellipse([425, 355, 455, 385], fill=(255, 60, 60))
    draw.ellipse([569, 355, 599, 385], fill=(255, 60, 60))
    # Nose slit
    draw.polygon([(505, 420), (519, 420), (512, 470)], fill=(25, 25, 30))
    # Mouth area
    draw.rectangle([420, 490, 604, 530], fill=(50, 50, 55))
    for x in range(425, 604, 20):
        draw.line([(x, 490), (x, 530)], fill=(25, 25, 30), width=3)

    # Binary / glitch decoration
    font_sm = load_font(18)
    import random
    random.seed(hash(username))
    for _ in range(30):
        bx = random.randint(50, 950)
        by = random.randint(50, 950)
        draw.text((bx, by), random.choice(["0", "1"]),
                  fill=(200, 20, 20, 80), font=font_sm)

    # "GORGON" text at bottom
    font_g = load_font(60)
    bbox = draw.textbbox((0, 0), "GORGON", font=font_g)
    tw = bbox[2] - bbox[0]
    draw.text(((1024 - tw) / 2, 700), "GORGON", fill=(200, 20, 20), font=font_g)

    # Red scan lines
    for y in range(0, 1024, 4):
        draw.line([(0, y), (1024, y)], fill=(200, 20, 20, 10), width=1)

    img.save(output_path)


# ---------------------------------------------------------------------------
# Mastodon upload
# ---------------------------------------------------------------------------

def upload_avatar_to_mastodon(mastodon_url, access_token, avatar_path):
    """Upload avatar image to Mastodon as profile picture."""
    import mimetypes
    boundary = "----AvatarUploadBoundary"

    filename = os.path.basename(avatar_path)
    mime_type = mimetypes.guess_type(avatar_path)[0] or "image/png"

    with open(avatar_path, "rb") as f:
        file_data = f.read()

    # Build multipart body
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="avatar"; filename="{filename}"\r\n'
        f"Content-Type: {mime_type}\r\n\r\n"
    ).encode("utf-8") + file_data + f"\r\n--{boundary}--\r\n".encode("utf-8")

    url = f"{mastodon_url}/api/v1/accounts/update_credentials"
    req = urllib.request.Request(url, data=body, method="PATCH")
    req.add_header("Authorization", f"Bearer {access_token}")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            if resp.status in (200, 202):
                return True
            else:
                print(f"    WARNING: Mastodon returned HTTP {resp.status}")
                return False
    except urllib.error.HTTPError as e:
        print(f"    WARNING: Mastodon upload failed: HTTP {e.code} - {e.reason}")
        return False
    except Exception as e:
        print(f"    WARNING: Mastodon upload error: {e}")
        return False


# ---------------------------------------------------------------------------
# Progress tracking
# ---------------------------------------------------------------------------

def load_progress(output_dir):
    """Load progress file."""
    path = os.path.join(output_dir, PROGRESS_FILE)
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"completed": [], "failed": []}


def save_progress(output_dir, progress):
    """Save progress file."""
    path = os.path.join(output_dir, PROGRESS_FILE)
    with open(path, "w") as f:
        json.dump(progress, f, indent=2)


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------

def process_npcs(args):
    """Main NPC avatar generation loop."""
    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # Load tokens
    token_file = os.path.abspath(args.token_file)
    tokens = {}
    if os.path.exists(token_file):
        with open(token_file, "r") as f:
            tokens = json.load(f)
        print(f"Loaded {len(tokens)} Mastodon tokens from {token_file}")
    else:
        print(f"WARNING: Token file not found: {token_file}")
        print("  Mastodon avatar uploads will be skipped.")

    # Initialize OpenAI client
    client = None
    if OpenAI and args.api_key:
        client = OpenAI(api_key=args.api_key)
        print("OpenAI client initialized.")
    else:
        print("WARNING: OpenAI not available. Only geometric avatars will be generated.")

    # Fetch NPCs
    npcs = fetch_npcs(args.ghosts_url)
    if not npcs:
        print("No NPCs found. Exiting.")
        return

    # Load progress
    progress = load_progress(output_dir)

    total = len(npcs)
    generated = 0
    skipped = 0
    failed = 0
    uploaded = 0

    for i, npc in enumerate(npcs, 1):
        info = extract_npc_info(npc)
        username = info["username"]
        role = info["role"]

        print(f"\n[{i}/{total}] {info['full_name']} (@{username}) - role: {role}")

        avatar_path = os.path.join(output_dir, f"{username}.png")

        # Skip if already exists and not forcing
        if os.path.exists(avatar_path) and not args.force:
            if username not in progress["completed"]:
                progress["completed"].append(username)
                save_progress(output_dir, progress)
            print(f"  [SKIP] Avatar already exists: {avatar_path}")
            skipped += 1
            continue

        # Skip if already completed in progress (but file missing = regenerate)
        if username in progress["completed"] and os.path.exists(avatar_path) and not args.force:
            print(f"  [SKIP] Already completed in previous run")
            skipped += 1
            continue

        # Determine generation method
        role_lower = (role or "").lower()
        full_name_lower = info["full_name"].lower()

        # Check if this is an organization/institution account
        is_org = username in ORGANIZATION_ACCOUNTS
        if not is_org:
            is_org = any(kw in full_name_lower for kw in ORGANIZATION_KEYWORDS)

        if is_org:
            # Use country logo as avatar
            country = ORGANIZATION_ACCOUNTS.get(username, info["country"])
            logo_path = os.path.join(os.path.dirname(output_dir), "logos", f"{country}.png")
            if os.path.exists(logo_path):
                import shutil
                shutil.copy2(logo_path, avatar_path)
                print(f"  [ORG] Using {country} logo as avatar")
                generated += 1
            else:
                print(f"  [ORG] Logo not found: {logo_path}, generating geometric...")
                generate_bot_avatar(username, avatar_path)
                generated += 1
        elif role_lower == "bot":
            print(f"  Generating geometric bot avatar...")
            generate_bot_avatar(username, avatar_path)
            generated += 1
        elif role_lower == "gorgon":
            print(f"  Generating gorgon hacker avatar...")
            generate_gorgon_avatar(username, avatar_path)
            generated += 1
        elif client:
            print(f"  Generating DALL-E avatar...")
            image_url = generate_dalle_avatar(client, info)
            if image_url:
                if download_image(image_url, avatar_path):
                    generated += 1
                else:
                    # Fallback to geometric
                    print(f"  Falling back to geometric avatar...")
                    generate_bot_avatar(username, avatar_path)
                    generated += 1
            else:
                # Fallback to geometric
                print(f"  DALL-E failed; falling back to geometric avatar...")
                generate_bot_avatar(username, avatar_path)
                generated += 1
            # Rate limiting for DALL-E
            time.sleep(1)
        else:
            # No OpenAI client available, use geometric
            print(f"  Generating geometric avatar (no OpenAI key)...")
            generate_bot_avatar(username, avatar_path)
            generated += 1

        # Verify file was created
        if not os.path.exists(avatar_path):
            print(f"  [FAIL] Avatar not created")
            failed += 1
            if username not in progress["failed"]:
                progress["failed"].append(username)
            save_progress(output_dir, progress)
            continue

        print(f"  [OK] Saved: {avatar_path}")

        # Track progress
        if username not in progress["completed"]:
            progress["completed"].append(username)
        if username in progress["failed"]:
            progress["failed"].remove(username)
        save_progress(output_dir, progress)

        # Upload to Mastodon
        if not args.skip_upload and username in tokens:
            token = tokens[username]
            # Handle token as string or dict
            access_token = token if isinstance(token, str) else (token.get("token") or token.get("access_token", ""))
            if access_token:
                print(f"  Uploading to Mastodon...")
                if upload_avatar_to_mastodon(args.mastodon_url, access_token, avatar_path):
                    uploaded += 1
                    print(f"  [OK] Uploaded to Mastodon")
                else:
                    print(f"  [WARN] Mastodon upload failed")
            else:
                print(f"  [SKIP] No access token for Mastodon upload")
        elif not args.skip_upload and username not in tokens:
            print(f"  [SKIP] No Mastodon token found for @{username}")

    # Summary
    print("\n" + "=" * 60)
    print(f" Avatar Generation Complete")
    print(f"  Total NPCs:  {total}")
    print(f"  Generated:   {generated}")
    print(f"  Skipped:     {skipped}")
    print(f"  Failed:      {failed}")
    print(f"  Uploaded:    {uploaded}")
    print(f"  Output dir:  {output_dir}")
    print("=" * 60)


# ---------------------------------------------------------------------------
# Upload-only mode
# ---------------------------------------------------------------------------

def upload_existing_avatars(args):
    """Upload existing avatar images to Mastodon profiles."""
    output_dir = os.path.abspath(args.output_dir)

    # Load tokens
    token_file = os.path.abspath(args.token_file)
    if not os.path.exists(token_file):
        print(f"ERROR: Token file not found: {token_file}")
        sys.exit(1)

    with open(token_file, "r") as f:
        tokens = json.load(f)
    print(f"Loaded {len(tokens)} Mastodon tokens from {token_file}")

    # Fetch NPCs to get username mapping
    npcs = fetch_npcs(args.ghosts_url)
    if not npcs:
        print("No NPCs found. Exiting.")
        return

    total = len(npcs)
    uploaded = 0
    skipped = 0
    failed = 0

    for i, npc in enumerate(npcs, 1):
        info = extract_npc_info(npc)
        username = info["username"]

        avatar_path = os.path.join(output_dir, f"{username}.png")

        print(f"[{i}/{total}] @{username}", end="")

        # Check avatar file exists
        if not os.path.exists(avatar_path):
            print(f" - [SKIP] No avatar file")
            skipped += 1
            continue

        # Check token exists
        if username not in tokens:
            print(f" - [SKIP] No Mastodon token")
            skipped += 1
            continue

        token = tokens[username]
        access_token = token if isinstance(token, str) else (token.get("token") or token.get("access_token", ""))
        if not access_token:
            print(f" - [SKIP] Empty access token")
            skipped += 1
            continue

        # Upload
        print(f" - Uploading...", end="")
        if upload_avatar_to_mastodon(args.mastodon_url, access_token, avatar_path):
            uploaded += 1
            print(f" [OK]")
        else:
            failed += 1
            print(f" [FAIL]")

        # Small delay to avoid rate limiting
        time.sleep(0.3)

    print("\n" + "=" * 60)
    print(f" Mastodon Avatar Upload Complete")
    print(f"  Total NPCs:  {total}")
    print(f"  Uploaded:    {uploaded}")
    print(f"  Skipped:     {skipped}")
    print(f"  Failed:      {failed}")
    print("=" * 60)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate NPC avatar images using OpenAI DALL-E API"
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("OPENAI_API_KEY", ""),
        help="OpenAI API key (or set OPENAI_API_KEY env var)"
    )
    parser.add_argument(
        "--ghosts-url",
        default="http://localhost:5000",
        help="GHOSTS API base URL (default: http://localhost:5000)"
    )
    parser.add_argument(
        "--mastodon-url",
        default="http://localhost:8000",
        help="Mastodon base URL (default: http://localhost:8000)"
    )
    parser.add_argument(
        "--token-file",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "..", "mastodon", "npc-data", "npc_tokens.json"),
        help="Path to NPC Mastodon tokens JSON file"
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "..", "image-assets", "avatars"),
        help="Output directory for avatar images"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate avatars even if they already exist"
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Skip uploading avatars to Mastodon"
    )
    parser.add_argument(
        "--upload-only",
        action="store_true",
        help="Upload existing avatars to Mastodon without generating new ones"
    )

    args = parser.parse_args()

    if args.upload_only:
        upload_existing_avatars(args)
    else:
        if not args.api_key:
            print("WARNING: No OpenAI API key provided.")
            print("  Only geometric avatars will be generated for all NPCs.")
            print("  Provide --api-key or set OPENAI_API_KEY to use DALL-E.")
            print()
        process_npcs(args)


if __name__ == "__main__":
    main()
