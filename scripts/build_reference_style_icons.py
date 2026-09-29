import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps, ImageEnhance

def create_squircle_mask(size, radius=220):
    mask = Image.new('L', (size * 2, size * 2), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size * 2, size * 2], radius=radius * 2, fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)

def crop_character_portrait(img_path, target_size=(1024, 1024), face_zoom=1.4, offset_x=0.5, offset_y=0.25):
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    
    crop_w = int(w / face_zoom)
    crop_h = int(crop_w * (target_size[1] / target_size[0]))
    
    if crop_h > h:
        crop_h = h
        crop_w = int(crop_h * (target_size[0] / target_size[1]))
        
    left = int(w * offset_x - crop_w / 2)
    top = int(h * offset_y - crop_h / 2)
    
    left = max(0, min(w - crop_w, left))
    top = max(0, min(h - crop_h, top))
    
    cropped = img.crop((left, top, left + crop_w, top + crop_h))
    return cropped.resize(target_size, Image.Resampling.LANCZOS)

def draw_curved_bottom_banner(draw, canvas_size, text="Lovia", subtitle=""):
    w, h = canvas_size, canvas_size
    
    # Curved banner polygon (wave curve at top)
    pts = []
    # Bottom-left
    pts.append((0, h))
    # Bottom-right
    pts.append((w, h))
    # Right side
    pts.append((w, h - 220))
    
    # Top curved curve points
    for x in range(w, -1, -20):
        # Sine wave / soft curve for top edge
        # reference 1 & 3 style: smooth concave curve or slight crest
        t = x / w
        y = (h - 230) + 30 * math.sin(t * math.pi) + 20 * math.cos(t * math.pi * 1.5)
        pts.append((x, int(y)))
        
    pts.append((0, h - 180))

    # Banner mask & gradient
    banner_mask = Image.new('L', (w, h), 0)
    b_draw = ImageDraw.Draw(banner_mask)
    b_draw.polygon(pts, fill=255)

    # Gradient: Vibrant Cyan -> Pink -> Magenta
    grad = Image.new('RGBA', (w, h), 0)
    for x in range(w):
        t = x / w
        r = int(0 * (1 - t) + 255 * t)
        g = int(220 * (1 - t) + 40 * t)
        b = int(255 * (1 - t) + 180 * t)
        for y in range(h - 300, h):
            grad.putpixel((x, y), (r, g, b, 245))

    banner_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    banner_layer.paste(grad, (0, 0), banner_mask)

    # Top glowing border of banner
    border_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border_layer)
    curve_pts = [p for p in pts if p[1] < h - 10]
    for i in range(len(curve_pts) - 1):
        border_draw.line([curve_pts[i], curve_pts[i+1]], fill=(255, 255, 255, 220), width=6)

    return banner_layer, border_layer

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

def generate_reference_style_duo_icon(male_char, female_char, out_path, title="Lovia"):
    size = 1024
    im = Image.new("RGBA", (size, size), (15, 12, 28, 255))

    # 1. Background gradient / atmosphere
    bg_grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_grad)
    for y in range(size):
        t = y / size
        r = int(30 * (1-t) + 10 * t)
        g = int(10 * (1-t) + 8 * t)
        b = int(60 * (1-t) + 25 * t)
        bg_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    im = Image.alpha_composite(im, bg_grad)

    # 2. Add atmospheric lighting / heart flare in background (like FateMan ref)
    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(halo)
    h_draw.ellipse([200, 100, 824, 724], fill=(255, 50, 130, 120))
    h_draw.ellipse([400, 200, 924, 724], fill=(0, 200, 255, 90))
    halo = halo.filter(ImageFilter.GaussianBlur(90))
    im = Image.alpha_composite(im, halo)

    # 3. Load Male (Left / Background) & Female (Right / Foreground)
    male_portrait = crop_character_portrait(f"assets/characters/{male_char}/cover.jpg", target_size=(780, 880), face_zoom=1.35, offset_x=0.5, offset_y=0.28)
    female_portrait = crop_character_portrait(f"assets/characters/{female_char}/cover.jpg", target_size=(780, 880), face_zoom=1.35, offset_x=0.5, offset_y=0.28)

    # Color boost & vibrance to match anime reference style
    male_portrait = ImageEnhance.Color(male_portrait).enhance(1.25)
    female_portrait = ImageEnhance.Color(female_portrait).enhance(1.3)
    male_portrait = ImageEnhance.Contrast(male_portrait).enhance(1.1)
    female_portrait = ImageEnhance.Contrast(female_portrait).enhance(1.1)

    # Smooth soft alpha fade for male right edge and female left edge
    # Soft male layer (placed slightly to the left)
    male_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    male_layer.paste(male_portrait, (-40, 60))

    # Soft female layer (placed to the right, in foreground)
    female_mask = Image.new("L", (780, 880), 255)
    f_draw = ImageDraw.Draw(female_mask)
    # Gradient fade on left side of female portrait so male blends seamlessly
    for x in range(200):
        alpha = int(255 * (x / 200)**1.5)
        f_draw.line([(x, 0), (x, 880)], fill=alpha)

    female_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    female_layer.paste(female_portrait, (280, 60), female_mask)

    # Composite Characters
    im = Image.alpha_composite(im, male_layer)
    im = Image.alpha_composite(im, female_layer)

    # 4. Cinematic Rim Light / Neon Haze
    rim_light = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    r_draw = ImageDraw.Draw(rim_light)
    r_draw.ellipse([-50, 100, 250, 700], fill=(0, 240, 255, 60))
    r_draw.ellipse([750, 100, 1050, 700], fill=(255, 40, 130, 80))
    rim_light = rim_light.filter(ImageFilter.GaussianBlur(50))
    im = Image.alpha_composite(im, rim_light)

    # 5. Floating Sparkles / Stars (Anime Aesthetic)
    sparkle_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(sparkle_layer)
    draw_stars(s_draw, 140, 220, size=18, color=(255, 255, 255, 230))
    draw_stars(s_draw, 220, 140, size=12, color=(0, 240, 255, 240))
    draw_stars(s_draw, 880, 240, size=16, color=(255, 120, 200, 240))
    draw_stars(s_draw, 820, 360, size=14, color=(255, 255, 255, 220))
    draw_stars(s_draw, 512, 120, size=22, color=(255, 240, 180, 255))
    im = Image.alpha_composite(im, sparkle_layer)

    # 6. Curved Signature Bottom Banner (References 1, 2, 3)
    banner_layer, border_layer = draw_curved_bottom_banner(s_draw, size, title)
    im = Image.alpha_composite(im, banner_layer)
    im = Image.alpha_composite(im, border_layer)

    # 7. Stylized Typography on Banner
    draw = ImageDraw.Draw(im)
    try:
        # Load bold stylish font
        font = ImageFont.truetype("arialbd.ttf", 90)
    except:
        font = ImageFont.load_default()

    # Draw Text with drop shadow and outline (like Zoya / Character Me / FateMan)
    text_bbox = draw.textbbox((0, 0), title, font=font)
    tw = text_bbox[2] - text_bbox[0]
    th = text_bbox[3] - text_bbox[1]
    tx = (size - tw) // 2
    ty = size - 170

    # Star accents beside title
    draw_stars(draw, tx - 45, ty + th//2, size=18, color=(255, 255, 255, 255))
    draw_stars(draw, tx + tw + 45, ty + th//2, size=18, color=(255, 255, 255, 255))
    draw_stars(draw, tx - 75, ty + th//2 - 15, size=10, color=(10, 10, 20, 240))
    draw_stars(draw, tx + tw + 75, ty + th//2 + 15, size=10, color=(10, 10, 20, 240))

    # Text Shadow
    for dx, dy in [(-3, -3), (3, -3), (-3, 3), (3, 3), (0, 4), (0, -4), (4, 0), (-4, 0)]:
        draw.text((tx + dx, ty + dy), title, fill=(15, 10, 30, 240), font=font)
    # Main White Text
    draw.text((tx, ty), title, fill=(255, 255, 255, 255), font=font)

    # 8. Apply Apple/Google Play App Icon Squircle Mask
    mask = create_squircle_mask(size, radius=220)
    final_icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final_icon.paste(im, (0, 0), mask)

    # Subtle inner border stroke
    border_draw = ImageDraw.Draw(final_icon)
    border_mask = Image.new('L', (size, size), 0)
    b_d = ImageDraw.Draw(border_mask)
    b_d.rounded_rectangle([2, 2, size-3, size-3], radius=220, outline=255, width=4)
    
    # Save
    final_icon.save(out_path, "PNG")
    print("Successfully generated icon:", out_path)

if __name__ == "__main__":
    os.makedirs("assets", exist_ok=True)
    # Generate multiple pairs featuring top app characters
    generate_reference_style_duo_icon("damon", "aria", "assets/app_icon_ref_damon_aria.png", "Lovia")
    generate_reference_style_duo_icon("alec", "chloe", "assets/app_icon_ref_alec_chloe.png", "Lovia")
    generate_reference_style_duo_icon("kai", "elena", "assets/app_icon_ref_kai_elena.png", "Lovia")
    generate_reference_style_duo_icon("jax_thorne_flirty", "delilah_hart_flirty", "assets/app_icon_ref_jax_delilah.png", "Lovia")
