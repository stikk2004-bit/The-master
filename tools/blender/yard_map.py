"""Draws a plan of the Hoboken yard from the models themselves, as a hand-inked railroad plan on old paper.

    python tools/blender/yard_map.py

It reads the Hoboken_Yard, Hoboken_Train and Hoboken_Boxcars scenes from the .blend (nothing is saved back),
looks straight down on every upward-facing face, and paints them by material, then letters the places,
hides, ladders, lookouts and lamps from the MARK_ and LIGHT_ empties. Writes:
    godot/textures/yard_map.png    the map the game shows on M (Jekyll's sketch)
    art/maps/hoboken_yard_map.pdf  the same map, to print
"""
import math
import os
import sys

import bpy
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402

FONTS = os.path.join(kit.ROOT, "tools", "fonts")
OUT_PNG = os.path.join(kit.ROOT, "godot", "textures", "yard_map.png")
OUT_PDF = os.path.join(kit.ROOT, "art", "maps", "hoboken_yard_map.pdf")

# the part of the world on the map (Blender meters) and how big a meter is
X0, X1 = -40.0, 30.0
Y0, Y1 = -42.0, 80.0
S = 16.0
PAD_L, PAD_T, PAD_R, PAD_B = 70, 190, 70, 470
W = int((X1 - X0) * S) + PAD_L + PAD_R
H = int((Y1 - Y0) * S) + PAD_T + PAD_B

PAPER = (226, 212, 180)
INK = (48, 36, 26)
INK_SOFT = (96, 78, 58)
RED_INK = (140, 40, 30)
GREEN_INK = (36, 92, 58)
LAMP = (214, 150, 40)

# fill color by material; None leaves it off the map
FILL = {
    "HB_Cinder": None, "HB_Skyline": None, "HB_Fence": (120, 100, 78),
    "HB_Ballast": (170, 158, 136), "HB_Tie": (112, 86, 62), "HB_Rail": (40, 34, 30),
    "HB_PlatformTop": (186, 180, 166), "HB_PlatformEdge": (150, 90, 70), "HB_Stone": (176, 168, 150),
    "HB_Brick": (168, 104, 84), "HB_BrickDark": (140, 96, 80), "HB_Slate": (116, 112, 110),
    "HB_Tin": (150, 150, 146), "HB_Iron": (58, 52, 46), "HB_Crate": (196, 160, 110),
    "HB_CrateDark": (150, 116, 82), "HB_Barrel": (150, 104, 64), "HB_Coal": (40, 38, 36),
    "HB_Cobble": (170, 164, 150), "HB_Wood": (150, 118, 84), "HB_GlassDark": (60, 60, 64),
    "HB_WindowLit": (230, 190, 110), "HB_LampGlass": (240, 196, 90), "HB_River": (120, 138, 150),
    "HB_Canvas": (160, 150, 118), "HB_Clock": (220, 210, 180),
    "HB_Path": (206, 188, 150), "HB_Planks": (178, 142, 98),
    "TR_Maroon": (128, 40, 36), "TR_Green": (70, 90, 70), "TR_Black": (46, 44, 42), "TR_Roof": (70, 66, 62),
    "TR_Iron": (54, 50, 46), "TR_Brass": (190, 150, 70), "TR_Boxcar": (140, 76, 56),
}
# some objects read better in one color of their own
OBJ_FILL = {
    "PrivateCar-col": (132, 38, 32),
    "Canopy": None,            # drawn afterwards, see through
    "Bounds-colonly": None,
    "Yard_Ground-col": None,
    "Skyline": None,
}


def P(x, y):
    return (PAD_L + (x - X0) * S, PAD_T + (Y1 - y) * S)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def faces(scene_names, skip=()):
    """(max z, material name, object name, 2D points) of every face that looks up"""
    out = []
    for sn in scene_names:
        sc = bpy.data.scenes.get(sn)
        if sc is None:
            continue
        for o in sc.objects:
            if o.type != "MESH" or o.name in skip:
                continue
            mw = o.matrix_world
            me = o.data
            nm = mw.to_3x3().inverted().transposed()
            for poly in me.polygons:
                n = nm @ poly.normal
                if n.length == 0 or n.normalized().z < 0.25:
                    continue
                vs = [mw @ me.vertices[i].co for i in poly.vertices]
                xs = [v.x for v in vs]
                ys = [v.y for v in vs]
                if max(xs) < X0 - 2 or min(xs) > X1 + 2 or max(ys) < Y0 - 2 or min(ys) > Y1 + 2:
                    continue
                slot = o.material_slots[poly.material_index] if poly.material_index < len(o.material_slots) else None
                mname = slot.material.name if slot and slot.material else ""
                out.append((max(v.z for v in vs), mname, o.name, [(v.x, v.y) for v in vs]))
    out.sort(key=lambda f: f[0])
    return out


def empties(scene_names):
    pts = {}
    for sn in scene_names:
        sc = bpy.data.scenes.get(sn)
        if sc is None:
            continue
        for o in sc.objects:
            if o.type == "EMPTY":
                pts[o.name.split(".")[0]] = (o.location.x, o.location.y, o.location.z)
    return pts


def paper():
    rng = np.random.default_rng(22)
    base = np.ones((H, W, 3), np.float32) * np.array(PAPER, np.float32)
    grain = rng.normal(0, 6, (H, W, 1)).astype(np.float32)
    blot = np.array(Image.fromarray((rng.random((H // 40 + 1, W // 40 + 1)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32)[..., None]
    base += grain + (blot - 128) * 0.12
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    base *= (1.0 - 0.18 * np.clip(d - 0.55, 0, 1))[..., None]
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")


def shade(c, k):
    return tuple(int(v * k) for v in c)


def draw_faces(img, fs):
    d = ImageDraw.Draw(img)
    for z, mname, oname, pts in fs:
        if oname in OBJ_FILL:
            col = OBJ_FILL[oname]
            if col is None:
                continue
            if mname in ("TR_Brass", "HB_Iron", "TR_Iron"):
                col = FILL.get(mname)
        else:
            col = FILL.get(mname, (150, 140, 120))
        if col is None:
            continue
        # higher things a little lighter, like light falling on roofs
        k = 0.92 + min(z, 8.0) * 0.012
        xy = [P(x, y) for x, y in pts]
        area = abs(sum(xy[i][0] * xy[i - 1][1] - xy[i - 1][0] * xy[i][1] for i in range(len(xy)))) / 2
        d.polygon(xy, fill=shade(col, k), outline=shade(col, 0.62) if area > 60 else None)


def hatch(img, fs, names, spacing=9, col=INK_SOFT):
    """diagonal hatching over the roofs of the named objects, the way a draughtsman marks a building"""
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    for z, mname, oname, pts in fs:
        if oname in names and z > 3.0:
            md.polygon([P(x, y) for x, y in pts], fill=255)
    lines = Image.new("L", img.size, 0)
    ld = ImageDraw.Draw(lines)
    for k in range(-H, W, spacing):
        ld.line([(k, 0), (k + H, H)], fill=110, width=1)
    lines = ImageChops.multiply(lines, mask)
    img.paste(Image.new("RGB", img.size, col), (0, 0), lines)


def canopy(img, fs):
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for z, mname, oname, pts in fs:
        if oname == "Canopy" and mname == "HB_Tin":
            d.polygon([P(x, y) for x, y in pts], fill=(120, 120, 118, 70))
    # the columns, as dots
    img.paste(over, (0, 0), over)


def label(d, xy, text, f, fill=INK, anchor="mm", angle=0, img=None):
    if angle == 0:
        d.text(xy, text, font=f, fill=fill, anchor=anchor)
        return
    bbox = d.textbbox((0, 0), text, font=f, anchor="lt")
    tw, th = bbox[2] - bbox[0] + 8, bbox[3] - bbox[1] + 8
    t = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(t).text((4, 4), text, font=f, fill=fill + (255,), anchor="lt")
    t = t.rotate(angle, expand=True, resample=Image.BICUBIC)
    img.paste(t, (int(xy[0] - t.width / 2), int(xy[1] - t.height / 2)), t)


def lamp_icon(d, c, r=7):
    x, y = c
    for k in range(8):
        a = k * math.pi / 4
        d.line([(x + math.cos(a) * r * 0.9, y + math.sin(a) * r * 0.9), (x + math.cos(a) * r * 1.7, y + math.sin(a) * r * 1.7)], fill=LAMP, width=2)
    d.ellipse([x - r * 0.7, y - r * 0.7, x + r * 0.7, y + r * 0.7], fill=LAMP, outline=INK)


def glow(img, pts, reach):
    """a soft wash of lamplight round each lamp: that's where they'll see you coming"""
    over = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(over)
    for x, y in pts:
        c = P(x, y)
        r = reach * S
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=70)
    over = over.filter(ImageFilter.GaussianBlur(reach * S * 0.35))
    img.paste(Image.new("RGB", img.size, (250, 214, 120)), (0, 0), over)


def hide_icon(d, c, n, f):
    x, y = c
    d.ellipse([x - 15, y - 15, x + 15, y + 15], fill=(214, 228, 204), outline=GREEN_INK, width=3)
    d.text((x, y + 1), n, font=f, fill=GREEN_INK, anchor="mm")


def ladder_icon(d, c):
    x, y = c
    d.line([(x - 5, y - 11), (x - 5, y + 11)], fill=INK, width=2)
    d.line([(x + 5, y - 11), (x + 5, y + 11)], fill=INK, width=2)
    for k in range(-2, 3):
        d.line([(x - 5, y + k * 4.5), (x + 5, y + k * 4.5)], fill=INK, width=2)


def lookout_icon(d, c):
    x, y = c
    d.polygon([(x, y - 17), (x + 15, y + 11), (x - 15, y + 11)], fill=(236, 200, 170), outline=RED_INK)
    d.ellipse([x - 7, y - 3, x + 7, y + 8], outline=RED_INK, width=2)
    d.ellipse([x - 2.5, y + 0, x + 2.5, y + 5], fill=RED_INK)


def diamond(d, c, r, fill, outline=INK):
    x, y = c
    d.polygon([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], fill=fill, outline=outline, width=2)


def arrow(d, a, b, col=INK, width=3, head=14, dash=None):
    ax, ay = a
    bx, by = b
    L = math.hypot(bx - ax, by - ay)
    if dash:
        n = int(L / dash)
        for k in range(0, n, 2):
            t0, t1 = k / n, min((k + 1) / n, 1.0)
            d.line([(ax + (bx - ax) * t0, ay + (by - ay) * t0), (ax + (bx - ax) * t1, ay + (by - ay) * t1)], fill=col, width=width)
    else:
        d.line([a, b], fill=col, width=width)
    ang = math.atan2(by - ay, bx - ax)
    d.polygon([(bx, by), (bx - head * math.cos(ang - 0.4), by - head * math.sin(ang - 0.4)),
               (bx - head * math.cos(ang + 0.4), by - head * math.sin(ang + 0.4))], fill=col)


def polyline_arrow(d, pts, col, width=3, dash=16):
    for i in range(len(pts) - 1):
        if i == len(pts) - 2:
            arrow(d, pts[i], pts[i + 1], col, width, dash=dash)
        else:
            a, b = pts[i], pts[i + 1]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            n = max(int(L / dash), 1)
            for k in range(0, n, 2):
                t0, t1 = k / n, min((k + 1) / n, 1.0)
                d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0), (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=col, width=width)


def compass(d, c, f):
    x, y = c
    d.ellipse([x - 46, y - 46, x + 46, y + 46], outline=INK, width=2)
    d.ellipse([x - 40, y - 40, x + 40, y + 40], outline=INK_SOFT, width=1)
    d.polygon([(x, y - 58), (x + 11, y), (x, y + 10), (x - 11, y)], fill=INK)
    d.polygon([(x, y + 46), (x + 8, y), (x - 8, y)], fill=INK_SOFT)
    d.text((x, y - 74), "N", font=f, fill=INK, anchor="mm")


def main():
    bpy.ops.wm.open_mainfile(filepath=kit.BLEND)
    scenes = ["Hoboken_Yard", "Hoboken_Train", "Hoboken_Boxcars"]
    fs = faces(scenes, skip=("Skyline",))
    mk = empties(scenes)

    img = paper()
    clean = img.copy()
    # a pale wash where River Street and the yard are, so the walls read
    d = ImageDraw.Draw(img)
    draw_faces(img, fs)
    hatch(img, fs, {"Station-col", "FreightShed-col", "Warehouses", "RowHouses", "NorthFronts"})
    canopy(img, fs)

    lamps = [(v[0], v[1]) for k, v in mk.items() if k.startswith("LIGHT_") and k.split("_")[1] in ("street", "yard", "gas", "lantern", "path")]
    glow(img, lamps, 5.0)
    d = ImageDraw.Draw(img)

    f_title = font("Cinzel-Bold.woff", 46)
    f_sub = font("IMFellEnglish-Italic.woff", 30)
    f_big = font("Cinzel-Bold.woff", 26)
    f_lab = font("IMFellEnglish-Regular.woff", 24)
    f_small = font("IMFellEnglish-Italic.woff", 21)
    f_num = font("Cinzel-Bold.woff", 18)

    # the yard's edge: a neat inked border round the map
    bx0, by0 = P(X0, Y1)
    bx1, by1 = P(X1, Y0)
    d.rectangle([bx0 - 8, by0 - 8, bx1 + 8, by1 + 8], outline=INK, width=3)
    d.rectangle([bx0 - 14, by0 - 14, bx1 + 14, by1 + 14], outline=INK, width=1)

    # lamps
    for x, y in lamps:
        lamp_icon(d, P(x, y))

    # names of places
    def L(x, y, text, f=f_lab, angle=0, fill=INK):
        label(d, P(x, y), text, f, fill=fill, angle=angle, img=img)
    L(-10.0, -32.0, "R I V E R    S T R E E T", f_big)
    L(20.0, 2.0, "STATION", f_big, angle=90, fill=(250, 240, 220))
    L(-21.0, 4.0, "FREIGHT HOUSE", f_big, angle=90, fill=(250, 240, 220))
    L(-35.5, 40.0, "WAREHOUSES", f_big, angle=90, fill=(250, 240, 220))
    L(10.0, 64.0, "PASSENGER PLATFORM", f_lab, angle=90)
    L(0.0, 32.0, "the lane", f_small, angle=90)
    L(-27.4, 34.0, "fence walk", f_small, angle=90)
    L(-9.0, 60.0, "Coal", f_small, fill=(230, 220, 200))
    L(-14.0, 74.5, "Water tower", f_small)
    L(-6.8, 22.6, "Switchman's shanty", f_small)
    L(-3.2, -22.7, "Switch tower", f_small)
    L(-22.6, -12.6, "Yard office", f_small)
    L(-20.5, 42.3, "Lumber", f_small)
    L(-23.5, 47.6, "Ties", f_small)
    L(-21.8, 28.2, "Car wheels", f_small)
    L(-24.1, 61.0, "Tool house", f_small)

    # the Senator's car
    L(TRACK_B := 4.0, -1.5, "THE SENATOR'S CAR", f_num, angle=90, fill=(250, 230, 210))

    # where things are
    if "MARK_gate_in" in mk:
        gx, gy, _ = mk["MARK_gate_in"]
        diamond(d, P(gx, gy - 2.1), 11, (236, 220, 190))
        L(gx + 5.6, gy - 3.6, "Freight gate", f_lab)
    if "MARK_rear_door" in mk:
        rx, ry, _ = mk["MARK_rear_door"]
        diamond(d, P(rx + 0.4, ry), 10, (220, 120, 100))
        L(rx + 1.2, ry - 2.2, "", f_small)
    if "MARK_vestibule" in mk:
        vx, vy, _ = mk["MARK_vestibule"]
        diamond(d, P(vx + 1.2, vy), 12, (240, 214, 120))
    hides = [("MARK_hide_tarp", "1"), ("MARK_hide_boxcar", "2"), ("MARK_hide_shed", "3")]
    for k, n in hides:
        if k in mk:
            hx, hy, _ = mk[k]
            hide_icon(d, P(hx, hy), n, f_num)
    i = 0
    while "MARK_ladder_%d_bottom" % i in mk:
        lx, ly, _ = mk["MARK_ladder_%d_bottom" % i]
        ladder_icon(d, P(lx - 1.2, ly + 0.6))
        i += 1
    for k in ("MARK_perch_tower", "MARK_perch_shed"):
        if k in mk:
            lookout_icon(d, P(mk[k][0], mk[k][1]))

    # the ways the seven come
    ways = []
    if "MARK_cab_stop" in mk:
        ways.append([(30.0, -31.0), (12.0, -30.4), (9.5, -26.0), (8.0, -16.0)])
    if "MARK_station_walk_0" in mk:
        ways.append([(mk["MARK_station_walk_%d" % k][0], mk["MARK_station_walk_%d" % k][1]) for k in range(3)])
    j = 0
    yard_way = []
    while "MARK_yard_walk_%d" % j in mk:
        yard_way.append((mk["MARK_yard_walk_%d" % j][0], mk["MARK_yard_walk_%d" % j][1]))
        j += 1
    if yard_way:
        ways.append(yard_way[1:])
    for w in ways:
        polyline_arrow(d, [P(x, y) for x, y in w], RED_INK, 3)

    # nothing spills past the frame: the margins get their clean paper back
    keep = Image.new("L", img.size, 255)
    ImageDraw.Draw(keep).rectangle([bx0, by0, bx1, by1], fill=0)
    img.paste(clean, (0, 0), keep)
    d = ImageDraw.Draw(img)
    d.rectangle([bx0 - 8, by0 - 8, bx1 + 8, by1 + 8], outline=INK, width=3)
    d.rectangle([bx0 - 14, by0 - 14, bx1 + 14, by1 + 14], outline=INK, width=1)

    # title
    d.text((W / 2, 62), "THE FREIGHT YARD AT HOBOKEN", font=f_title, fill=INK, anchor="mm")
    d.text((W / 2, 112), "Drawn from memory by J., the night of November 22, 1910", font=f_sub, fill=INK_SOFT, anchor="mm")
    d.line([(W / 2 - 330, 146), (W / 2 + 330, 146)], fill=INK, width=2)
    compass(d, (W - PAD_R - 70, PAD_T + 100), f_big)
    # scale bar: ten meters
    sx, sy = PAD_L + 30, PAD_T + 40
    for k in range(5):
        d.rectangle([sx + k * 2 * S, sy, sx + (k + 1) * 2 * S, sy + 8], fill=INK if k % 2 == 0 else PAPER, outline=INK)
    d.text((sx, sy + 26), "0", font=f_small, fill=INK, anchor="mm")
    d.text((sx + 10 * S, sy + 26), "10 m", font=f_small, fill=INK, anchor="mm")

    # the key
    ky = H - PAD_B + 40
    col1, col2 = PAD_L + 30, W / 2 + 20
    rows = 44
    hide_icon(d, (col1 + 15, ky + 15), "1", f_num)
    d.text((col1 + 44, ky + 15), "Hiding places: 1 under the tarp wagon,", font=f_lab, fill=INK, anchor="lm")
    d.text((col1 + 44, ky + 15 + 28), "2 the empty boxcar, 3 the shed's dark door", font=f_lab, fill=INK, anchor="lm")
    ladder_icon(d, (col1 + 15, ky + rows * 2 + 5))
    d.text((col1 + 44, ky + rows * 2 + 5), "Ladders up the boxcars", font=f_lab, fill=INK, anchor="lm")
    lookout_icon(d, (col1 + 15, ky + rows * 3 + 10))
    d.text((col1 + 44, ky + rows * 3 + 10), "Lookouts up high, turning their lanterns", font=f_lab, fill=INK, anchor="lm")
    lamp_icon(d, (col1 + 15, ky + rows * 4 + 12))
    d.text((col1 + 44, ky + rows * 4 + 12), "Lamps: they'll see you a long way off in the light", font=f_lab, fill=INK, anchor="lm")
    d.rectangle([col1 + 2, ky + rows * 5 + 2, col1 + 28, ky + rows * 5 + 22], fill=FILL["HB_Path"], outline=INK_SOFT)
    d.text((col1 + 44, ky + rows * 5 + 12), "Walks and plank crossings", font=f_lab, fill=INK, anchor="lm")
    arrow(d, (col1, ky + rows * 6 + 14), (col1 + 32, ky + rows * 6 + 14), RED_INK, 3, head=12)
    d.text((col1 + 44, ky + rows * 6 + 14), "The ways the seven come: by cab, out of the station, across the yard", font=f_lab, fill=INK, anchor="lm")
    diamond(d, (col1 + 15, ky + rows * 7 + 16), 11, (220, 120, 100))
    d.text((col1 + 44, ky + rows * 7 + 16), "The rear door, where the seven go in", font=f_lab, fill=INK, anchor="lm")
    diamond(d, (col2 + 15, ky + rows * 7 + 16), 12, (240, 214, 120))
    d.text((col2 + 44, ky + rows * 7 + 16), "The dark front steps: your way aboard", font=f_lab, fill=INK, anchor="lm")
    d.text((W / 2, H - 34), "Five watchmen walk the yard where they please. Mind the beams.", font=f_sub, fill=INK_SOFT, anchor="mm")

    img = img.filter(ImageFilter.SMOOTH)
    os.makedirs(os.path.dirname(OUT_PDF), exist_ok=True)
    img.save(OUT_PNG, optimize=True)
    img.save(OUT_PDF, "PDF", resolution=150.0)
    # the game puts you on the map with these; they live in mission_ui.gd (MAP_X0, MAP_Y1, MAP_PX_PER_M,
    # MAP_PAD, MAP_SIZE), so change them there too if the frame or scale changes here
    print("map", W, "x", H, "->", OUT_PNG, OUT_PDF)
    print("mission_ui.gd: MAP_X0 %.1f  MAP_Y1 %.1f  MAP_PX_PER_M %.1f  MAP_PAD (%d, %d)  MAP_SIZE (%d, %d)" % (X0, Y1, S, PAD_L, PAD_T, W, H))


if __name__ == "__main__":
    main()
