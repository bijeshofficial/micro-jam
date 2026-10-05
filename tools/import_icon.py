#!/usr/bin/env python3
"""Turns the designed app icon into every icon file the game and stores need.

    python3 tools/import_icon.py ~/Downloads/"micro jam icon assets"

Takes the easyappicon.com export (or any folder holding a square PNG of at
least 1024 px) and writes:

  docs/store/art/icon_master.png      the full-size source, kept for later
  docs/store/art/icon_1024.png        App Store icon (RGB, no alpha: Apple rejects alpha)
  docs/store/art/icon_512.png         Google Play icon (512 x 512)
  assets/app_icon/icon_192.png        Android legacy launcher icon (Android 7)
  assets/app_icon/adaptive_foreground.png   Android 8+ adaptive icon layers, 432 x 432:
  assets/app_icon/adaptive_background.png   the picture fills the 66% safe zone
  assets/app_icon/adaptive_monochrome.png   Android 13+ themed icon (bus silhouette)

Needs Pillow (python3 -m pip install pillow).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
ART = os.path.join(ROOT, "docs/store/art")
ICONS = os.path.join(ROOT, "assets/app_icon")
FG = 264   # adaptive foreground picture size, px of 432


def find_master(folder: str) -> str:
    """The largest square PNG in the folder (easyappicon: iTunesArtwork@3x)."""
    best, best_size = "", 0
    for dirpath, _, files in os.walk(folder):
        for f in files:
            if not f.lower().endswith(".png"):
                continue
            p = os.path.join(dirpath, f)
            with Image.open(p) as im:
                if im.width == im.height and im.width > best_size and "foreground" not in f:
                    best, best_size = p, im.width
    if best_size < 1024:
        sys.exit("no square PNG of at least 1024 px found in " + folder)
    return best


def flat(im: Image.Image) -> Image.Image:
    """RGB with no alpha channel (transparent pixels become white)."""
    bg = Image.new("RGB", im.size, (255, 255, 255))
    bg.paste(im, mask=im.getchannel("A"))
    return bg


def edge_pad(im: Image.Image, total: int) -> Image.Image:
    """Centres `im` on a `total` square, stretching its outermost pixels out."""
    w = im.width
    off = (total - w) // 2
    far = total - w - off
    out = Image.new("RGB", (total, total))
    out.paste(im, (off, off))
    out.paste(im.crop((0, 0, w, 1)).resize((w, off)), (off, 0))
    out.paste(im.crop((0, w - 1, w, w)).resize((w, far)), (off, off + w))
    out.paste(im.crop((0, 0, 1, w)).resize((off, w)), (0, off))
    out.paste(im.crop((w - 1, 0, w, w)).resize((far, w)), (off + w, off))
    for (x, y), (cx, cy, cw, ch) in (((0, 0), (0, 0, off, off)), ((w - 1, 0), (off + w, 0, far, off)),
                                     ((0, w - 1), (0, off + w, off, far)), ((w - 1, w - 1), (off + w, off + w, far, far))):
        out.paste(im.getpixel((x, y)), (cx, cy, cx + cw, cy + ch))
    return out


def rounded(im: Image.Image, radius_frac: float) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    r = int(im.width * radius_frac)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), r, fill=255)
    out = im.copy()
    out.putalpha(mask)
    return out


def monochrome() -> Image.Image:
    """Android 13+ themed icon: a plain bus silhouette (the launcher tints it).

    Drawn at 4x and scaled down for smooth edges; it sits inside the middle
    ~45% of the 432 px canvas, as Android's themed-icon guidance asks.
    """
    k = 4
    im = Image.new("L", (432 * k, 432 * k), 0)
    d = ImageDraw.Draw(im)

    def box(x0, y0, x1, y1, r, fill):
        d.rounded_rectangle((x0 * k, y0 * k, x1 * k, y1 * k), r * k, fill=fill)

    box(146, 136, 226, 152, 4, 255)            # luggage on the roof rack
    box(138, 150, 300, 156, 3, 255)            # roof rack
    box(116, 156, 316, 270, 26, 255)           # body
    box(132, 172, 170, 212, 8, 0)              # windscreen
    for i in range(4):                         # side windows
        box(184 + i * 32, 172, 208 + i * 32, 212, 6, 0)
    box(124, 232, 308, 238, 3, 0)              # stripe
    for cx in (164, 270):                      # wheels with a gap ring
        d.ellipse(((cx - 30) * k, (270 - 30) * k, (cx + 30) * k, (270 + 30) * k), fill=0)
        d.ellipse(((cx - 22) * k, (270 - 22) * k, (cx + 22) * k, (270 + 22) * k), fill=255)
        d.ellipse(((cx - 8) * k, (270 - 8) * k, (cx + 8) * k, (270 + 8) * k), fill=0)
    alpha = im.resize((432, 432), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (432, 432), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = find_master(os.path.expanduser(sys.argv[1]))
    master = flat(Image.open(src).convert("RGBA"))
    print("source:", src, master.size)
    os.makedirs(ART, exist_ok=True)
    os.makedirs(ICONS, exist_ok=True)

    lanczos = Image.Resampling.LANCZOS
    master.save(os.path.join(ART, "icon_master.png"), optimize=True)
    master.resize((1024, 1024), lanczos).save(os.path.join(ART, "icon_1024.png"), optimize=True)
    master.resize((512, 512), lanczos).save(os.path.join(ART, "icon_512.png"), optimize=True)

    # Legacy launcher: the picture in a rounded square on transparency.
    rounded(master.resize((192, 192), lanczos).convert("RGBA"), 0.18).save(os.path.join(ICONS, "icon_192.png"))

    # Adaptive icon (432 px = 108 dp). Launchers show only the middle 72 dp
    # (288 px) through a circle or squircle mask. The picture goes a bit
    # smaller than that (FG px) so a circle doesn't clip the bus, and the
    # background continues the picture's edges outward (sky up, road down),
    # softened, so the ring around it reads as the same scene.
    off = (432 - FG) // 2
    small = master.resize((FG, FG), lanczos)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.paste(small, (off, off))
    fg.save(os.path.join(ICONS, "adaptive_foreground.png"))
    bg = edge_pad(small, 432).filter(ImageFilter.GaussianBlur(10))
    bg.paste(small.filter(ImageFilter.GaussianBlur(3)), (off, off))
    bg.save(os.path.join(ICONS, "adaptive_background.png"))

    monochrome().save(os.path.join(ICONS, "adaptive_monochrome.png"))

    for d, names in ((ART, ["icon_1024.png", "icon_512.png"]), (ICONS, ["icon_192.png", "adaptive_foreground.png", "adaptive_background.png", "adaptive_monochrome.png"])):
        for n in names:
            with Image.open(os.path.join(d, n)) as im:
                print("  %-28s %dx%d %s" % (n, im.width, im.height, im.mode))


if __name__ == "__main__":
    main()
