import os
import re
import sys
import json
import time
import hashlib
import io
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image, ImageOps, ImageDraw, ImageFilter

HEADERS = {'User-Agent': 'LoviaApp/2.0'}
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
ASSETS_ROOT = os.path.join(PROJECT_ROOT, 'assets', 'characters')
CHAR_DART = os.path.join(PROJECT_ROOT, 'lib', 'models', 'character.dart')
PUBSPEC = os.path.join(PROJECT_ROOT, 'pubspec.yaml')

EMOTIONS = [
    'happy', 'sad', 'romantic', 'angry', 'shy', 'playful',
    'surprised', 'thinking', 'laughing', 'emotional', 'excited'
]

def fetch_posts(tag, total_needed=85):
    posts = []
    pid = 0
    seen_images = set()
    while len(posts) < total_needed and pid < 5:
        url = f'https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1&limit=50&pid={pid}&tags={tag}'
        print(f"Fetching {tag} (pid={pid})...")
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode('utf-8'))
            for item in data:
                img_name = item.get('image')
                if img_name and img_name not in seen_images:
                    seen_images.add(img_name)
                    posts.append(item)
                    if len(posts) >= total_needed:
                        break
        except Exception as e:
            print(f"Error fetching page {pid}: {e}")
        pid += 1
    print(f"Total unique posts collected for {tag}: {len(posts)}")
    return posts

def download_image(item):
    d = item['directory']
    img_name = item['image']
    url = f'https://safebooru.org/images/{d}/{img_name}'
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        resp = urllib.request.urlopen(req, timeout=20)
        data = resp.read()
        return data, url
    except Exception as e:
        print(f"Failed to download {url}: {e}")
        return None, url

def create_emotion_sprite(cover_img, emotion):
    size = 512
    w, h = cover_img.size
    crop_h = int(h * 0.62)
    crop_w = int(w * 0.88)
    left = (w - crop_w) // 2
    top = int(h * 0.04)
    face_crop = cover_img.crop((left, top, left + crop_w, top + crop_h))
    face_resized = face_crop.resize((size, size), Image.Resampling.LANCZOS)
    
    sprite = face_resized.convert('RGBA')
    
    mask = Image.new('L', (size, size), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.ellipse([20, 20, size - 20, size - 20], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(12))
    sprite.putalpha(mask)
    
    vfx = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vfx)
    cx = size // 2
    
    if emotion == 'romantic':
        for hx, hy, hs in [(cx + 140, 130, 22), (cx - 130, 180, 16), (cx + 120, 260, 18)]:
            v_draw.ellipse([hx - hs, hy - hs, hx, hy], fill=(255, 105, 160, 230))
            v_draw.ellipse([hx, hy - hs, hx + hs, hy], fill=(255, 105, 160, 230))
            v_draw.polygon([(hx - hs, hy - hs // 4), (hx + hs, hy - hs // 4), (hx, hy + hs)], fill=(255, 105, 160, 230))
    elif emotion in ['sad', 'emotional']:
        for tx, ty in [(cx - 50, 250), (cx + 50, 250)]:
            v_draw.ellipse([tx - 6, ty, tx + 6, ty + 18], fill=(160, 220, 255, 230))
            v_draw.polygon([(tx - 6, ty + 8), (tx + 6, ty + 8), (tx, ty - 4)], fill=(160, 220, 255, 230))
    elif emotion in ['happy', 'excited']:
        for sx, sy, ss in [(cx + 140, 120, 16), (cx - 130, 100, 14), (cx + 120, 240, 15)]:
            v_draw.polygon([(sx, sy - ss), (sx + ss // 4, sy), (sx, sy + ss), (sx - ss // 4, sy)], fill=(255, 225, 90, 240))
            v_draw.polygon([(sx - ss, sy), (sx, sy + ss // 4), (sx + ss, sy), (sx, sy - ss // 4)], fill=(255, 225, 90, 240))
    elif emotion == 'shy':
        b_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        b_draw = ImageDraw.Draw(b_img)
        b_draw.ellipse([cx - 90, 250, cx - 20, 290], fill=(255, 120, 150, 160))
        b_draw.ellipse([cx + 20, 250, cx + 90, 290], fill=(255, 120, 150, 160))
        b_img = b_img.filter(ImageFilter.GaussianBlur(8))
        sprite = Image.alpha_composite(sprite, b_img)
    elif emotion == 'angry':
        vx, vy = cx + 110, 100
        v_draw.arc([vx - 14, vy - 14, vx + 14, vy], 20, 160, fill=(230, 45, 45, 240), width=4)
        v_draw.arc([vx - 14, vy, vx + 14, vy + 14], 200, 340, fill=(230, 45, 45, 240), width=4)
        v_draw.arc([vx - 14, vy - 14, vx, vy + 14], 290, 430, fill=(230, 45, 45, 240), width=4)
        v_draw.arc([vx, vy - 14, vx + 14, vy + 14], 110, 250, fill=(230, 45, 45, 240), width=4)
    elif emotion == 'thinking':
        for bx, by, br in [(cx + 120, 110, 6), (cx + 135, 90, 10), (cx + 155, 65, 16)]:
            v_draw.ellipse([bx - br, by - br, bx + br, by + br], fill=(200, 225, 255, 220))
    elif emotion == 'laughing':
        v_draw.arc([cx - 180, 70, cx + 180, 430], 190, 350, fill=(255, 240, 160, 200), width=6)
    elif emotion == 'playful':
        v_draw.polygon([(cx + 130, 130), (cx + 145, 140), (cx + 130, 150), (cx + 115, 140)], fill=(255, 200, 240, 240))
    
    sprite = Image.alpha_composite(sprite, vfx)
    return sprite

def main():
    print("=== Lovia 150 Unique Character Assets Generator ===")
    
    # 1. Parse all characters from character.dart
    with open(CHAR_DART, 'r', encoding='utf-8') as f:
        content = f.read()
    
    pattern = r'id:\s*"([^"]+)",\s*(?:assetFolder:\s*"[^"]+",\s*)?name:\s*"([^"]+)",\s*gender:\s*Gender\.(male|female)'
    matches = re.findall(pattern, content)
    print(f"Parsed {len(matches)} characters from character.dart.")
    
    males = [m for m in matches if m[2] == 'male']
    females = [m for m in matches if m[2] == 'female']
    print(f"Males: {len(males)}, Females: {len(females)}")
    assert len(males) == 75, f"Expected 75 males, got {len(males)}"
    assert len(females) == 75, f"Expected 75 females, got {len(females)}"
    
    # 2. Fetch metadata from Safebooru
    print("\nFetching male anime portrait metadata...")
    male_posts = fetch_posts('1boy+solo+rating:general+portrait', 90)
    print("\nFetching female anime portrait metadata...")
    female_posts = fetch_posts('1girl+solo+rating:general+portrait', 90)
    
    # 3. Download images concurrently
    print("\nDownloading male images...")
    male_images = []
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(download_image, p): p for p in male_posts}
        for fut in as_completed(futures):
            raw, url = fut.result()
            if raw:
                try:
                    im = Image.open(io.BytesIO(raw)).convert('RGB')
                    male_images.append(im)
                    print(f"  [M] Downloaded {len(male_images)}/75: {im.size}")
                    if len(male_images) >= 75:
                        break
                except Exception as e:
                    print(f"  [M] Corrupt image {url}: {e}")
    
    print("\nDownloading female images...")
    female_images = []
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(download_image, p): p for p in female_posts}
        for fut in as_completed(futures):
            raw, url = fut.result()
            if raw:
                try:
                    im = Image.open(io.BytesIO(raw)).convert('RGB')
                    female_images.append(im)
                    print(f"  [F] Downloaded {len(female_images)}/75: {im.size}")
                    if len(female_images) >= 75:
                        break
                except Exception as e:
                    print(f"  [F] Corrupt image {url}: {e}")
    
    assert len(male_images) >= 75, f"Insufficient male images: {len(male_images)}"
    assert len(female_images) >= 75, f"Insufficient female images: {len(female_images)}"
    
    # 4. Generate assets for each character
    print("\nGenerating covers and sprites for all 150 characters...")
    m_idx = 0
    f_idx = 0
    all_cover_hashes = set()
    
    for char_id, char_name, gender in matches:
        char_dir = os.path.join(ASSETS_ROOT, char_id)
        os.makedirs(char_dir, exist_ok=True)
        
        if gender == 'male':
            raw_img = male_images[m_idx]
            m_idx += 1
        else:
            raw_img = female_images[f_idx]
            f_idx += 1
        
        # Fit to 720x1024 high-res card art
        cover = ImageOps.fit(raw_img, (720, 1024), Image.Resampling.LANCZOS)
        cover_path = os.path.join(char_dir, 'cover.jpg')
        cover.save(cover_path, 'JPEG', quality=92)
        
        # Verify hash uniqueness
        with open(cover_path, 'rb') as cf:
            h = hashlib.md5(cf.read()).hexdigest()
            assert h not in all_cover_hashes, f"Duplicate hash detected for {char_id}!"
            all_cover_hashes.add(h)
        
        # Generate 11 emotion sprites
        for emo in EMOTIONS:
            sprite = create_emotion_sprite(cover, emo)
            sprite_path = os.path.join(char_dir, f'{emo}.png')
            sprite.save(sprite_path, 'PNG')
        
        if (m_idx + f_idx) % 20 == 0 or (m_idx + f_idx) == 150:
            print(f"  Progress: {m_idx + f_idx}/150 characters generated with 0 duplicate images.")
    
    print(f"\nSUCCESS: Generated 150 unique character folders with {len(all_cover_hashes)} distinct covers!")
    
    # 5. Update pubspec.yaml with all 150 character directories
    print("\nUpdating pubspec.yaml...")
    with open(PUBSPEC, 'r', encoding='utf-8') as f:
        pubspec_text = f.read()
    
    # Generate assets list
    asset_lines = []
    for char_id, _, _ in matches:
        asset_lines.append(f"    - assets/characters/{char_id}/")
    
    # Also keep the original 30 directories just in case anything references them
    original_30 = [
        "liam", "seraphina", "kai", "aria", "damon", "elena", "noah", "chloe",
        "julian", "maya", "alec", "lucas", "isabella", "leo", "sammy", "felix",
        "ryder", "mila", "zoe", "piper", "lily", "tristan", "marcus", "gabriel",
        "rowan", "celeste", "violet", "selene", "hazel", "evie"
    ]
    for d in original_30:
        entry = f"    - assets/characters/{d}/"
        if entry not in asset_lines:
            asset_lines.append(entry)
    
    new_assets_block = "  assets:\n" + "\n".join(asset_lines) + "\n"
    
    # Replace assets: block in pubspec.yaml
    pubspec_updated = re.sub(r'  assets:.*?(?=\n\n|\n  # An image asset|\Z)', new_assets_block, pubspec_text, flags=re.DOTALL)
    with open(PUBSPEC, 'w', encoding='utf-8') as f:
        f.write(pubspec_updated)
    print("pubspec.yaml successfully updated with all character asset paths.")
    
    # 6. Update character.dart to remove assetFolder
    print("\nUpdating lib/models/character.dart to remove assetFolder...")
    # Remove lines like ssetFolder: "liam",
    dart_clean = re.sub(r'\s*assetFolder:\s*"[^"]+",', '', content)
    with open(CHAR_DART, 'w', encoding='utf-8') as f:
        f.write(dart_clean)
    print("lib/models/character.dart updated.")

if __name__ == '__main__':
    main()
