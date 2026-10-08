"""Erzeugt das App-Icon (Fina) für Android und iOS.

    python tool/make_icons.py

Android: klassische mipmaps + adaptives Icon (Vordergrund-PNG, Hintergrundfarbe
aus res/values/colors.xml). iOS: überschreibt alle PNGs im AppIcon-Set in ihrer
jeweiligen Größe (ohne Alphakanal, wie Apple es verlangt).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SS = 4  # Supersampling für glatte Kanten

INK = (58, 47, 56, 255)
BG_TOP = (252, 240, 246)
BG_BOTTOM = (243, 214, 232)
BODY_A = (250, 211, 230)
BODY_B = (229, 156, 203)


def gradient(size, c1, c2, diagonal=False):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = ((x / w + y / h) / 2) if diagonal else (y / h)
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,)
    return img


def ellipse(draw, cx, cy, w, h, fill):
    draw.ellipse([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], fill=fill)


def draw_fina(canvas, cx, cy, f):
    """Zeichnet Fina mit Mittelpunkt (cx, cy) und Figurgröße f."""
    s = canvas.size[0]
    # Schatten
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [cx - 0.24 * f, cy + 0.33 * f, cx + 0.24 * f, cy + 0.37 * f], fill=(142, 74, 120, 40)
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(0.01 * f)))

    # Sprössling
    d = ImageDraw.Draw(canvas)
    top = cy - 0.17 * f
    stem_top = top - 0.075 * f
    d.line([(cx, top + 0.02 * f), (cx, stem_top)], fill=(125, 191, 152, 255), width=int(0.026 * f))
    for sign in (-1, 1):
        leaf = Image.new("RGBA", (int(0.16 * f), int(0.08 * f)), (0, 0, 0, 0))
        ImageDraw.Draw(leaf).ellipse([0, 0, leaf.size[0] - 1, leaf.size[1] - 1], fill=(158, 211, 181, 255))
        leaf = leaf.rotate(-sign * 32, expand=True, resample=Image.BICUBIC)
        lx = cx + (0.005 * f if sign > 0 else -leaf.size[0] - 0.005 * f)
        ly = stem_top - leaf.size[1] / 2 - 0.01 * f
        canvas.alpha_composite(leaf, (int(lx), int(ly)))

    # Körper mit Verlauf
    bw, bh = 0.58 * f, 0.50 * f
    body_box = (int(cx - bw / 2), int(cy + 0.08 * f - bh / 2), int(cx + bw / 2), int(cy + 0.08 * f + bh / 2))
    size = (body_box[2] - body_box[0], body_box[3] - body_box[1])
    grad = gradient((max(1, size[0] // 8), max(1, size[1] // 8)), BODY_A, BODY_B, diagonal=True).resize(size)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size[0] - 1, size[1] - 1], fill=255)
    canvas.paste(grad, body_box[:2], mask)

    d = ImageDraw.Draw(canvas)
    # Glanzlicht
    hl = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ellipse(ImageDraw.Draw(hl), cx - 0.13 * f, cy - 0.04 * f, 0.10 * f, 0.055 * f, (255, 255, 255, 150))
    canvas.alpha_composite(hl)

    # Wangen
    ch = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    for sign in (-1, 1):
        ellipse(ImageDraw.Draw(ch), cx + sign * 0.17 * f, cy + 0.135 * f, 0.085 * f, 0.042 * f, (240, 127, 174, 115))
    canvas.alpha_composite(ch)

    # Augen
    for sign in (-1, 1):
        ex, ey = cx + sign * 0.095 * f, cy + 0.075 * f
        ellipse(d, ex, ey, 0.048 * f, 0.058 * f, INK)
        ellipse(d, ex - 0.008 * f, ey - 0.012 * f, 0.016 * f, 0.016 * f, (255, 255, 255, 255))

    # Lächeln
    mw, mh = 0.09 * f, 0.055 * f
    my = cy + 0.13 * f
    d.arc([cx - mw / 2, my - mh / 2, cx + mw / 2, my + mh / 2], 20, 160, fill=INK, width=int(0.02 * f))


def render(size, adaptive=False, opaque=False):
    s = size * SS
    if adaptive:
        canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        draw_fina(canvas, s / 2, s * 0.49, s * 0.86)
    else:
        canvas = gradient((s // 8, s // 8), BG_TOP, BG_BOTTOM).resize((s, s))
        draw_fina(canvas, s / 2, s * 0.47, s)
    img = canvas.resize((size, size), Image.LANCZOS)
    return img.convert("RGB") if opaque else img


def rounded(img, radius_ratio=0.23):
    mask = Image.new("L", img.size, 0)
    r = int(img.size[0] * radius_ratio)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], r, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    res = ROOT / "android/app/src/main/res"
    for density, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        folder = res / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        rounded(render(px)).save(folder / "ic_launcher.png")
        render(int(px * 108 / 48), adaptive=True).save(folder / "ic_launcher_foreground.png")
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
        newline="\n",
    )

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    big = render(1024, opaque=True)
    for png in ios.glob("*.png"):
        w, _ = Image.open(png).size
        big.resize((w, w), Image.LANCZOS).save(png)

    # Web/PWA: normale Icons (abgerundet), maskable (vollflächig, Figur in der
    # Sicherheitszone), Apple-Touch-Icon (deckend, iOS rundet selbst), Favicon.
    web = ROOT / "web"
    if web.exists():
        icons = web / "icons"
        icons.mkdir(exist_ok=True)
        for px in (192, 512):
            rounded(render(px)).save(icons / f"Icon-{px}.png")
            figure = render(int(px * 0.8), adaptive=True)
            bg = gradient((px // 4, px // 4), BG_TOP, BG_BOTTOM).resize((px, px))
            bg.alpha_composite(figure, ((px - figure.size[0]) // 2, (px - figure.size[1]) // 2))
            bg.convert("RGB").save(icons / f"Icon-maskable-{px}.png")
        render(180, opaque=True).save(icons / "apple-touch-icon.png")
        rounded(render(48)).save(web / "favicon.png")

    preview = ROOT / "build/icon_preview.png"
    preview.parent.mkdir(exist_ok=True)
    rounded(render(512)).save(preview)
    print("Icons geschrieben, Vorschau:", preview)


if __name__ == "__main__":
    main()
