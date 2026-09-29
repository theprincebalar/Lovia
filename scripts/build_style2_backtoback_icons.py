import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps, ImageEnhance

def create_squircle_mask(size, radius=220):
    mask = Image.new('L', (size * 2, size * 2), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size * 2, size * 2], radius=radius * 2, fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)

def draw_stars(draw, x, y, size=16, color=(255, 255, 255, 255)):
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

def generate_back_to_back_icon(male_char, female_char, out_path, title="Lovia"):
    size = 1024
    im = Image.new("RGBA", (size, size), (12, 10, 24, 255))

    # 1. Background with glowing Heart Aura (FateMan reference style)
    bg_glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_d = ImageDraw.Draw(bg_glow)
    
    # Heart Nebula in background
    bg_d.ellipse([260, 150, 764, 650], fill=(255, 45, 120, 160))
    bg_d.ellipse([150, 200, 550, 600], fill=(138, 43, 226, 120))
    bg_d.ellipse([474, 200, 874, 600], fill=(0, 210, 255, 100))
    bg_glow = bg_glow.filter(ImageFilter.GaussianBlur(110))
    im = Image.alpha_composite(im, bg_glow)

    # 2. Male on Left (Silhouetted/Rim-lit bold male)
    male_img = Image.open(f"assets/characters/{male_char}/cover.jpg").convert("RGBA")
    mw, mh = male_img.size
    male_crop = male_img.crop((int(mw*0.1), int(mh*0.05), int(mw*0.9), int(mh*0.8))).resize((680, 850), Image.Resampling.LANCZOS)
    male_crop = ImageEnhance.Contrast(male_crop).enhance(1.2)
    male_crop = ImageEnhance.Color(male_crop).enhance(1.25)

    # 3. Female on Right (Alluring front gaze)
    female_img = Image.open(f"assets/characters/{female_char}/cover.jpg").convert("RGBA")
    fw, fh = female_img.size
    female_crop = female_img.crop((int(fw*0.15), int(fh*0.05), int(fw*0.95), int(fh*0.8))).resize((720, 880), Image.Resampling.LANCZOS)
    female_crop = ImageEnhance.Color(female_crop).enhance(1.35)
    female_crop = ImageEnhance.Brightness(female_crop).enhance(1.05)

    # Compose Male
    im.paste(male_crop, (-20, 70), male_crop)

    # Smooth blend mask for Female
    f_mask = Image.new("L", (720, 880), 255)
    f_d = ImageDraw.Draw(f_mask)
    for x in range(240):
        alpha = int(255 * (x / 240)**1.3)
        f_d.line([(x, 0), (x, 880)], fill=alpha)

    female_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    female_layer.paste(female_crop, (320, 50), f_mask)
    im = Image.alpha_composite(im, female_layer)

    # 4. Cinematic Rim Lighting
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rim_d = ImageDraw.Draw(rim)
    rim_d.ellipse([-80, 150, 200, 750], fill=(0, 240, 255, 80))
    rim_d.ellipse([780, 150, 1080, 750], fill=(255, 45, 120, 90))
    rim = rim.filter(ImageFilter.GaussianBlur(40))
    im = Image.alpha_composite(im, rim)

    # 5. Floating Anime Sparkles (✦)
    sp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sp_d = ImageDraw.Draw(sp)
    draw_stars(sp_d, 120, 180, size=20, color=(255, 255, 255, 240))
    draw_stars(sp_d, 260, 110, size=14, color=(0, 240, 255, 240))
    draw_stars(sp_d, 900, 210, size=22, color=(255, 120, 200, 255))
    draw_stars(sp_d, 840, 340, size=14, color=(255, 255, 255, 220))
    draw_stars(sp_d, 512, 90, size=24, color=(255, 240, 150, 255))
    im = Image.alpha_composite(im, sp)

    # 6. Curved Bottom Ribbon Banner (Zoya & Character Me style)
    banner_mask = Image.new('L', (size, size), 0)
    b_d = ImageDraw.Draw(banner_mask)
    pts = [(0, size), (size, size), (size, size - 210)]
    for x in range(size, -1, -20):
        t = x / size
        # Asymmetrical wave crest
        y = (size - 220) + 35 * math.sin(t * math.pi) - 15 * math.cos(t * math.pi * 2)
        pts.append((x, int(y)))
    pts.append((0, size - 170))
    b_d.polygon(pts, fill=255)

    # Gradient: Magenta (#FF1493) to Electric Cyan (#00E5FF)
    banner_grad = Image.new('RGBA', (size, size), 0)
    for x in range(size):
        t = x / size
        # Vibrant pink to purple gradient
        r = int(255 * (1 - t) + 120 * t)
        g = int(40 * (1 - t) + 20 * t)
        b = int(140 * (1 - t) + 240 * t)
        for y in range(size - 260, size):
            banner_grad.putpixel((x, y), (r, g, b, 245))

    banner_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    banner_layer.paste(banner_grad, (0, 0), banner_mask)
    im = Image.alpha_composite(im, banner_layer)

    # Top border line for banner
    border_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border_layer)
    curve_pts = [p for p in pts if p[1] < size - 10]
    for i in range(len(curve_pts) - 1):
        b_draw.line([curve_pts[i], curve_pts[i+1]], fill=(255, 255, 255, 230), width=5)
    im = Image.alpha_composite(im, border_layer)

    # 7. Typography (with script/bold outline)
    draw = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("arialbd.ttf", 94)
    except:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), title, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2
    ty = size - 160

    # Star icons framing the name
    draw_stars(draw, tx - 50, ty + th//2, size=18, color=(15, 10, 25, 255))
    draw_stars(draw, tx - 50, ty + th//2, size=14, color=(255, 255, 255, 255))
    draw_stars(draw, tx + tw + 50, ty + th//2, size=18, color=(15, 10, 25, 255))
    draw_stars(draw, tx + tw + 50, ty + th//2, size=14, color=(255, 255, 255, 255))

    # Bold 3D Drop Shadow / Outline
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if dx*dx + dy*dy <= 16:
                draw.text((tx + dx, ty + dy), title, fill=(10, 8, 22, 255), font=font)

    # Main Crisp White Text
    draw.text((tx, ty), title, fill=(255, 255, 255, 255), font=font)

    # 8. Squircle mask
    mask = create_squircle_mask(size, radius=220)
    final_icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final_icon.paste(im, (0, 0), mask)
    final_icon.save(out_path, "PNG")
    print("Saved:", out_path)

if __name__ == "__main__":
    generate_back_to_back_icon("damon", "aria", "assets/app_icon_ref_backtoback_damon_aria.png", "Lovia")
    generate_back_to_back_icon("alec", "chloe", "assets/app_icon_ref_backtoback_alec_chloe.png", "Lovia")
    generate_back_to_back_icon("jax_thorne_flirty", "delilah_hart_flirty", "assets/app_icon_ref_backtoback_jax_delilah.png", "Lovia")
