"""Painted textures for the Honey House, the Drafting Room and the Trading Floor.

    python tools/paint_rooms.py

No trading signals, setups, indicator logic or strategy appear anywhere here (the Trading
Floor rule). Screens show journaling and the pre-market check-in, never charts to trade from.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "godot", "textures")
ART = os.path.join(ROOT, "art")
FONTS = os.path.join(HERE, "fonts")
rng = np.random.default_rng(40)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def mono(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def save(img, name, quality=None):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    if name.endswith(".jpg"):
        img.convert("RGB").save(path, quality=quality or 88)
    else:
        img.save(path)
    print("painted", name)


def site_shots():
    # the two site previews that didn't have game-ready copies yet
    for src, dst in (("preview-tinytides.png", "work_tinytides.jpg"), ("preview-zv.png", "work_zv.jpg")):
        im = Image.open(os.path.join(ART, "source", "assets", src)).convert("RGB")
        w = 768
        save(im.resize((w, int(im.height * w / im.width)), Image.LANCZOS), dst)
    logo = Image.open(os.path.join(ART, "source", "bees", "logo.png")).convert("RGBA").resize((512, 512), Image.LANCZOS)
    save(logo, "bees_logo.png")


def chalk_board(lines, name, W=1024, H=768):
    base = np.zeros((H, W, 3))
    base[:] = np.array([0.1, 0.12, 0.11])
    base += rng.normal(0, 0.01, (H, W, 1))
    img = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for i in range(14):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        d.ellipse([x - 140, y - 30, x + 140, y + 30], fill=(38, 42, 40))
    img = img.filter(ImageFilter.GaussianBlur(10))
    d = ImageDraw.Draw(img)
    chalk = (228, 228, 216)
    for text, f, x, y in lines:
        d.text((x, y), text, fill=chalk, font=f)
    arr = np.asarray(img).astype(np.float64) + rng.normal(0, 6, (H, W, 3))
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), name)


def pricing():
    h = font("IMFellEnglish-Regular.woff", 62)
    b = font("IMFellEnglish-Regular.woff", 40)
    i = font("IMFellEnglish-Italic.woff", 36)
    chalk_board([
        ("Jekyll Studio", h, 60, 36),
        ("$50 one time to set up", b, 70, 140),
        ("domain, hosting, going live, basic upkeep", i, 100, 192),
        ("+ a build fee that fits the work", b, 70, 262),
        ("a simple site: about $200 to build,", i, 100, 314),
        ("about $250 all told", i, 100, 360),
        ("Monthly plan, if you want one:", b, 70, 440),
        ("$30 to $300+, by how much work it is", i, 100, 492),
        ("You own your site outright.", b, 70, 580),
        ("stikk2004@gmail.com   (601) 569-3719", i, 70, 660),
    ], "pricing_chalk.png")


def plaque():
    W, H = 1024, 640
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    brush = np.sin(x * 0.9 + rng.normal(0, 1, (H, W)) * 0.4) * 0.03
    base = np.stack([0.66 + brush, 0.5 + brush, 0.24 + brush * 0.6], -1)
    tarnish = np.clip(rng.normal(0, 1, (H // 16, W // 16)), -2, 2)
    tarnish = np.asarray(Image.fromarray(((tarnish + 2) * 60).astype(np.uint8)).resize((W, H), Image.BICUBIC)) / 255.0
    base *= (0.85 + 0.15 * tarnish)[..., None]
    img = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    d.rectangle([18, 18, W - 18, H - 18], outline=(70, 50, 20), width=8)
    d.rectangle([38, 38, W - 38, H - 38], outline=(120, 90, 40), width=3)
    big = font("Cinzel-Bold.woff", 124)
    f = font("IMFellEnglish-Italic.woff", 44)
    ink = (40, 26, 10)
    d.text((W / 2, 170), "NO COURSE", fill=ink, font=big, anchor="mm")
    d.line([(160, 270), (W - 160, 270)], fill=ink, width=3)
    for k, t in enumerate(["Journaling, psychology and accountability", "are shared here.",
                           "Strategy never is. No signals. No setups.", "Nothing for sale."]):
        d.text((W / 2, 330 + k * 62), t, fill=ink, font=f, anchor="mm")
    for (cx, cy) in ((60, 60), (W - 60, 60), (60, H - 60), (W - 60, H - 60)):
        d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(90, 66, 28))
    save(img, "plaque_no_course.png")


def ticker():
    W, H = 4096, 128
    img = Image.new("RGB", (W, H), (10, 8, 4))
    d = ImageDraw.Draw(img)
    f = mono(64)
    words = ["CHECK IN BEFORE THE OPEN", "JOURNAL EVERY TRADE", "SLEEP IS PART OF THE WORK", "NO SIGNALS HERE",
             "NO SETUPS, NO COURSE", "ACCOUNTABILITY OVER HYPE", "WALK AWAY WHEN IT GETS LOUD", "JEKYLL ISLAND TRADING"]
    text = "   •   ".join(words) + "   •   "
    x = 20
    while x < W:
        d.text((x, H / 2), text, fill=(255, 176, 60), font=f, anchor="lm")
        x += d.textlength(text, font=f)
    save(img.filter(ImageFilter.GaussianBlur(0.6)), "ticker.png")


def screen(lines, name, color=(120, 255, 150)):
    W, H = 512, 384
    img = Image.new("RGB", (W, H), (4, 10, 6))
    d = ImageDraw.Draw(img)
    f = mono(24)
    for k, t in enumerate(lines):
        d.text((24, 26 + k * 34), t, fill=color, font=f)
    arr = np.asarray(img).astype(np.float64)
    # scanlines and a little bloom, like an old tube
    arr[::3] *= 0.75
    glow = np.asarray(Image.fromarray(arr.astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(np.float64)
    arr = np.clip(arr + glow * 0.5, 0, 255)
    yy, xx = np.mgrid[0:H, 0:W]
    vig = 1.0 - 0.45 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    arr *= np.clip(vig, 0, 1)[..., None]
    save(Image.fromarray(arr.astype(np.uint8)), name)


def screens():
    screen(["JEKYLL ISLAND TRADING", "PRE-MARKET CHECK-IN", "", "SLEEP ..... ?", "FOCUS ..... ?", "MOOD ...... ?", "", "READY  /  EASY  /  SIT OUT", "", "> press E at the terminal_"],
           "screen_checkin.png", (255, 180, 70))
    screen(["TRADE JOURNAL", "", "what I planned:", "what I did:", "how I felt:", "what I learned:", "", "one line a day.", "every day.", "_"],
           "screen_journal.png")
    screen(["ACCOUNTABILITY", "", "partner check-in: 7:45", "did you journal? ....", "did you sleep? ......", "did you stop when", "  you said you would?", "", "be honest. that's all.", "_"],
           "screen_partner.png", (255, 180, 70))
    screen(["", "", "        MEMBERS", "      LEADERBOARD", "", "   ask in the Discord", "      for a seat", "", "", ""],
           "screen_members.png")


def blueprint():
    W, H = 1024, 768
    img = Image.new("RGB", (W, H), (22, 52, 110))
    d = ImageDraw.Draw(img)
    line = (220, 232, 250)
    for gx in range(0, W, 32):
        d.line([(gx, 0), (gx, H)], fill=(40, 72, 132), width=1)
    for gy in range(0, H, 32):
        d.line([(0, gy), (W, gy)], fill=(40, 72, 132), width=1)
    # a wireframe of a web page, drawn like an architect would
    d.rectangle([90, 70, 934, 700], outline=line, width=4)
    d.rectangle([90, 70, 934, 140], outline=line, width=3)
    d.text((120, 92), "LOGO", fill=line, font=mono(28))
    for k, t in enumerate(["HOME", "ABOUT", "WORK", "CONTACT"]):
        d.text((560 + k * 92, 96), t, fill=line, font=mono(18))
    d.rectangle([130, 180, 560, 420], outline=line, width=3)
    d.line([(130, 180), (560, 420)], fill=line, width=1)
    d.line([(560, 180), (130, 420)], fill=line, width=1)
    for k in range(5):
        d.line([(600, 200 + k * 36), (890, 200 + k * 36)], fill=line, width=3)
    d.rectangle([600, 380, 760, 420], outline=line, width=3)
    for c in range(3):
        d.rectangle([130 + c * 270, 460, 370 + c * 270, 640], outline=line, width=3)
    f = font("IMFellEnglish-Italic.woff", 30)
    d.text((100, 720), "Jekyll Studio  ·  draft no. 1  ·  scale: one screen", fill=line, font=f)
    save(img.filter(ImageFilter.GaussianBlur(0.5)), "blueprint.png")


def clipboard():
    W, H = 512, 704
    img = Image.new("RGB", (W, H), (226, 214, 184))
    d = ImageDraw.Draw(img)
    h = font("IMFellEnglish-Regular.woff", 52)
    f = font("IMFellEnglish-Italic.woff", 34)
    ink = (30, 26, 40)
    d.text((40, 40), "Bee Removal", fill=ink, font=h)
    d.line([(40, 110), (470, 110)], fill=ink, width=2)
    for k, t in enumerate(["homes, barns and sheds", "walls, eaves and trees", "commercial jobs too:", "  gas stations, storefronts", "", "live removal when we can,", "the bees get a new home", "", "call or text", "601-569-3719"]):
        d.text((40, 140 + k * 50), t, fill=ink, font=f)
    arr = np.asarray(img).astype(np.float64) + rng.normal(0, 5, (H, W, 3))
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), "clipboard_bees.png")


def farm_dusk():
    W, H = 1024, 512
    a = np.zeros((H, W, 3))
    for yy in range(H):
        t = yy / H
        if t < 0.62:
            a[yy] = np.array([0.95, 0.62, 0.3]) * (0.35 + 0.65 * (t / 0.62) ** 1.5) + np.array([0.1, 0.12, 0.25]) * (1 - t / 0.62)
        else:
            a[yy] = np.array([0.08, 0.07, 0.04]) * (1.2 - (t - 0.62))
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    pts = [(0, int(H * 0.62))]
    for x in range(0, W + 1, 12):
        # a flat pine treeline: small, even crowns
        pts.append((x, int(H * (0.55 + 0.012 * math.sin(x * 0.013) + 0.018 * abs(math.sin(x * 0.19)) + rng.uniform(-0.006, 0.006)))))
    pts += [(W, H), (0, H)]
    d.polygon(pts, fill=(18, 16, 10))
    for k in range(9):
        x = rng.uniform(0, W)
        d.rectangle([x, H * 0.66, x + 26, H * 0.66 + 22], fill=(236, 232, 220))
        d.rectangle([x - 2, H * 0.66 - 4, x + 28, H * 0.66], fill=(160, 150, 130))
    save(img.filter(ImageFilter.GaussianBlur(1.0)), "farm_dusk.png")


if __name__ == "__main__":
    site_shots()
    pricing()
    plaque()
    ticker()
    screens()
    blueprint()
    clipboard()
    farm_dusk()
