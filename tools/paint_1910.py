"""Painted textures for the 1910 chapter: window blinds, skyline, clock, the view from
the train, the marsh window, and the chalkboard in the meeting room.

    python tools/paint_1910.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "godot", "textures")
FONTS = os.path.join(HERE, "fonts")
rng = np.random.default_rng(1910)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))
    print("painted", name)


def blinds():
    # Vanderlip: "the blinds were down and only slender threads of amber light showed the shape of the windows"
    W, H = 256, 512
    a = np.zeros((H, W, 3))
    base = np.array([0.06, 0.035, 0.02])
    a[:] = base
    slat = 40
    for y in range(0, H, slat):
        g = rng.uniform(0.6, 1.0)
        a[y:y + 5, :] = np.array([1.0, 0.62, 0.25]) * g
    # the edge of the blind lets more light past
    a[:, :6] = np.array([1.0, 0.6, 0.24]) * 0.8
    a[:, -6:] = np.array([1.0, 0.6, 0.24]) * 0.8
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    save(img, "blinds.png")


def coach_window():
    W, H = 256, 512
    img = Image.new("RGB", (W, H), (18, 12, 8))
    d = ImageDraw.Draw(img)
    # a dim ceiling lamp glow and the backs of empty seats
    for r in range(160, 0, -4):
        c = int(60 * (1 - r / 160))
        d.ellipse([W / 2 - r, -r / 2, W / 2 + r, r * 0.8], fill=(18 + c, 12 + int(c * 0.7), 8 + int(c * 0.4)))
    d.rectangle([20, 300, 236, 512], fill=(26, 20, 16))
    d.rectangle([30, 290, 226, 330], fill=(40, 28, 20))
    save(img.filter(ImageFilter.GaussianBlur(2)), "coach_window.png")


def skyline():
    W, H = 2048, 512
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 0
    while x < W:
        bw = int(rng.uniform(30, 110))
        bh = int(rng.uniform(60, 330)) if rng.random() > 0.08 else int(rng.uniform(330, 470))
        top = H - bh
        shade = int(rng.uniform(10, 22))
        d.rectangle([x, top, x + bw, H], fill=(shade, shade, shade + 4, 255))
        if bh > 300 and rng.random() < 0.5:
            # a tower top, the way the Singer and Metropolitan towers stood over the city then
            d.polygon([(x + bw * 0.2, top), (x + bw * 0.5, top - 60), (x + bw * 0.8, top)], fill=(shade, shade, shade + 4, 255))
        for wy in range(top + 8, H - 6, 9):
            for wx in range(x + 4, x + bw - 4, 7):
                if rng.random() < 0.18:
                    g = rng.uniform(0.5, 1.0)
                    d.rectangle([wx, wy, wx + 3, wy + 4], fill=(int(255 * g), int(190 * g), int(110 * g), 255))
        x += bw + int(rng.uniform(0, 12))
    save(img, "skyline.png")


def clock_face():
    S = 512
    img = Image.new("RGB", (S, S), (0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 8, S - 8, S - 8], fill=(236, 226, 200))
    d.ellipse([8, 8, S - 8, S - 8], outline=(40, 30, 20), width=10)
    c = S / 2
    f = font("Cinzel-Bold.woff", 44)
    for i in range(12):
        a = math.pi / 2 - i * math.pi / 6
        num = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"][i]
        r = c * 0.76
        tx, ty = c + math.cos(a) * r, c - math.sin(a) * r
        d.text((tx, ty), num, fill=(30, 22, 16), font=f, anchor="mm")
    # twenty minutes to eleven, the night they left
    for ang, L, w in ((math.pi / 2 - (10 + 40 / 60) * math.pi / 6, 0.45, 12), (math.pi / 2 - 40 * math.pi / 30, 0.68, 8)):
        d.line([(c, c), (c + math.cos(ang) * c * L, c - math.sin(ang) * c * L)], fill=(20, 16, 12), width=w)
    d.ellipse([c - 12, c - 12, c + 12, c + 12], fill=(20, 16, 12))
    save(img, "clock_face.png")


def night_scroll():
    """What slides past the car windows at night: tree lines, fields, a farmhouse lamp now and then."""
    W, H = 2048, 512
    a = np.zeros((H, W, 3))
    y = np.linspace(0, 1, H)[:, None]
    sky = np.array([0.05, 0.06, 0.09]) * (1.2 - y[..., None].squeeze()[:, None] * 0.0)
    a[:] = np.array([0.04, 0.05, 0.075])
    a[: int(H * 0.45)] *= 1.3
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # tree line: a wavy silhouette that wraps around
    pts = []
    for x in range(0, W + 1, 8):
        t = x / W * 2 * math.pi
        h = 0.42 + 0.06 * math.sin(t * 3) + 0.04 * math.sin(t * 11 + 1) + 0.03 * math.sin(t * 29 + 2) + rng.uniform(-0.02, 0.02)
        pts.append((x, int(H * h)))
    d.polygon(pts + [(W, H), (0, H)], fill=(6, 7, 8))
    for i in range(7):
        x = rng.uniform(0, W)
        yy = rng.uniform(0.52, 0.62) * H
        for r in range(12, 0, -2):
            g = (1 - r / 12)
            d.ellipse([x - r, yy - r, x + r, yy + r], fill=(int(40 + 215 * g), int(28 + 150 * g), int(10 + 70 * g)))
    save(img.filter(ImageFilter.GaussianBlur(1.2)), "night_scroll.png")


def marsh_window():
    W, H = 256, 512
    a = np.zeros((H, W, 3))
    for yy in range(H):
        t = yy / H
        if t < 0.62:
            c = np.array([0.72, 0.74, 0.72]) * (0.85 + 0.15 * t)
        elif t < 0.66:
            c = np.array([0.36, 0.4, 0.34])
        else:
            c = np.array([0.42, 0.44, 0.3]) * (1.0 - (t - 0.66) * 0.6)
        a[yy] = c
    noise = rng.normal(0, 0.02, (H, W, 1))
    img = Image.fromarray((np.clip(a + noise, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # a live oak limb and moss across the top of the view
    d.line([(-10, 70), (90, 40), (200, 60), (270, 20)], fill=(40, 42, 36), width=14)
    for i in range(40):
        x = rng.uniform(0, W)
        L = rng.uniform(30, 120)
        d.line([(x, 50), (x + rng.uniform(-6, 6), 50 + L)], fill=(120, 126, 110), width=2)
    save(img.filter(ImageFilter.GaussianBlur(1.5)), "marsh_window.png")


def chalkboard():
    W, H = 1024, 640
    base = np.zeros((H, W, 3))
    base[:] = np.array([0.1, 0.12, 0.11])
    base += rng.normal(0, 0.01, (H, W, 1))
    img = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # old erasures
    for i in range(18):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        d.ellipse([x - 120, y - 30, x + 120, y + 30], fill=(38, 42, 40))
    img = img.filter(ImageFilter.GaussianBlur(10))
    d = ImageDraw.Draw(img)
    f_head = font("IMFellEnglish-Regular.woff", 54)
    f = font("IMFellEnglish-Italic.woff", 38)
    chalk = (226, 226, 214)
    lines = [
        ("A National Reserve Association", f_head, 40),
        ("one reserve, held in common", f, 118),
        ("fifteen districts, a branch in each", f, 164),
        ("member banks own the stock", f, 210),
        ("rediscount good commercial paper", f, 256),
        ("notes that stretch at harvest, shrink after", f, 302),
        ("keeps the Treasury's deposits", f, 348),
        ("Board: most chosen by the banks,", f, 420),
        ("a few named by Washington.", f, 466),
    ]
    for text, ff, y in lines:
        x = 70 if ff is f_head else 110
        d.text((x, y), text, fill=chalk, font=ff)
        if ff is f and not text.startswith("a few"):
            d.line([(78, y + 24), (96, y + 24)], fill=chalk, width=4)
    d.text((110, 540), "Do not call it a central bank.", fill=chalk, font=f)
    d.line([(105, 590), (620, 594)], fill=chalk, width=3)
    arr = np.asarray(img).astype(np.float64)
    arr += rng.normal(0, 6, arr.shape)
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), "chalkboard_1910.png")


if __name__ == "__main__":
    blinds()
    coach_window()
    skyline()
    clock_face()
    night_scroll()
    marsh_window()
    chalkboard()
