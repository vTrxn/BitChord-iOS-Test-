import math
from PIL import Image, ImageDraw

def create_app_icon(output_path):
    size = 1024
    img = Image.new("RGB", (size, size), (12, 10, 20))
    draw = ImageDraw.Draw(img)

    # 1. Background Gradient (deep obsidian to violet-indigo)
    cx, cy = size / 2, size / 2
    max_radius = math.sqrt(cx**2 + cy**2)

    for y in range(size):
        for x in range(0, size, 4):  # step by 4 for fast smooth gradient
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / max_radius
            # interpolate from center (32, 22, 58) to edge (12, 10, 20)
            r = int(34 * (1 - dist) + 12 * dist)
            g = int(24 * (1 - dist) + 10 * dist)
            b = int(62 * (1 - dist) + 20 * dist)
            draw.rectangle([x, y, x + 4, y], fill=(r, g, b))

    # 2. Concentric acoustic rings (subtle, elegant)
    ring_color = (60, 45, 100)
    for r in [380, 440, 490]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ring_color, width=2)

    # 3. Inner glowing badge (circle)
    badge_r = 310
    draw.ellipse([cx - badge_r, cy - badge_r, cx + badge_r, cy + badge_r], fill=(24, 18, 44), outline=(80, 50, 140), width=4)

    # 4. Stylized BitChord Waveform Bars
    # Bar heights and positions around center
    bars = [
        {"x": cx - 180, "h": 160, "w": 42, "color": (99, 102, 241)},   # Indigo
        {"x": cx - 90,  "h": 320, "w": 44, "color": (139, 92, 246)},  # Purple
        {"x": cx,       "h": 440, "w": 48, "color": (192, 132, 252)},  # Light Violet
        {"x": cx + 90,  "h": 280, "w": 44, "color": (217, 70, 239)},  # Fuchsia
        {"x": cx + 180, "h": 140, "w": 42, "color": (236, 72, 153)}   # Pink
    ]

    for b in bars:
        bx = b["x"]
        bw = b["w"]
        bh = b["h"]
        col = b["color"]
        top_y = cy - bh / 2
        bot_y = cy + bh / 2
        draw.rounded_rectangle([bx - bw / 2, top_y, bx + bw / 2, bot_y], radius=bw / 2, fill=col)

    # 5. Play indicator dot in center (small bright cyan accent)
    dot_r = 16
    draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=(255, 255, 255))

    img.save(output_path, "PNG")
    print(f"App icon generated at {output_path}")

create_app_icon("C:/Users/USUARIO/BitChord-iOS/BitChord/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
