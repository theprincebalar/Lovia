import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps, ImageEnhance

def create_squircle_mask(size, radius=220):
    mask = Image.new('L', (size * 2, size * 2), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size * 2, size * 2], radius=radius * 2, fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)

def draw_stars(draw, x, y, size=16, color=(255, 255, 255, 255)):
    # 4-point sparkle star (✦)
    pts = [
        (x, y - size),
        (x + size*0.25, y - size*0.25),
        (x + size, y),
        (x + size*0.25, y + size*0.25),
        (x, y + size),
        (x - size*0.25, y + size*0.25),
        (x - size, y),
        (x - size*0.25, y - size*0.25)
    ]
    draw.polygon(pts, fill=color)

def draw_curved_bottom_banner(canvas_size, text="Lovia"):
    w, h = canvas_size, canvas_size
    
    # Curved banner polygon (wave curve at top)
    pts = [(0, h), (w, h), (w, h - 220)]
    for x in range(w, -1, -16):
        t = x / w
        # Asymmetric smooth curve like Reference 1 (Zoya)
        y = (h - 225) + 32 * math.sin(t * math.pi) + 18 * math.cos(t * math.pi * 1.4)
        pts.append((x, int(y)))
    pts.append((0, h - 180))

    banner_mask = Image.new('L', (w, h), 0)
    b_draw = ImageDraw.Draw(banner_mask)
    b_draw.polygon(pts, fill=255)

    # Gradient: Electric Cyan (#00E5FF) to Hot Pink (#FF1493) to Violet (#8A2BE2)
    grad = Image.new('RGBA', (w, h), 0)
    for x in range(w):
        t = x / w
        r = int(0 * (1 - t) + 255 * t)
        g = int(225 * (1 - t) + 40 * t)
        b = int(255 * (1 - t) + 190 * t)
        for y in range(h - 280, h):
            grad.putpixel((x, y), (r, g, b, 250))

    banner_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    banner_layer.paste(grad, (0, 0), banner_mask)

    # Top border curve
    border_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border_layer)
    curve_pts = [p for p in pts if p[1] < h - 10]
    for i in range(len(curve_pts) - 1):
        border_draw.line([curve_pts[i], curve_pts[i+1]], fill=(255, 255, 255, 240), width=6)

    return banner_layer, border_layer

def generate_full_bleed_duo_icon(male_char, female_char, out_path, title="Lovia"):
    size = 1024
    im = Image.new("RGBA", (size, size), (20, 15, 35, 255))

    # 1. Load male and female images
    male_src = Image.open(f"assets/characters/{male_char}/cover.jpg").convert("RGBA")
    female_src = Image.open(f"assets/characters/{female_char}/cover.jpg").convert("RGBA")

    # Zoom in significantly on the faces so their hair/heads reach and slightly crop past y=0
    # Male: Focus on head/face and upper chest
    mw, mh = male_src.size
    male_crop_w = int(mw * 0.72)
    male_crop_h = int(male_crop_w * (size / 600))
    m_left = int(mw * 0.12)
    m_top = 0 # Start right at the very top (y=0) to eliminate top space completely
    male_crop = male_src.crop((m_left, m_top, m_left + male_crop_w, min(mh, m_top + male_crop_h)))
    male_crop = male_crop.resize((620, size), Image.Resampling.LANCZOS)
    male_crop = ImageEnhance.Color(male_crop).enhance(1.2)
    male_crop = ImageEnhance.Contrast(male_crop).enhance(1.12)

    # Female: Focus on alluring face/eyes and hair
    fw, fh = female_src.size
    female_crop_w = int(fw * 0.72)
    female_crop_h = int(female_crop_w * (size / 620))
    f_left = int(fw * 0.14)
    f_top = 0 # Start right at the very top (y=0)
    female_crop = female_src.crop((f_left, f_top, f_left + female_crop_w, min(fh, f_top + female_crop_h)))
    female_crop = female_crop.resize((640, size), Image.Resampling.LANCZOS)
    female_crop = ImageEnhance.Color(female_crop).enhance(1.28)
    female_crop = ImageEnhance.Contrast(female_crop).enhance(1.1)

    # 2. Paste Male on Left (Starts at top-left 0, 0)
    im.paste(male_crop, (0, 0))

    # 3. Create smooth romantic blend mask for Female on Right
    female_mask = Image.new("L", (640, size), 255)
    fm_draw = ImageDraw.Draw(female_mask)
    # Smooth S-curve gradient fade on the left side of the female crop
    blend_width = 240
    for x in range(blend_width):
        t = x / blend_width
        # Smooth cubic ease
        alpha = int(255 * (3*t**2 - 2*t**3))
        fm_draw.line([(x, 0), (x, size)], fill=alpha)

    # Paste Female on Right (Starts at y=0)
    female_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    female_layer.paste(female_crop, (size - 640, 0), female_mask)
    im = Image.alpha_composite(im, female_layer)

    # 4. Add subtle lighting & romantic glow in the middle
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    # Warm romantic center aura
    g_draw.ellipse([340, 100, 680, 500], fill=(255, 60, 140, 45))
    # Cyan highlight on male edge
    g_draw.ellipse([-40, 100, 260, 700], fill=(0, 220, 255, 35))
    glow = glow.filter(ImageFilter.GaussianBlur(50))
    im = Image.alpha_composite(im, glow)

    # 5. Add Sparkles (✦) like reference Zoya / Character Me
    sp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sp_d = ImageDraw.Draw(sp)
    draw_stars(sp_d, 120, 180, size=18, color=(255, 255, 255, 230))
    draw_stars(sp_d, 220, 130, size=12, color=(0, 240, 255, 240))
    draw_stars(sp_d, 890, 220, size=16, color=(255, 120, 200, 240))
    draw_stars(sp_d, 830, 360, size=14, color=(255, 255, 255, 220))
    draw_stars(sp_d, 490, 110, size=20, color=(255, 245, 170, 255))
    im = Image.alpha_composite(im, sp)

    # 6. Signature Curved Bottom Banner
    banner_layer, border_layer = draw_curved_bottom_banner(size, title)
    im = Image.alpha_composite(im, banner_layer)
    im = Image.alpha_composite(im, border_layer)

    # 7. Typography on Banner
    draw = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("arialbd.ttf", 96)
    except:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), title, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2
    ty = size - 165

    # Star accents beside title (✦ Lovia ✦)
    draw_stars(draw, tx - 52, ty + th//2, size=18, color=(15, 10, 25, 255))
    draw_stars(draw, tx - 52, ty + th//2, size=14, color=(255, 255, 255, 255))
    draw_stars(draw, tx + tw + 52, ty + th//2, size=18, color=(15, 10, 25, 255))
    draw_stars(draw, tx + tw + 52, ty + th//2, size=14, color=(255, 255, 255, 255))

    # Bold 3D outline/shadow for text
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if dx*dx + dy*dy <= 16:
                draw.text((tx + dx, ty + dy), title, fill=(12, 10, 24, 255), font=font)

    # Main White Text
    draw.text((tx, ty), title, fill=(255, 255, 255, 255), font=font)

    # 8. Apply App Icon Squircle Mask (100% full-bleed from top to bottom)
    mask = create_squircle_mask(size, radius=220)
    final_icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final_icon.paste(im, (0, 0), mask)

    final_icon.save(out_path, "PNG")
    print("Generated full-bleed icon:", out_path)

if __name__ == "__main__":
    os.makedirs("assets", exist_ok=True)
    # Generate for Damon & Aria, Jax & Delilah, Alec & Chloe, and Kai & Elena
    generate_full_bleed_duo_icon("damon", "aria", "assets/app_icon_fullbleed_damon_aria.png", "Lovia")
    generate_full_bleed_duo_icon("jax_thorne_flirty", "delilah_hart_flirty", "assets/app_icon_fullbleed_jax_delilah.png", "Lovia")
    generate_full_bleed_duo_icon("alec", "chloe", "assets/app_icon_fullbleed_alec_chloe.png", "Lovia")
    generate_full_bleed_duo_icon("kai", "elena", "assets/app_icon_fullbleed_kai_elena.png", "Lovia")
