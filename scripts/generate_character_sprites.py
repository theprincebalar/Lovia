import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "characters")

CHARACTERS = {
    "liam": {
        "gender": "male",
        "skin": (245, 220, 200),
        "skin_shadow": (225, 195, 175),
        "hair": (80, 50, 30),
        "hair_highlight": (120, 80, 50),
        "eyes": (40, 140, 90),
        "clothing_primary": (35, 45, 65),
        "clothing_secondary": (60, 80, 110),
        "hair_type": "short_wavy",
        "style": "cozy_sweater",
    },
    "seraphina": {
        "gender": "female",
        "skin": (252, 230, 225),
        "skin_shadow": (235, 205, 200),
        "hair": (205, 195, 225),
        "hair_highlight": (235, 225, 250),
        "eyes": (130, 90, 185),
        "clothing_primary": (45, 25, 60),
        "clothing_secondary": (160, 120, 190),
        "hair_type": "long_flowy",
        "style": "elegant_dress",
    },
    "kai": {
        "gender": "male",
        "skin": (240, 215, 195),
        "skin_shadow": (215, 185, 165),
        "hair": (30, 35, 45),
        "hair_highlight": (70, 85, 115),
        "eyes": (35, 120, 200),
        "clothing_primary": (25, 25, 30),
        "clothing_secondary": (190, 40, 60),
        "hair_type": "messy_undercut",
        "style": "street_leather",
    },
    "aria": {
        "gender": "female",
        "skin": (250, 225, 210),
        "skin_shadow": (230, 195, 180),
        "hair": (235, 190, 95),
        "hair_highlight": (255, 225, 150),
        "eyes": (180, 120, 50),
        "clothing_primary": (240, 90, 110),
        "clothing_secondary": (255, 240, 245),
        "hair_type": "twin_tails",
        "style": "cute_crop",
    },
    "damon": {
        "gender": "male",
        "skin": (235, 210, 190),
        "skin_shadow": (205, 180, 160),
        "hair": (20, 20, 25),
        "hair_highlight": (60, 60, 75),
        "eyes": (90, 110, 125),
        "clothing_primary": (15, 18, 22),
        "clothing_secondary": (200, 170, 100),
        "hair_type": "sleek_back",
        "style": "formal_suit",
    },
    "elena": {
        "gender": "female",
        "skin": (245, 215, 200),
        "skin_shadow": (220, 185, 170),
        "hair": (25, 20, 25),
        "hair_highlight": (80, 50, 70),
        "eyes": (160, 30, 60),
        "clothing_primary": (180, 25, 55),
        "clothing_secondary": (30, 30, 35),
        "hair_type": "side_swept_glam",
        "style": "blazer_glam",
    },
    "noah": {
        "gender": "male",
        "skin": (242, 218, 198),
        "skin_shadow": (218, 190, 170),
        "hair": (115, 75, 45),
        "hair_highlight": (160, 115, 80),
        "eyes": (85, 130, 100),
        "clothing_primary": (40, 70, 65),
        "clothing_secondary": (230, 210, 180),
        "hair_type": "soft_curls",
        "style": "turtleneck_coat",
    },
    "chloe": {
        "gender": "female",
        "skin": (253, 230, 220),
        "skin_shadow": (230, 200, 190),
        "hair": (150, 75, 40),
        "hair_highlight": (195, 120, 75),
        "eyes": (70, 140, 130),
        "clothing_primary": (50, 90, 120),
        "clothing_secondary": (240, 225, 200),
        "hair_type": "bob_with_bangs",
        "style": "cardigan_glasses",
    },
    "julian": {
        "gender": "male",
        "skin": (238, 208, 188),
        "skin_shadow": (210, 175, 155),
        "hair": (175, 55, 35),
        "hair_highlight": (220, 100, 70),
        "eyes": (200, 110, 30),
        "clothing_primary": (30, 30, 40),
        "clothing_secondary": (180, 60, 40),
        "hair_type": "spiky_wolf",
        "style": "denim_hoodie",
    },
    "maya": {
        "gender": "female",
        "skin": (240, 212, 200),
        "skin_shadow": (215, 182, 170),
        "hair": (35, 40, 80),
        "hair_highlight": (75, 85, 150),
        "eyes": (95, 160, 230),
        "clothing_primary": (20, 25, 45),
        "clothing_secondary": (110, 130, 200),
        "hair_type": "long_straight",
        "style": "starlight_hoodie",
    },
}

EMOTIONS = [
    "happy",
    "sad",
    "romantic",
    "angry",
    "shy",
    "playful",
    "surprised",
    "thinking",
    "laughing",
    "emotional",
    "excited",
]

def draw_character(char_id, emotion):
    c = CHARACTERS[char_id]
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = size // 2
    head_cy = 210
    head_rx = 85
    head_ry = 100

    # 1. Back hair (for long hair characters)
    if c["hair_type"] in ["long_flowy", "twin_tails", "long_straight", "side_swept_glam"]:
        back_hair_color = tuple(max(0, val - 25) for val in c["hair"])
        if c["hair_type"] == "twin_tails":
            draw.ellipse([cx - 150, head_cy - 40, cx - 70, head_cy + 220], fill=back_hair_color)
            draw.ellipse([cx + 70, head_cy - 40, cx + 150, head_cy + 220], fill=back_hair_color)
        else:
            draw.ellipse([cx - 125, head_cy - 50, cx + 125, head_cy + 250], fill=back_hair_color)

    # 2. Shoulders & Body Clothing
    shoulder_w = 175 if c["gender"] == "male" else 145
    body_top = head_cy + head_ry - 20
    
    # Neck
    neck_w = 34 if c["gender"] == "male" else 26
    draw.polygon([
        (cx - neck_w, head_cy + head_ry - 35),
        (cx + neck_w, head_cy + head_ry - 35),
        (cx + neck_w + 10, body_top + 45),
        (cx - neck_w - 10, body_top + 45)
    ], fill=c["skin_shadow"])

    # Torso / Outfit
    cloth1 = c["clothing_primary"]
    cloth2 = c["clothing_secondary"]
    draw.polygon([
        (cx - shoulder_w, size),
        (cx - shoulder_w + 20, body_top + 40),
        (cx - neck_w - 15, body_top + 25),
        (cx, body_top + 45),
        (cx + neck_w + 15, body_top + 25),
        (cx + shoulder_w - 20, body_top + 40),
        (cx + shoulder_w, size),
        (cx, size)
    ], fill=cloth1)

    # Inner collar / shirt
    draw.polygon([
        (cx - neck_w - 5, body_top + 25),
        (cx, body_top + 75),
        (cx + neck_w + 5, body_top + 25),
        (cx, body_top + 45)
    ], fill=cloth2)

    # Stylish accents (tie / necklace / collar lines)
    if c["style"] == "formal_suit":
        draw.polygon([(cx - 7, body_top + 70), (cx + 7, body_top + 70), (cx + 12, size - 40), (cx, size - 20), (cx - 12, size - 40)], fill=cloth2)
    elif c["style"] == "cardigan_glasses" or c["style"] == "elegant_dress":
        draw.ellipse([cx - 16, body_top + 50, cx + 16, body_top + 80], outline=cloth2, width=3)

    # 3. Head & Face Base
    face_pts = [
        (cx - head_rx, head_cy - 20),
        (cx - head_rx + 5, head_cy + 40),
        (cx - 35, head_cy + head_ry),
        (cx, head_cy + head_ry + 10),
        (cx + 35, head_cy + head_ry),
        (cx + head_rx - 5, head_cy + 40),
        (cx + head_rx, head_cy - 20),
        (cx, head_cy - head_ry)
    ]
    draw.polygon(face_pts, fill=c["skin"])
    # Chin shadow
    draw.arc([cx - 45, head_cy + head_ry - 15, cx + 45, head_cy + head_ry + 8], 20, 160, fill=c["skin_shadow"], width=3)

    # Ears
    ear_y = head_cy + 15
    draw.ellipse([cx - head_rx - 12, ear_y - 20, cx - head_rx + 8, ear_y + 25], fill=c["skin"])
    draw.ellipse([cx + head_rx - 8, ear_y - 20, cx + head_rx + 12, ear_y + 25], fill=c["skin"])
    draw.arc([cx - head_rx - 6, ear_y - 12, cx - head_rx + 4, ear_y + 15], 30, 200, fill=c["skin_shadow"], width=2)
    draw.arc([cx + head_rx - 4, ear_y - 12, cx + head_rx + 6, ear_y + 15], 340, 150, fill=c["skin_shadow"], width=2)

    # 4. Eyebrows & Eyes
    eye_y = head_cy + 12
    eye_spacing = 42
    eye_w = 26
    eye_h = 20

    brow_l_tilt = 0
    brow_r_tilt = 0
    brow_y_offset = 0

    if emotion == "angry":
        brow_l_tilt = 8
        brow_r_tilt = -8
        brow_y_offset = 5
    elif emotion in ["sad", "emotional"]:
        brow_l_tilt = -6
        brow_r_tilt = 6
        brow_y_offset = -3
    elif emotion == "surprised":
        brow_y_offset = -12
    elif emotion == "thinking":
        brow_l_tilt = -5
        brow_r_tilt = 4
        brow_y_offset = -4
    elif emotion in ["excited", "happy"]:
        brow_y_offset = -6

    brow_col = tuple(max(0, val - 35) for val in c["hair"])
    # Left brow
    draw.line([
        (cx - eye_spacing - eye_w, eye_y - 22 + brow_y_offset + brow_l_tilt),
        (cx - eye_spacing + 5, eye_y - 24 + brow_y_offset - brow_l_tilt)
    ], fill=brow_col, width=4)
    # Right brow
    draw.line([
        (cx + eye_spacing - 5, eye_y - 24 + brow_y_offset - brow_r_tilt),
        (cx + eye_spacing + eye_w, eye_y - 22 + brow_y_offset + brow_r_tilt)
    ], fill=brow_col, width=4)

    # Draw Eyes
    for side in [-1, 1]:
        ex = cx + side * eye_spacing
        
        # Wink for playful
        if emotion == "playful" and side == 1:
            draw.arc([ex - eye_w // 2, eye_y - 10, ex + eye_w // 2, eye_y + 10], 200, 340, fill=(35, 35, 45), width=4)
            continue
        # Closed joyful eyes for laughing
        if emotion == "laughing":
            draw.arc([ex - eye_w // 2 - 2, eye_y - 12, ex + eye_w // 2 + 2, eye_y + 8], 190, 350, fill=(35, 35, 45), width=4)
            continue

        # Normal / expressive open eyes
        draw.ellipse([ex - eye_w // 2, eye_y - eye_h // 2, ex + eye_w // 2, eye_y + eye_h // 2], fill=(255, 255, 255))
        
        iris_rx = 9 if emotion != "surprised" else 7
        iris_ry = 10 if emotion != "surprised" else 7
        
        iris_x_off = -4 if emotion == "thinking" and side == -1 else (4 if emotion == "thinking" and side == 1 else 0)
        if emotion == "shy":
            iris_x_off = side * 3

        draw.ellipse([ex - iris_rx + iris_x_off, eye_y - iris_ry, ex + iris_rx + iris_x_off, eye_y + iris_ry], fill=c["eyes"])
        draw.ellipse([ex - 4 + iris_x_off, eye_y - 5, ex + 4 + iris_x_off, eye_y + 5], fill=(20, 20, 25))
        
        if emotion == "romantic":
            draw.ellipse([ex - 5 + iris_x_off, eye_y - 7, ex - 1 + iris_x_off, eye_y - 3], fill=(255, 235, 245))
            draw.ellipse([ex + 2 + iris_x_off, eye_y + 2, ex + 5 + iris_x_off, eye_y + 5], fill=(255, 200, 230))
        elif emotion in ["excited", "emotional"]:
            draw.ellipse([ex - 5 + iris_x_off, eye_y - 7, ex - 1 + iris_x_off, eye_y - 3], fill=(255, 255, 255))
            draw.ellipse([ex + 2 + iris_x_off, eye_y - 6, ex + 5 + iris_x_off, eye_y - 3], fill=(255, 255, 255))
            draw.ellipse([ex + 1 + iris_x_off, eye_y + 2, ex + 4 + iris_x_off, eye_y + 5], fill=(255, 255, 255))
        else:
            draw.ellipse([ex - 4 + iris_x_off, eye_y - 6, ex - 1 + iris_x_off, eye_y - 3], fill=(255, 255, 255))
            draw.ellipse([ex + 2 + iris_x_off, eye_y + 2, ex + 4 + iris_x_off, eye_y + 4], fill=(255, 255, 255))

        draw.arc([ex - eye_w // 2 - 3, eye_y - eye_h // 2 - 3, ex + eye_w // 2 + 3, eye_y + eye_h // 2 + 3], 200, 340, fill=(30, 25, 30), width=4)
        if c["gender"] == "female":
            draw.line([(ex + side * (eye_w // 2), eye_y - 3), (ex + side * (eye_w // 2 + 6), eye_y - 7)], fill=(30, 25, 30), width=3)

    if c["style"] == "cardigan_glasses":
        for side in [-1, 1]:
            gx = cx + side * eye_spacing
            draw.rounded_rectangle([gx - eye_w - 2, eye_y - eye_h - 2, gx + eye_w + 2, eye_y + eye_h + 2], radius=6, outline=(190, 160, 110), width=3)
        draw.line([cx - eye_spacing + eye_w, eye_y, cx + eye_spacing - eye_w, eye_y], fill=(190, 160, 110), width=3)

    # Nose
    nose_y = head_cy + 38
    draw.line([(cx, nose_y - 6), (cx + 3, nose_y + 2)], fill=c["skin_shadow"], width=2)

    # Cheeks
    blush_opacity = 0
    if emotion in ["romantic", "shy"]:
        blush_opacity = 180
    elif emotion in ["happy", "playful", "emotional", "laughing"]:
        blush_opacity = 120
    elif emotion == "excited":
        blush_opacity = 140

    if blush_opacity > 0:
        blush_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        b_draw = ImageDraw.Draw(blush_img)
        blush_col = (255, 110, 140, blush_opacity)
        b_draw.ellipse([cx - eye_spacing - 25, head_cy + 30, cx - eye_spacing + 25, head_cy + 52], fill=blush_col)
        b_draw.ellipse([cx + eye_spacing - 25, head_cy + 30, cx + eye_spacing + 25, head_cy + 52], fill=blush_col)
        blush_img = blush_img.filter(ImageFilter.GaussianBlur(6))
        img.alpha_composite(blush_img)
        draw = ImageDraw.Draw(img)

    # Mouth
    mouth_y = head_cy + 68
    lip_color = (200, 70, 90) if c["gender"] == "female" else (180, 105, 95)

    if emotion in ["happy", "excited"]:
        draw.chord([cx - 22, mouth_y - 5, cx + 22, mouth_y + 20], 0, 180, fill=lip_color, outline=(140, 50, 70))
        draw.chord([cx - 16, mouth_y - 2, cx + 16, mouth_y + 6], 0, 180, fill=(255, 255, 255))
    elif emotion == "laughing":
        draw.chord([cx - 26, mouth_y - 8, cx + 26, mouth_y + 24], 0, 180, fill=(180, 40, 60), outline=(130, 30, 50))
        draw.chord([cx - 20, mouth_y - 4, cx + 20, mouth_y + 6], 0, 180, fill=(255, 255, 255))
        draw.ellipse([cx - 10, mouth_y + 10, cx + 10, mouth_y + 22], fill=(230, 80, 100))
    elif emotion == "romantic":
        draw.arc([cx - 18, mouth_y - 12, cx + 18, mouth_y + 12], 20, 160, fill=lip_color, width=3)
        draw.line([(cx - 14, mouth_y), (cx + 14, mouth_y)], fill=(230, 110, 130), width=2)
    elif emotion == "shy":
        draw.arc([cx - 12, mouth_y - 6, cx + 12, mouth_y + 8], 25, 155, fill=lip_color, width=3)
    elif emotion == "sad":
        draw.arc([cx - 18, mouth_y + 4, cx + 18, mouth_y + 24], 200, 340, fill=lip_color, width=3)
    elif emotion == "angry":
        draw.line([(cx - 18, mouth_y + 2), (cx + 18, mouth_y + 2)], fill=(120, 40, 40), width=4)
        draw.line([(cx - 14, mouth_y + 6), (cx + 14, mouth_y + 6)], fill=(160, 60, 60), width=2)
    elif emotion == "surprised":
        draw.ellipse([cx - 10, mouth_y - 6, cx + 10, mouth_y + 14], fill=(130, 40, 50), outline=lip_color, width=2)
    elif emotion == "thinking":
        draw.line([(cx - 15, mouth_y + 3), (cx + 12, mouth_y - 2)], fill=lip_color, width=3)
    elif emotion == "playful":
        draw.arc([cx - 16, mouth_y - 10, cx + 16, mouth_y + 14], 15, 165, fill=lip_color, width=3)
        draw.line([(cx + 14, mouth_y + 2), (cx + 20, mouth_y - 4)], fill=lip_color, width=3)
    elif emotion == "emotional":
        draw.arc([cx - 16, mouth_y - 8, cx + 16, mouth_y + 10], 30, 150, fill=lip_color, width=3)

    # Front Hair
    hair_col = c["hair"]
    hair_hi = c["hair_highlight"]

    if c["hair_type"] == "short_wavy":
        draw.ellipse([cx - head_rx - 15, head_cy - head_ry - 30, cx + head_rx + 15, head_cy - 10], fill=hair_col)
        draw.polygon([(cx - 70, head_cy - 20), (cx - 40, head_cy + 15), (cx - 20, head_cy - 30)], fill=hair_col)
        draw.polygon([(cx - 30, head_cy - 20), (cx + 5, head_cy + 10), (cx + 30, head_cy - 30)], fill=hair_col)
        draw.polygon([(cx + 20, head_cy - 20), (cx + 60, head_cy + 5), (cx + 75, head_cy - 20)], fill=hair_col)
        draw.arc([cx - 45, head_cy - head_ry - 15, cx + 45, head_cy - head_ry + 25], 200, 340, fill=hair_hi, width=6)

    elif c["hair_type"] == "long_flowy":
        draw.ellipse([cx - head_rx - 20, head_cy - head_ry - 35, cx + head_rx + 20, head_cy + 10], fill=hair_col)
        draw.polygon([(cx - head_rx - 5, head_cy - 20), (cx - head_rx + 15, head_cy + 150), (cx - head_rx - 20, head_cy + 120)], fill=hair_col)
        draw.polygon([(cx + head_rx - 15, head_cy - 20), (cx + head_rx + 5, head_cy + 150), (cx + head_rx + 20, head_cy + 120)], fill=hair_col)
        draw.polygon([(cx - 75, head_cy - 30), (cx - 30, head_cy + 12), (cx - 10, head_cy - 40)], fill=hair_col)
        draw.polygon([(cx - 10, head_cy - 40), (cx + 35, head_cy + 15), (cx + 75, head_cy - 30)], fill=hair_col)
        draw.arc([cx - 50, head_cy - head_ry - 10, cx + 50, head_cy - head_ry + 30], 210, 330, fill=hair_hi, width=8)

    elif c["hair_type"] == "messy_undercut":
        draw.ellipse([cx - head_rx - 15, head_cy - head_ry - 35, cx + head_rx + 15, head_cy - 15], fill=hair_col)
        for ox in [-70, -45, -20, 10, 35, 65]:
            draw.polygon([(cx + ox - 15, head_cy - 40), (cx + ox, head_cy + 15), (cx + ox + 15, head_cy - 40)], fill=hair_col)
        draw.arc([cx - 50, head_cy - head_ry - 15, cx + 50, head_cy - head_ry + 20], 190, 350, fill=hair_hi, width=5)

    elif c["hair_type"] == "twin_tails":
        draw.ellipse([cx - head_rx - 15, head_cy - head_ry - 30, cx + head_rx + 15, head_cy], fill=hair_col)
        draw.polygon([(cx - 70, head_cy - 20), (cx - 40, head_cy + 20), (cx - 20, head_cy - 30)], fill=hair_col)
        draw.polygon([(cx - 25, head_cy - 20), (cx, head_cy + 25), (cx + 25, head_cy - 20)], fill=hair_col)
        draw.polygon([(cx + 20, head_cy - 20), (cx + 50, head_cy + 20), (cx + 70, head_cy - 20)], fill=hair_col)
        draw.ellipse([cx - 85, head_cy - 20, cx - 60, head_cy], fill=(240, 70, 100))
        draw.ellipse([cx + 60, head_cy - 20, cx + 85, head_cy], fill=(240, 70, 100))

    elif c["hair_type"] == "sleek_back":
        draw.ellipse([cx - head_rx - 10, head_cy - head_ry - 35, cx + head_rx + 10, head_cy - 10], fill=hair_col)
        draw.arc([cx - 60, head_cy - head_ry - 10, cx + 60, head_cy - head_ry + 30], 210, 330, fill=hair_hi, width=7)

    elif c["hair_type"] == "side_swept_glam":
        draw.ellipse([cx - head_rx - 20, head_cy - head_ry - 35, cx + head_rx + 20, head_cy + 10], fill=hair_col)
        draw.polygon([(cx - head_rx - 10, head_cy - 20), (cx - head_rx + 25, head_cy + 180), (cx - head_rx - 25, head_cy + 140)], fill=hair_col)
        draw.polygon([(cx - 65, head_cy - 30), (cx + 40, head_cy + 20), (cx + 70, head_cy - 30)], fill=hair_col)
        draw.arc([cx - 45, head_cy - head_ry - 10, cx + 45, head_cy - head_ry + 35], 200, 340, fill=hair_hi, width=7)

    elif c["hair_type"] == "soft_curls":
        draw.ellipse([cx - head_rx - 15, head_cy - head_ry - 30, cx + head_rx + 15, head_cy - 10], fill=hair_col)
        for ox in [-60, -30, 0, 30, 60]:
            draw.ellipse([cx + ox - 18, head_cy - 35, cx + ox + 18, head_cy + 10], fill=hair_col)
        draw.arc([cx - 45, head_cy - head_ry - 10, cx + 45, head_cy - head_ry + 20], 200, 340, fill=hair_hi, width=6)

    elif c["hair_type"] == "bob_with_bangs":
        draw.ellipse([cx - head_rx - 15, head_cy - head_ry - 30, cx + head_rx + 15, head_cy + 20], fill=hair_col)
        draw.polygon([(cx - head_rx - 15, head_cy - 20), (cx - head_rx + 10, head_cy + 110), (cx - head_rx - 20, head_cy + 80)], fill=hair_col)
        draw.polygon([(cx + head_rx - 10, head_cy - 20), (cx + head_rx + 15, head_cy + 110), (cx + head_rx + 20, head_cy + 80)], fill=hair_col)
        draw.rectangle([cx - 60, head_cy - 25, cx + 60, head_cy + 5], fill=hair_col)
        draw.arc([cx - 40, head_cy - head_ry - 10, cx + 40, head_cy - head_ry + 20], 200, 340, fill=hair_hi, width=7)

    elif c["hair_type"] == "spiky_wolf":
        draw.ellipse([cx - head_rx - 18, head_cy - head_ry - 35, cx + head_rx + 18, head_cy - 5], fill=hair_col)
        for ox in [-75, -50, -25, 5, 30, 55, 75]:
            draw.polygon([(cx + ox - 15, head_cy - 35), (cx + ox, head_cy + 20), (cx + ox + 15, head_cy - 35)], fill=hair_col)
        draw.arc([cx - 50, head_cy - head_ry - 15, cx + 50, head_cy - head_ry + 25], 195, 345, fill=hair_hi, width=6)

    elif c["hair_type"] == "long_straight":
        draw.ellipse([cx - head_rx - 18, head_cy - head_ry - 35, cx + head_rx + 18, head_cy + 5], fill=hair_col)
        draw.polygon([(cx - head_rx - 15, head_cy - 20), (cx - head_rx + 10, head_cy + 220), (cx - head_rx - 25, head_cy + 180)], fill=hair_col)
        draw.polygon([(cx + head_rx - 10, head_cy - 20), (cx + head_rx + 15, head_cy + 220), (cx + head_rx + 25, head_cy + 180)], fill=hair_col)
        draw.polygon([(cx - 70, head_cy - 25), (cx - 15, head_cy + 12), (cx + 5, head_cy - 30)], fill=hair_col)
        draw.polygon([(cx + 5, head_cy - 30), (cx + 35, head_cy + 15), (cx + 70, head_cy - 25)], fill=hair_col)
        draw.arc([cx - 45, head_cy - head_ry - 10, cx + 45, head_cy - head_ry + 25], 200, 340, fill=hair_hi, width=7)

    # Emotion particles
    fx_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fx_draw = ImageDraw.Draw(fx_img)

    if emotion == "romantic":
        for hx, hy, hs in [(cx + 120, head_cy - 40, 16), (cx - 110, head_cy + 20, 12), (cx + 95, head_cy + 80, 14)]:
            fx_draw.ellipse([hx - hs, hy - hs, hx, hy], fill=(255, 90, 140, 220))
            fx_draw.ellipse([hx, hy - hs, hx + hs, hy], fill=(255, 90, 140, 220))
            fx_draw.polygon([(hx - hs, hy - hs // 4), (hx + hs, hy - hs // 4), (hx, hy + hs)], fill=(255, 90, 140, 220))

    elif emotion in ["sad", "emotional"]:
        tx, ty = cx - eye_spacing + 12, eye_y + 16
        fx_draw.ellipse([tx - 4, ty, tx + 4, ty + 12], fill=(180, 225, 255, 230))
        fx_draw.polygon([(tx - 4, ty + 6), (tx + 4, ty + 6), (tx, ty - 2)], fill=(180, 225, 255, 230))

    elif emotion in ["excited", "happy"]:
        for sx, sy, ss in [(cx + 115, head_cy - 30, 14), (cx - 105, head_cy - 50, 10), (cx + 100, head_cy + 60, 12)]:
            fx_draw.polygon([(sx, sy - ss), (sx + ss // 4, sy), (sx, sy + ss), (sx - ss // 4, sy)], fill=(255, 230, 110, 240))
            fx_draw.polygon([(sx - ss, sy), (sx, sy + ss // 4), (sx + ss, sy), (sx, sy - ss // 4)], fill=(255, 230, 110, 240))

    elif emotion == "thinking":
        for bx, by, br in [(cx + 105, head_cy - 50, 5), (cx + 115, head_cy - 65, 8), (cx + 130, head_cy - 85, 14)]:
            fx_draw.ellipse([bx - br, by - br, bx + br, by + br], fill=(210, 220, 255, 200))

    elif emotion == "shy":
        fx_draw.arc([cx + head_rx + 5, head_cy - 15, cx + head_rx + 25, head_cy + 15], 160, 320, fill=(160, 210, 255, 220), width=3)

    elif emotion == "angry":
        vx, vy = cx + 55, head_cy - 35
        fx_draw.arc([vx - 10, vy - 10, vx + 10, vy], 20, 160, fill=(220, 50, 50, 230), width=3)
        fx_draw.arc([vx - 10, vy, vx + 10, vy + 10], 200, 340, fill=(220, 50, 50, 230), width=3)
        fx_draw.arc([vx - 10, vy - 10, vx, vy + 10], 290, 430, fill=(220, 50, 50, 230), width=3)
        fx_draw.arc([vx, vy - 10, vx + 10, vy + 10], 110, 250, fill=(220, 50, 50, 230), width=3)

    img.alpha_composite(fx_img)
    return img

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    count = 0
    for char_id in CHARACTERS:
        char_folder = os.path.join(OUTPUT_DIR, char_id)
        os.makedirs(char_folder, exist_ok=True)
        for emotion in EMOTIONS:
            img = draw_character(char_id, emotion)
            out_path = os.path.join(char_folder, f"{emotion}.png")
            img.save(out_path, "PNG")
            count += 1
    print(f"Generated {count} transparent character sprites in {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
