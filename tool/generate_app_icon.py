"""產生 App 圖示（Android）。

造型取自 lib/ui/widgets/placeholder_character.dart 的佔位角色，配色取自
lib/core/app_theme.dart，讓 icon 跟 App 裡看到的她是同一個人。

用法：python tool/generate_app_icon.py
產出：
  android/app/src/main/res/mipmap-*/ic_launcher.png            舊版方形圖示（API 21~25）
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png adaptive icon 前景（API 26+）
  android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png themed icon 單色層（API 33+）
  android/app/src/main/ic_launcher-playstore.png               上架用 512px 圖
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# 與 AppTheme 同一組色
BLUSH = (247, 200, 208, 255)
ROSE = (231, 154, 168, 255)
DEEP_ROSE = (180, 104, 122, 255)
INK = (91, 74, 80, 255)
SKIN = (252, 227, 214, 255)
HAIR = (110, 75, 58, 255)
WHITE = (255, 255, 255, 255)
BG_TOP = (255, 241, 243)
BG_BOTTOM = (243, 185, 198)

# 各密度對應的像素數：舊版圖示 48dp、adaptive 圖層 108dp
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

SS = 4  # 先放大 4 倍畫再縮小，用縮圖換抗鋸齒


def _question_font(size):
    """問號用粗體字型畫最漂亮；跨平台跑不到就回 None，改用手繪。"""
    for name in ("arialbd.ttf", "seguisb.ttf", "DejaVuSans-Bold.ttf", "Arial Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return None


def render_character(canvas=4096, mono=False):
    """把角色畫在一張夠大的透明畫布上，回傳裁到內容邊界的圖。

    座標以「臉寬」為單位、臉心為原點，跟 placeholder_character.dart 的比例對齊。
    mono=True 回傳單色層（themed icon 用）：只靠一層 alpha 表達造型，
    所以頭髮挖掉臉、氣泡畫成圈，不然整顆頭會糊成一塊剪影。
    """
    fw = canvas * 0.24
    cx, cy = canvas * 0.46, canvas * 0.52

    def box(x, y, w, h):
        return [cx + (x - w / 2) * fw, cy + (y - h / 2) * fw,
                cx + (x + w / 2) * fw, cy + (y + h / 2) * fw]

    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    mask = Image.new("L", (canvas, canvas), 0)  # 單色層的 alpha：255 = 實心
    d = ImageDraw.Draw(img)
    m = ImageDraw.Draw(mask)

    def shape(kind, xywh, fill=None, solid=None, **kw):
        """fill=彩色層顏色（None 表示只畫單色層）；solid=單色層填 255/0（None 表示不畫）。"""
        if fill is not None:
            getattr(d, kind)(box(*xywh), fill=fill, **kw)
        if solid is not None:
            getattr(m, kind)(box(*xywh), fill=solid, **kw)

    # 後髮 → 臉 → 瀏海，順序跟 App 裡的疊法一致。
    # 只取頭像：身體在小尺寸下會糊成一團跟底色分不開。
    # 後髮要比臉寬（兩側露出頭髮）但下緣收在下巴以上，不然會變成落腮鬍
    shape("ellipse", (0, -0.09, 1.42, 1.32), HAIR, solid=255)
    shape("ellipse", (0, 0.03, 1.00, 1.12), SKIN, solid=0)
    shape("pieslice", (0, -0.30, 1.08, 1.02), HAIR, solid=255, start=180, end=360)
    shape("ellipse", (0, -0.30, 1.08, 0.50), HAIR, solid=255)

    # 眼睛（含高光）與腮紅、嘴巴
    for sx in (-0.25, 0.25):
        shape("ellipse", (sx, 0.05, 0.19, 0.25), INK, solid=255)
        shape("ellipse", (sx - 0.04, -0.01, 0.07, 0.09), WHITE)
    for sx in (-0.36, 0.36):
        shape("ellipse", (sx, 0.28, 0.22, 0.13), ROSE)
    shape("ellipse", (0, 0.36, 0.15, 0.13), DEEP_ROSE, solid=255)

    # 頭上的問號：她聽錯了才是重點
    bx, by, br = 0.80, -0.62, 0.34

    def qbox(x, y, w, h):
        return box(bx + x * br, by + y * br, w * br, h * br)

    shape("ellipse", (bx, by, br * 2, br * 2), WHITE, solid=255)
    shape("ellipse", (bx, by, br * 1.72, br * 1.72), solid=0)  # 單色層只留外圈
    font = _question_font(round(1.7 * br * fw))
    for target, colour in ((d, DEEP_ROSE), (m, 255)):
        if font is not None:
            target.text(qbox(0, -0.06, 0, 0)[:2], "?", font=font, fill=colour, anchor="mm")
            continue
        # 找不到字型時用弧線＋豎筆＋點自己畫一個問號
        stroke = max(2, int(0.22 * br * fw))
        target.arc(qbox(0, -0.42, 0.92, 0.92), start=170, end=20, fill=colour, width=stroke)
        target.line([qbox(0.43, -0.26, 0, 0)[:2], qbox(0.02, 0.34, 0, 0)[:2]],
                    fill=colour, width=stroke)
        target.ellipse(qbox(0.02, 0.74, 0.30, 0.30), fill=colour)

    if mono:
        art = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        art.paste(Image.new("RGBA", (canvas, canvas), (0, 0, 0, 255)), mask=mask)
    else:
        art = img
    return art.crop(art.getbbox())


def place(art, size, coverage):
    """把角色等比縮到佔畫布 coverage 比例後置中。"""
    scale = size * coverage / max(art.size)
    w, h = max(1, round(art.width * scale)), max(1, round(art.height * scale))
    small = art.resize((w, h), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(small, ((size - w) // 2, (size - h) // 2), small)
    return canvas


def gradient_bg(size, radius_ratio=0.22):
    strip = Image.new("RGB", (1, size))
    px = strip.load()
    for y in range(size):
        t = y / max(1, size - 1)
        px[0, y] = tuple(round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
    bg = strip.resize((size, size), Image.BILINEAR).convert("RGBA")
    if radius_ratio:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, size - 1, size - 1], radius=int(size * radius_ratio), fill=255)
        bg.putalpha(mask)
    return bg


def write(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)
    print(f"  {os.path.relpath(path, ROOT)}  {size}x{size}")


def main():
    art = render_character()
    mono_art = render_character(mono=True)

    for density, factor in DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")

        # 舊版方形圖示：48dp，角色配圓角漸層底
        legacy_px = round(48 * factor)
        big = legacy_px * SS
        legacy = gradient_bg(big)
        legacy.alpha_composite(place(art, big, 0.84))
        write(legacy, os.path.join(folder, "ic_launcher.png"), legacy_px)

        # adaptive icon 圖層：108dp，內容留在中央 66dp 安全區內
        layer_px = round(108 * factor)
        big = layer_px * SS
        write(place(art, big, 0.60),
              os.path.join(folder, "ic_launcher_foreground.png"), layer_px)
        write(place(mono_art, big, 0.60),
              os.path.join(folder, "ic_launcher_monochrome.png"), layer_px)

    # 上架用（Play Console 要 512x512 不透明）
    big = 512 * SS
    store = gradient_bg(big, radius_ratio=0)
    store.alpha_composite(place(art, big, 0.78))
    write(store.convert("RGB"), os.path.join(ROOT, "android", "app", "src", "main",
                                             "ic_launcher-playstore.png"), 512)


if __name__ == "__main__":
    main()
