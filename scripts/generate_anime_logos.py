import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

def create_circular_avatar(img_path, size=(400, 400), crop_box=None):
    img = Image.open(img_path).convert("RGBA")
    
    # If crop_box is provided (e.g. focused on face)
    if crop_box:
        img = img.crop(crop_box)
    else:
        # Default center crop to square
        w, h = img.size
        min_dim = min(w, h)
        left = (w - min_dim) // 2
        top = int(h * 0.05) # bias towards head/face
        img = img.crop((left, top, left + min_dim, top + min_dim))
        
    img = img.resize(size, Image.Resampling.LANCZOS)
    
    # Circular mask with smooth antialiasing
    mask = Image.new('L', (size[0] * 4, size[1] * 4), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size[0] * 4, size[1] * 4), fill=255)
    mask = mask.resize(size, Image.Resampling.LANCZOS)
    
    avatar = Image.new('RGBA', size, (0, 0, 0, 0))
    avatar.paste(img, (0, 0), mask)
    return avatar

def generate_anime_badge_logo():
    canvas_size = 1024
    im = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    # 1. Background Badge (Modern Dark Squircle with Neon Border)
    margin = 40
    rect_box = [margin, margin, canvas_size - margin, canvas_size - margin]
    radius = 220
    
    # Outer Glow
    for i in range(15, 0, -1):
        alpha = int(120 / (i + 1))
        glow_box = [margin - i*2, margin - i*2, canvas_size - margin + i*2, canvas_size - margin + i*2]
        draw.rounded_rectangle(glow_box, radius=radius + i*2, fill=(255, 45, 115, alpha))
        
    # Main badge background
    draw.rounded_rectangle(rect_box, radius=radius, fill=(15, 18, 30, 255), outline=(255, 75, 140, 220), width=6)
    
    # Inner subtle background radial glow
    center_glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    cg_draw = ImageDraw.Draw(center_glow)
    cg_draw.ellipse([200, 200, 824, 824], fill=(120, 40, 200, 70))
    center_glow = center_glow.filter(ImageFilter.GaussianBlur(80))
    im = Image.alpha_composite(im, center_glow)
    draw = ImageDraw.Draw(im)

    # 2. Get Characters (Male: Damon, Female: Aria)
    boy_avatar = create_circular_avatar('assets/characters/damon/cover.jpg', size=(460, 460))
    girl_avatar = create_circular_avatar('assets/characters/aria/cover.jpg', size=(460, 460))

    # Add glowing rings around avatars
    def draw_avatar_ring(cx, cy, r, color):
        ring_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        r_draw = ImageDraw.Draw(ring_img)
        r_draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=12)
        return ring_img

    # Boy on Left, Girl on Right
    boy_x, boy_y = 120, 220
    girl_x, girl_y = 444, 220

    # Glow rings
    boy_ring = draw_avatar_ring(boy_x + 230, boy_y + 230, 236, (79, 140, 255, 230))
    girl_ring = draw_avatar_ring(girl_x + 230, girl_y + 230, 236, (255, 75, 140, 230))
    
    # Composite Boy
    im.paste(boy_avatar, (boy_x, boy_y), boy_avatar)
    im = Image.alpha_composite(im, boy_ring)
    
    # Composite Girl
    im.paste(girl_avatar, (girl_x, girl_y), girl_avatar)
    im = Image.alpha_composite(im, girl_ring)
    
    draw = ImageDraw.Draw(im)
    
    # 3. Center Heart Accent overlapping both
    heart_center_x, heart_center_y = 512, 450
    # Heart glow
    heart_glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    hg_draw = ImageDraw.Draw(heart_glow)
    hg_draw.ellipse([heart_center_x - 80, heart_center_y - 80, heart_center_x + 80, heart_center_y + 80], fill=(255, 50, 100, 160))
    heart_glow = heart_glow.filter(ImageFilter.GaussianBlur(30))
    im = Image.alpha_composite(im, heart_glow)
    draw = ImageDraw.Draw(im)
    
    # Heart shape polygon
    heart_pts = [
        (512, 490),
        (450, 420),
        (440, 380),
        (465, 355),
        (500, 365),
        (512, 395),
        (524, 365),
        (559, 355),
        (584, 380),
        (574, 420),
        (512, 490)
    ]
    draw.polygon(heart_pts, fill=(255, 60, 120, 255), outline=(255, 255, 255, 240))

    # Sparkle
    draw.polygon([(512, 365), (517, 390), (542, 395), (517, 400), (512, 425), (507, 400), (482, 395), (507, 390)], fill=(255, 240, 150, 255))

    # 4. Text banner / LOVIA styling
    # Banner pill at bottom
    pill_box = [230, 780, 794, 890]
    draw.rounded_rectangle(pill_box, radius=55, fill=(255, 45, 115, 240), outline=(255, 255, 255, 200), width=4)
    
    # Try loading bold font or fallback
    try:
        font = ImageFont.truetype("arialbd.ttf", 64)
        subfont = ImageFont.truetype("arial.ttf", 28)
    except:
        font = ImageFont.load_default()
        subfont = font
        
    text = "L O V I A"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((canvas_size - tw) // 2, 795), text, fill=(255, 255, 255, 255), font=font)

    # Save high-resolution PNG
    output_path = "assets/logo_anime_badge_1024.png"
    im.save(output_path, "PNG")
    print("Saved:", output_path)

def generate_anime_neon_circular_logo():
    canvas_size = 1024
    im = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Circular Badge
    center = 512
    radius = 460
    
    # Outer neon ring glow
    for i in range(20, 0, -2):
        alpha = int(140 / (i + 1))
        draw.ellipse([center - radius - i, center - radius - i, center + radius + i, center + radius + i], outline=(255, 60, 140, alpha), width=6)

    # Base dark circle
    draw.ellipse([center - radius, center - radius, center + radius, center + radius], fill=(12, 14, 24, 255), outline=(255, 80, 160, 255), width=8)

    # Inner character split (Split Circle or Intertwined Duos)
    # Alec & Chloe
    boy_img = create_circular_avatar('assets/characters/alec/cover.jpg', size=(540, 540))
    girl_img = create_circular_avatar('assets/characters/chloe/cover.jpg', size=(540, 540))

    # Dual overlapping circles inside the main emblem
    boy_pos = (70, 200)
    girl_pos = (414, 200)

    im.paste(boy_img, (boy_pos[0], boy_pos[1]), boy_img)
    im.paste(girl_img, (girl_pos[0], girl_pos[1]), girl_img)

    # Glowing border rings
    draw.ellipse([boy_pos[0], boy_pos[1], boy_pos[0] + 540, boy_pos[1] + 540], outline=(0, 210, 255, 220), width=8)
    draw.ellipse([girl_pos[0], girl_pos[1], girl_pos[0] + 540, girl_pos[1] + 540], outline=(255, 60, 130, 220), width=8)

    # Bottom badge ribbon
    ribbon_box = [260, 780, 764, 880]
    draw.rounded_rectangle(ribbon_box, radius=50, fill=(18, 20, 36, 240), outline=(255, 80, 160, 240), width=4)
    
    try:
        font = ImageFont.truetype("arialbd.ttf", 52)
    except:
        font = ImageFont.load_default()
        
    text = "ANIME DUO"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((canvas_size - tw) // 2, 802), text, fill=(255, 255, 255, 255), font=font)

    output_path = "assets/logo_anime_neon_circular.png"
    im.save(output_path, "PNG")
    print("Saved:", output_path)

if __name__ == "__main__":
    os.makedirs("assets", exist_ok=True)
    generate_anime_badge_logo()
    generate_anime_neon_circular_logo()
