"""The three rooms off the Grand Lobby: the Honey House, the Drafting Room, the Trading Floor.

    python tools/blender/build_rooms.py                  # all three
    python tools/blender/build_rooms.py honey drafting   # some

Each room's door is on its south wall; you walk in facing north (+Y).
Objects named HiveLid and HiveFrame are animated by the game. LIGHT_ and MARK_ empties
work as in build_1910.py.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402
from build_1910 import chair, light, mark  # noqa: E402
from kit import MB, mat, text_mesh  # noqa: E402

TEX = os.path.join(kit.ROOT, "godot", "textures")
CINZEL = os.path.join(kit.ROOT, "tools", "fonts", "Cinzel-Bold.woff")


def pic(mb, center, w, h, facing, m):
    """A flat picture facing +/-X or +/-Y with UVs 0..1."""
    c = Vector(center)
    n = Vector((facing[0], facing[1], 0))
    up = Vector((0, 0, 1))
    # the picture's right-hand edge, as seen by someone standing in front of it
    ax = up.cross(n)
    pts = [c - ax * w / 2 - up * h / 2, c + ax * w / 2 - up * h / 2, c + ax * w / 2 + up * h / 2, c - ax * w / 2 + up * h / 2]
    mb.quad(pts, m, uv=[(0, 0), (1, 0), (1, 1), (0, 1)])


def frame_box(mb, center, w, h, facing, m, border=0.08, depth=0.05):
    """A picture frame around a w x h opening on a wall facing +/-X or +/-Y."""
    c = Vector(center)
    n = Vector((facing[0], facing[1], 0))
    back = c - n * depth / 2
    along_x = abs(facing[0]) > 0.5   # frame lies in the Y-Z plane
    for s in (-1, 1):
        if along_x:
            mb.boxc(back + Vector((0, s * (w / 2 + border / 2), 0)), (depth, border, h + 2 * border), m)
            mb.boxc(back + Vector((0, 0, s * (h / 2 + border / 2))), (depth, w + 2 * border, border), m)
        else:
            mb.boxc(back + Vector((s * (w / 2 + border / 2), 0, 0)), (border, depth, h + 2 * border), m)
            mb.boxc(back + Vector((0, 0, s * (h / 2 + border / 2))), (w + 2 * border, depth, border), m)


def room_shell(mb, m_wall, m_floor, m_ceiling, W, D, H, door_w=1.4, door_h=2.3, north_gap=None, wainscot=None):
    mb.box((-W - 0.2, -D - 0.2, -0.12), (W + 0.2, D + 0.2, 0.0), m_floor)
    if m_ceiling:
        mb.box((-W - 0.2, -D - 0.2, H), (W + 0.2, D + 0.2, H + 0.12), m_ceiling)
    mb.box((-W - 0.2, -D - 0.2, 0.0), (-door_w / 2, -D, H), m_wall)
    mb.box((door_w / 2, -D - 0.2, 0.0), (W + 0.2, -D, H), m_wall)
    mb.box((-door_w / 2, -D - 0.2, door_h), (door_w / 2, -D, H), m_wall)
    mb.box((-W - 0.2, -D, 0.0), (-W, D, H), m_wall)
    mb.box((W, -D, 0.0), (W + 0.2, D, H), m_wall)
    if north_gap:
        a, b, gh = north_gap
        mb.box((-W - 0.2, D, 0.0), (a, D + 0.2, H), m_wall)
        mb.box((b, D, 0.0), (W + 0.2, D + 0.2, H), m_wall)
        mb.box((a, D, gh), (b, D + 0.2, H), m_wall)
    else:
        mb.box((-W - 0.2, D, 0.0), (W + 0.2, D + 0.2, H), m_wall)
    if wainscot:
        for (p0, p1) in (((-W, -D), (-door_w / 2, -D + 0.04)), ((door_w / 2, -D), (W, -D + 0.04)), ((-W, D - 0.04), (W, D)),
                         ((-W, -D), (-W + 0.04, D)), ((W - 0.04, -D), (W, D))):
            mb.box((p0[0], p0[1], 0.0), (p1[0], p1[1], 1.05), wainscot)
            mb.box((p0[0] - 0.02, p0[1] - 0.02, 1.05), (p1[0] + 0.02, p1[1] + 0.02, 1.11), wainscot)
            mb.box((p0[0] - 0.03, p0[1] - 0.03, H - 0.16), (p1[0] + 0.03, p1[1] + 0.03, H), wainscot)


def door_frame(mb, m, door_w=1.4, door_h=2.3, D=4.0):
    for s in (-1, 1):
        mb.box((s * door_w / 2 - 0.08, -D - 0.25, 0.0), (s * door_w / 2 + 0.08, -D + 0.05, door_h + 0.1), m)
    mb.box((-door_w / 2 - 0.12, -D - 0.25, door_h), (door_w / 2 + 0.12, -D + 0.05, door_h + 0.18), m)


# ================================================================== the Honey House
def honey():
    sc = kit.new_scene("Honey_House")
    coll = sc.collection
    m = {
        "planks": mat("HY_Planks", "#6a4a2c", 0.8),
        "floor": mat("HY_Floor", "#5a3a20", 0.7),
        "porch": mat("HY_Porch", "#6a6050", 0.85),
        "beam": mat("HY_Beam", "#4a3420", 0.85),
        "tin": mat("HY_Tin", "#5a5a58", 0.6, 0.5),
        "hive": mat("HY_HiveWhite", "#e8e2d2", 0.7),
        "hive_top": mat("HY_HiveTop", "#8a8a88", 0.4, 0.8),
        "comb": mat("HY_Comb", "#d89a30", 0.4),
        "honey": mat("HY_Honey", "#c8741a", 0.08, 0.0, "#c06010", 0.35, alpha=0.9),
        "lid": mat("HY_Lid", "#b8903e", 0.3, 0.9),
        "label": kit.img_mat("HY_Label", os.path.join(kit.ROOT, "art", "textures", "honey_label.jpg"), 0.8),
        "logo": kit.img_mat("HY_Logo", os.path.join(TEX, "bees_logo.png"), 0.8),
        "sky": kit.img_mat("HY_Sky", os.path.join(TEX, "farm_dusk.png"), 0.9, emit=1.2),
        "clip": kit.img_mat("HY_Clipboard", os.path.join(TEX, "clipboard_bees.png"), 0.9),
        "screen": mat("HY_Screen", "#101010", 0.9, 0.0, None, 0.0, alpha=0.35),
        "steel": mat("HY_Steel", "#a8a8a4", 0.35, 0.9),
        "amber": mat("HY_AmberGlass", "#e09030", 0.2, 0.0, "#e08020", 1.6),
        "lantern": mat("HY_Lantern", "#ffc070", 0.3, 0.0, "#ffb050", 3.0),
        "iron": mat("HY_Iron", "#1c1a18", 0.5, 0.6),
        "block": mat("HY_Block", "#8a867c", 0.9),
        "veil": mat("HY_Veil", "#ecebe4", 0.9),
        "straw": mat("HY_Straw", "#c8a860", 0.9),
        "ground": mat("HY_Ground", "#2a2616", 0.95),
    }
    W, D, H = 5.0, 4.0, 3.0
    s = MB()
    room_shell(s, m["planks"], m["floor"], None, W, D, H, north_gap=(-2.6, 2.6, 2.6))
    # a steep gable roof you can see up into, rafters and tie beams showing
    ridge = 4.4
    slope = math.atan2(ridge - H, W)
    half = math.hypot(W + 0.3, ridge - H) / 2
    for side in (-1, 1):
        cx = side * (W + 0.3) / 2
        cz = (H + ridge) / 2 - 0.05
        s.boxc((cx, (D + 3.3 - D - 0.3) / 2, cz), (2 * half, D * 2 + 3.6, 0.06), m["planks"], ry=-side * slope)
        s.boxc((cx, (D + 3.3 - D - 0.3) / 2, cz + 0.07), (2 * half + 0.1, D * 2 + 3.7, 0.03), m["tin"], ry=-side * slope)
    for yy in (-D - 0.2, D):
        s.box((-W, yy, H), (W, yy + 0.2, ridge), m["planks"])
    y = -D + 0.3
    while y < D + 3.2:
        for side in (-1, 1):
            s.rod((side * W, y, H - 0.05), (0.0, y, ridge - 0.05), 0.07, m["beam"])
        y += 1.1
    for yy in (-2.0, 0.6, 3.2):
        s.box((-W, yy - 0.1, H - 0.15), (W, yy + 0.1, H + 0.05), m["beam"])
    s.box((-0.1, -D, ridge - 0.25), (0.1, D + 3.3, ridge - 0.05), m["beam"])
    # vertical battens on the walls
    for x in [-W + 0.02, W - 0.02]:
        yy = -D + 0.3
        while yy < D:
            s.box((x - 0.03, yy - 0.03, 0.0), (x + 0.03, yy + 0.03, H), m["beam"])
            yy += 0.6
    # the amber window on the east wall
    s.box((W - 0.05, -0.6, 1.1), (W + 0.05, 0.6, 2.2), m["amber"])
    for zz in (1.1, 1.65, 2.2):
        s.box((W - 0.08, -0.65, zz - 0.03), (W + 0.02, 0.65, zz + 0.03), m["beam"])
    for yy in (-0.6, 0.0, 0.6):
        s.box((W - 0.08, yy - 0.03, 1.1), (W + 0.02, yy + 0.03, 2.2), m["beam"])
    door_frame(s, m["beam"])
    s.obj("HoneyHouse-col", coll)
    light(coll, "window", 0, (W - 0.8, 0.0, 1.7))

    # the screened back porch, and the fields beyond it
    p = MB()
    p.box((-W, D, -0.12), (W, D + 3.2, 0.0), m["porch"])
    for x in (-W, -2.6, 2.6, W):
        p.box((x - 0.07, D + 3.1, 0.0), (x + 0.07, D + 3.24, H), m["beam"])
    for y in (D + 1.0, D + 2.1):
        for x in (-W, W):
            p.box((x - 0.07, y - 0.07, 0.0), (x + 0.07, y + 0.07, H), m["beam"])
    p.box((-W, D + 3.1, 0.9), (W, D + 3.24, 1.0), m["beam"])
    p.obj("Porch-col", coll)
    sc_ = MB()
    sc_.quad([(-W, D + 3.17, 0.0), (W, D + 3.17, 0.0), (W, D + 3.17, H), (-W, D + 3.17, H)], m["screen"])
    for x in (-W, W):
        sc_.quad([(x, D, 0.0), (x, D + 3.17, 0.0), (x, D + 3.17, H), (x, D, H)], m["screen"])
    sc_.obj("Screens", coll)
    bk = MB()
    bk.quad([(-40.0, 30.0, -2.0), (40.0, 30.0, -2.0), (40.0, 30.0, 22.0), (-40.0, 30.0, 22.0)], m["sky"], uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    bk.box((-40.0, D + 3.3, -0.3), (40.0, 30.0, -0.05), m["ground"])
    for x in (-3.4, 3.8):
        bk.box((x - 0.26, 9.5 - 0.2, 0.0), (x + 0.26, 9.5 + 0.2, 0.62), m["hive"])
        bk.box((x - 0.3, 9.5 - 0.24, 0.62), (x + 0.3, 9.5 + 0.24, 0.68), m["hive_top"])
    bk.obj("Fields-col", coll)
    light(coll, "sunset", 0, (0.0, 12.0, 4.0))

    # the hive on the porch: two deeps and a honey super on a block stand
    hv = MB()
    hx, hy = 0.0, D + 1.6
    for dx in (-0.2, 0.2):
        hv.box((hx + dx - 0.1, hy - 0.22, 0.0), (hx + dx + 0.1, hy + 0.22, 0.2), m["block"])
    hv.box((hx - 0.28, hy - 0.22, 0.2), (hx + 0.28, hy + 0.26, 0.24), m["hive"])
    z = 0.24
    for hgt in (0.24, 0.24, 0.17):
        hv.box((hx - 0.255, hy - 0.205, z), (hx + 0.255, hy + 0.205, z + hgt - 0.004), m["hive"])
        for side in (-1, 1):
            hv.box((hx + side * 0.255 - 0.02 * (side < 0), hy - 0.06, z + hgt * 0.55), (hx + side * 0.255 + 0.02 * (side > 0), hy + 0.06, z + hgt * 0.7), m["hive"])
        z += hgt
    hv.box((hx - 0.24, hy - 0.2, z), (hx + 0.24, hy + 0.2, z + 0.015), m["hive"])
    hv.box((hx - 0.2, hy - 0.215, 0.24), (hx + 0.2, hy - 0.2, 0.26), m["iron"])
    hv.obj("Hive-col", coll)
    lid = MB()
    lid.box((hx - 0.285, hy - 0.235, 0.0), (hx + 0.285, hy + 0.235, 0.07), m["hive"])
    lid.box((hx - 0.29, hy - 0.24, 0.07), (hx + 0.29, hy + 0.24, 0.085), m["hive_top"])
    lo = lid.obj("HiveLid", coll)
    lo.location = (0, 0, z + 0.015)
    fr = MB()
    fr.box((hx - 0.24, hy - 0.012, 0.0), (hx + 0.24, hy + 0.012, 0.02), m["planks"])
    fr.box((hx - 0.24, hy - 0.012, 0.135), (hx + 0.24, hy + 0.012, 0.155), m["planks"])
    fr.box((hx - 0.25, hy - 0.012, 0.0), (hx - 0.23, hy + 0.012, 0.155), m["planks"])
    fr.box((hx + 0.23, hy - 0.012, 0.0), (hx + 0.25, hy + 0.012, 0.155), m["planks"])
    fr.box((hx - 0.23, hy - 0.016, 0.02), (hx + 0.23, hy + 0.016, 0.135), m["comb"])
    fr.box((hx - 0.28, hy - 0.01, 0.14), (hx + 0.28, hy + 0.01, 0.155), m["planks"])
    fo = fr.obj("HiveFrame", coll)
    fo.location = (0, 0, z - 0.165)

    # shelves of honey along the west wall, under the farm's sign
    sh = MB()
    for zz in (0.85, 1.35, 1.85):
        sh.box((-W + 0.02, -2.8, zz - 0.04), (-W + 0.42, 1.8, zz), m["beam"])
    for yy in (-2.8, -0.5, 1.8):
        sh.box((-W + 0.02, yy - 0.04, 0.0), (-W + 0.42, yy + 0.04, 2.1), m["beam"])
    jars = MB()
    for zz in (0.85, 1.35, 1.85):
        yy = -2.55
        while yy < 1.6:
            if abs(yy + 0.5) < 0.12:
                yy += 0.26
                continue
            jx = -W + 0.24
            jars.lathe((jx, yy, zz), [(0.05, 0.0), (0.065, 0.02), (0.065, 0.13), (0.05, 0.16), (0.045, 0.17)], m["honey"], seg=16)
            jars.cyl((jx, yy, zz + 0.165), 0.05, 0.05, 0.03, m["lid"], seg=16)
            pic(jars, (jx + 0.067, yy, zz + 0.08), 0.085, 0.085, (1, 0), m["label"])
            yy += 0.26
    jars.obj("HoneyJars", coll)
    sh.obj("Shelves-col", coll)
    sg = MB()
    sg.box((-W + 0.02, -1.0, 2.25), (-W + 0.08, 0.0, 3.0), m["beam"])
    pic(sg, (-W + 0.09, -0.5, 2.62), 0.66, 0.66, (1, 0), m["logo"])
    sg.obj("FarmSign", coll)
    text_mesh("FarmSignText", "JEKYLL'S 40 ACRE FARM", 0.12, (-W + 0.1, -0.5, 2.15), (math.pi / 2, 0, -math.pi / 2), m["lid"], coll, extrude=0.005, font=CINZEL)

    # the work bench: frames waiting to be uncapped, a smoker, an extractor, a bucket
    wb = MB()
    wb.box((-1.3, -1.0, 0.86), (1.3, 0.2, 0.92), m["beam"])
    for x in (-1.2, 1.2):
        for y in (-0.9, 0.1):
            wb.box((x - 0.05, y - 0.05, 0.0), (x + 0.05, y + 0.05, 0.86), m["beam"])
    for k in range(4):
        wb.box((-0.9, -0.6 + k * 0.03, 0.92), (-0.42, -0.58 + k * 0.03, 1.07), m["comb"] if k % 2 == 0 else m["planks"])
    wb.cyl((0.3, -0.4, 0.92), 0.08, 0.08, 0.22, m["tin"], seg=14)
    wb.lathe((0.3, -0.4, 1.14), [(0.08, 0.0), (0.03, 0.08), (0.02, 0.12)], m["tin"], seg=12)
    wb.box((0.4, -0.52, 0.94), (0.62, -0.28, 1.02), m["planks"])
    for k in range(5):
        wb.lathe((0.7 + (k % 3) * 0.14, -0.1 - (k // 3) * 0.14, 0.92), [(0.05, 0.0), (0.065, 0.02), (0.065, 0.13), (0.05, 0.16)], m["honey"], seg=14)
    wb.cyl((2.2, -0.9, 0.0), 0.38, 0.38, 0.95, m["steel"], seg=24)
    wb.cyl((2.2, -0.9, 0.95), 0.4, 0.4, 0.04, m["steel"], seg=24)
    wb.rod((2.2, -0.9, 0.99), (2.2, -0.9, 1.25), 0.03, m["iron"])
    wb.rod((2.2, -0.9, 1.25), (2.45, -0.9, 1.25), 0.02, m["iron"])
    wb.cyl((-2.3, -1.6, 0.0), 0.2, 0.22, 0.45, m["hive"], seg=16)
    wb.obj("Bench-col", coll)
    # the veil and jacket by the door, the clipboard for bee removal jobs
    ve = MB()
    ve.rod((W - 0.02, -3.2, 1.7), (W - 0.15, -3.2, 1.7), 0.015, m["iron"])
    ve.box((W - 0.28, -3.45, 0.95), (W - 0.06, -2.95, 1.66), m["veil"])
    ve.cyl((W - 0.2, -3.2, 1.72), 0.2, 0.2, 0.02, m["straw"], seg=18)
    ve.cyl((W - 0.2, -3.2, 1.72), 0.1, 0.09, 0.1, m["straw"], seg=14)
    ve.box((W - 0.04, -2.1, 1.05), (W - 0.02, -1.5, 1.85), m["beam"])
    pic(ve, (W - 0.045, -1.8, 1.43), 0.52, 0.72, (-1, 0), m["clip"])
    ve.box((W - 0.06, -1.9, 1.8), (W - 0.03, -1.7, 1.86), m["steel"])
    ve.obj("Gear", coll)
    # lanterns hanging from the tie beams
    ln = MB()
    for i, (x, y) in enumerate(((-2.2, -2.0), (2.2, 0.6), (0.0, 3.2), (0.0, D + 2.2))):
        ln.rod((x, y, H - 0.05), (x, y, 2.35), 0.01, m["iron"])
        ln.lathe((x, y, 2.05), [(0.09, 0.0), (0.11, 0.05), (0.09, 0.1)], m["iron"], seg=10)
        ln.cyl((x, y, 2.12), 0.08, 0.08, 0.2, m["lantern"], seg=10)
        ln.lathe((x, y, 2.32), [(0.11, 0.0), (0.03, 0.08)], m["iron"], seg=10)
        light(coll, "lantern", i, (x, y, 2.1))
    ln.obj("Lanterns", coll)

    mark(coll, "MARK_hy_spawn", (0.0, -3.3, 0.0), 0.0)
    mark(coll, "MARK_hive", (0.0, D + 0.9, 0.0))
    mark(coll, "MARK_jars", (-4.0, -0.5, 0.0))
    mark(coll, "MARK_clipboard", (4.2, -1.8, 0.0))
    mark(coll, "MARK_bench", (0.0, -1.6, 0.0))
    mark(coll, "MARK_hive_cam", (1.1, D + 0.4, 1.35))
    mark(coll, "MARK_hive_look", (0.0, D + 1.6, 0.9))
    kit.export(sc, "honey_house", images=False)


# ================================================================== the Drafting Room
SITES = [
    ("roots", "work_roots.jpg", "rootsbehavioralhealth.org"),
    ("gogit", "work_go-git-er.jpg", "go-git-er.com"),
    ("tinytides", "work_tinytides.jpg", "tinytidesplayroom.netlify.app"),
    ("zv", "work_zv.jpg", "zvautomotive.com"),
    ("prscms", "work_pearl-river.jpg", "prscms.org"),
    ("farm", "work_40-acre.jpg", "40acrefarm.netlify.app"),
]


def drafting():
    sc = kit.new_scene("Drafting_Room")
    coll = sc.collection
    m = {
        "walnut": mat("DR_Walnut", "#3a2414", 0.5),
        "plaster": mat("DR_Plaster", "#6a7a64", 0.85),
        "floor": mat("DR_Floor", "#6a4424", 0.5),
        "ceiling": mat("DR_Ceiling", "#d0c6a8", 0.85),
        "gilt": mat("DR_Gilt", "#b8903e", 0.3, 0.9),
        "brass": mat("DR_Brass", "#b8903e", 0.3, 0.9),
        "leather": mat("DR_Leather", "#3a1a10", 0.5),
        "green": mat("DR_LampGreen", "#1f6b43", 0.3, 0.0, "#2a8a50", 0.8),
        "lamp": mat("DR_Lamp", "#ffd8a0", 0.3, 0.0, "#ffc070", 3.0),
        "pricing": kit.img_mat("DR_Pricing", os.path.join(TEX, "pricing_chalk.png"), 0.8),
        "blueprint": kit.img_mat("DR_Blueprint", os.path.join(TEX, "blueprint.png"), 0.7),
        "paper": mat("DR_Paper", "#e8dcc0", 0.9),
        "book": mat("DR_Book", "#4a2a1a", 0.6),
        "steel": mat("DR_Steel", "#8a8a8e", 0.3, 0.9),
        "plant": mat("DR_Plant", "#2e4a22", 0.8),
        "pot": mat("DR_Pot", "#8a5a34", 0.7),
    }
    W, D, H = 5.0, 4.0, 3.6
    s = MB()
    room_shell(s, m["plaster"], m["floor"], m["ceiling"], W, D, H, wainscot=m["walnut"])
    for xx in (-2.5, 0.0, 2.5):
        s.box((xx - 0.12, -D, H - 0.28), (xx + 0.12, D, H), m["walnut"])
    for yy in (-2.0, 0.0, 2.0):
        s.box((-W, yy - 0.1, H - 0.22), (W, yy + 0.1, H), m["walnut"])
    door_frame(s, m["walnut"])
    s.obj("DraftingRoom-col", coll)
    # the six sites, framed like paintings, three on each side wall
    fr = MB()
    k = 0
    for side, x in ((-1, -W), (1, W)):
        for yy in (-2.2, 0.0, 2.2):
            key, img, domain = SITES[k]
            k += 1
            mi = kit.img_mat("DR_Work_" + key, os.path.join(TEX if key in ("tinytides", "zv") else os.path.join(kit.ROOT, "art", "textures"), img), 0.4, emit=0.5)
            facing = (-side, 0)
            px = x - side * 0.06
            frame_box(fr, (px, yy, 1.95), 1.5, 0.72, facing, m["gilt"], border=0.09, depth=0.06)
            pic(fr, (px - side * 0.005, yy, 1.95), 1.5, 0.72, facing, mi)
            fr.box((px - side * 0.03 - 0.01, yy - 0.34, 1.36), (px - side * 0.03 + 0.01, yy + 0.34, 1.46), m["brass"])
            text_mesh("Plate_" + key, domain, 0.045, (px - side * 0.045, yy, 1.41), (math.pi / 2, 0, math.pi / 2 * side), m["walnut"], coll, extrude=0.002, font=CINZEL)
            light(coll, "picture", k, (px - side * 0.7, yy, 2.7))
            mark(coll, "MARK_site_" + key, (px - side * 1.0, yy, 0.0), math.pi / 2 * side)
    fr.obj("Frames", coll)
    # the pricing board and the desk with the 1997 drawer, north wall
    nw = MB()
    nw.box((-3.6, D - 0.08, 1.05), (-1.2, D - 0.02, 2.85), m["walnut"])
    pic(nw, (-2.4, D - 0.09, 1.95), 2.24, 1.66, (0, -1), m["pricing"])
    nw.box((1.2, D - 0.7, 0.0), (3.8, D - 0.05, 0.78), m["walnut"])
    nw.box((1.15, D - 0.75, 0.78), (3.85, D - 0.02, 0.83), m["walnut"])
    for i, xx in enumerate((1.55, 2.2, 2.85, 3.5)):
        for zz in (0.2, 0.55):
            nw.box((xx - 0.28, D - 0.72, zz - 0.14), (xx + 0.28, D - 0.7, zz + 0.14), m["walnut"])
            nw.boxc((xx, D - 0.73, zz), (0.08, 0.02, 0.025), m["brass"])
    nw.box((3.3, D - 0.735, 0.24), (3.7, D - 0.73, 0.32), m["brass"])
    for kk in range(6):
        nw.boxc((1.6 + kk * 0.05, D - 0.4, 0.84 + kk * 0.003), (0.3, 0.4, 0.003), m["paper"], rz=0.08 * kk)
    nw.obj("NorthWall-col", coll)
    text_mesh("Drawer1997", "1997", 0.05, (3.5, D - 0.745, 0.28), (math.pi / 2, 0, 0), m["walnut"], coll, extrude=0.002, font=CINZEL)
    # the drafting table, tilted, with tonight's draft pinned to it
    dt = MB()
    tx, ty = 1.4, -0.4
    for dx in (-0.55, 0.55):
        for dy in (-0.35, 0.35):
            dt.rod((tx + dx, ty + dy, 0.0), (tx + dx * 0.9, ty + dy * 0.9, 0.9), 0.03, m["walnut"])
    board = Matrix.Rotation(math.radians(-22), 4, "X")
    dt.boxc((tx, ty, 1.0), (1.3, 0.95, 0.04), m["walnut"], rx=math.radians(-22))
    c = Vector((tx, ty, 1.0)) + Vector((0, 0.0, 0.025)) + Vector((0, -math.sin(math.radians(22)) * 0.0, 0))
    pts = []
    for (u, v) in ((-0.55, -0.4), (0.55, -0.4), (0.55, 0.4), (-0.55, 0.4)):
        p = Vector((u, v, 0.022))
        p = board.to_3x3() @ p
        pts.append(Vector((tx, ty, 1.0)) + p)
    dt.quad(pts, m["blueprint"], uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    tsq = board.to_3x3() @ Vector((0, -0.42, 0.04))
    dt.boxc(Vector((tx, ty, 1.0)) + tsq, (1.2, 0.05, 0.012), m["walnut"], rx=math.radians(-22))
    dt.cyl((tx + 0.2, ty - 0.9, 0.0), 0.2, 0.18, 0.62, m["walnut"], seg=14)
    dt.cyl((tx + 0.2, ty - 0.9, 0.62), 0.22, 0.22, 0.05, m["leather"], seg=16)
    dt.box((2.4, -1.1, 0.0), (2.9, -0.6, 0.7), m["walnut"])
    dt.cyl((2.65, -0.85, 0.7), 0.07, 0.08, 0.03, m["brass"], seg=12)
    dt.rod((2.65, -0.85, 0.73), (2.65, -0.85, 1.05), 0.015, m["brass"])
    dt.rod((2.5, -0.85, 1.08), (2.8, -0.85, 1.08), 0.06, m["green"], seg=12)
    dt.obj("DraftingTable-col", coll)
    light(coll, "banker", 0, (2.65, -0.85, 0.95))
    # bookcases flanking the door, a palm in the corner
    bc = MB()
    for x0 in (-4.6, 2.4):
        bc.box((x0, -D + 0.04, 0.0), (x0 + 2.0, -D + 0.42, 2.5), m["walnut"])
        for zz in (0.35, 0.9, 1.45, 2.0):
            for kk in range(20):
                bc.boxc((x0 + 0.1 + kk * 0.09, -D + 0.26, zz + 0.15), (0.07, 0.26, 0.26 + (kk % 3) * 0.03), m["book"] if kk % 5 else m["leather"])
    bc.cyl((-4.3, 3.3, 0.0), 0.22, 0.28, 0.45, m["pot"], seg=14)
    for kk in range(7):
        a = kk / 7 * 2 * math.pi
        bc.rod((-4.3, 3.3, 0.45), (-4.3 + math.cos(a) * 0.5, 3.3 + math.sin(a) * 0.5, 1.2), 0.04, m["plant"])
    bc.obj("Bookcases-col", coll)
    # chandelier
    ch = MB()
    ch.rod((0.0, 0.0, H), (0.0, 0.0, 2.9), 0.02, m["brass"])
    for kk in range(6):
        a = 2 * math.pi * kk / 6
        p = (math.cos(a) * 0.45, math.sin(a) * 0.45, 2.78)
        ch.rod((0.0, 0.0, 2.88), p, 0.015, m["brass"])
        ch.sphere(p, 0.07, m["lamp"], sub=1)
    ch.obj("Chandelier", coll)
    light(coll, "chandelier", 0, (0.0, 0.0, 2.6))
    mark(coll, "MARK_dr_spawn", (0.0, -3.3, 0.0), 0.0)
    mark(coll, "MARK_pricing", (-2.4, 3.0, 0.0))
    mark(coll, "MARK_drafting", (1.4, -1.4, 0.0))
    mark(coll, "MARK_drawer", (3.5, 2.8, 0.0))
    kit.export(sc, "drafting_room", images=False)


# ================================================================== the Trading Floor
def trading():
    sc = kit.new_scene("Trading_Floor")
    coll = sc.collection
    m = {
        "wall": mat("TF_Wall", "#1e1410", 0.6),
        "floor": mat("TF_Floor", "#2a1c12", 0.6),
        "ceiling": mat("TF_Ceiling", "#3a3632", 0.9),
        "desk": mat("TF_Desk", "#2e1c10", 0.5),
        "bezel": mat("TF_Bezel", "#b8b09a", 0.5),
        "metal": mat("TF_Metal", "#2a2a2c", 0.4, 0.8),
        "brass": mat("TF_Brass", "#b8903e", 0.3, 0.9),
        "leather": mat("TF_Leather", "#1a1410", 0.5),
        "plaque": kit.img_mat("TF_Plaque", os.path.join(TEX, "plaque_no_course.png"), 0.35),
        "ticker": kit.img_mat("TF_Ticker", os.path.join(TEX, "ticker.png"), 0.5, emit=1.5),
        "s_checkin": kit.img_mat("TF_ScreenCheckin", os.path.join(TEX, "screen_checkin.png"), 0.3, emit=1.4),
        "s_journal": kit.img_mat("TF_ScreenJournal", os.path.join(TEX, "screen_journal.png"), 0.3, emit=1.4),
        "s_partner": kit.img_mat("TF_ScreenPartner", os.path.join(TEX, "screen_partner.png"), 0.3, emit=1.4),
        "s_members": kit.img_mat("TF_ScreenMembers", os.path.join(TEX, "screen_members.png"), 0.3, emit=1.4),
        "lamp": mat("TF_Lamp", "#ffd8a0", 0.3, 0.0, "#ffc070", 2.5),
        "rug": mat("TF_Rug", "#1c2a20", 0.95),
    }
    W, D, H = 5.5, 4.5, 3.4
    s = MB()
    room_shell(s, m["wall"], m["floor"], m["ceiling"], W, D, H, wainscot=m["desk"])
    door_frame(s, m["desk"], D=D)
    for xx in (-2.75, 0.0, 2.75):
        s.box((xx - 0.1, -D, H - 0.24), (xx + 0.1, D, H), m["desk"])
    s.obj("TradingFloor-col", coll)
    # the plaque, lit from above
    pl = MB()
    pl.box((-1.35, D - 0.08, 1.05), (1.35, D - 0.02, 2.75), m["desk"])
    pic(pl, (0.0, D - 0.09, 1.9), 2.4, 1.5, (0, -1), m["plaque"])
    pl.obj("Plaque", coll)
    light(coll, "plaque", 0, (0.0, D - 1.2, 3.0))
    # the ticker board along the top of the north wall
    tk = MB()
    tk.box((-W + 0.1, D - 0.2, 2.86), (W - 0.1, D - 0.02, 3.2), m["metal"])
    pts = [(-W + 0.2, D - 0.205, 2.9), (W - 0.2, D - 0.205, 2.9), (W - 0.2, D - 0.205, 3.16), (-W + 0.2, D - 0.205, 3.16)]
    tk.quad(pts, m["ticker"], uv=[(0, 0), (2.6, 0), (2.6, 1), (0, 1)])
    tk.obj("Ticker", coll)

    def crt(mb, c, rz, screen_m):
        R = Matrix.Rotation(rz, 3, "Z")
        cx, cy, cz = c
        mb.boxc((cx, cy, cz + 0.2), (0.46, 0.42, 0.4), m["bezel"], rz=rz)
        back = R @ Vector((0, 0.24, 0))
        mb.boxc((cx + back.x, cy + back.y, cz + 0.2), (0.34, 0.24, 0.3), m["bezel"], rz=rz)
        front = R @ Vector((0, -0.212, 0))
        ax = R @ Vector((1, 0, 0))
        p0 = Vector((cx, cy, cz + 0.21)) + front
        pts = [p0 - ax * 0.17 - Vector((0, 0, 0.13)), p0 + ax * 0.17 - Vector((0, 0, 0.13)), p0 + ax * 0.17 + Vector((0, 0, 0.13)), p0 - ax * 0.17 + Vector((0, 0, 0.13))]
        mb.quad(pts, screen_m, uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
        kb = R @ Vector((0, -0.45, 0))
        mb.boxc((cx + kb.x, cy + kb.y, cz + 0.015), (0.44, 0.16, 0.03), m["bezel"], rz=rz)

    dk = MB()
    screens = [m["s_journal"], m["s_partner"], m["s_journal"]]
    for row, yy in enumerate((-0.6, 1.6)):
        dk.box((-3.8, yy - 0.4, 0.72), (3.8, yy + 0.4, 0.77), m["desk"])
        for x in (-3.7, 0.0, 3.7):
            dk.box((x - 0.05, yy - 0.35, 0.0), (x + 0.05, yy + 0.35, 0.72), m["desk"])
        for i, x in enumerate((-2.6, 0.0, 2.6)):
            crt(dk, (x, yy + 0.05, 0.77), 0.0, screens[(i + row) % 3])
            light(coll, "screen_green" if (i + row) % 3 != 1 else "screen_amber", row * 3 + i, (x, yy - 0.5, 1.0))
    dk.obj("Desks-col", coll)
    chs = MB()
    for yy in (-0.6, 1.6):
        for x in (-2.6, 0.0, 2.6):
            chair(chs, {"velvet": m["leather"], "mahog": m["desk"]}, (x, yy - 0.95), (0, 1), arm=True)
    chs.obj("Chairs", coll)
    # the pre-market check-in terminal by the door
    ck = MB()
    ck.box((-3.55, -3.35, 0.0), (-2.85, -2.75, 1.0), m["desk"])
    crt(ck, (-3.2, -2.95, 1.0), math.pi, m["s_checkin"])
    ck.obj("Checkin-col", coll)
    light(coll, "screen_amber", 9, (-3.2, -2.4, 1.3))
    # members-only doors on the east wall
    dr = MB()
    for yy, label, screen_m in ((-1.6, "LEADERBOARD", m["s_members"]), (1.9, "JOURNAL", m["s_members"])):
        dr.box((W - 0.08, yy - 0.55, 0.0), (W - 0.02, yy + 0.55, 2.2), m["desk"])
        for s2 in (-1, 1):
            dr.box((W - 0.12, yy + s2 * 0.6 - 0.06, 0.0), (W - 0.02, yy + s2 * 0.6 + 0.06, 2.3), m["desk"])
        dr.box((W - 0.12, yy - 0.66, 2.2), (W - 0.02, yy + 0.66, 2.34), m["desk"])
        dr.box((W - 0.1, yy - 0.3, 1.55), (W - 0.085, yy + 0.3, 1.78), m["brass"])
        dr.boxc((W - 0.1, yy - 0.4, 1.0), (0.04, 0.05, 0.05), m["brass"])
        text_mesh("DoorPlate_" + label, label, 0.07, (W - 0.105, yy, 1.7), (math.pi / 2, 0, math.pi / 2), m["desk"], coll, extrude=0.002, font=CINZEL)
        text_mesh("DoorSub_" + label, "MEMBERS ONLY", 0.045, (W - 0.105, yy, 1.6), (math.pi / 2, 0, math.pi / 2), m["desk"], coll, extrude=0.002, font=CINZEL)
    dr.obj("MemberDoors-col", coll)
    rg = MB()
    rg.box((-4.0, -2.2, 0.0), (4.0, 2.6, 0.012), m["rug"])
    rg.obj("Rug", coll)
    lp = MB()
    for i, x in enumerate((-2.75, 2.75)):
        lp.rod((x, 0.5, H), (x, 0.5, 2.6), 0.015, m["metal"])
        lp.lathe((x, 0.5, 2.6), [(0.03, 0.0), (0.25, -0.18), (0.26, -0.22), (0.0, -0.21)], m["metal"], seg=16)
        lp.sphere((x, 0.5, 2.42), 0.06, m["lamp"], sub=1)
        light(coll, "pendant", i, (x, 0.5, 2.3))
    lp.obj("Lamps", coll)
    mark(coll, "MARK_tf_spawn", (0.0, -3.8, 0.0), 0.0)
    mark(coll, "MARK_plaque", (0.0, 3.4, 0.0))
    mark(coll, "MARK_checkin", (-3.2, -2.3, 0.0))
    mark(coll, "MARK_door_leaderboard", (4.6, -1.6, 0.0))
    mark(coll, "MARK_door_journal", (4.6, 1.9, 0.0))
    mark(coll, "MARK_desks", (0.0, 0.5, 0.0))
    kit.export(sc, "trading_floor", images=False)


BUILDERS = {"honey": honey, "drafting": drafting, "trading": trading}


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
