import os
import json
import urllib.request
from PIL import Image
import io

ASSETS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "characters")
USER_AGENT = "LoviaApp/2.0 (contact@lovia.app)"

# 10 characters matching the app and the user's screenshot aesthetic
CHARACTERS_CONFIG = [
    # Females
    {"id": "elena", "gender": "female", "theme": "waifu", "index": 0},      # Elegant anime doctor/director (like top-left in user screenshot)
    {"id": "chloe", "gender": "female", "theme": "kitsune", "index": 0},    # Cute anime tomboy with ears (like top-right in user screenshot)
    {"id": "seraphina", "gender": "female", "theme": "waifu", "index": 1},  # Romantic violinist
    {"id": "aria", "gender": "female", "theme": "neko", "index": 0},        # Bubbly pink-haired anime girl (like bottom-right in screenshot)
    {"id": "maya", "gender": "female", "theme": "waifu", "index": 2},       # Enigmatic stargazer
    # Males
    {"id": "liam", "gender": "male", "theme": "husbando", "index": 0},      # Gentle botanical artist
    {"id": "kai", "gender": "male", "theme": "husbando", "index": 1},       # Adventurous photographer
    {"id": "damon", "gender": "male", "theme": "husbando", "index": 2},     # Intense billionaire in suit
    {"id": "noah", "gender": "male", "theme": "husbando", "index": 3},      # Cozy counselor
    {"id": "julian", "gender": "male", "theme": "husbando", "index": 4},    # Passionate rockstar
]

EMOTION_MAP = {
    "happy": "smile",
    "sad": "cry",
    "romantic": "cuddle",
    "angry": "angry",
    "shy": "blush",
    "playful": "wink",
    "surprised": "shocked",
    "thinking": "think",
    "laughing": "laugh",
    "emotional": "pout",
    "excited": "smug",
}

def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode('utf-8'))

def download_image_bytes(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=25) as resp:
        return resp.read()

def main():
    print("=== Downloading High-Quality Anime Illustrations for Lovia ===")

    # 1. Fetch pools of waifus, husbandos, nekos, kitsunes
    print("Fetching character covers...")
    waifus = fetch_json("https://nekos.best/api/v2/waifu?amount=10")["results"]
    husbandos = fetch_json("https://nekos.best/api/v2/husbando?amount=10")["results"]
    nekos = fetch_json("https://nekos.best/api/v2/neko?amount=5")["results"]
    kitsunes = fetch_json("https://nekos.best/api/v2/kitsune?amount=5")["results"]

    pools = {
        "waifu": waifus,
        "husbando": husbandos,
        "neko": nekos,
        "kitsune": kitsunes,
    }

    # Fetch emotion images pools
    print("Fetching anime emotion pools...")
    emotion_pools = {}
    for emo, endpoint in EMOTION_MAP.items():
        try:
            res = fetch_json(f"https://nekos.best/api/v2/{endpoint}?amount=10")["results"]
            emotion_pools[emo] = res
            print(f"  {emo} ({endpoint}): {len(res)} assets")
        except Exception as e:
            print(f"  Failed {emo}: {e}")

    # Process each character
    for idx, c in enumerate(CHARACTERS_CONFIG):
        char_id = c["id"]
        char_dir = os.path.join(ASSETS_DIR, char_id)
        os.makedirs(char_dir, exist_ok=True)
        print(f"\nProcessing character [{char_id}]...")

        # 1. Download Cover Image (high-res full card art)
        pool = pools[c["theme"]]
        cover_meta = pool[c["index"] % len(pool)]
        cover_url = cover_meta["url"]
        try:
            raw_bytes = download_image_bytes(cover_url)
            img = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
            # Resize nicely for mobile display
            img.thumbnail((720, 1024), Image.Resampling.LANCZOS)
            cover_path = os.path.join(char_dir, "cover.jpg")
            img.save(cover_path, "JPEG", quality=92)
            print(f"  [OK] Saved cover: {cover_path} ({img.size})")
        except Exception as e:
            print(f"  [FAIL] Error downloading cover for {char_id}: {e}")

        # 2. Download or map all 11 emotion images
        for emo in EMOTION_MAP:
            emo_list = emotion_pools.get(emo, [])
            if emo_list:
                emo_meta = emo_list[idx % len(emo_list)]
                emo_url = emo_meta["url"]
                out_path = os.path.join(char_dir, f"{emo}.png")
                try:
                    emo_bytes = download_image_bytes(emo_url)
                    emo_img = Image.open(io.BytesIO(emo_bytes))
                    emo_img.thumbnail((512, 512), Image.Resampling.LANCZOS)
                    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
                    ox = (512 - emo_img.width) // 2
                    oy = (512 - emo_img.height) // 2
                    if emo_img.mode != 'RGBA':
                        emo_img = emo_img.convert('RGBA')
                    canvas.paste(emo_img, (ox, oy), emo_img)
                    canvas.save(out_path, "PNG")
                    print(f"    [OK] Saved emotion [{emo}]")
                except Exception as e:
                    print(f"    [FAIL] Error emotion [{emo}]: {e}")

    print("\nAll anime character assets successfully downloaded and configured!")

if __name__ == "__main__":
    main()
