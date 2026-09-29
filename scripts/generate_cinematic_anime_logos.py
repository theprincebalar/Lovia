import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

def make_avatar(path, size=500):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    min_dim = min(w, h)
    left = (w - min_dim) // 2
    top = int(h * 0.05)
    img = img.crop((left, top, left + min_dim, top + min_dim))
    img = img.resize((size, size), Image.Resampling.LANCZOS)
    
    # Mask
    mask = Image.new('L', (size * 4, size * 4), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size * 4, size * 4), fill=255)
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    
    res = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    res.paste(img, (0, 0), mask)
    return res

def generate_cinematic_split_logo(male_name, female_name, out_name, title="LOVIA"):
    canvas_size = 1024
    im = Image.new("RGBA", (canvas_size, canvas_size), (10, 10, 20, 255))
    draw = ImageDraw.Draw(im)

    # 1. Background radial lighting
    bg_glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_glow)
    bg_draw.ellipse([100, 100, 924, 924], fill=(130, 20, 90, 100))
    bg_glow = bg_glow.filter(ImageFilter.GaussianBlur(100))
    im = Image.alpha_composite(im, bg_glow)
    draw = ImageDraw.Draw(im)

    # Outer Shield / Hexagonal Emblem
    cx, cy, r = 512, 512, 460
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(15, 12, 28, 255), outline=(255, 42, 133, 255), width=8)
    
    # Inner gold dash ring
    draw.ellipse([cx - r + 20, cy - r + 20, cx + r - 20, cy + r - 20], outline=(255, 215, 0, 180), width=3)

    # 2. Diagonal Split Composition
    # Load Male and Female images
    male_img = Image.open(f"assets/characters/{male_name}/cover.jpg").convert("RGBA")
    female_img = Image.open(f"assets/characters/{female_name}/cover.jpg").convert("RGBA")

    # Resize to fill half
    male_sq = male_img.crop((male_img.width//4, int(male_img.height*0.05), int(male_img.width*0.85), int(male_img.height*0.75))).resize((650, 750), Image.Resampling.LANCZOS)
    female_sq = female_img.crop((female_img.width//4, int(female_img.height*0.05), int(female_img.width*0.85), int(female_img.height*0.75))).resize((650, 750), Image.Resampling.LANCZOS)

    # Left mask for male (slanted)
    m_mask = Image.new('L', (canvas_size, canvas_size), 0)
    m_draw = ImageDraw.Draw(m_mask)
    # Slanted polygon on left
    m_draw.polygon([(0, 0), (600, 0), (424, canvas_size), (0, canvas_size)], fill=255)
    # Clip to circular emblem
    circle_mask = Image.new('L', (canvas_size, canvas_size), 0)
    c_draw = ImageDraw.Draw(circle_mask)
    c_draw.ellipse([cx - r + 10, cy - r + 10, cx + r - 10, cy + r - 10], fill=255)
    
    m_final_mask = ImageOps.invert(ImageOps.invert(m_mask))
    m_final_mask = Image.composite(m_mask, Image.new('L', (canvas_size, canvas_size), 0), circle_mask)

    # Right mask for female
    f_mask = Image.new('L', (canvas_size, canvas_size), 0)
    f_draw = ImageDraw.Draw(f_mask)
    f_draw.polygon([(600, 0), (canvas_size, 0), (canvas_size, canvas_size), (424, canvas_size)], fill=255)
    f_final_mask = Image.composite(f_mask, Image.new('L', (canvas_size, canvas_size), 0), circle_mask)

    # Composite Male into left side
    male_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    male_layer.paste(male_sq, (30, 100))
    im.paste(male_layer, (0, 0), m_final_mask)

    # Composite Female into right side
    female_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    female_layer.paste(female_sq, (420, 100))
    im.paste(female_layer, (0, 0), f_final_mask)

    draw = ImageDraw.Draw(im)

    # Slanted neon dividing laser line
    draw.line([(600, cy - r + 10), (424, cy + r - 10)], fill=(0, 240, 255, 255), width=10)
    draw.line([(598, cy - r + 10), (422, cy + r - 10)], fill=(255, 255, 255, 255), width=4)

    # Center Glowing Heart Badge
    heart_box = [cx - 60, cy - 60, cx + 60, cy + 60]
    draw.ellipse(heart_box, fill=(255, 42, 133, 255), outline=(255, 255, 255, 255), width=4)
    # Heart icon
    draw.text((cx - 24, cy - 32), "❤", fill=(255, 255, 255, 255), font=ImageFont.truetype("arialbd.ttf", 48) if os.path.exists("C:/Windows/Fonts/arialbd.ttf") else ImageFont.load_default())

    # Bottom Banner
    pill_box = [200, 790, 824, 910]
    draw.rounded_rectangle(pill_box, radius=60, fill=(15, 12, 28, 250), outline=(255, 215, 0, 255), width=5)
    
    try:
        font = ImageFont.truetype("arialbd.ttf", 64)
    except:
        font = ImageFont.load_default()
        
    bbox = draw.textbbox((0, 0), title, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((canvas_size - tw) // 2, 815), title, fill=(255, 255, 255, 255), font=font)

    im.save(out_name, "PNG")
    print("Generated:", out_name)

if __name__ == "__main__":
    generate_cinematic_split_logo("damon", "aria", "assets/logo_anime_cinematic_damon_aria.png", "LOVIA")
    generate_cinematic_split_logo("alec", "chloe", "assets/logo_anime_cinematic_alec_chloe.png", "LOVIA")
    generate_cinematic_split_logo("kai", "elena", "assets/logo_anime_cinematic_kai_elena.png", "LOVIA")
