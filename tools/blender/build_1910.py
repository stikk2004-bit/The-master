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
STEP_RISE = 0.34     # car steps: tread tops at 1.46, 1.12, 0.78, 0.44
DOOR_H = 2.05
TRACK_A = -4.0
TRACK_B = 4.0
GATE = (-26.6, -24.4)  # the freight gate in the yard's south fence
CAR_Y0, CAR_Y1 = 13.3, 34.3   # the Senator's car on track B; its south vestibule (the seven's doors) is y0..y0+1.1
SIDE_GATE_Y = 21.0     # a side gate in the yard's west fence, from the warehouse alley
CINZEL = os.path.join(kit.ROOT, "tools", "fonts", "Cinzel-Bold.woff")


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
        "path": mat("HB_Path", "#8e836e", 0.95),
        "planks": mat("HB_Planks", "#5e4a36", 0.85),
        "sign": mat("HB_SignPaint", "#d8ccb0", 0.8),
        "sw_red": mat("HB_SwitchRed", "#ff3020", 0.3, 0.0, "#ff2a10", 3.0),
        "sw_green": mat("HB_SwitchGreen", "#50ff90", 0.3, 0.0, "#40ff80", 3.0),
        "sack": mat("HB_Sack", "#8a7a5c", 0.95),
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


def walk(mb, m, pts, w=1.8, mat_key="path"):
    """a gravel walk along a polyline, a hair above the cinders, with round ends so the joins don't gap"""
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy)
        nx, ny = -dy / L * w / 2, dx / L * w / 2
        mb.quad([(ax + nx, ay + ny, 0.03), (ax - nx, ay - ny, 0.03), (bx - nx, by - ny, 0.03), (bx + nx, by + ny, 0.03)], m[mat_key])
    for x, y in pts:
        mb.cyl((x, y, 0.0), w / 2, w / 2, 0.03, m[mat_key], seg=16)


def crossing(mb, m, x, y, w=2.0, east_to=None):
    """a plank grade crossing over the track at x: planks flush with the rail tops, sloped ends down to the cinders"""
    top = RAIL_TOP + 0.01
    y0, y1 = y - w / 2, y + w / 2
    spans = [(x - 1.95, x - 0.78), (x - 0.66, x + 0.66), (x + 0.78, (east_to if east_to else x + 1.95))]
    for a, b in spans:
        yy = y0
        while yy < y1 - 0.05:
            mb.box((a, yy, 0.28), (b, min(yy + 0.36, y1), top), m["planks"])
            yy += 0.4
    ends = [(-1, x - 1.95, x - 3.1)] + ([] if east_to else [(1, x + 1.95, x + 3.1)])
    for sgn, xa, xb in ends:
        # the ramp: top slope, the two sides, the high end is against the planks
        mb.quad([(xa, y0, top), (xa, y1, top), (xb, y1, 0.0), (xb, y0, 0.0)][::(1 if sgn < 0 else -1)], m["planks"])
        mb.quad([(xa, y0, 0.0), (xa, y0, top), (xb, y0, 0.0)][::(1 if sgn < 0 else -1)], m["planks"])
        mb.quad([(xa, y1, 0.0), (xb, y1, 0.0), (xa, y1, top)][::(1 if sgn < 0 else -1)], m["planks"])


def post_lamp(mb, m, c, h=2.7):
    """a short iron post with a lantern on a bracket, the kind that marks a walk"""
    x, y, z = c
    mb.cyl((x, y, z), 0.12, 0.1, 0.3, m["stone"], seg=8)
    mb.rod((x, y, z + 0.3), (x, y, z + h), 0.045, m["iron"])
    mb.rod((x, y, z + h - 0.1), (x + 0.35, y, z + h - 0.1), 0.02, m["iron"])
    mb.boxc((x + 0.35, y, z + h - 0.38), (0.2, 0.2, 0.3), m["lamp_glass"])
    mb.lathe((x + 0.35, y, z + h - 0.22), [(0.17, 0.0), (0.03, 0.14)], m["iron"], seg=4)
    return (x + 0.35, y, z + h - 0.4)


def switch_stand(mb, m, c, lens):
    """a switch stand beside the rails: a low iron post with a lamp that shows red or green down the track"""
    x, y, z = c
    mb.box((x - 0.25, y - 0.2, z), (x + 0.25, y + 0.2, z + 0.12), m["tie"])
    mb.rod((x, y, z + 0.12), (x, y, z + 1.25), 0.05, m["iron"])
    mb.rod((x, y, z + 0.5), (x + 0.5, y, z + 0.5), 0.025, m["iron"])     # the throw lever
    mb.boxc((x, y, z + 1.4), (0.24, 0.24, 0.28), m["iron"])
    mb.cyl((x, y - 0.13, z + 1.4), 0.08, 0.08, 0.03, m[lens], seg=12, rot=Matrix.Rotation(math.pi / 2, 4, "X"))
    mb.cyl((x, y + 0.1, z + 1.4), 0.08, 0.08, 0.03, m[lens], seg=12, rot=Matrix.Rotation(-math.pi / 2, 4, "X"))
    mb.lathe((x, y, z + 1.54), [(0.16, 0.0), (0.02, 0.12)], m["iron"], seg=6)
    return (x, y, z + 1.4)


def semaphore(mb, m, c, h=7.0):
    """a signal mast at the throat of the yard: an arm and a red lamp you can see from anywhere"""
    x, y, z = c
    mb.box((x - 0.4, y - 0.4, z), (x + 0.4, y + 0.4, z + 0.4), m["stone"])
    mb.rod((x, y, z + 0.4), (x, y, z + h), 0.1, m["tie"], r2=0.08)
    mb.box((x - 0.08, y - 0.05, z + h - 0.9), (x + 1.6, y + 0.05, z + h - 0.6), m["plat_edge"])
    mb.boxc((x - 0.2, y, z + h - 0.75), (0.26, 0.26, 0.3), m["iron"])
    mb.cyl((x - 0.2, y - 0.14, z + h - 0.75), 0.09, 0.09, 0.03, m["sw_red"], seg=12, rot=Matrix.Rotation(math.pi / 2, 4, "X"))
    for k in range(int(h / 0.4) - 2):
        mb.rod((x + 0.12, y - 0.15, z + 0.8 + k * 0.4), (x + 0.12, y + 0.15, z + 0.8 + k * 0.4), 0.015, m["iron"])
    mb.lathe((x, y, z + h), [(0.14, 0.0), (0.02, 0.2)], m["iron"], seg=8)
    return (x - 0.2, y - 0.3, z + h - 0.75)


def lumber_pile(mb, m, c, layers=5, length=6.0, rz=0.0):
    x, y, z = c
    rot = Matrix.Rotation(rz, 3, "Z")
    for k in range(3):
        v = rot @ Vector((0, -length / 2 + 0.4 + k * (length - 0.8) / 2, 0))
        mb.boxc((x + v.x, y + v.y, z + 0.08), (2.3, 0.16, 0.16), m["tie"], rz=rz)
    zz = z + 0.16
    for k in range(layers):
        for j in range(7):
            v = rot @ Vector((-0.96 + j * 0.32, 0, 0))
            mb.boxc((x + v.x, y + v.y, zz + 0.07), (0.28, length - R.uniform(0.0, 0.5), 0.14), m["planks"], rz=rz + R.uniform(-0.01, 0.01))
        zz += 0.15
        if k % 2 == 1 and k < layers - 1:
            for i in range(3):
                v = rot @ Vector((0, -length / 2 + 0.4 + i * (length - 0.8) / 2, 0))
                mb.boxc((x + v.x, y + v.y, zz + 0.04), (2.2, 0.08, 0.08), m["tie"], rz=rz)
            zz += 0.08
    return zz


def tie_pile(mb, m, c, layers=6, rz=0.0):
    """new crossties stacked criss-cross to season"""
    x, y, z = c
    zz = z
    for k in range(layers):
        a = rz + (0.0 if k % 2 == 0 else math.pi / 2)
        rot = Matrix.Rotation(a, 3, "Z")
        for j in range(5):
            v = rot @ Vector((-1.0 + j * 0.5, 0, 0))
            mb.boxc((x + v.x, y + v.y, zz + 0.09), (0.24, 2.6, 0.18), m["tie"], rz=a + R.uniform(-0.03, 0.03))
        zz += 0.18


def wheelset(mb, m, c):
    """a pair of car wheels on their axle, waiting for the shop"""
    x, y, z = c
    rx = Matrix.Rotation(math.pi / 2, 4, "Y")
    for sx in (-0.72, 0.72):
        mb.cyl((x + sx - 0.05, y, z + 0.46), 0.46, 0.46, 0.1, m["iron"], seg=16, rot=rx @ Matrix.Translation((0, 0, -0.05)))
        mb.cyl((x + sx - 0.02, y, z + 0.46), 0.5, 0.5, 0.04, m["rail"], seg=16, rot=rx)
    mb.rod((x - 0.9, y, z + 0.46), (x + 0.9, y, z + 0.46), 0.07, m["iron"])


def dray(mb, m, c, rz=0.0):
    """a freight wagon with its shafts down, a load of barrels and a tarp over half of it"""
    x, y, z = c
    rot = Matrix.Rotation(rz, 3, "Z")

    def P(dx, dy, dz):
        v = rot @ Vector((dx, dy, dz))
        return (x + v.x, y + v.y, z + v.z)
    mb.boxc(P(0, 0, 0.95), (1.7, 3.6, 0.1), m["wood"], rz=rz)
    for sx in (-0.85, 0.85):
        mb.boxc(P(sx, 0, 1.2), (0.06, 3.6, 0.4), m["wood"], rz=rz)
    rx = Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y")
    for sx in (-0.95, 0.95):
        for sy, r in ((-1.2, 0.55), (1.2, 0.45)):
            mb.cyl(P(sx, sy, r), r, r, 0.08, m["iron"], seg=16, rot=rx @ Matrix.Translation((0, 0, -0.04)))
    for sx in (-0.4, 0.4):
        mb.rod(P(sx, 1.8, 0.95), P(sx * 0.6, 4.2, 0.05), 0.04, m["wood"])
    for k in range(4):
        barrel(mb, m, P(-0.4 + (k % 2) * 0.8, -1.2 + (k // 2) * 0.75, 1.0), h=0.85, r=0.3)
    mb.quad([P(-0.95, 0.1, 1.0), P(0.95, 0.1, 1.0), P(0.95, 1.75, 1.0), P(-0.95, 1.75, 1.0)], m["canvas"])
    mb.boxc(P(0, 0.95, 1.3), (1.6, 1.6, 0.5), m["canvas"], rz=rz)


def milk_can(mb, m, c):
    x, y, z = c
    mb.lathe((x, y, z), [(0.16, 0.0), (0.17, 0.35), (0.12, 0.48), (0.08, 0.52), (0.09, 0.6)], m["tin"], seg=12)


def sack(mb, m, c, rz=0.0):
    x, y, z = c
    mb.sphere((x, y, z + 0.16), 0.3, m["sack"], sub=2, scale=(1.5, 0.9, 0.55))


def hut(mb, m, x0, x1, y0, y1, h, wall, window_face=None, lit=True):
    """a board-and-batten hut with a tin roof, one window, a stovepipe"""
    mb.box((x0, y0, 0.0), (x1, y1, h), wall)
    mb.box((x0 - 0.05, y0 - 0.05, 0.0), (x1 + 0.05, y1 + 0.05, 0.3), m["stone"])
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    mb.quad([(x0 - 0.3, y0 - 0.3, h), (x1 + 0.3, y0 - 0.3, h), (x1 + 0.3, cy, h + 0.9), (x0 - 0.3, cy, h + 0.9)], m["tin"])
    mb.quad([(x0 - 0.3, cy, h + 0.9), (x1 + 0.3, cy, h + 0.9), (x1 + 0.3, y1 + 0.3, h), (x0 - 0.3, y1 + 0.3, h)], m["tin"])
    mb.quad([(x0, y0, h), (x0, cy, h + 0.9), (x0, y1, h)], m["wood"])
    mb.quad([(x1, y1, h), (x1, cy, h + 0.9), (x1, y0, h)], m["wood"])
    mb.rod((x0 + 0.5, cy + 0.6, h + 0.5), (x0 + 0.5, cy + 0.6, h + 1.7), 0.08, m["iron"])
    if window_face is None:
        return None
    fx, fy = window_face
    X = x1 if fx > 0 else x0
    mb.arch_window((X + fx * 0.02, cy - 0.5, 1.5), 0.9, 1.0, m["wood"], m["window_lit"] if lit else m["glass_dark"], (fx, fy))
    # the door beside it
    mb.box((X + fx * 0.01 - 0.03, cy + 0.4, 0.3), (X + fx * 0.01 + 0.03, cy + 1.3, 2.3), m["crate_dark"])
    return (X + fx * 1.0, cy - 0.5, 1.5)


def yard_more(coll, m):
    """walks, crossings, lamps that mark the ways through, and more freight for cover"""
    # ---- walks: gravel from the freight gate across to the tracks; the lane between the tracks; the way
    # from the freight house to the Senator's car's front end
    wk = MB()
    walk(wk, m, [(-25.5, -27.2), (-25.3, -24.0), (-16.0, -22.4), (-7.1, -19.8)])
    walk(wk, m, [(0.0, -21.4), (0.0, 50.0)], w=1.6)
    walk(wk, m, [(-27.4, SIDE_GATE_Y - 0.2), (-22.8, 18.0), (-19.2, 16.5), (-15.6, 15.4), (-12.0, 14.0), (-7.1, 12.2)], w=1.2)
    walk(wk, m, [(-25.3, -24.0), (-27.4, -20.0), (-27.4, 60.0)], w=1.2)     # the fence walk, behind the freight house
    walk(wk, m, [(-11.2, 32.0), (-11.2, 44.0), (-15.5, 50.5)], w=1.2)          # up to the lumber and the ties
    wk.obj("Walks-col", coll)
    # ---- plank crossings over the rails
    cx = MB()
    crossing(cx, m, TRACK_A, -19.8)
    crossing(cx, m, TRACK_B, -21.0, east_to=6.25)
    crossing(cx, m, TRACK_A, 12.2)
    cx.obj("Crossings-col", coll)
    # ---- lamps along the walks (small pools of light: easy to follow, easy to be seen in)
    pl = MB()
    for i, c in enumerate(((-17.8, -20.6, 0.0), (-1.2, -21.9, 0.0), (-1.2, 22.5, 0.0), (-17.0, 17.6, 0.0), (-1.2, 44.0, 0.0))):
        light(coll, "path", i, post_lamp(pl, m, c))
    # switch stands with their lamps: red and green points to steer by in the dark
    for i, (c, lens) in enumerate((((-6.2, 2.6, 0.0), "sw_green"), ((-6.4, 15.8, 0.0), "sw_red"), ((-6.3, 50.4, 0.0), "sw_green"),
                                   ((1.9, -23.2, 0.0), "sw_red"), ((1.9, 46.0, 0.0), "sw_green"))):
        light(coll, "sigred" if lens == "sw_red" else "siggreen", i, switch_stand(pl, m, c, lens))
    light(coll, "sigred", 9, semaphore(pl, m, (1.7, -25.9, 0.0)))
    pl.obj("WalkLamps-col", coll)
    # ---- the yard office by the gate: a lit window, somebody's coat on a nail inside
    of = MB()
    lp = hut(of, m, -24.2, -21.0, -18.2, -14.2, 2.8, m["wood"], window_face=(1, 0))
    of.obj("YardOffice-col", coll)
    light(coll, "window", 300, lp)
    # a tool house at the north end, dark
    th = MB()
    hut(th, m, -25.8, -22.4, 56.0, 59.5, 2.6, m["fence"], window_face=(1, 0), lit=False)
    th.obj("ToolHouse-col", coll)
    # ---- more freight in the north of the yard, where it was bare cinders
    fr = MB()
    lumber_pile(fr, m, (-20.5, 38.0, 0.0), layers=6, length=6.0)
    lumber_pile(fr, m, (-16.2, 45.8, 0.0), layers=4, length=5.0, rz=0.35)
    tie_pile(fr, m, (-23.5, 45.0, 0.0), layers=7)
    tie_pile(fr, m, (-13.8, 40.6, 0.0), layers=5, rz=0.2)
    for k in range(4):
        wheelset(fr, m, (-19.5, 29.2 + k * 1.3, 0.0))
    dray(fr, m, (-8.2, 41.5, 0.0), 0.2)
    for x, y in ((-17.5, -7.2), (-18.3, -7.0), (-17.9, -7.8)):
        barrel(fr, m, (x, y, 0.0), h=0.85)
    fr.obj("NorthFreight-col", coll)
    # ---- the passenger platform: baggage carts, mail sacks and milk cans by the station wall
    pf = MB()
    for y in (6.0, 24.0, 40.0):
        baggage_cart(pf, m, (12.2, y, 0.62), 0.0)
        sack(pf, m, (12.2, y + 0.6, 1.25))
    for k, (x, y) in enumerate(((12.5, 13.4), (12.9, 13.7), (12.6, 14.1), (12.9, 14.4))):
        milk_can(pf, m, (x, y, 0.62))
    for x, y in ((12.4, 31.0), (12.9, 31.5), (12.2, 32.0)):
        sack(pf, m, (x, y, 0.62))
    pf.obj("PlatformFreight-col", coll)
    # ---- signboards
    sg = MB()
    sg.box((-16.02, -0.2, 4.1), (-15.94, 8.6, 4.95), m["wood"])
    sg.box((-3.2 - 1.3, -26.36, 3.35), (-3.2 + 1.3, -26.3, 3.95), m["wood"])
    sg.box((-21.0 + 0.02, -18.1, 2.35), (-20.94, -15.9, 2.7), m["wood"])
    sg.obj("Signboards", coll)
    kit.text_mesh("Sign_FreightHouse", "FREIGHT HOUSE", 0.52, (-15.9, 4.2, 4.52), (math.pi / 2, 0, math.pi / 2), m["sign"], coll, extrude=0.01, font=CINZEL)
    kit.text_mesh("Sign_Tower", "D. L. & W. R. R.", 0.3, (-3.2, -26.4, 3.65), (math.pi / 2, 0, 0), m["sign"], coll, extrude=0.008, font=CINZEL)
    kit.text_mesh("Sign_Office", "YARD OFFICE", 0.2, (-20.9, -17.0, 2.52), (math.pi / 2, 0, math.pi / 2), m["sign"], coll, extrude=0.006, font=CINZEL)


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
    g.box((-182, -60, -0.2), (-60, -8, 0.0), m["cinder"])
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
    # and three down its east edge past the station's north end, from the river landing
    for i in range(3):
        p.box((13.0 + i * 0.42, 36.0, 0.0), (13.0 + (i + 1) * 0.42, 37.6, 0.62 - (i + 1) * 0.155), m["stone"])
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
        if y in (12, 36):
            continue        # the Senator's door and the next coach's are there
        cano.boxc((7.4, y, 0.62 + 0.25), (0.5, 1.8, 0.08), m["wood"])  # benches
        cano.boxc((7.2, y, 0.62 + 0.55), (0.08, 1.8, 0.5), m["wood"])
    cano.obj("Canopy", coll)
    for i, pt in enumerate(lamp_pts):
        light(coll, "gas", i, pt)

    # the Senator's trunks, waiting by the rear of his car
    tk = MB()
    tk.boxc((12.3, 17.8, 0.62 + 0.3), (0.9, 0.55, 0.6), m["crate_dark"], rz=0.2)
    tk.boxc((12.35, 17.9, 0.62 + 0.75), (0.7, 0.45, 0.3), m["barrel"], rz=0.25)
    tk.boxc((12.5, 18.9, 0.62 + 0.25), (0.6, 0.4, 0.5), m["crate_dark"], rz=-0.3)
    tk.obj("Trunks-col", coll)
    # a porter's step box, left on the cinders under the front steps of the Senator's car
    sb = MB()
    vy = CAR_Y1 - 0.55
    sb.box((1.25, vy - 0.25, 0.0), (1.62, vy + 0.25, 0.2), m["wood"])
    sb.box((1.23, vy - 0.27, 0.2), (1.64, vy + 0.27, 0.23), m["iron"])
    sb.obj("StepBox-col", coll)

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
    s.box((-178, -36.0, 0.0), (60, -27.0, 0.03), m["cobble"])
    s.box((-178, -37.5, 0.0), (60, -36.0, 0.18), m["stone"])
    s.box((-178, -27.0, 0.0), (-29.0, -26.0, 0.18), m["stone"])   # the north walk, west of the yard
    s.obj("Street-col", coll)
    ss = MB()
    for i, x in enumerate((-20, 0, 30)):
        light(coll, "street", i, gas_lamp(ss, m, (x, -26.6, 0.0), 3.8))
    for i, x in enumerate((-166, -134, -102, -70, -44)):
        light(coll, "street", 10 + i, gas_lamp(ss, m, (x, -36.6 if i % 2 else -26.5, 0.18), 3.8))
    ss.obj("StreetLamps-col", coll)
    # the far side of River Street, west of the yard: brick fronts, a few windows still lit
    nb = MB()
    x = -178.0
    k = 0
    while x < -50.0:
        w = R.uniform(8, 12)
        h = R.uniform(8, 13)
        lit = building(nb, m, x, min(x + w - 0.2, -49.0), -25.8, -15.0, h, m["brick"] if k % 2 else m["brick_dark"], m["slate"],
                       facing=(0, -1), lit=0.22, rows=(2.4, 5.6), spacing=2.8, win_w=1.0, win_h=1.7)
        for j, pt in enumerate(lit[:1]):
            light(coll, "window", 200 + k, pt)
        x += w
        k += 1
    nb.obj("NorthFronts", coll)
    # row houses across the street
    rh = MB()
    x = -178.0
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
              (-7.2, -1.2, 1), (-8.0, 0.2, 2), (-12.8, 4.5, 1), (-15.2, 2.0, 1), (-15.2, 8.0, 2), (-10.4, 11.2, 2), (-9.6, 16.4, 1),
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
    baggage_cart(bc, m, (-8.6, 6.4, 0.0), 0.05)
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
        if abs(y + 1.0 - SIDE_GATE_Y) < 0.5:
            continue
        tp.boxc((-29.0, y + 1.0, 1.1), (0.08, 2.0, 2.2), m["fence"], rz=R.uniform(-0.02, 0.02))
    # the side gate: two posts, the leaf swung back into the alley
    for gy in (SIDE_GATE_Y - 1.0, SIDE_GATE_Y + 1.0):
        tp.box((-29.15, gy - 0.12, 0.0), (-28.85, gy + 0.12, 2.5), m["tie"])
    lf = Matrix.Rotation(-1.2, 3, "Z")
    for k in range(5):
        a = lf @ Vector((0.0, -0.1 - 0.4 * k, 0.0))
        tp.boxc((-29.0 + a.x, SIDE_GATE_Y + 1.0 + a.y, 1.0), (0.06, 0.3, 2.0), m["fence"], rz=-1.2)
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
    # the south fence, with the freight gate standing open between x -26.6 and -24.4
    wl.box((-28.6, -27.4, 0.0), (GATE[0], -27.1, 4.0), m["fence"])
    wl.box((GATE[1], -27.4, 0.0), (8.0, -27.1, 4.0), m["fence"])
    wl.box((11.0, -27.4, 0.0), (14.0, -27.1, 4.0), m["fence"])
    wl.box((13.7, -27.0, 0.0), (14.0, 78.0, 4.0), m["fence"])
    # River Street: house fronts to the south, the north walk, both ends
    wl.box((-180.0, -38.4, 0.0), (60.3, -38.1, 4.0), m["fence"])
    wl.box((-180.0, -26.0, 0.0), (-28.6, -25.7, 4.0), m["fence"])
    wl.box((26.0, -27.4, 0.0), (60.3, -27.1, 4.0), m["fence"])
    wl.box((-180.3, -38.4, 0.0), (-180.0, -25.7, 4.0), m["fence"])
    wl.box((60.0, -38.4, 0.0), (60.3, -27.1, 4.0), m["fence"])
    wl.obj("Bounds-colonly", coll)
    # the yard's south railing, the part you can see, and the gate
    rl = MB()
    for x0, x1 in ((-28.0, GATE[0]), (GATE[1], 8.0)):
        xx = x0
        while xx <= x1 + 0.01:
            rl.rod((xx, -27.25, 0.0), (xx, -27.25, 1.1), 0.03, m["iron"])
            xx += 2.0
        rl.rod((x0, -27.25, 1.05), (x1, -27.25, 1.05), 0.03, m["iron"])
        rl.rod((x0, -27.25, 0.55), (x1, -27.25, 0.55), 0.03, m["iron"])
    for gx in GATE:
        rl.box((gx - 0.18, -27.43, 0.0), (gx + 0.18, -27.07, 1.6), m["stone"])
        rl.box((gx - 0.22, -27.47, 1.6), (gx + 0.22, -27.03, 1.7), m["stone"])
    # the gate leaf, swung back into the yard
    for k in range(6):
        rl.rod((GATE[0] + 0.1, -27.2 + 0.28 * k, 0.1), (GATE[0] + 0.1, -27.2 + 0.28 * k, 1.35), 0.02, m["iron"])
    for zz in (0.15, 0.75, 1.3):
        rl.rod((GATE[0] + 0.1, -27.2, zz), (GATE[0] + 0.1, -25.8, zz), 0.025, m["iron"])
    rl.obj("Railing", coll)
    sg = MB()
    sg.quad([(GATE[0] - 0.2, -27.48, 1.72), (GATE[1] + 0.2, -27.48, 1.72), (GATE[1] + 0.2, -27.48, 2.12), (GATE[0] - 0.2, -27.48, 2.12)], m["wood"])
    sg.obj("GateBoard", coll)

    # ---------------- places to hide and to climb
    hd = MB()
    # a freight wagon under a canvas tarp, low enough to crawl under; you can see the platform from there
    tx, ty = -7.2, -16.8
    hd.box((tx - 1.1, ty - 1.8, 0.75), (tx + 1.1, ty + 1.8, 0.85), m["wood"])
    for wx in (-0.9, 0.9):
        for wy in (-1.3, 1.3):
            hd.cyl((tx + wx, ty + wy, 0.38), 0.38, 0.38, 0.08, m["iron"], seg=12, rot=Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Translation((0, 0, -0.04)))
    hd.box((tx - 1.0, ty - 1.6, 0.85), (tx + 0.6, ty + 1.2, 1.6), m["crate_dark"])
    for pts in ([(tx - 1.25, ty - 1.9, 0.3), (tx - 1.25, ty + 1.9, 0.3), (tx - 0.2, ty + 1.9, 1.95), (tx - 0.2, ty - 1.9, 1.95)],
                [(tx - 0.2, ty - 1.9, 1.95), (tx - 0.2, ty + 1.9, 1.95), (tx + 1.25, ty + 1.9, 0.9), (tx + 1.25, ty - 1.9, 0.9)]):
        hd.quad(pts, m["canvas"])
        hd.quad(pts[::-1], m["canvas"])   # both sides, so it's still canvas when you're under it
    hd.obj("TarpWagon", coll)
    # an empty boxcar, its west door rolled open: somewhere to wait while the lantern goes by
    ebc = MB()
    y0, y1, X = -6.0, 5.8, TRACK_A
    ebc.box((X - 1.4, y0 + 0.2, 1.0), (X + 1.4, y1 - 0.2, 1.35), m["t_iron"])
    ebc.box((X - 1.35, y0, 1.35), (X + 1.35, y1, 1.45), m["wood"])
    ebc.box((X - 1.35, y0, 4.1), (X + 1.35, y1, 4.25), m["roof"])
    ebc.box((X - 1.35, y0, 1.45), (X + 1.35, y0 + 0.08, 4.1), m["boxcar"])
    ebc.box((X - 1.35, y1 - 0.08, 1.45), (X + 1.35, y1, 4.1), m["boxcar"])
    ebc.box((X + 1.27, y0, 1.45), (X + 1.35, y1, 4.1), m["boxcar"])
    mid = (y0 + y1) / 2
    ebc.box((X - 1.35, y0, 1.45), (X - 1.27, mid - 1.0, 4.1), m["boxcar"])
    ebc.box((X - 1.35, mid + 1.0, 1.45), (X - 1.27, y1, 4.1), m["boxcar"])
    ebc.box((X - 1.35, mid - 1.0, 3.6), (X - 1.27, mid + 1.0, 4.1), m["boxcar"])
    ebc.box((X - 1.43, mid + 1.0, 1.5), (X - 1.37, mid + 3.0, 3.6), m["crate_dark"])   # the door, rolled back
    for yy in (y0 + 2.2, y1 - 2.2):
        truck(ebc, m, X, yy)
    ebc.obj("EmptyBoxcar-col", coll)
    ld = MB()
    for i, yb in enumerate((y0, 14.0, 26.4, 39.0)):
        # an iron ladder up the south end of each boxcar, by the west corner
        for sx in (-5.25, -4.85):
            ld.rod((sx, yb - 0.1, 1.0), (sx, yb - 0.1, 4.3), 0.02, m["iron"])
        zz = 1.2
        while zz < 4.25:
            ld.rod((-5.25, yb - 0.1, zz), (-4.85, yb - 0.1, zz), 0.016, m["iron"])
            zz += 0.35
        mark(coll, "MARK_ladder_%d_bottom" % i, (-5.05, yb - 0.75, 0.0), 0.0)
        mark(coll, "MARK_ladder_%d_top" % i, (-4.4, yb + 0.9, 4.25), 0.0)
    ld.obj("Ladders", coll)
    # more freight to hide behind: crates, cases and barrels scattered on the yard's west side
    mc = MB()
    extra = [(-8.9, -24.9, 1), (-18.2, -17.6, 2), (-12.6, -23.8, 1), (-6.9, -23.2, 1), (-0.9, -23.4, 1), (1.45, -17.6, 2),
             (-8.6, -3.4, 1), (-12.9, 0.3, 2), (-7.9, 4.2, 1), (-17.8, 21.6, 1), (-8.4, 22.4, 2), (-10.6, 28.0, 1),
             (-6.4, 31.6, 2), (-13.0, 34.6, 1), (-7.4, -8.4, 1), (-12.6, -17.8, 1)]
    for x, y, n in extra:
        rz = R.uniform(-0.4, 0.4)
        z = 0.0
        for k in range(n):
            sz = R.uniform(0.95, 1.3)
            crate(mc, m, (x + R.uniform(-0.12, 0.12), y + R.uniform(-0.12, 0.12), z), (sz * R.uniform(0.9, 1.4), sz, sz * 0.9), rz + R.uniform(-0.15, 0.15))
            z += sz * 0.9
    # a two-high stack of plain cases you can climb, with something useful on top
    crate(mc, m, (-9.4, 29.2, 0.0), (1.15, 1.15, 1.0), 0.1)
    crate(mc, m, (-9.4, 29.2, 1.0), (1.0, 1.0, 0.9), 0.25)
    mark(coll, "MARK_stones_0", (-9.4, 29.2, 1.9))
    mark(coll, "MARK_stones_1", (-4.0, 3.2, 4.25))
    for cx, cy in ((-9.6, -18.8), (-1.0, -25.2), (-12.2, 8.6), (-7.2, 26.2), (-14.4, -16.4)):
        for k in range(R.randint(3, 5)):
            barrel(mc, m, (cx + R.uniform(-0.8, 0.8), cy + R.uniform(-0.8, 0.8), 0.0))
    mc.obj("MoreFreight-col", coll)

    # ---------------- a switchman's tower at the south end of the yard: a watchman stands up there
    tw = MB()
    TX, TY, TH = -3.2, -25.2, 4.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            tw.box((TX + sx * 1.0 - 0.1, TY + sy * 1.0 - 0.1, 0.0), (TX + sx * 1.0 + 0.1, TY + sy * 1.0 + 0.1, TH), m["wood"])
    for zz in (1.4, 2.9):
        tw.box((TX - 1.1, TY - 1.05, zz), (TX + 1.1, TY - 0.95, zz + 0.12), m["wood"])
        tw.box((TX - 1.1, TY + 0.95, zz), (TX + 1.1, TY + 1.05, zz + 0.12), m["wood"])
    tw.box((TX - 1.4, TY - 1.4, TH), (TX + 1.4, TY + 1.4, TH + 0.12), m["wood"])            # the floor up top
    for (a, b) in (((TX - 1.4, TY - 1.4), (TX + 1.4, TY - 1.32)), ((TX - 1.4, TY + 1.32), (TX + 1.4, TY + 1.4)),
                   ((TX - 1.4, TY - 1.4), (TX - 1.32, TY + 1.4)), ((TX + 1.32, TY - 1.4), (TX + 1.4, TY + 1.4))):
        tw.box((a[0], a[1], TH + 0.12), (b[0], b[1], TH + 1.05), m["wood"])                # waist-high walls
    for sx in (-1, 1):
        for sy in (-1, 1):
            tw.rod((TX + sx * 1.35, TY + sy * 1.35, TH + 1.05), (TX + sx * 1.35, TY + sy * 1.35, TH + 2.4), 0.05, m["wood"])
    tw.lathe((TX, TY, TH + 2.4), [(2.1, 0.0), (0.15, 0.9)], m["tin"], seg=4)
    for k in range(12):
        tw.rod((TX + 1.2, TY - 1.6, 0.35 * k + 0.2), (TX + 0.8, TY - 1.6, 0.35 * k + 0.2), 0.02, m["iron"])
    tw.obj("SwitchTower-col", coll)
    light(coll, "lantern", 7, (TX + 1.2, TY + 1.2, TH + 1.6))
    mark(coll, "MARK_perch_tower", (TX, TY, TH + 0.12), 0.0)
    # and the freight shed's flat roof
    mark(coll, "MARK_perch_shed", (-16.7, 4.0, 6.1), -math.pi / 2)

    # ---------------- the four ways the seven come (the owner drew them): each ends at one of the two doors
    # in the Senator's car's south vestibule, the lane side (west) or the platform side (east)
    dy = CAR_Y0 + 0.55                       # the middle of the south vestibule's doorways
    ways = {
        # through the side gate in the west fence, past the freight house's north end, over the planks
        "fence": [(-28.0, SIDE_GATE_Y, 0.0), (-26.2, SIDE_GATE_Y - 0.5, 0.0), (-22.8, 18.0, 0.0), (-19.2, 16.5, 0.0),
                  (-15.6, 15.4, 0.0), (-12.0, 14.0, 0.0), (-7.2, 12.2, 0.0), (-4.0, 12.2, 0.0), (-0.9, 12.2, 0.0),
                  (0.5, dy, 0.0)],
        # in at the freight gate, along the gravel walk, over the planks and up the lane between the tracks
        "gate": [(-25.5, -29.0, 0.0), (-25.4, -24.2, 0.0), (-16.0, -22.5, 0.0), (-7.2, -19.9, 0.0), (-4.0, -19.8, 0.0),
                 (-0.6, -19.5, 0.0), (0.0, -17.0, 0.0), (0.0, dy - 1.4, 0.0), (0.5, dy, 0.0)],
        # up the stairs from the river landing past the station's north end, then down the platform
        "north": [(15.2, 36.8, 0.0), (13.3, 36.8, 0.62), (10.8, 34.5, 0.62), (10.8, 16.4, 0.62), (6.9, dy, 0.62)],
        # off a motor cab on River Street, up the platform's steps and along it
        "street": [(9.9, -29.4, 0.0), (9.5, -28.4, 0.0), (9.5, -21.6, 0.62), (10.9, -19.5, 0.62), (10.9, 10.0, 0.62), (6.9, dy, 0.62)],
    }
    for way, pts in ways.items():
        for i, pt in enumerate(pts):
            mark(coll, "MARK_way_%s_%d" % (way, i), pt)
    # up the car's steps and in (tread tops: side_steps), the lane side and the platform side
    for i, (xx, zz) in enumerate(((1.82, 0.44), (2.02, 0.78), (2.22, 1.12), (2.42, 1.46), (2.75, 1.8), (3.5, 1.8))):
        mark(coll, "MARK_door_w_%d" % i, (xx, dy, zz))
    for i, (xx, zz) in enumerate(((6.4, 0.62), (6.0, 0.78), (5.8, 1.12), (5.58, 1.46), (5.25, 1.8), (4.5, 1.8))):
        mark(coll, "MARK_door_e_%d" % i, (xx, dy, zz))
    # the lookalike travelers: out of the station's side door or up from the street, along the platform
    # between the benches and the lamp columns, and into an ordinary coach (the back one or the one ahead)
    for i, (xx, yy) in enumerate(((13.3, -3.6), (8.6, 3.0), (7.0, CAR_Y0 - 20.75), (8.6, 24.0), (7.0, CAR_Y1 + 0.85),
                                  (8.6, -19.0), (8.6, CAR_Y0 - 20.75), (8.6, CAR_Y1 + 0.85))):
        mark(coll, "MARK_traveler_%d" % i, (xx, yy, 0.62))
    # a few more corners for the watchmen to clear
    for i, (sx, sy) in enumerate(((-27.4, -26.4), (-27.4, 20.0), (-27.2, 50.0), (-20.0, 70.0), (0.5, 66.0), (-10.0, 46.0),
                                  (-14.6, -1.0), (-18.5, -14.0), (-26.0, -10.0), (1.4, 40.0))):
        mark(coll, "MARK_spot_%d" % (31 + i), (sx, sy, 0.0))
    # the freight shed's dark doorway on the loading dock
    dd = MB()
    dd.box((-16.06, 3.0, 1.1), (-15.98, 5.4, 3.6), m["glass_dark"])
    dd.obj("ShedDoorway", coll)
    mark(coll, "MARK_hide_tarp", (tx - 0.1, ty, 0.0), -math.pi / 2)
    mark(coll, "MARK_hide_tarp_out", (tx - 2.0, ty - 0.4, 0.0), -math.pi / 2)
    mark(coll, "MARK_hide_boxcar", (X - 0.4, mid, 1.45), -math.pi / 2)
    mark(coll, "MARK_hide_boxcar_out", (X - 2.4, mid, 0.0), -math.pi / 2)
    mark(coll, "MARK_hide_shed", (-15.7, 4.2, 1.1), -math.pi / 2)
    mark(coll, "MARK_hide_shed_out", (-14.2, 4.2, 0.0), -math.pi / 2)
    # where the watchmen may go: spread over the yard; the game picks among these at random
    spots = [(-20, -24), (-10, -24), (0, -24), (3, -19), (-3, -16), (-11.5, -20), (-12.5, -12), (-11, -3), (-12.5, 5), (-11.5, 12),
             (-9, 17), (-10, 24), (-1.8, -10), (-1.5, 0), (-1.5, 10), (-1.5, 20), (-1.5, 32), (-6.4, -12), (-6.8, 8), (-6.6, 20),
             (-6.6, 34), (0.9, -15), (0.9, -3), (0.9, 12), (0.9, 28), (-14.2, -5), (-14.2, 12), (-8, 30), (-1.5, 56), (8.2, -18), (9.4, -4)]
    for i, (sx, sy) in enumerate(spots):
        mark(coll, "MARK_spot_%d" % i, (sx, sy, 0.0))
    # River Street: where the night starts, Jekyll and his motorcar, the gate, where to leave the car
    mark(coll, "MARK_street_start", (-160.0, -33.2, 0.0), -math.pi / 2)
    mark(coll, "MARK_jekyll", (-153.2, -28.4, 0.18), math.pi * 0.8)
    mark(coll, "MARK_jcar", (-150.0, -30.4, 0.03), -math.pi / 2)
    mark(coll, "MARK_cam_jekyll", (-156.5, -32.6, 1.75))
    mark(coll, "MARK_cam_jekyll_look", (-153.0, -28.6, 1.5))
    mark(coll, "MARK_park", (-21.0, -30.6, 0.03), -math.pi / 2)
    mark(coll, "MARK_gate_out", (-25.5, -29.0, 0.0), 0.0)
    mark(coll, "MARK_gate_in", (-25.5, -25.0, 0.0), 0.0)

    # ---------------- where things happen
    mark(coll, "MARK_player_start", (-14.2, -21.0, 0.0), 0.0)
    mark(coll, "MARK_cam_watch", (-8.6, -17.2, 1.3))
    mark(coll, "MARK_cam_watch_look", (4.0, CAR_Y0 + 0.55, 2.2))
    mark(coll, "MARK_cam_wide", (-2.0, -40.0, 9.0))
    mark(coll, "MARK_cam_wide_look", (4.0, -5.0, 1.5))
    mark(coll, "MARK_cab_in", (46.0, -31.5, 0.03), math.pi / 2)
    mark(coll, "MARK_cab_stop", (9.5, -30.3, 0.03), math.pi / 2)
    mark(coll, "MARK_cab_out", (-46.0, -31.5, 0.03), math.pi / 2)
    mark(coll, "MARK_step_bottom", (9.5, -28.4, 0.0))
    mark(coll, "MARK_step_top", (9.5, -21.6, 0.62))
    mark(coll, "MARK_porter", (7.6, CAR_Y0 + 2.3, 0.62), -math.pi / 2)
    # the player's way in: the step box, the four steps of the dark north vestibule, and in at its west door
    vy = CAR_Y1 - 0.55
    mark(coll, "MARK_vestibule", (1.0, vy, 0.0))
    for i, (xx, zz) in enumerate(((0.95, 0.0), (1.44, 0.22), (1.82, 0.44), (2.02, 0.78), (2.22, 1.12), (2.42, 1.46), (2.75, 1.8), (3.3, 1.8))):
        mark(coll, "MARK_board_%d" % i, (xx, vy, zz))
    mark(coll, "MARK_steps_marker", (2.0, vy, 2.7))
    mark(coll, "MARK_cam_board", (-1.6, vy - 3.4, 1.7))
    mark(coll, "MARK_cam_board_look", (2.4, vy + 0.1, 1.3))
    mark(coll, "MARK_cam_rear", (9.6, CAR_Y0 + 5.0, 2.6))
    mark(coll, "MARK_cam_rear_look", (5.0, CAR_Y0 + 0.55, 2.2))
    # the yard detective walks the lane between the tracks
    for i, pt in enumerate(((-2.2, -23.0), (-2.2, -8.0), (-1.9, 6.0), (-2.2, 12.5), (-2.2, -2.0), (-2.4, -16.0))):
        mark(coll, "MARK_detective_%d" % i, (pt[0], pt[1], 0.3))
    # the brakeman walks the train, north to the engine and back, clear of the car steps
    for i, pt in enumerate(((0.8, 44.0), (0.8, 30.0), (0.8, 16.0), (0.8, 2.0), (0.8, -6.0), (0.8, 10.0), (0.8, 26.0))):
        mark(coll, "MARK_brakeman_%d" % i, (pt[0], pt[1], 0.3))
    # the night watchman keeps to the east edge of the crate lane, a few steps off the way through it
    for i, pt in enumerate(((-5.9, -18.0), (-5.4, -8.0), (-5.4, -2.0), (-5.8, 6.0))):
        mark(coll, "MARK_watchman_%d" % i, (pt[0], pt[1], 0.3))
    # the conductor paces the ground south of the Senator's car
    for i, pt in enumerate(((1.6, -14.8), (-0.6, -17.2), (1.8, -19.6), (3.2, -17.0))):
        mark(coll, "MARK_conductor_%d" % i, (pt[0], pt[1], 0.3))
    yard_more(coll, m)
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


def side_steps(mb, m, x, side, ya, yb, n, hw=1.5):
    """Car steps down one side: n iron treads, each a riser lower and a little farther out than the one above."""
    for s in range(n):
        top = FLOOR - STEP_RISE * (s + 1)
        d_out = 0.24 + 0.2 * s
        xo, xi = x + side * (hw + d_out), x + side * (hw + d_out - 0.32)
        mb.box((min(xo, xi), ya, top - 0.05), (max(xo, xi), yb, top), m["t_iron"])
    bottom = FLOOR - STEP_RISE * n - 0.05
    for yy in (ya + 0.02, yb - 0.02):
        mb.rod((x + side * (hw - 0.02), yy, FLOOR - 0.05), (x + side * (hw + 0.24 + 0.2 * (n - 1)), yy, bottom), 0.02, m["t_iron"])


def vestibule_door(mb, m, xo, side, ya, yb):
    """A closed vestibule door: black, with a dark glass light in its upper half."""
    xs = (min(xo, xo - side * 0.05), max(xo, xo - side * 0.05))
    mb.box((xs[0], ya, FLOOR), (xs[1], yb, FLOOR + DOOR_H), m["black"])
    mb.box((xs[0] - 0.005, ya + 0.12, FLOOR + 1.1), (xs[1] + 0.005, yb - 0.12, FLOOR + 1.85), m["t_glass"])


def car(mb, m, y0, y1, paint, windows, x=TRACK_B, observation=False, name_lights=None, coll=None, tag="car", door_west=False,
        open_doors=(), brass=False):
    """A passenger car body from y0 (south) to y1 (north). open_doors names the vestibule doors left out of the
    mesh so the game can swing them, as ("n" or "s", -1 west or 1 east); door_west is ("n", -1).
    See swing_doors."""
    open_doors = set(open_doors) | ({("n", -1)} if door_west else set())
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
        mb.box((x - hw - 0.03, body_y0, zz), (x + hw + 0.03, body_y1, zz + 0.07), m["t_brass"] if (observation or brass) else m["black"])
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
    # vestibules: hollow, a door each side, real steps down to the ground
    ends = [(body_y1, y1)] + ([] if observation else [(y0, body_y0)])
    for a, b in ends:
        vx0, vx1 = x - hw + 0.05, x + hw - 0.05
        mb.box((vx0, a, z0 - 0.06), (vx1, b, z0), m["t_iron"])                    # floor
        mb.box((vx0, a, z1 - 0.12), (vx1, b, z1), m["black"])                      # ceiling
        mb.box((x - hw - 0.05, a, z1 - 0.05), (x + hw + 0.05, b, z1 + 0.25), m["roof"])
        for side in (-1, 1):
            xo = x + side * hw
            xs = (min(xo, xo - side * 0.06), max(xo, xo - side * 0.06))
            # posts either side of the door, and the header over it
            mb.box((xs[0], a, z0), (xs[1], a + 0.12, z1 - 0.12), m["black"])
            mb.box((xs[0], b - 0.12, z0), (xs[1], b, z1 - 0.12), m["black"])
            mb.box((xs[0], a + 0.12, z0 + DOOR_H), (xs[1], b - 0.12, z1 - 0.12), m["black"])
            if ("n" if b == y1 else "s", side) not in open_doors:
                vestibule_door(mb, m, xo, side, a + 0.12, b - 0.12)
            side_steps(mb, m, x, side, a + 0.15, b - 0.15, 3 if side > 0 else 4, hw)
        # the far end: panels either side of the diaphragm
        yy = b if b == y1 else a
        yw = (yy - 0.05, yy) if b == y1 else (yy, yy + 0.05)
        mb.box((vx0, yw[0], z0), (x - 1.0, yw[1], z1 - 0.12), m["black"])
        mb.box((x + 1.0, yw[0], z0), (vx1, yw[1], z1 - 0.12), m["black"])
        # diaphragm (the canvas bellows between cars)
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
            side_steps(mb, m, x, side, py0 + 0.5, py1 - 0.1, 3 if side > 0 else 4, hw)
        # awning over the platform
        mb.box((x - hw - 0.05, py0 - 0.1, z1 - 0.05), (x + hw + 0.05, py1, z1 + 0.1), m["roof"])
        for side in (-1, 1):
            mb.rod((x + side * (hw - 0.05), py0 + 0.05, z0 + 1.03), (x + side * (hw - 0.05), py0 + 0.05, z1 - 0.05), 0.02, m["t_brass"])
            mb.boxc((x + side * (hw - 0.02), py0 - 0.02, z0 + 1.3), (0.16, 0.16, 0.22), m["red_lamp"])
        # the rear doorway, lit from inside; the door itself is its own object (it opens)
        mb.quad([(x - 0.4, y0 - 0.004, z0), (x + 0.4, y0 - 0.004, z0), (x + 0.4, y0 - 0.004, z0 + DOOR_H), (x - 0.4, y0 - 0.004, z0 + DOOR_H)], m["window_lit"])
        mb.box((x - 0.5, y0 - 0.06, z0), (x - 0.4, y0, z0 + DOOR_H + 0.1), m["maroon"])
        mb.box((x + 0.4, y0 - 0.06, z0), (x + 0.5, y0, z0 + DOOR_H + 0.1), m["maroon"])
        mb.box((x - 0.5, y0 - 0.06, z0 + DOOR_H), (x + 0.5, y0, z0 + DOOR_H + 0.1), m["maroon"])
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


def swing_doors(coll, m, x, y0, y1, hw=1.5):
    """The doors of the Senator's car that the game swings open, each hinged so turning it about Z opens it
    inward: EntryDoorW and EntryDoorE, both sides of the south vestibule, where the seven go in (hinged on
    their south edges), and FrontDoor, the west door of the north vestibule, your way in (hinged on its
    north edge)."""
    wdt = 1.1 - 0.24
    for name, side in (("EntryDoorW", -1), ("EntryDoorE", 1)):
        ed = MB()
        t = -side * 0.05
        ed.box((min(0.0, t), 0.0, 0.0), (max(0.0, t), wdt, DOOR_H), m["black"])
        ed.box((min(0.0, t) - 0.005, 0.12, 1.1), (max(0.0, t) + 0.005, wdt - 0.12, 1.85), m["blinds"])
        ed.sphere((side * 0.035, wdt - 0.1, 1.0), 0.03, m["t_brass"], sub=1)
        ed.obj(name, coll, loc=(x + side * hw, y0 + 0.12, FLOOR))
    fd = MB()
    fd.box((0.0, -wdt, 0.0), (0.05, 0.0, DOOR_H), m["black"])
    fd.box((-0.005, -wdt + 0.12, 1.1), (0.055, -0.12, 1.85), m["t_glass"])
    fd.sphere((-0.035, -wdt + 0.1, 1.0), 0.03, m["t_brass"], sub=1)
    fd.obj("FrontDoor", coll, loc=(x - hw, y1 - 0.12, FLOOR))


def train():
    sc = kit.new_scene("Hoboken_Train")
    coll = sc.collection
    m = M()
    # from the back: an ordinary coach, the Senator's car (the seven go in at its south end, both sides; you
    # at its dark north end), another coach, the tender and the engine
    c1 = MB()
    car(c1, m, CAR_Y0 - 21.3, CAR_Y0 - 0.3, m["green"], m["coach_win"])
    for side in (-1, 1):       # red marker lamps on the last car
        c1.boxc((TRACK_B + side * 1.48, CAR_Y0 - 21.32, FLOOR + 1.3), (0.16, 0.16, 0.22), m["red_lamp"])
        light(coll, "red", 0 if side < 0 else 1, (TRACK_B + side * 1.48, CAR_Y0 - 21.6, FLOOR + 1.3))
    c1.obj("Coach1-col", coll)
    pc = MB()
    car(pc, m, CAR_Y0, CAR_Y1, m["maroon"], m["blinds"], brass=True, open_doors=(("n", -1), ("s", -1), ("s", 1)))
    pc.obj("PrivateCar-col", coll)
    swing_doors(coll, m, TRACK_B, CAR_Y0, CAR_Y1)
    c2 = MB()
    car(c2, m, CAR_Y1 + 0.3, CAR_Y1 + 21.3, m["green"], m["t_glass"])
    c2.obj("Coach2-col", coll)
    lo = MB()
    ty0 = CAR_Y1 + 21.6
    tender(lo, m, ty0, ty0 + 8.1)
    ly0 = ty0 + 8.4
    head, stack = locomotive(lo, m, ly0)
    lo.obj("Engine-col", coll)
    light(coll, "headlamp", 0, (head[0], head[1] + 0.4, head[2]))
    light(coll, "firebox", 0, (TRACK_B, ly0 + 1.3, 3.0))
    mark(coll, "MARK_stack", stack)
    mark(coll, "MARK_cylinder_L", (TRACK_B - 1.4, ly0 + 12.9, 1.3))
    mark(coll, "MARK_cylinder_R", (TRACK_B + 1.4, ly0 + 12.9, 1.3))
    # warm light behind the Senator's blinds, and the dim coaches either side
    for i, k in enumerate((2.5, 7.0, 11.5, 16.0)):
        light(coll, "blinds", i, (TRACK_B, CAR_Y0 + k, FLOOR + 1.7))
    light(coll, "coach", 0, (TRACK_B, CAR_Y0 - 10.0, FLOOR + 1.8))
    light(coll, "coach", 1, (TRACK_B, CAR_Y1 + 11.0, FLOOR + 1.8))
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
    # Arthur's valise on the lounge desk, and where you stand to get the papers under the lamp
    mark(coll, "MARK_valise", (1.25, 8.9, 0.0))
    mark(coll, "MARK_desk_stand", (0.62, 8.85, 0.0), -math.pi / 2)
    mark(coll, "MARK_pc_reset", (0.0, -7.9, 0.0), 0.0)
    # the real steward's round: galley, up the corridor, through the dining room to the lounge and back
    for i, pt in enumerate(((0.0, -8.4), (1.0, -5.0), (1.08, 0.3), (1.25, 4.5), (0.55, 5.6), (0.55, 7.7))):
        mark(coll, "MARK_stew_%d" % i, (pt[0], pt[1], 0.0))
    mark(coll, "MARK_cam_lounge", (-0.9, 5.4, 1.9))
    mark(coll, "MARK_cam_lounge_look", (1.0, 8.6, 0.9))
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
    mark(coll, "MARK_draft", (1.4, -0.36, 0.8))
    # what's worth a photograph once the room empties out
    mark(coll, "MARK_chalk_spot", (-4.6, 0.0, 0.0), math.pi / 2)
    mark(coll, "MARK_notes_paul", (-1.4, 0.36, 0.8))
    mark(coll, "MARK_notes_abe", (-1.4, -0.36, 0.8))
    mark(coll, "MARK_arthur_window", (4.75, -0.2, 0.0), -math.pi / 2)
    mark(coll, "MARK_mt_door", (-3.5, -3.25, 0.0))
    mark(coll, "MARK_mt_out", (-3.5, -4.8, 0.0))
    mark(coll, "MARK_cam_door", (-1.2, -2.6, 2.0))
    mark(coll, "MARK_cam_door_look", (-3.6, -3.4, 1.2))
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
