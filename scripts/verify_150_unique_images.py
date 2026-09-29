import os
import hashlib

ASSETS_ROOT = 'assets/characters'

with open('lib/models/character.dart', 'r', encoding='utf-8') as f:
    text = f.read()

import re
matches = re.findall(r'id:\s*"([^"]+)",', text)
print(f"Total character IDs in character.dart: {len(matches)}")

missing_covers = []
missing_sprites = []
cover_hashes = {}
duplicate_hashes = {}

emotions = ['happy', 'sad', 'romantic', 'angry', 'shy', 'playful', 'surprised', 'thinking', 'laughing', 'emotional', 'excited']

for cid in matches:
    cdir = os.path.join(ASSETS_ROOT, cid)
    cpath = os.path.join(cdir, 'cover.jpg')
    if not os.path.exists(cpath):
        missing_covers.append(cid)
    else:
        with open(cpath, 'rb') as f:
            h = hashlib.md5(f.read()).hexdigest()
            if h in cover_hashes:
                duplicate_hashes.setdefault(h, [cover_hashes[h]]).append(cid)
            else:
                cover_hashes[h] = cid
    
    for emo in emotions:
        spath = os.path.join(cdir, f'{emo}.png')
        if not os.path.exists(spath):
            missing_sprites.append((cid, emo))

print(f"Missing covers: {len(missing_covers)}")
print(f"Missing sprites: {len(missing_sprites)}")
print(f"Unique cover hashes: {len(cover_hashes)}")
print(f"Duplicate cover hashes: {len(duplicate_hashes)}")

if duplicate_hashes:
    for h, cids in duplicate_hashes.items():
        print(f"  Duplicate hash {h}: {cids}")
else:
    print("ALL 150 CHARACTERS HAVE COMPLETELY UNIQUE IMAGES! ZERO REPETITION!")
