"""The 1910 chapter's places: the Hoboken rail yard, the train, a motor cab,
the private car's interior and the meeting room on Jekyll Island.

    python tools/blender/build_1910.py            # everything
    python tools/blender/build_1910.py yard train # just these

Empties named LIGHT_<kind>_<n> become lights in the game and MARK_<name> become
positions the game script uses (spawn points, paths, seats, camera spots).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402
from kit import MB, mat  # noqa: E402

TEX = os.path.join(kit.ROOT, "godot", "textures")
R = kit.rng_seed(1910)

RAIL_TOP = 0.56
FLOOR = 1.8          # car floor height above the ground
TRACK_A = -4.0
TRACK_B = 4.0


def mark(coll, name, loc, rz=0.0):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    e.rotation_euler = (0, 0, rz)
    e.empty_display_size = 0.3
    coll.objects.link(e)
    return e


def light(coll, kind, n, loc):
    return mark(coll, "LIGHT_%s_%d" % (kind, n), loc)


# ------------------------------------------------------------------ materials
def M():
    return {
        "cinder": mat("HB_Cinder", "#2a2622", 0.95),
        "ballast": mat("HB_Ballast", "#4a4640", 0.95),
        "tie": mat("HB_Tie", "#3a2e24", 0.9),
        "rail": mat("HB_Rail", "#3a3634", 0.4, 0.8),
        "plat_top": mat("HB_PlatformTop", "#6a6660", 0.9),
        "plat_edge": mat("HB_PlatformEdge", "#6a3a2a", 0.9),
        "brick": mat("HB_Brick", "#5a3226", 0.9),
        "brick_dark": mat("HB_BrickDark", "#3a2a24", 0.9),
        "stone": mat("HB_Stone", "#6a6458", 0.9),
        "tin": mat("HB_Tin", "#4a4c4e", 0.6, 0.4),
        "iron": mat("HB_Iron", "#1c1a18", 0.5, 0.6),
        "crate": mat("HB_Crate", "#7a6448", 0.9),
        "crate_dark": mat("HB_CrateDark", "#4a3a2a", 0.9),
        "barrel": mat("HB_Barrel", "#5a4028", 0.8),
        "coal": mat("HB_Coal", "#121212", 0.7),
        "cobble": mat("HB_Cobble", "#4a4640", 0.85),
        "wood": mat("HB_Wood", "#5a4a3a", 0.85),
        "slate": mat("HB_Slate", "#2a2e32", 0.7),
        "glass_dark": mat("HB_GlassDark", "#0c0e12", 0.1),
        "window_lit": mat("HB_WindowLit", "#ffb870", 0.3, 0.0, "#ffb060", 1.2),
        "lamp_glass": mat("HB_LampGlass", "#ffd090", 0.3, 0.0, "#ffb050", 2.0),
        "clock": kit.img_mat("HB_Clock", os.path.join(TEX, "clock_face.png"), 0.6, emit=0.9),
        "skyline": kit.img_mat("HB_Skyline", os.path.join(TEX, "skyline.png"), 0.9, emit=1.4),
        "river": mat("HB_River", "#05070a", 0.08),
        "fence": mat("HB_Fence", "#3a3028", 0.9),
        "canvas": mat("HB_Canvas", "#5a5446", 0.9),
        # the train
        "maroon": mat("TR_Maroon", "#3e1512", 0.45),
        "green": mat("TR_Green", "#1e2a1e", 0.5),
        "black": mat("TR_Black", "#141414", 0.45, 0.2),
        "roof": mat("TR_Roof", "#1a1a1a", 0.8),
        "t_iron": mat("TR_Iron", "#1a1816", 0.5, 0.7),
        "t_brass": mat("TR_Brass", "#b8903e", 0.3, 0.95),
        "blinds": kit.img_mat("TR_Blinds", os.path.join(TEX, "blinds.png"), 0.4, emit=1.6),
        "coach_win": kit.img_mat("TR_CoachWindow", os.path.join(TEX, "coach_window.png"), 0.4, emit=0.6),
        "t_glass": mat("TR_Glass", "#0a0c10", 0.08),
        "red_lamp": mat("TR_RedLamp", "#ff2a1a", 0.3, 0.0, "#ff2010", 3.0),
        "headlamp": mat("TR_Headlamp", "#fff0c0", 0.3, 0.0, "#ffe0a0", 6.0),
        "firebox": mat("TR_Firebox", "#ff8a30", 0.4, 0.0, "#ff7020", 3.0),
        "boxcar": mat("TR_Boxcar", "#5a2a1c", 0.9),
        # the motor cab
        "car_body": mat("MC_Body", "#1c1416", 0.35, 0.1),
        "car_trim": mat("MC_Trim", "#101010", 0.5),
        "tire": mat("MC_Tire", "#0c0c0c", 0.8),
        "car_lamp": mat("MC_Lamp", "#ffe8b0", 0.3, 0.0, "#ffd890", 4.0),
        "car_leather": mat("MC_Leather", "#2a1810", 0.6),
    }


# ------------------------------------------------------------------ props
def crate(mb, m, c, s, rz=0.0):
    x, y, z = c
    mb.boxc((x, y, z + s[2] / 2), s, m["crate"], rz=rz)
    # slats: darker boards across the faces
    for dz in (0.15, 0.5, 0.85):
        mb.boxc((x, y, z + s[2] * dz), (s[0] + 0.02, s[1] + 0.02, 0.07), m["crate_dark"], rz=rz)


def barrel(mb, m, c, h=0.9, r=0.3):
    x, y, z = c
    mb.lathe((x, y, z), [(r * 0.86, 0.0), (r, h * 0.3), (r * 1.04, h * 0.5), (r, h * 0.7), (r * 0.86, h)], m["barrel"], seg=14)
    for t in (0.12, 0.88):
        mb.lathe((x, y, z), [(r * (0.93 if t < 0.5 else 0.93) + 0.01, h * t - 0.03), (r * 0.95 + 0.012, h * t + 0.03)], m["iron"], seg=14, caps=False)


def baggage_cart(mb, m, c, rz=0.0):
    x, y, z = c
    rot = Matrix.Rotation(rz, 3, "Z")

    def P(dx, dy, dz):
        v = rot @ Vector((dx, dy, dz))
        return (x + v.x, y + v.y, z + v.z)
    mb.boxc(P(0, 0, 0.62), (1.2, 2.6, 0.08), m["wood"], rz=rz)
    for sx in (-0.58, 0.58):
        mb.boxc(P(sx, 0, 0.75), (0.05, 2.6, 0.22), m["wood"], rz=rz)
    for wx in (-0.5, 0.5):
        for wy in (-0.9, 0.9):
            mb.cyl(P(wx, wy, 0.3), 0.3, 0.3, 0.08, m["iron"], seg=12, rot=Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Translation((0, 0, -0.04)))
    mb.rod(P(0, 1.3, 0.62), P(0, 2.2, 0.9), 0.025, m["iron"])
    # a trunk or two
    mb.boxc(P(0.1, -0.5, 0.9), (0.9, 0.55, 0.5), m["crate_dark"], rz=rz + 0.1)
    mb.boxc(P(-0.1, 0.5, 0.85), (0.7, 0.5, 0.4), m["barrel"], rz=rz - 0.2)


def gas_lamp(mb, m, c, h=3.6):
    x, y, z = c
    mb.lathe((x, y, z), [(0.16, 0), (0.14, 0.12), (0.07, 0.25), (0.055, h - 0.4), (0.07, h - 0.3)], m["iron"], seg=10)
    mb.rod((x - 0.3, y, z + h - 0.55), (x + 0.3, y, z + h - 0.55), 0.02, m["iron"])
    # lantern: glass box with a sloped iron cap
    mb.boxc((x, y, z + h - 0.05), (0.32, 0.32, 0.42), m["lamp_glass"])
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.rod((x + sx * 0.17, y + sy * 0.17, z + h - 0.28), (x + sx * 0.17, y + sy * 0.17, z + h + 0.17), 0.012, m["iron"])
    mb.lathe((x, y, z + h + 0.15), [(0.26, 0.0), (0.05, 0.22), (0.02, 0.3)], m["iron"], seg=4)
    return (x, y, z + h - 0.05)


def pole(mb, m, c, h=9.0):
    x, y, z = c
    mb.rod((x, y, 0), (x, y, h), 0.12, m["tie"], r2=0.1)
    for dz in (h - 0.6, h - 1.4):
        mb.boxc((x, y, dz), (0.1, 2.2, 0.1), m["tie"])
        for dy in (-0.9, -0.3, 0.3, 0.9):
            mb.cyl((x, y + dy, dz + 0.05), 0.03, 0.02, 0.1, m["glass_dark"], seg=6)


def building(mb, m, x0, x1, y0, y1, h, wall, roof_m, windows=None, lit=0.0, facing=None, win_w=1.2, win_h=2.0, rows=(2.5,), spacing=3.2):
    mb.box((x0, y0, 0), (x1, y1, h), wall)
    mb.box((x0 - 0.3, y0 - 0.3, h), (x1 + 0.3, y1 + 0.3, h + 0.35), m["stone"])
    if roof_m:
        mb.box((x0, y0, h + 0.35), (x1, y1, h + 0.6), roof_m)
    if not facing:
        return []
    lights = []
    fx, fy = facing
    for zc in rows:
        if abs(fx) > 0.5:
            X = x1 if fx > 0 else x0
            n = int((y1 - y0 - 1.0) / spacing)
            for i in range(n):
                yc = y0 + 1.0 + spacing * (i + 0.5)
                is_lit = R.random() < lit
                mb.arch_window((X + fx * 0.02, yc, zc), win_w, win_h, m["stone"], m["window_lit"] if is_lit else m["glass_dark"], facing)
                if is_lit:
                    lights.append((X + fx * 1.2, yc, zc))
        else:
            Y = y1 if fy > 0 else y0
            n = int((x1 - x0 - 1.0) / spacing)
            for i in range(n):
                xc = x0 + 1.0 + spacing * (i + 0.5)
                is_lit = R.random() < lit
                mb.arch_window((xc, Y + fy * 0.02, zc), win_w, win_h, m["stone"], m["window_lit"] if is_lit else m["glass_dark"], facing)
                if is_lit:
                    lights.append((xc, Y + fy * 1.2, zc))
    return lights


# ------------------------------------------------------------------ the yard
def track(mb, m, x, y0, y1):
    # ballast bed, ties every 0.6 m, two rails
    bw_top, bw_bot, bh = 2.8, 3.8, 0.25
    pts = [(x - bw_bot / 2, y0, 0), (x + bw_bot / 2, y0, 0), (x + bw_top / 2, y0, bh), (x - bw_top / 2, y0, bh)]
    ptsb = [(p[0], y1, p[2]) for p in pts]
    for i in range(4):
        a, b = pts[i], pts[(i + 1) % 4]
        c, d = ptsb[(i + 1) % 4], ptsb[i]
        mb.quad([a, b, c, d], m["ballast"])
    mb.quad(pts[::-1], m["ballast"])
    mb.quad(ptsb, m["ballast"])
    y = y0 + 0.3
    while y < y1 - 0.3:
        mb.boxc((x + R.uniform(-0.04, 0.04), y, bh + 0.08), (2.6, 0.24, 0.16), m["tie"], rz=R.uniform(-0.03, 0.03))
        y += 0.6
    for sx in (-0.7175, 0.7175):
        mb.box((x + sx - 0.035, y0, RAIL_TOP - 0.15), (x + sx + 0.035, y1, RAIL_TOP), m["rail"])


def yard():
    sc = kit.new_scene("Hoboken_Yard")
    coll = sc.collection
    m = M()

    g = MB()
    g.box((-60, -60, -0.2), (60, 110, 0.0), m["cinder"])
    g.obj("Yard_Ground-col", coll)

    tr = MB()
    track(tr, m, TRACK_A, -26.0, 90.0)
    track(tr, m, TRACK_B, -26.0, 90.0)
    tr.obj("Tracks-col", coll)

    # ---------------- the passenger platform and its canopy
    p = MB()
    p.box((6.25, -22.0, 0.0), (13.0, 60.0, 0.62), m["plat_top"])
    p.box((6.2, -22.0, 0.0), (6.45, 60.0, 0.6), m["plat_edge"])
    # steps down to the street at the south end
    for i in range(4):
        p.box((8.0, -22.0 - (i + 1) * 0.32, 0.0), (11.0, -22.0 - i * 0.32, 0.62 - (i + 1) * 0.155), m["stone"])
    p.obj("Platform-col", coll)

    cano = MB()
    lamp_pts = []
    for i, y in enumerate(range(-18, 60, 6)):
        cano.cyl((9.8, y, 0.62), 0.14, 0.12, 4.0, m["iron"], seg=10)
        cano.rod((9.8, y, 4.3), (6.4, y, 4.55), 0.05, m["iron"])
        cano.rod((9.8, y, 4.3), (13.2, y, 4.55), 0.05, m["iron"])
        cano.rod((9.8, y - 2.8, 4.62), (9.8, y + 2.8, 4.62), 0.06, m["iron"])
        # a hanging lamp between columns
        cano.rod((9.8, y + 3.0, 4.62), (9.8, y + 3.0, 4.1), 0.015, m["iron"])
        cano.sphere((9.8, y + 3.0, 3.95), 0.18, m["lamp_glass"], sub=2)
        cano.lathe((9.8, y + 3.0, 4.05), [(0.26, 0.0), (0.1, 0.12), (0.03, 0.2)], m["iron"], seg=10)
        lamp_pts.append((9.8, y + 3.0, 3.85))
    # tin roof, two slopes falling to a center gutter over the columns
    cano.quad([(6.0, -21, 4.5), (9.8, -21, 4.66), (9.8, 60, 4.66), (6.0, 60, 4.5)], m["tin"])
    cano.quad([(9.8, -21, 4.66), (13.6, -21, 4.5), (13.6, 60, 4.5), (9.8, 60, 4.66)], m["tin"])
    cano.quad([(6.0, 60, 4.44), (9.8, 60, 4.6), (9.8, -21, 4.6), (6.0, -21, 4.44)], m["tin"])
    cano.quad([(9.8, 60, 4.6), (13.6, 60, 4.44), (13.6, -21, 4.44), (9.8, -21, 4.6)], m["tin"])
    for y in range(-20, 58, 8):
        cano.boxc((7.4, y, 0.62 + 0.25), (0.5, 1.8, 0.08), m["wood"])  # benches
        cano.boxc((7.2, y, 0.62 + 0.55), (0.08, 1.8, 0.5), m["wood"])
    cano.obj("Canopy", coll)
    for i, pt in enumerate(lamp_pts):
        light(coll, "gas", i, pt)

    # the Senator's trunks, waiting by the rear of his car
    tk = MB()
    tk.boxc((8.2, -15.4, 0.62 + 0.3), (0.9, 0.55, 0.6), m["crate_dark"], rz=0.2)
    tk.boxc((8.3, -15.3, 0.62 + 0.75), (0.7, 0.45, 0.3), m["barrel"], rz=0.25)
    tk.boxc((8.9, -16.4, 0.62 + 0.25), (0.6, 0.4, 0.5), m["crate_dark"], rz=-0.3)
    tk.obj("Trunks-col", coll)

    # ---------------- the station building and its clock tower
    st = MB()
    lit = building(st, m, 14.0, 26.0, -24.0, 32.0, 9.0, m["brick"], m["slate"], facing=(-1, 0), lit=0.7, rows=(2.6, 6.2), spacing=4.0, win_w=1.6, win_h=2.4)
    st.box((16.5, -30.0, 0.0), (23.5, -23.0, 24.0), m["brick"])
    st.box((16.2, -30.3, 24.0), (23.8, -22.7, 24.6), m["stone"])
    st.lathe((20.0, -26.5, 24.6), [(4.2, 0.0), (2.6, 3.0), (0.6, 6.2), (0.15, 7.2)], m["slate"], seg=4)
    for fx, fy, rz in ((0, -1, 0), (-1, 0, 0), (1, 0, 0), (0, 1, 0)):
        c = Vector((20.0 + fx * 3.52, -26.5 + fy * 3.52, 19.5))
        pts = []
        for k in range(24):
            a = 2 * math.pi * k / 24
            if abs(fx) > 0:
                pts.append((c.x, c.y + math.cos(a) * 2.2 * -fx, c.z + math.sin(a) * 2.2))
            else:
                pts.append((c.x + math.cos(a) * 2.2 * fy * -1, c.y, c.z + math.sin(a) * 2.2))
        f = st.quad(pts, m["clock"])
        if f:
            for lp, k in zip(f.loops, range(24)):
                a = 2 * math.pi * k / 24
                lp[st.uv].uv = (0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a))
    # street entrance arch lit from inside
    st.arch_window((20.0, -30.05, 2.2), 3.2, 3.6, m["stone"], m["window_lit"], (0, -1))
    st.obj("Station-col", coll)
    for i, pt in enumerate(lit):
        light(coll, "window", i, pt)
    light(coll, "window", 99, (20.0, -31.5, 2.5))
    light(coll, "clock", 0, (20.0, -26.5, 19.5))

    # ---------------- the street along the south end
    s = MB()
    s.box((-60, -36.0, 0.0), (60, -27.0, 0.03), m["cobble"])
    s.box((-60, -37.5, 0.0), (60, -36.0, 0.18), m["stone"])
    s.obj("Street-col", coll)
    ss = MB()
    for i, x in enumerate((-20, 0, 30)):
        light(coll, "street", i, gas_lamp(ss, m, (x, -26.6, 0.0), 3.8))
    ss.obj("StreetLamps-col", coll)
    # row houses across the street
    rh = MB()
    x = -60.0
    while x < 60.0:
        w = R.uniform(6, 9)
        h = R.uniform(9, 14)
        building(rh, m, x, x + w - 0.2, -48.0, -38.5, h, m["brick_dark"] if R.random() < 0.5 else m["brick"], m["slate"],
                 facing=(0, 1), lit=0.18, rows=(2.4, 5.6, 8.6) if h > 10 else (2.4, 5.6), spacing=2.4, win_w=1.0, win_h=1.6)
        x += w
    rh.obj("RowHouses", coll)

    # ---------------- the freight side, west of the tracks
    f = MB()
    building(f, m, -26.0, -16.0, -6.0, 14.0, 5.5, m["brick_dark"], m["tin"], facing=(1, 0), lit=0.0, rows=(3.2,), spacing=4.0)
    f.box((-16.0, -6.0, 0.0), (-14.6, 14.0, 1.1), m["wood"])  # loading dock
    f.obj("FreightShed-col", coll)
    cr = MB()
    stacks = [(-13.2, -18.5, 2), (-11.6, -17.4, 1), (-12.4, -15.6, 2), (-9.2, -11.8, 1), (-8.4, -13.0, 2), (-13.6, -9.0, 3),
              (-7.2, -1.2, 1), (-8.0, 0.2, 2), (-12.8, 4.5, 1), (-15.2, 2.0, 1), (-15.2, 8.0, 2), (-10.4, 11.2, 2), (-9.6, 12.6, 1),
              (-12.0, 16.8, 2), (-7.6, 17.6, 1), (-15.0, 22.0, 3), (-11.0, 25.0, 1), (-13.2, 30.0, 2)]
    for x, y, n in stacks:
        rz = R.uniform(-0.3, 0.3)
        z = 0.0
        for k in range(n):
            sz = R.uniform(1.0, 1.35)
            crate(cr, m, (x + R.uniform(-0.1, 0.1), y + R.uniform(-0.1, 0.1), z), (sz, sz, sz * 0.9), rz + R.uniform(-0.1, 0.1))
            z += sz * 0.9
    for x, y in ((-15.1, -4.0), (-15.1, 10.5)):
        crate(cr, m, (x, y, 1.1), (1.0, 1.0, 0.9), 0.1)
    cr.obj("Crates-col", coll)
    br = MB()
    for cx, cy in ((-6.8, -5.8), (-10.2, 7.4), (-6.4, 23.0), (-14.0, -12.6)):
        for k in range(R.randint(3, 6)):
            barrel(br, m, (cx + R.uniform(-0.9, 0.9), cy + R.uniform(-0.9, 0.9), 0.0))
    br.obj("Barrels-col", coll)
    bc = MB()
    baggage_cart(bc, m, (-9.0, -7.8, 0.0), 0.3)
    baggage_cart(bc, m, (-10.6, 1.8, 0.0), -0.15)
    baggage_cart(bc, m, (-6.8, 8.4, 0.0), 0.05)
    bc.obj("Carts-col", coll)
    # a switchman's shanty and a stack of spare rails
    sh = MB()
    sh.box((-8.0, 19.0, 0.0), (-5.6, 21.2, 2.5), m["wood"])
    sh.lathe((-6.8, 20.1, 2.5), [(1.8, 0.0), (0.1, 0.9)], m["tin"], seg=4)
    sh.arch_window((-5.58, 20.1, 1.5), 0.6, 0.7, m["wood"], m["window_lit"], (1, 0))
    sh.rod((-6.8, 20.1, 3.0), (-6.8, 20.1, 3.8), 0.07, m["iron"])
    for k in range(5):
        sh.box((-16.0, 26.0 + k * 0.2, 0.08 * k), (-6.0, 26.12 + k * 0.2, 0.08 * k + 0.12), m["rail"])
    sh.obj("Shanty-col", coll)
    light(coll, "lantern", 0, (-5.0, 20.1, 1.5))
    fl = MB()
    for i, (x, y) in enumerate(((-10.6, -4.2), (-12.2, 19.8), (-4.0, -24.0))):
        light(coll, "yard", i, gas_lamp(fl, m, (x, y, 0.0), 3.4))
    fl.obj("YardLamps-col", coll)
    # coal heap and water tower up by the engine
    co = MB()
    co.sphere((-9.0, 60.0, -2.0), 6.0, m["coal"], sub=3, scale=(1.4, 1.2, 0.55))
    co.cyl((-14.0, 70.0, 0.0), 0.3, 0.3, 6.0, m["iron"])
    co.cyl((-14.0, 70.0, 6.0), 3.0, 3.0, 4.0, m["wood"], seg=16)
    co.lathe((-14.0, 70.0, 10.0), [(3.3, 0.0), (0.2, 1.6)], m["tin"], seg=16)
    co.obj("CoalAndWater-col", coll)

    # telegraph poles and the fence at the back of the yard
    tp = MB()
    for y in range(-24, 90, 14):
        pole(tp, m, (-28.0, float(y), 0.0))
    for y in range(-26, 90, 2):
        tp.boxc((-29.0, y + 1.0, 1.1), (0.08, 2.0, 2.2), m["fence"], rz=R.uniform(-0.02, 0.02))
    tp.obj("Fence-col", coll)
    wh = MB()
    building(wh, m, -48.0, -31.0, -24.0, 90.0, 13.0, m["brick_dark"], m["slate"], facing=(1, 0), lit=0.08, rows=(3.0, 7.0, 10.5), spacing=4.0)
    wh.obj("Warehouses", coll)

    # the river beyond the station and the city across it
    rv = MB()
    rv.box((27.0, -200.0, -1.2), (400.0, 400.0, -1.0), m["river"])
    rv.obj("River", coll)
    sk = MB()
    X = 170.0
    for i in range(6):
        y0 = -220.0 + i * 90.0
        f = sk.quad([(X, y0 + 90, 0.0), (X, y0, 0.0), (X, y0, 42.0), (X, y0 + 90, 42.0)], m["skyline"], uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    sk.obj("Skyline", coll)

    # invisible walls: keep the player in the yard
    wl = MB()
    wl.box((-28.6, -27.0, 0.0), (-28.3, 90.0, 4.0), m["fence"])
    wl.box((-28.6, 78.0, 0.0), (28.0, 78.3, 4.0), m["fence"])
    wl.box((-28.6, -27.4, 0.0), (8.0, -27.1, 4.0), m["fence"])
    wl.box((11.0, -27.4, 0.0), (14.0, -27.1, 4.0), m["fence"])
    wl.box((13.7, -27.0, 0.0), (14.0, 78.0, 4.0), m["fence"])
    wl.obj("Bounds-colonly", coll)
    # the yard's south railing, the part you can see
    rl = MB()
    for x in range(-28, 8, 2):
        rl.rod((x, -27.25, 0.0), (x, -27.25, 1.1), 0.03, m["iron"])
    rl.rod((-28, -27.25, 1.05), (8, -27.25, 1.05), 0.03, m["iron"])
    rl.rod((-28, -27.25, 0.55), (8, -27.25, 0.55), 0.03, m["iron"])
    rl.obj("Railing", coll)

    # ---------------- where things happen
    mark(coll, "MARK_player_start", (-14.2, -21.0, 0.0), 0.0)
    mark(coll, "MARK_cam_watch", (-8.6, -17.2, 1.3))
    mark(coll, "MARK_cam_watch_look", (5.2, -13.0, 2.2))
    mark(coll, "MARK_cam_wide", (-2.0, -40.0, 9.0))
    mark(coll, "MARK_cam_wide_look", (4.0, -5.0, 1.5))
    mark(coll, "MARK_cab_in", (46.0, -31.5, 0.03), math.pi / 2)
    mark(coll, "MARK_cab_stop", (9.5, -30.3, 0.03), math.pi / 2)
    mark(coll, "MARK_cab_out", (-46.0, -31.5, 0.03), math.pi / 2)
    mark(coll, "MARK_step_bottom", (9.5, -28.4, 0.0))
    mark(coll, "MARK_step_top", (9.5, -21.6, 0.62))
    mark(coll, "MARK_rear_approach", (7.1, -13.9, 0.62))
    mark(coll, "MARK_rear_board", (5.4, -12.8, 1.8))
    mark(coll, "MARK_rear_door", (4.0, -12.1, 1.8))
    mark(coll, "MARK_porter", (7.2, -14.6, 0.62), -math.pi / 2)
    mark(coll, "MARK_vestibule", (2.0, 8.6, 0.3))
    for i, pt in enumerate(((-2.2, -23.0), (-2.2, -8.0), (-1.9, 6.0), (-2.2, 12.5), (-2.2, -2.0), (-2.4, -16.0))):
        mark(coll, "MARK_detective_%d" % i, (pt[0], pt[1], 0.3))
    for i, pt in enumerate(((1.8, 44.0), (1.8, 30.0), (1.8, 16.0), (1.8, 2.0), (1.8, -6.0), (1.8, 10.0), (1.8, 26.0))):
        mark(coll, "MARK_brakeman_%d" % i, (pt[0], pt[1], 0.3))
    kit.export(sc, "hoboken_yard")
    return sc


# ------------------------------------------------------------------ the train
def truck(mb, m, x, y, wheel_r=0.46):
    axle_z = RAIL_TOP + wheel_r
    mb.box((x - 1.2, y - 1.3, axle_z - 0.2), (x + 1.2, y + 1.3, axle_z + 0.25), m["t_iron"])
    for dy in (-0.85, 0.85):
        for sx in (-0.72, 0.72):
            mb.cyl((x + sx - 0.05, y + dy, axle_z), wheel_r, wheel_r, 0.1, m["t_iron"], seg=16, rot=Matrix.Rotation(math.pi / 2, 4, "Y"))
        mb.rod((x - 0.9, y + dy, axle_z), (x + 0.9, y + dy, axle_z), 0.07, m["t_iron"])
    mb.box((x - 1.25, y - 0.5, axle_z - 0.1), (x + 1.25, y + 0.5, axle_z + 0.1), m["t_iron"])


def car(mb, m, y0, y1, paint, windows, x=TRACK_B, observation=False, name_lights=None, coll=None, tag="car"):
    """A passenger car body from y0 (south) to y1 (north)."""
    hw = 1.5
    z0, z1 = FLOOR, FLOOR + 2.55
    vest = 1.1
    body_y0 = y0 + (0.0 if observation else vest)
    body_y1 = y1 - vest
    # underframe and trucks
    mb.box((x - 1.35, y0 + 0.2, z0 - 0.4), (x + 1.35, y1 - 0.2, z0), m["t_iron"])
    for yy in (body_y0 + 2.6, body_y1 - 2.6):
        truck(mb, m, x, yy)
    # battery boxes and truss rods under the floor
    mb.box((x - 0.9, (y0 + y1) / 2 - 1.5, z0 - 0.85), (x + 0.9, (y0 + y1) / 2 + 1.5, z0 - 0.4), m["t_iron"])
    # body shell
    mb.box((x - hw, body_y0, z0), (x + hw, body_y1, z1), paint)
    # belt rail and letterboard trim
    for zz in (z0 + 0.82, z1 - 0.3):
        mb.box((x - hw - 0.03, body_y0, zz), (x + hw + 0.03, body_y1, zz + 0.07), m["t_brass"] if observation else m["black"])
    # roof: low arc over the sides, a clerestory up the middle
    for side in (-1, 1):
        mb.quad([(x + side * hw, body_y0, z1), (x + side * (hw + 0.1), body_y0, z1 - 0.05), (x + side * (hw + 0.1), body_y1, z1 - 0.05), (x + side * hw, body_y1, z1)][::(1 if side > 0 else -1)], m["roof"])
        mb.quad([(x + side * hw, body_y0, z1), (x + side * 0.75, body_y0, z1 + 0.28), (x + side * 0.75, body_y1, z1 + 0.28), (x + side * hw, body_y1, z1)][::(-1 if side > 0 else 1)], m["roof"])
    mb.box((x - 0.75, body_y0 + 0.4, z1 + 0.28), (x + 0.75, body_y1 - 0.4, z1 + 0.62), paint)
    mb.box((x - 0.85, body_y0 + 0.3, z1 + 0.62), (x + 0.85, body_y1 - 0.3, z1 + 0.72), m["roof"])
    mb.quad([(x - 0.75, body_y0, z1 + 0.28), (x + 0.75, body_y0, z1 + 0.28), (x + 0.85, body_y0 + 0.3, z1 + 0.62), (x - 0.85, body_y0 + 0.3, z1 + 0.62)], m["roof"])
    mb.quad([(x + 0.75, body_y1, z1 + 0.28), (x - 0.75, body_y1, z1 + 0.28), (x - 0.85, body_y1 - 0.3, z1 + 0.62), (x + 0.85, body_y1 - 0.3, z1 + 0.62)], m["roof"])
    # clerestory windows
    y = body_y0 + 1.0
    while y < body_y1 - 1.0:
        for side in (-1, 1):
            mb.boxc((x + side * 0.76, y, z1 + 0.45), (0.02, 0.5, 0.2), windows)
        y += 1.3
    # side windows, paired
    y = body_y0 + 1.2
    k = 0
    while y < body_y1 - 1.0:
        for side in (-1, 1):
            w = 0.95 if observation and (y < body_y0 + 5.5) else 0.62
            mb.boxc((x + side * (hw + 0.012), y, z0 + 1.5), (0.02, w, 0.9), windows)
            mb.boxc((x + side * (hw + 0.02), y, z0 + 1.03), (0.03, w + 0.12, 0.05), m["black"])
        y += 1.35 if not observation else (1.7 if y < body_y0 + 5.5 else 1.35)
        k += 1
    # vestibules: a hood over the step, a door each side, steps down to the rail
    ends = [(body_y1, y1)] + ([] if observation else [(y0, body_y0)])
    for a, b in ends:
        mb.box((x - hw + 0.05, a, z0), (x + hw - 0.05, b, z1), m["black"])
        mb.box((x - hw - 0.05, a, z1 - 0.05), (x + hw + 0.05, b, z1 + 0.25), m["roof"])
        for side in (-1, 1):
            mb.box((x + side * hw - 0.02, a + 0.1, z0 + 0.1), (x + side * (hw + 0.01), b - 0.1, z1 - 0.2), m["t_glass"])
            for s in range(3):
                zz = z0 - 0.35 * (s + 1)
                xx = x + side * (hw - 0.1 - s * 0.05)
                mb.box((min(xx, xx + side * 0.35), a + 0.15, zz), (max(xx, xx + side * 0.35), b - 0.15, zz + 0.06), m["t_iron"])
        # diaphragm (the canvas bellows between cars)
        yy = b if b > a and b == y1 else a
        mb.box((x - 1.0, yy - 0.15, z0), (x + 1.0, yy + 0.15, z1 - 0.1), m["black"])
    if observation:
        # the open platform at the rear, brass rails all round, red marker lamps
        py0, py1 = y0 - 1.3, y0
        mb.box((x - hw, py0, z0 - 0.12), (x + hw, py1, z0), m["t_iron"])
        mb.box((x - hw, py0, z0 - 0.2), (x + hw, py1, z0 - 0.12), m["t_brass"])
        for xx in (x - hw + 0.05, x + hw - 0.05):
            mb.rod((xx, py0 + 0.05, z0), (xx, py0 + 0.05, z0 + 1.05), 0.025, m["t_brass"])
        for k2 in range(9):
            xx = x - hw + 0.05 + k2 * (2 * hw - 0.1) / 8
            mb.rod((xx, py0 + 0.05, z0), (xx, py0 + 0.05, z0 + 1.0), 0.012, m["t_brass"])
        mb.rod((x - hw, py0 + 0.05, z0 + 1.03), (x + hw, py0 + 0.05, z0 + 1.03), 0.03, m["t_brass"])
        for side in (-1, 1):
            mb.rod((x + side * (hw - 0.05), py0 + 0.05, z0 + 1.03), (x + side * (hw - 0.05), py0 + 0.45, z0 + 1.03), 0.03, m["t_brass"])
            for s in range(3):
                zz = z0 - 0.35 * (s + 1)
                xx = x + side * (hw - 0.1 - s * 0.05)
                mb.box((min(xx, xx + side * 0.35), py0 + 0.5, zz), (max(xx, xx + side * 0.35), py1 - 0.1, zz + 0.06), m["t_iron"])
        # awning over the platform
        mb.box((x - hw - 0.05, py0 - 0.1, z1 - 0.05), (x + hw + 0.05, py1, z1 + 0.1), m["roof"])
        for side in (-1, 1):
            mb.rod((x + side * (hw - 0.05), py0 + 0.05, z0 + 1.03), (x + side * (hw - 0.05), py0 + 0.05, z1 - 0.05), 0.02, m["t_brass"])
            mb.boxc((x + side * (hw - 0.02), py0 - 0.02, z0 + 1.3), (0.16, 0.16, 0.22), m["red_lamp"])
        # rear door with its blind down
        mb.boxc((x, y0 - 0.02, z0 + 1.1), (0.8, 0.04, 2.0), m["maroon"])
        mb.boxc((x, y0 - 0.045, z0 + 1.45), (0.55, 0.02, 0.8), m["blinds"])
        if coll is not None:
            for side in (-1, 1):
                light(coll, "red", 0 if side < 0 else 1, (x + side * (hw - 0.02), py0 - 0.3, z0 + 1.3))


def locomotive(mb, m, y0, x=TRACK_B):
    """A Pacific-type engine facing north. y0 is the back of the cab."""
    blk = m["black"]
    ir = m["t_iron"]
    bz = 3.0
    # cab
    mb.box((x - 1.55, y0, 1.7), (x + 1.55, y0 + 2.8, 4.3), blk)
    mb.box((x - 1.7, y0 - 0.3, 4.3), (x + 1.7, y0 + 3.0, 4.45), m["roof"])
    for side in (-1, 1):
        mb.boxc((x + side * 1.56, y0 + 1.4, 3.3), (0.02, 1.0, 0.7), m["firebox"])
    # boiler, firebox, smokebox
    rotY = Matrix.Rotation(-math.pi / 2, 4, "X")
    mb.cyl((x, y0 + 2.8, bz), 1.02, 1.0, 2.2, blk, seg=24, rot=rotY)
    mb.cyl((x, y0 + 5.0, bz), 0.95, 0.95, 6.8, blk, seg=24, rot=rotY)
    for yy in (y0 + 6.0, y0 + 8.2, y0 + 10.4):
        mb.cyl((x, yy, bz), 0.99, 0.99, 0.12, m["t_brass"], seg=24, rot=rotY)
    mb.cyl((x, y0 + 11.8, bz), 1.0, 1.0, 1.9, blk, seg=24, rot=rotY)
    mb.cyl((x, y0 + 13.7, bz), 0.96, 0.9, 0.12, ir, seg=24, rot=rotY)
    # stack, domes, bell, headlamp
    mb.lathe((x, y0 + 12.7, bz + 0.85), [(0.34, 0.0), (0.28, 0.5), (0.3, 1.1), (0.38, 1.3), (0.3, 1.35)], blk, seg=16)
    mb.lathe((x, y0 + 8.0, bz + 0.85), [(0.5, 0.0), (0.45, 0.35), (0.3, 0.6), (0.0, 0.65)], blk, seg=16)
    mb.lathe((x, y0 + 10.2, bz + 0.85), [(0.42, 0.0), (0.38, 0.3), (0.25, 0.5), (0.0, 0.55)], blk, seg=16)
    mb.lathe((x, y0 + 11.3, bz + 1.0), [(0.05, 0.0), (0.18, 0.1), (0.2, 0.3), (0.12, 0.4)], m["t_brass"], seg=12)
    mb.box((x - 0.32, y0 + 13.4, bz + 1.0), (x + 0.32, y0 + 13.9, bz + 1.6), blk)
    mb.boxc((x, y0 + 13.92, bz + 1.3), (0.34, 0.04, 0.34), m["headlamp"])
    # running boards and pilot
    for side in (-1, 1):
        mb.box((x + side * 1.15 - 0.25, y0 + 2.8, 2.05), (x + side * 1.15 + 0.25, y0 + 13.6, 2.12), ir)
        mb.cyl((x + side * 1.3, y0 + 12.4, 1.75), 0.38, 0.38, 1.4, blk, seg=16, rot=rotY)
    for k in range(9):
        t = k / 8
        xx = x - 1.3 + 2.6 * t
        mb.rod((xx, y0 + 14.0, 1.55), (x + (xx - x) * 0.3, y0 + 15.1, 0.62), 0.04, ir)
    mb.box((x - 1.35, y0 + 13.9, 1.45), (x + 1.35, y0 + 14.2, 1.7), ir)
    # frame and wheels
    mb.box((x - 0.9, y0 - 0.5, 1.2), (x + 0.9, y0 + 14.0, 1.6), ir)
    for i, yy in enumerate((y0 + 3.4, y0 + 5.4, y0 + 7.4)):
        r = 0.88
        for side in (-1, 1):
            mb.cyl((x + side * 0.72 - 0.06, yy, RAIL_TOP + r), r, r, 0.12, ir, seg=22, rot=Matrix.Rotation(math.pi / 2, 4, "Y"))
            mb.cyl((x + side * 0.8, yy, RAIL_TOP + r), 0.18, 0.18, 0.1, m["t_brass"], seg=10, rot=Matrix.Rotation(math.pi / 2, 4, "Y"))
    for side in (-1, 1):
        mb.box((x + side * 0.86 - 0.04, y0 + 3.4, RAIL_TOP + 0.62), (x + side * 0.86 + 0.04, y0 + 7.4, RAIL_TOP + 0.74), m["t_brass"])
        mb.rod((x + side * 0.9, y0 + 5.4, RAIL_TOP + 0.9), (x + side * 1.3, y0 + 12.0, 1.75), 0.05, m["t_brass"])
    for yy, r in ((y0 + 10.4, 0.45), (y0 + 12.0, 0.45), (y0 + 0.9, 0.55)):
        for side in (-1, 1):
            mb.cyl((x + side * 0.72 - 0.05, yy, RAIL_TOP + r), r, r, 0.1, ir, seg=16, rot=Matrix.Rotation(math.pi / 2, 4, "Y"))
    return (x, y0 + 14.05, bz + 1.3), (x, y0 + 12.7, bz + 2.2)


def tender(mb, m, y0, y1, x=TRACK_B):
    mb.box((x - 1.5, y0, 1.7), (x + 1.5, y1, 3.7), m["black"])
    mb.box((x - 1.55, y0, 3.7), (x + 1.55, y1, 3.8), m["t_iron"])
    mb.sphere((x, (y0 + y1) / 2, 3.6), 1.4, m["coal"], sub=2, scale=(1.0, 2.4, 0.5))
    for yy in (y0 + 1.6, y1 - 1.6):
        truck(mb, m, x, yy)
    mb.box((x - 1.35, y0 + 0.2, 1.3), (x + 1.35, y1 - 0.2, 1.7), m["t_iron"])


def boxcar(mb, m, y0, y1, x=TRACK_A):
    mb.box((x - 1.35, y0, 1.35), (x + 1.35, y1, 4.1), m["boxcar"])
    mb.box((x - 1.45, y0 - 0.05, 4.1), (x + 1.45, y1 + 0.05, 4.25), m["roof"])
    mb.box((x - 1.4, y0 + 0.2, 1.0), (x + 1.4, y1 - 0.2, 1.35), m["t_iron"])
    for yy in (y0 + 2.2, y1 - 2.2):
        truck(mb, m, x, yy)
    for side in (-1, 1):
        mb.box((x + side * 1.36 - 0.02, (y0 + y1) / 2 - 1.0, 1.4), (x + side * 1.36 + 0.02, (y0 + y1) / 2 + 1.0, 3.9), m["crate_dark"])
        for yy in range(int(y0) + 1, int(y1), 1):
            mb.box((x + side * 1.37 - 0.01, yy - 0.03, 1.4), (x + side * 1.37 + 0.01, yy + 0.03, 4.05), m["crate_dark"])


def train():
    sc = kit.new_scene("Hoboken_Train")
    coll = sc.collection
    m = M()
    pc = MB()
    car(pc, m, -12.0, 9.0, m["maroon"], m["blinds"], observation=True, coll=coll)
    pc.obj("PrivateCar-col", coll)
    c1 = MB()
    car(c1, m, 9.3, 30.3, m["green"], m["coach_win"])
    c1.obj("Coach1-col", coll)
    c2 = MB()
    car(c2, m, 30.6, 51.6, m["green"], m["t_glass"])
    c2.obj("Coach2-col", coll)
    lo = MB()
    tender(lo, m, 51.9, 60.0)
    head, stack = locomotive(lo, m, 60.3)
    lo.obj("Engine-col", coll)
    light(coll, "headlamp", 0, (head[0], head[1] + 0.4, head[2]))
    light(coll, "firebox", 0, (TRACK_B, 61.6, 3.0))
    mark(coll, "MARK_stack", stack)
    mark(coll, "MARK_cylinder_L", (TRACK_B - 1.4, 73.2, 1.3))
    mark(coll, "MARK_cylinder_R", (TRACK_B + 1.4, 73.2, 1.3))
    # warm light behind the private car's blinds, and a dim coach
    for i, y in enumerate((-9.5, -5.0, -0.5, 4.0)):
        light(coll, "blinds", i, (TRACK_B, y, FLOOR + 1.7))
    light(coll, "coach", 0, (TRACK_B, 20.0, FLOOR + 1.8))
    kit.export(sc, "hoboken_train")

    sc2 = kit.new_scene("Hoboken_Boxcars")
    b = MB()
    boxcar(b, m, 14.0, 25.8)
    boxcar(b, m, 26.4, 38.2)
    boxcar(b, m, 39.0, 50.8)
    b.obj("Boxcars-col", sc2.collection)
    kit.export(sc2, "hoboken_boxcars")


# ------------------------------------------------------------------ the motor cab
def motorcar():
    sc = kit.new_scene("Motorcar_1910")
    coll = sc.collection
    m = M()
    mb = MB()
    body, trim = m["car_body"], m["car_trim"]
    L = 4.3
    # it faces +Y; origin between the axles on the ground
    wb = 2.9
    rw = 0.46
    for yy in (-wb / 2, wb / 2):
        for side in (-1, 1):
            x = side * 0.78
            rot = Matrix.Rotation(math.pi / 2, 4, "Y")
            mb.cyl((x - 0.06, yy, rw), rw, rw, 0.12, m["tire"], seg=20, rot=rot)
            mb.cyl((x - 0.065, yy, rw), rw * 0.78, rw * 0.78, 0.13, m["car_trim"], seg=20, rot=rot)
            for k in range(10):
                a = 2 * math.pi * k / 10
                mb.rod((x, yy, rw), (x, yy + math.cos(a) * rw * 0.75, rw + math.sin(a) * rw * 0.75), 0.018, m["wood"])
            mb.cyl((x - 0.08, yy, rw), 0.08, 0.08, 0.16, m["t_brass"], seg=10, rot=rot)
    # chassis, fenders and running boards
    mb.box((-0.55, -2.1, 0.45), (0.55, 2.2, 0.65), trim)
    for side in (-1, 1):
        mb.box((side * 0.62, -1.05, 0.52), (side * 0.95, 1.05, 0.56), trim)
        for yy in (-wb / 2, wb / 2):
            pts = []
            for k in range(10):
                a = math.pi * k / 9
                pts.append((yy - math.cos(a) * 0.62, 0.46 + math.sin(a) * 0.56))
            for k in range(9):
                (y1, z1), (y2, z2) = pts[k], pts[k + 1]
                mb.quad([(side * 0.64, y1, z1), (side * 0.95, y1, z1), (side * 0.95, y2, z2), (side * 0.64, y2, z2)], trim)
    # hood and radiator
    mb.box((-0.48, 1.05, 0.65), (0.48, 2.05, 1.25), body)
    mb.box((-0.5, 2.05, 0.55), (0.5, 2.15, 1.3), m["t_brass"])
    mb.box((-0.44, 2.14, 0.62), (0.44, 2.16, 1.22), trim)
    for side in (-1, 1):
        mb.lathe((side * 0.55, 2.2, 1.12), [(0.0, -0.13), (0.13, -0.12), (0.14, 0.0), (0.13, 0.12), (0.0, 0.13)], m["t_brass"], seg=12)
        mb.boxc((side * 0.55, 2.33, 1.12), (0.2, 0.02, 0.2), m["car_lamp"])
    # driver's seat, open, with a glass screen
    mb.box((-0.7, 0.2, 0.65), (0.7, 1.05, 1.05), body)
    mb.box((-0.62, 0.3, 1.05), (0.62, 0.7, 1.3), m["car_leather"])
    mb.box((-0.62, 1.0, 1.05), (0.62, 1.04, 1.75), m["t_glass"])
    # the closed passenger compartment
    mb.box((-0.78, -1.95, 0.65), (0.78, 0.2, 2.05), body)
    mb.box((-0.82, -2.0, 2.05), (0.82, 1.1, 2.12), trim)
    for side in (-1, 1):
        mb.box((side * 0.785 - 0.01, -1.5, 1.25), (side * 0.785 + 0.01, -0.35, 1.85), m["t_glass"])
        mb.box((side * 0.785 - 0.015, -0.3, 0.8), (side * 0.785 + 0.015, 0.15, 1.95), trim)
        mb.boxc((side * 0.82, 0.18, 1.55), (0.1, 0.1, 0.16), m["car_lamp"])
    mb.box((-0.6, -1.96, 1.3), (0.6, -1.94, 1.8), m["t_glass"])
    mb.box((-0.6, -2.2, 0.8), (0.6, -1.95, 1.2), trim)  # trunk rack
    mb.obj("Motorcar", coll)
    mark(coll, "MARK_headlamps", (0.0, 2.4, 1.12))
    mark(coll, "MARK_door", (0.95, -0.9, 0.0))
    kit.export(sc, "motorcar")




# ------------------------------------------------------------------ inside the private car
def PM():
    return {
        "mahog": mat("PC_Mahogany", "#4a1e12", 0.45),
        "inlay": mat("PC_Inlay", "#a07a4a", 0.4),
        "ceiling": mat("PC_Ceiling", "#d8c8a0", 0.8),
        "gilt": mat("PC_Gilt", "#b8903e", 0.3, 0.9),
        "carpet": mat("PC_Carpet", "#1c3020", 0.95),
        "floor": mat("PC_Floor", "#5a3a22", 0.6),
        "tile": mat("PC_Tile", "#c8c0b0", 0.5),
        "velvet": mat("PC_Velvet", "#2a4a2e", 0.9),
        "leather": mat("PC_Leather", "#3a1a10", 0.5),
        "linen": mat("PC_Linen", "#eee8d8", 0.8),
        "china": mat("PC_China", "#f2eee4", 0.2),
        "silver": mat("PC_Silver", "#c8c4bc", 0.25, 1.0),
        "iron": mat("PC_Iron", "#1a1816", 0.5, 0.6),
        "glass": mat("PC_Glass", "#a0b0c0", 0.05, 0.0, None, 0.0, alpha=0.12),
        "blind": mat("PC_Blind", "#c8a870", 0.9),
        "galley": mat("PC_Galley", "#8a8270", 0.5, 0.3),
        "jacket": mat("PC_JacketWhite", "#f0ece2", 0.8),
        "lamp": mat("PC_Lamp", "#ffd8a0", 0.3, 0.0, "#ffc070", 3.0),
        "stove_glow": mat("PC_StoveGlow", "#ff7a30", 0.4, 0.0, "#ff6a20", 2.5),
        "paper": mat("PC_Paper", "#e8dcc0", 0.9),
        "coffee": mat("PC_Coffee", "#2a1408", 0.1),
        "valise": mat("PC_Valise", "#3a2414", 0.5),
    }


def chair(mb, m, c, facing, arm=False, seat_m=None):
    """A dining chair or an armchair. facing: unit (x, y) the sitter looks along."""
    x, y = c
    fx, fy = facing
    rz = math.atan2(-fx, fy)
    R = Matrix.Rotation(rz, 3, "Z")

    def P(dx, dy, dz):
        v = R @ Vector((dx, dy, dz))
        return (x + v.x, y + v.y, v.z)
    seat_m = seat_m or m["velvet"]
    w = 0.62 if arm else 0.48
    mb.boxc(P(0, 0, 0.44), (w, 0.5, 0.08 if not arm else 0.16), seat_m, rz=rz)
    mb.boxc(P(0, -0.25, 0.44 + (0.4 if not arm else 0.46)), (w, 0.08, 0.8 if not arm else 0.9), m["mahog"] if not arm else seat_m, rz=rz)
    if not arm:
        mb.boxc(P(0, -0.2, 0.9), (w - 0.1, 0.03, 0.36), seat_m, rz=rz)
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.rod(P(sx * (w / 2 - 0.04), sy * 0.21, 0.0), P(sx * (w / 2 - 0.04), sy * 0.21, 0.42), 0.022, m["mahog"])
        if arm:
            mb.boxc(P(sx * (w / 2 + 0.03), 0.0, 0.66), (0.1, 0.52, 0.12), seat_m, rz=rz)


def private_car():
    sc = kit.new_scene("Private_Car")
    coll = sc.collection
    m = PM()
    H = 2.45
    X = 1.6
    Y0, Y1 = -10.5, 10.1
    win_ys = [-8.3, -7.0, -3.9, -2.2, -0.5, 1.6, 3.4, 6.0, 7.8, 9.2]
    shell = MB()
    shell.box((-X - 0.1, Y0, -0.12), (X + 0.1, Y1, 0.0), m["floor"])
    # walls with real openings where the windows are, so the night can go by outside
    for side in (-1, 1):
        x0, x1 = (-X - 0.1, -X) if side < 0 else (X, X + 0.1)
        edges = [Y0]
        for wy in win_ys:
            edges += [wy - 0.38, wy + 0.38]
        edges.append(Y1)
        for i in range(0, len(edges), 2):
            shell.box((x0, edges[i], 0.0), (x1, edges[i + 1], H), m["mahog"])
        for wy in win_ys:
            shell.box((x0, wy - 0.38, 0.0), (x1, wy + 0.38, 0.9), m["mahog"])
            shell.box((x0, wy - 0.38, 1.75), (x1, wy + 0.38, H), m["mahog"])
            xi = X * side
            shell.box((min(xi, xi - side * 0.015), wy - 0.36, 1.75 - 0.32), (max(xi, xi - side * 0.015), wy + 0.36, 1.75), m["blind"])
            shell.box((min(xi, xi + side * 0.02), wy - 0.37, 0.88), (max(xi, xi + side * 0.02), wy + 0.37, 0.93), m["inlay"])
            shell.boxc((xi + side * 0.05, wy, 1.32), (0.01, 0.74, 0.86), m["glass"])
    shell.box((-X - 0.1, Y0 - 0.1, 0.0), (X + 0.1, Y0, H), m["mahog"])
    shell.box((-X - 0.1, Y1, 0.0), (-0.5, Y1 + 0.1, H), m["mahog"])
    shell.box((0.5, Y1, 0.0), (X + 0.1, Y1 + 0.1, H), m["mahog"])
    shell.box((-0.5, Y1, 2.1), (0.5, Y1 + 0.1, H), m["mahog"])
    shell.boxc((0.0, Y1 + 0.05, 1.05), (1.0, 0.04, 2.1), m["glass"])
    # ceiling with the raised clerestory down the middle
    shell.box((-X - 0.1, Y0, H), (-0.8, Y1, H + 0.08), m["ceiling"])
    shell.box((0.8, Y0, H), (X + 0.1, Y1, H + 0.08), m["ceiling"])
    shell.box((-0.8, Y0, H + 0.4), (0.8, Y1, H + 0.48), m["ceiling"])
    for side in (-1, 1):
        shell.box((side * 0.8 - 0.04, Y0, H), (side * 0.8 + 0.04, Y1, H + 0.4), m["mahog"])
        yy = Y0 + 0.8
        while yy < Y1 - 0.8:
            shell.boxc((side * 0.83, yy, H + 0.22), (0.02, 0.5, 0.2), m["glass"])
            yy += 1.2
    for yy in [Y0 + 0.5 + 1.1 * k for k in range(19)]:
        shell.box((-X, yy - 0.03, H - 0.06), (X, yy + 0.03, H), m["gilt"])
    shell.obj("CarShell-col", coll)

    rooms = MB()
    # vestibule to galley: a doorway in the middle
    rooms.box((-X, -9.35, 0.0), (-0.45, -9.25, H), m["mahog"])
    rooms.box((0.45, -9.35, 0.0), (X, -9.25, H), m["mahog"])
    rooms.box((-0.45, -9.35, 2.05), (0.45, -9.25, H), m["mahog"])
    # galley to corridor: the pantry door, standing half open
    rooms.box((-X, -5.55, 0.0), (0.55, -5.45, H), m["mahog"])
    rooms.box((1.45, -5.55, 0.0), (X, -5.45, H), m["mahog"])
    rooms.box((0.55, -5.55, 2.05), (1.45, -5.45, H), m["mahog"])
    rooms.boxc((0.62, -5.1, 1.02), (0.06, 0.85, 2.04), m["mahog"], rz=0.25)
    # staterooms along the west, the corridor along the east
    rooms.box((0.45, -5.45, 0.0), (0.55, 0.55, H), m["mahog"])
    rooms.box((-X, 0.45, 0.0), (0.55, 0.55, H), m["mahog"])
    for dy in (-4.4, -2.5, -0.6):
        rooms.boxc((0.56, dy, 1.0), (0.02, 0.75, 1.95), m["inlay"])
        rooms.boxc((0.58, dy + 0.28, 1.0), (0.04, 0.04, 0.04), m["gilt"])
    # arch between the dining room and the lounge
    rooms.box((-X, 4.95, 0.0), (-1.0, 5.05, H), m["mahog"])
    rooms.box((1.0, 4.95, 0.0), (X, 5.05, H), m["mahog"])
    rooms.box((-1.0, 4.95, 2.1), (1.0, 5.05, H), m["mahog"])
    # floors: tile in the galley, carpet down the rest
    rooms.box((-X, -9.25, 0.0), (X, -5.55, 0.01), m["tile"])
    rooms.box((0.55, -5.45, 0.0), (X, 0.5, 0.012), m["carpet"])
    rooms.box((-X, 0.55, 0.0), (X, Y1, 0.012), m["carpet"])
    rooms.obj("Rooms-col", coll)

    # ---- the galley
    g = MB()
    g.box((-X, -9.2, 0.0), (-1.02, -5.65, 0.9), m["galley"])
    g.box((-X, -9.2, 0.9), (-0.98, -5.65, 0.94), m["mahog"])
    g.box((-X, -9.2, 1.45), (-1.25, -5.65, 2.2), m["mahog"])
    for yy in (-8.6, -7.7, -6.8, -6.0):
        g.boxc((-1.24, yy, 1.82), (0.02, 0.8, 0.66), m["inlay"])
    g.box((0.95, -9.2, 0.0), (X, -8.1, 0.82), m["iron"])
    g.box((0.95, -9.2, 0.82), (X, -8.1, 0.86), m["iron"])
    g.boxc((0.94, -8.65, 0.45), (0.02, 0.5, 0.25), m["stove_glow"])
    for yy, r in ((-8.9, 0.14), (-8.4, 0.11)):
        g.cyl((1.27, yy, 0.86), r, r * 0.95, 0.18, m["silver"], seg=14)
    g.rod((1.27, -8.95, 0.86), (1.27, -8.95, H), 0.07, m["iron"])
    g.box((1.0, -7.6, 0.0), (X, -6.6, 1.35), m["mahog"])
    g.boxc((0.99, -7.1, 1.0), (0.02, 0.1, 0.1), m["gilt"])
    # the steward's spare jacket on its hook
    g.rod((1.58, -6.05, 1.75), (1.45, -6.05, 1.75), 0.012, m["gilt"])
    g.box((1.36, -6.28, 1.0), (1.5, -5.82, 1.72), m["jacket"])
    g.rod((1.43, -6.28, 1.66), (1.43, -6.34, 1.1), 0.05, m["jacket"])
    g.rod((1.43, -5.82, 1.66), (1.43, -5.76, 1.1), 0.05, m["jacket"])
    # the coffee service waiting on the counter
    g.cyl((-1.3, -6.6, 0.94), 0.2, 0.19, 0.015, m["silver"], seg=24)
    g.lathe((-1.34, -6.62, 0.955), [(0.05, 0.0), (0.07, 0.06), (0.07, 0.16), (0.04, 0.22), (0.02, 0.24)], m["silver"], seg=12)
    for dx, dy in ((0.07, 0.1), (-0.06, 0.12), (0.1, -0.06)):
        g.cyl((-1.3 + dx, -6.6 + dy, 0.955), 0.035, 0.03, 0.06, m["china"], seg=10)
    g.obj("Galley-col", coll)

    # ---- the dining room
    d = MB()
    d.box((-0.45, 1.4, 0.72), (0.45, 4.0, 0.76), m["mahog"])
    d.box((-0.5, 1.35, 0.5), (0.5, 4.05, 0.76), m["linen"])
    d.rod((0.0, 2.7, 0.0), (0.0, 2.7, 0.72), 0.08, m["mahog"])
    d.box((-0.3, 2.3, 0.0), (0.3, 3.1, 0.05), m["mahog"])
    for (cx, cy) in ((-0.2, 2.05), (-0.2, 3.35), (0.2, 2.05), (0.2, 3.35)):
        d.cyl((cx, cy, 0.76), 0.12, 0.11, 0.012, m["china"], seg=18)
        d.cyl((cx + (0.08 if cx < 0 else -0.08), cy + 0.12, 0.76), 0.035, 0.03, 0.07, m["china"], seg=10)
    d.lathe((0.0, 2.7, 0.76), [(0.06, 0.0), (0.08, 0.08), (0.08, 0.2), (0.04, 0.28), (0.02, 0.3)], m["silver"], seg=12)
    d.lathe((0.0, 3.0, 0.76), [(0.05, 0.0), (0.02, 0.05), (0.015, 0.3), (0.04, 0.32)], m["silver"], seg=10)
    d.box((-X, 1.0, 0.0), (-1.2, 4.4, 0.9), m["mahog"])
    for bx in (-1.5, -1.4, -1.32):
        d.lathe((bx, 1.6 + (bx + 1.5) * 4, 0.9), [(0.04, 0.0), (0.04, 0.2), (0.015, 0.28), (0.015, 0.34)], m["glass"], seg=8)
    d.obj("Dining-col", coll)
    ch = MB()
    for (cx, cy), f in (((-0.82, 2.05), (1, 0)), ((-0.82, 3.35), (1, 0)), ((0.82, 2.05), (-1, 0)), ((0.82, 3.35), (-1, 0))):
        chair(ch, m, (cx, cy), f)
    # ---- the lounge at the rear
    for (cx, cy), f in (((-1.05, 6.4), (1, 0)), ((1.05, 6.4), (-1, 0))):
        chair(ch, m, (cx, cy), f, arm=True)
    ch.box((-X + 0.05, 7.8, 0.0), (-1.0, 9.6, 0.42), m["velvet"])
    ch.box((-X + 0.05, 7.8, 0.42), (-1.3, 9.6, 1.0), m["velvet"])
    for yy in (7.8, 9.6):
        ch.box((-X + 0.05, yy - 0.08, 0.0), (-1.0, yy + 0.08, 0.62), m["velvet"])
    ch.cyl((0.0, 7.2, 0.0), 0.22, 0.22, 0.55, m["mahog"], seg=16)
    ch.cyl((0.0, 7.2, 0.55), 0.35, 0.35, 0.03, m["mahog"], seg=20)
    ch.box((1.0, 8.2, 0.0), (X, 9.5, 0.76), m["mahog"])
    for k in range(5):
        ch.boxc((1.3 + (k % 2) * 0.05, 8.6 + k * 0.03, 0.765 + k * 0.004), (0.3, 0.4, 0.004), m["paper"], rz=0.1 * k)
    ch.box((1.1, 9.0, 0.76), (1.5, 9.4, 1.0), m["valise"])
    ch.obj("Furniture", coll)

    # lamps: sconces between the windows, a ceiling lamp over the table and one in the lounge
    lp = MB()
    for side in (-1, 1):
        for wy in (-2.95, 2.5, 6.9, 8.5):
            xi = side * (X - 0.03)
            lp.boxc((xi, wy, 1.95), (0.04, 0.12, 0.18), m["gilt"])
            lp.sphere((xi - side * 0.12, wy, 2.0), 0.07, m["lamp"], sub=1)
            light(coll, "sconce", int((wy + 10) * 10) + (0 if side < 0 else 1), (xi - side * 0.25, wy, 2.0))
    for i, (yy) in enumerate((2.7, 7.4, -7.4, -2.5)):
        lp.lathe((0.0, yy, H + 0.4), [(0.03, 0.0), (0.03, -0.25), (0.22, -0.4), (0.18, -0.5), (0.0, -0.52)], m["gilt"], seg=12)
        lp.sphere((0.0, yy, H - 0.14), 0.1, m["lamp"], sub=1)
        light(coll, "ceiling", i, (0.0, yy, H - 0.3))
    lp.obj("Lamps", coll)
    light(coll, "stove", 0, (0.8, -8.65, 0.5))

    # ---- where people are
    def seat(name, c, facing):
        fx, fy = facing
        rz = math.atan2(-fx, fy)
        mark(coll, "MARK_seat_" + name, (c[0] + fx * 0.12, c[1] + fy * 0.12, 0.0), rz)
    seat("frank", (-0.82, 2.05), (1, 0))
    seat("paul", (-0.82, 3.35), (1, 0))
    seat("harry", (0.82, 2.05), (-1, 0))
    seat("ben", (0.82, 3.35), (-1, 0))
    seat("nelson", (-1.05, 6.4), (1, 0))
    seat("abe", (1.05, 6.4), (-1, 0))
    seat("arthur", (-1.25, 8.7), (1, 0))
    mark(coll, "MARK_pc_spawn", (0.0, -9.9, 0.0), 0.0)
    mark(coll, "MARK_peek", (1.0, -6.1, 0.0))
    mark(coll, "MARK_cam_peek", (1.05, -5.35, 1.55))
    mark(coll, "MARK_cam_peek_look", (-0.1, 3.0, 1.1))
    mark(coll, "MARK_jacket", (1.0, -6.05, 0.0))
    mark(coll, "MARK_tray", (-0.75, -6.6, 0.0))
    kit.export(sc, "private_car")


# ------------------------------------------------------------------ the meeting room on Jekyll Island
def JM():
    return {
        "oak": mat("JK_Oak", "#3a2414", 0.5),
        "plaster": mat("JK_Plaster", "#8a8a70", 0.85),
        "floor": mat("JK_Floor", "#5a3c24", 0.6),
        "ceiling": mat("JK_Ceiling", "#d0c4a4", 0.85),
        "stone": mat("JK_Stone", "#7a7266", 0.9),
        "brick": mat("JK_Brick", "#3a2218", 0.9),
        "baize": mat("JK_Baize", "#1f3a26", 0.95),
        "leather": mat("JK_Leather", "#3a1a10", 0.5),
        "brass": mat("JK_Brass", "#b8903e", 0.3, 0.9),
        "paper": mat("JK_Paper", "#e8dcc0", 0.9),
        "ink": mat("JK_Ink", "#101014", 0.2),
        "china": mat("JK_China", "#f2eee4", 0.2),
        "window": kit.img_mat("JK_Window", os.path.join(TEX, "marsh_window.png"), 0.4, emit=1.3),
        "chalk": kit.img_mat("JK_Chalkboard", os.path.join(TEX, "chalkboard_1910.png"), 0.8),
        "fire": mat("JK_Fire", "#ff8a30", 0.4, 0.0, "#ff7020", 5.0),
        "ember": mat("JK_Ember", "#6a1a08", 0.6, 0.0, "#ff4010", 1.5),
        "rug": mat("JK_Rug", "#5a1c18", 0.95),
        "gun": mat("JK_Gun", "#2a1a10", 0.4),
        "steel": mat("JK_Steel", "#5a5a5e", 0.35, 0.9),
        "lamp": mat("JK_Lamp", "#ffd8a0", 0.3, 0.0, "#ffc070", 3.0),
        "book": mat("JK_Book", "#4a2a1a", 0.6),
    }


def meeting_room():
    sc = kit.new_scene("Jekyll_Meeting")
    coll = sc.collection
    m = JM()
    W, D, H = 5.5, 3.5, 3.8
    s = MB()
    s.box((-W - 0.2, -D - 0.2, -0.12), (W + 0.2, D + 0.2, 0.0), m["floor"])
    s.box((-W - 0.2, -D - 0.2, H), (W + 0.2, D + 0.2, H + 0.12), m["ceiling"])
    # walls: oak wainscot to the chair rail, plaster above; openings for the door and windows
    s.box((-W - 0.2, D, 0.0), (W + 0.2, D + 0.2, H), m["plaster"])
    s.box((-W - 0.2, -D - 0.2, 0.0), (-4.1, -D, H), m["plaster"])
    s.box((-2.9, -D - 0.2, 0.0), (W + 0.2, -D, H), m["plaster"])
    s.box((-4.1, -D - 0.2, 2.3), (-2.9, -D, H), m["plaster"])
    s.box((-W - 0.2, -D, 0.0), (-W, D, H), m["plaster"])
    wys = (-2.0, 0.0, 2.0)
    edges = [-D]
    for wy in wys:
        edges += [wy - 0.55, wy + 0.55]
    edges.append(D)
    for i in range(0, len(edges), 2):
        s.box((W, edges[i], 0.0), (W + 0.2, edges[i + 1], H), m["plaster"])
    for wy in wys:
        s.box((W, wy - 0.55, 0.0), (W + 0.2, wy + 0.55, 0.8), m["plaster"])
        s.box((W, wy - 0.55, 3.0), (W + 0.2, wy + 0.55, H), m["plaster"])
        s.quad([(W + 0.1, wy + 0.55, 0.8), (W + 0.1, wy - 0.55, 0.8), (W + 0.1, wy - 0.55, 3.0), (W + 0.1, wy + 0.55, 3.0)], m["window"], uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
        for zz in (0.8, 1.9, 3.0):
            s.box((W - 0.02, wy - 0.58, zz - 0.03), (W + 0.12, wy + 0.58, zz + 0.03), m["oak"])
        for yy in (wy - 0.55, wy, wy + 0.55):
            s.box((W - 0.02, yy - 0.03, 0.8), (W + 0.12, yy + 0.03, 3.0), m["oak"])
        light(coll, "daylight", int(wy + 5), (W - 0.8, wy, 2.0))
    # wainscot, chair rail, crown molding
    for (a, b) in (((-W, -D), (W, -D + 0.04)), ((-W, D - 0.04), (W, D)), ((-W, -D), (-W + 0.04, D)), ((W - 0.04, -D), (W, D))):
        s.box((a[0], a[1], 0.0), (b[0], b[1], 1.1), m["oak"])
        s.box((a[0] - 0.02, a[1] - 0.02, 1.1), (b[0] + 0.02, b[1] + 0.02, 1.16), m["oak"])
        s.box((a[0] - 0.03, a[1] - 0.03, H - 0.18), (b[0] + 0.03, b[1] + 0.03, H), m["oak"])
    # beams across the ceiling
    for xx in (-3.6, -1.2, 1.2, 3.6):
        s.box((xx - 0.12, -D, H - 0.28), (xx + 0.12, D, H), m["oak"])
    s.obj("Room-col", coll)

    f = MB()
    # the fireplace on the north wall
    f.box((-1.2, D - 0.55, 0.0), (1.2, D, 1.5), m["stone"])
    f.box((-1.35, D - 0.62, 1.5), (1.35, D, 1.62), m["oak"])
    f.box((-0.6, D - 0.56, 0.0), (0.6, D - 0.1, 0.95), m["brick"])
    f.box((-0.62, D - 0.57, 0.95), (0.62, D - 0.1, 1.02), m["stone"])
    for k in range(3):
        f.rod((-0.35 + k * 0.08, D - 0.4, 0.12 + k * 0.03), (0.35 - k * 0.1, D - 0.28, 0.14 + k * 0.03), 0.06, m["ember"])
    f.sphere((0.0, D - 0.33, 0.3), 0.22, m["fire"], sub=2, scale=(1.4, 0.6, 1.2))
    f.box((-0.8, D - 0.1, 1.62), (0.8, D, 3.0), m["oak"])
    f.obj("Fireplace-col", coll)
    light(coll, "fire", 0, (0.0, D - 0.9, 0.55))
    # the long table and its papers
    t = MB()
    t.box((-2.3, -0.65, 0.72), (2.3, 0.65, 0.78), m["oak"])
    t.box((-2.2, -0.55, 0.78), (2.2, 0.55, 0.785), m["baize"])
    for xx in (-1.9, 1.9):
        for yy in (-0.45, 0.45):
            t.lathe((xx, yy, 0.0), [(0.06, 0.0), (0.05, 0.1), (0.08, 0.35), (0.05, 0.6), (0.06, 0.72)], m["oak"], seg=10)
    rs = kit.rng_seed(7)
    for k in range(26):
        xx = rs.uniform(-2.0, 2.0)
        yy = rs.uniform(-0.45, 0.45)
        t.boxc((xx, yy, 0.787 + k * 0.0006), (0.22, 0.29, 0.003), m["paper"], rz=rs.uniform(-0.5, 0.5))
    for xx in (-1.4, 0.0, 1.4):
        for yy in (-0.35, 0.35):
            t.cyl((xx + 0.15, yy, 0.785), 0.04, 0.035, 0.07, m["ink"], seg=8)
            t.cyl((xx - 0.2, yy * 0.8, 0.785), 0.07, 0.06, 0.01, m["china"], seg=14)
            t.cyl((xx - 0.2, yy * 0.8, 0.795), 0.035, 0.03, 0.06, m["china"], seg=10)
    for k in range(4):
        t.box((-2.1, -0.2 + k * 0.1, 0.787 + k * 0.035), (-1.8, -0.05 + k * 0.1, 0.787 + (k + 1) * 0.035), m["book"])
    t.obj("Table-col", coll)
    ch = MB()
    seats = {
        "nelson": ((-2.8, 0.0), (1, 0)), "paul": ((-1.4, 1.1), (0, -1)), "frank": ((0.0, 1.1), (0, -1)), "harry": ((1.4, 1.1), (0, -1)),
        "abe": ((-1.4, -1.1), (0, 1)), "ben": ((0.0, -1.1), (0, 1)), "arthur": ((1.4, -1.1), (0, 1)), "empty": ((2.8, 0.0), (-1, 0)),
    }
    for key, (c, fc) in seats.items():
        chair(ch, {"velvet": m["leather"], "mahog": m["oak"]}, c, fc, arm=(key == "nelson"))
        if key != "empty":
            rz = math.atan2(-fc[0], fc[1])
            mark(coll, "MARK_seat_" + key, (c[0] + fc[0] * 0.12, c[1] + fc[1] * 0.12, 0.0), rz)
    # sideboard with the coffee, bookcases, the shotguns nobody fired
    ch.box((-1.6, -D + 0.04, 0.0), (1.0, -D + 0.55, 0.92), m["oak"])
    ch.lathe((0.4, -D + 0.3, 0.92), [(0.07, 0.0), (0.09, 0.1), (0.09, 0.24), (0.05, 0.32), (0.02, 0.34)], m["brass"], seg=12)
    for xx in (2.0, 3.6):
        ch.box((xx - 0.7, -D + 0.04, 0.0), (xx + 0.7, -D + 0.4, 2.4), m["oak"])
        for zz in (0.4, 0.9, 1.4, 1.9):
            for k in range(14):
                ch.boxc((xx - 0.62 + k * 0.09, -D + 0.25, zz + 0.16), (0.07, 0.24, 0.3 + (k % 3) * 0.03), m["book"] if k % 4 else m["leather"])
    for k in range(3):
        base = Vector((-5.2 + k * 0.18, -3.2, 0.0))
        top = base + Vector((0.25, 0.1, 1.2))
        ch.rod(base, base + (top - base) * 0.35, 0.03, m["gun"])
        ch.rod(base + (top - base) * 0.35, top, 0.012, m["steel"])
    ch.obj("Furniture", coll)
    # the chalkboard on the west wall
    cb = MB()
    cb.box((-W + 0.04, -1.3, 1.0), (-W + 0.1, 1.3, 2.55), m["oak"])
    cb.quad([(-W + 0.11, -1.2, 1.08), (-W + 0.11, 1.2, 1.08), (-W + 0.11, 1.2, 2.47), (-W + 0.11, -1.2, 2.47)], m["chalk"], uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    cb.obj("Chalkboard", coll)
    # gas chandeliers and sconces
    lp = MB()
    for i, xx in enumerate((-1.3, 1.3)):
        lp.rod((xx, 0.0, H), (xx, 0.0, 3.0), 0.02, m["brass"])
        for k in range(5):
            a = 2 * math.pi * k / 5
            p = (xx + math.cos(a) * 0.4, math.sin(a) * 0.4, 2.85)
            lp.rod((xx, 0.0, 2.95), p, 0.015, m["brass"])
            lp.sphere(p, 0.07, m["lamp"], sub=1)
        light(coll, "chandelier", i, (xx, 0.0, 2.7))
    for i, (xx, yy) in enumerate(((-3.8, D - 0.1), (3.8, D - 0.1), (-W + 0.1, -2.4), (-W + 0.1, 2.4))):
        lp.sphere((xx + (0.12 if xx < -W + 1 else 0), yy - (0.12 if yy > 0 else 0), 2.1), 0.07, m["lamp"], sub=1)
        light(coll, "sconce", i, (xx + (0.3 if xx < -W + 1 else 0), yy - (0.3 if yy > 0 else 0), 2.1))
    lp.obj("Lamps", coll)
    rg = MB()
    rg.box((-3.4, -1.9, 0.0), (3.4, 1.9, 0.012), m["rug"])
    rg.obj("Rug", coll)
    mark(coll, "MARK_mt_spawn", (-3.5, -2.9, 0.0), 0.0)
    mark(coll, "MARK_cam_table", (3.9, -2.8, 2.3))
    mark(coll, "MARK_cam_table_look", (-1.2, 0.3, 1.0))
    mark(coll, "MARK_draft", (0.7, -1.7, 0.2))
    kit.export(sc, "meeting_room")


BUILDERS = {"yard": yard, "train": train, "motorcar": motorcar, "private_car": private_car, "meeting": meeting_room}



def main(keys):
    bpy.ops.wm.open_mainfile(filepath=kit.BLEND)
    for k in keys:
        BUILDERS[k]()
        print("built", k)
    bpy.ops.wm.save_as_mainfile(filepath=kit.BLEND, compress=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    keys = [a for a in argv if a in BUILDERS] or list(BUILDERS.keys())
    main(keys)
