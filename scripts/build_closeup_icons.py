import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance
from build_full_bleed_icons import create_squircle_mask, draw_curved_bottom_banner, draw_stars

def generate_ultra_closeup_icon(male_char, female_char, out_path, title="Lovia"):
    size = 1024
    im = Image.new("RGBA", (size, size), (20, 15, 35, 255))

    # 1. Load male and female images
    male_src = Image.open(f"assets/characters/{male_char}/cover.jpg").convert("RGBA")
    female_src = Image.open(f"assets/characters/{female_char}/cover.jpg").convert("RGBA")

    # Ultra close-up zoom directly on eye/face level (like Reference 1 Zoya & Reference 3 Character Me)
    mw, mh = male_src.size
    male_crop_w = int(mw * 0.58)
    male_crop_h = int(male_crop_w * (size / 620))
    m_left = int(mw * 0.20)
    m_top = int(mh * 0.02)
    male_crop = male_src.crop((m_left, m_top, m_left + male_crop_w, min(mh, m_top + male_crop_h)))
    male_crop = male_crop.resize((650, size), Image.Resampling.LANCZOS)
    male_crop = ImageEnhance.Color(male_crop).enhance(1.25)
    male_crop = ImageEnhance.Contrast(male_crop).enhance(1.12)

    fw, fh = female_src.size
    female_crop_w = int(fw * 0.58)
    female_crop_h = int(female_crop_w * (size / 640))
    f_left = int(fw * 0.20)
    f_top = int(fh * 0.02)
    female_crop = female_src.crop((f_left, f_top, f_left + female_crop_w, min(fh, f_top + female_crop_h)))
    female_crop = female_crop.resize((660, size), Image.Resampling.LANCZOS)
    female_crop = ImageEnhance.Color(female_crop).enhance(1.32)
    female_crop = ImageEnhance.Contrast(female_crop).enhance(1.12)

    # Paste male
    im.paste(male_crop, (0, 0))

    # Female blend mask
    female_mask = Image.new("L", (660, size), 255)
    fm_draw = ImageDraw.Draw(female_mask)
    blend_width = 260
    for x in range(blend_width):
        t = x / blend_width
        alpha = int(255 * (3*t**2 - 2*t**3))
        fm_draw.line([(x, 0), (x, size)], fill=alpha)

    female_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    female_layer.paste(female_crop, (size - 660, 0), female_mask)
    im = Image.alpha_composite(im, female_layer)

    # Glow & sparkles
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    g_draw.ellipse([340, 100, 680, 500], fill=(255, 60, 140, 50))
    g_draw.ellipse([-40, 100, 260, 700], fill=(0, 220, 255, 40))
    glow = glow.filter(ImageFilter.GaussianBlur(50))
    im = Image.alpha_composite(im, glow)

    # Sparkles
    sp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sp_d = ImageDraw.Draw(sp)
    draw_stars(sp_d, 120, 160, size=20, color=(255, 255, 255, 240))
    draw_stars(sp_d, 220, 110, size=13, color=(0, 240, 255, 240))
    draw_stars(sp_d, 900, 200, size=18, color=(255, 120, 200, 240))
    draw_stars(sp_d, 840, 320, size=15, color=(255, 255, 255, 220))
    draw_stars(sp_d, 500, 90, size=22, color=(255, 245, 170, 255))
    im = Image.alpha_composite(im, sp)

    # Curved Banner
    banner_layer, border_layer = draw_curved_bottom_banner(size, title)
    im = Image.alpha_composite(im, banner_layer)
    im = Image.alpha_composite(im, border_layer)

    # Typography
    draw = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("arialbd.ttf", 98)
    except:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), title, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2
    ty = size - 165

    draw_stars(draw, tx - 54, ty + th//2, size=18, color=(15, 10, 25, 255))
    draw_stars(draw, tx - 54, ty + th//2, size=14, color=(255, 255, 255, 255))
    draw_stars(draw, tx + tw + 54, ty + th//2, size=18, color=(15, 10, 25, 255))
    draw_stars(draw, tx + tw + 54, ty + th//2, size=14, color=(255, 255, 255, 255))

    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if dx*dx + dy*dy <= 16:
                draw.text((tx + dx, ty + dy), title, fill=(12, 10, 24, 255), font=font)

    draw.text((tx, ty), title, fill=(255, 255, 255, 255), font=font)

    mask = create_squircle_mask(size, radius=220)
    final_icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final_icon.paste(im, (0, 0), mask)

    final_icon.save(out_path, "PNG")
    print("Generated ultra close-up icon:", out_path)

if __name__ == "__main__":
    generate_ultra_closeup_icon("damon", "aria", "assets/app_icon_closeup_damon_aria.png", "Lovia")
    generate_ultra_closeup_icon("jax_thorne_flirty", "delilah_hart_flirty", "assets/app_icon_closeup_jax_delilah.png", "Lovia")
    generate_ultra_closeup_icon("alec", "chloe", "assets/app_icon_closeup_alec_chloe.png", "Lovia")
