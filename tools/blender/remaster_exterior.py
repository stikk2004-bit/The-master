"""Remaster touches for the clubhouse grounds: real lanterns on the gas lamps along the front
walk, a couple of benches, and stone urns at the porch steps.

    python tools/blender/remaster_exterior.py

Safe to run more than once: it rebuilds its own objects and only replaces the lamp glass.
"""
import math
import os
import sys

import bpy  # noqa: I001  (bpy has to load before bmesh)
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402
from kit import MB, mat  # noqa: E402


def lantern(mb, m, c, w=0.36, h=0.5):
    """An iron-framed lantern: four glass panes, a flame inside, a peaked cap with a finial."""
    x, y, z = c
    hw = w / 2
    # glass panes, set a touch inside the frame
    for (a, b) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
        p0 = Vector((x + a[0] * (hw - 0.01), y + a[1] * (hw - 0.01), z))
        p1 = Vector((x + b[0] * (hw - 0.01), y + b[1] * (hw - 0.01), z))
        mb.quad([p0, p1, p1 + Vector((0, 0, h)), p0 + Vector((0, 0, h))], m["pane"])
        mb.quad([p1, p0, p0 + Vector((0, 0, h)), p1 + Vector((0, 0, h))], m["pane"])
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.rod((x + sx * hw, y + sy * hw, z - 0.02), (x + sx * hw, y + sy * hw, z + h + 0.02), 0.014, m["iron"], seg=6)
    mb.box((x - hw - 0.03, y - hw - 0.03, z - 0.05), (x + hw + 0.03, y + hw + 0.03, z), m["iron"])
    mb.box((x - hw - 0.02, y - hw - 0.02, z + h), (x + hw + 0.02, y + hw + 0.02, z + h + 0.03), m["iron"])
    mb.lathe((x, y, z + h + 0.03), [(hw * 1.5, 0.0), (hw * 0.25, 0.22), (0.04, 0.26)], m["iron"], seg=4)
    mb.sphere((x, y, z + h + 0.3), 0.035, m["iron"], sub=1)
    mb.lathe((x, y, z - 0.05), [(hw * 0.9, 0.0), (0.05, -0.12)], m["iron"], seg=4)
    # the burner and its flame
    mb.cyl((x, y, z), 0.03, 0.03, 0.12, m["brass"], seg=8)
    mb.sphere((x, y, z + 0.2), 0.05, m["flame"], sub=2, scale=(1.0, 1.0, 1.7))


def bench(mb, m, c, rz):
    from mathutils import Matrix
    R = Matrix.Rotation(rz, 3, "Z")
    x, y = c

    def P(dx, dy, dz):
        v = R @ Vector((dx, dy, dz))
        return (x + v.x, y + v.y, v.z)
    for k in range(4):
        mb.boxc(P(0, -0.2 + k * 0.13, 0.45), (1.6, 0.1, 0.035), m["wood"], rz=rz)
    for k in range(3):
        mb.boxc(P(0, 0.26, 0.6 + k * 0.12), (1.6, 0.03, 0.09), m["wood"], rz=rz)
    for sx in (-0.7, 0.7):
        mb.boxc(P(sx, 0.0, 0.22), (0.05, 0.5, 0.44), m["iron"], rz=rz)
        mb.boxc(P(sx, 0.28, 0.6), (0.05, 0.05, 0.4), m["iron"], rz=rz)
        mb.boxc(P(sx, 0.02, 0.62), (0.05, 0.5, 0.04), m["iron"], rz=rz)


def urn(mb, m, c):
    x, y = c
    mb.box((x - 0.35, y - 0.35, 0.0), (x + 0.35, y + 0.35, 0.5), m["stone"])
    mb.lathe((x, y, 0.5), [(0.18, 0.0), (0.12, 0.12), (0.3, 0.45), (0.38, 0.62), (0.34, 0.66), (0.3, 0.64)], m["stone"], seg=16)
    for k in range(9):
        a = 2 * math.pi * k / 9
        mb.rod((x, y, 1.05), (x + math.cos(a) * 0.55, y + math.sin(a) * 0.55, 1.5 + 0.15 * math.sin(a * 3)), 0.03, m["fern"], seg=5)
    mb.sphere((x, y, 1.12), 0.28, m["fern"], sub=1, scale=(1.0, 1.0, 0.6))


def main():
    bpy.ops.wm.open_mainfile(filepath=kit.BLEND)
    sc = bpy.data.scenes["Clubhouse_Exterior"]
    for w in bpy.context.window_manager.windows:
        w.scene = sc
    coll = sc.collection
    m = {
        "iron": bpy.data.materials["Iron"],
        "pane": mat("LampPane", "#ffd9a0", 0.1, 0.0, "#ffb060", 0.4, alpha=0.3),
        "flame": mat("LampFlame", "#ffc070", 0.4, 0.0, "#ffa040", 6.0),
        "brass": bpy.data.materials["Brass"],
        "wood": mat("GroundsWood", "#5a4630", 0.8),
        "stone": mat("GroundsStone", "#8a8478", 0.9),
        "fern": mat("Shrub", "#2a4127", 0.9) if "Shrub" not in bpy.data.materials else bpy.data.materials["Shrub"],
    }
    # take the old glass boxes off the lamp posts and remember where they were
    lamps = bpy.data.objects["GasLamps-col"]
    me = lamps.data
    names = [mm.name for mm in me.materials]
    heads = []
    if "LampGlass" in names:
        gi = names.index("LampGlass")
        bm = bmesh.new()
        bm.from_mesh(me)
        glass = [f for f in bm.faces if f.material_index == gi]
        groups = {}
        for f in glass:
            cc = f.calc_center_median()
            key = (round(cc.x), round(cc.y))
            groups.setdefault(key, []).append(f)
        for key, fs in groups.items():
            vs = {v for f in fs for v in f.verts}
            lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
            hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
            if (hi - lo).length > 0.3:
                heads.append(((lo + hi) / 2, hi.z - lo.z))
        bmesh.ops.delete(bm, geom=glass, context="FACES")
        bm.to_mesh(me)
        bm.free()
    for old in [o for o in coll.objects if o.name.startswith(("Lanterns", "GroundsProps"))]:
        bpy.data.objects.remove(old, do_unlink=True)
    ln = MB()
    for c, hgt in heads:
        lantern(ln, m, (c.x, c.y, c.z - hgt / 2 + 0.02), 0.36, hgt - 0.05)
    ln.obj("Lanterns", coll)
    pr = MB()
    # benches face the walk; urns stand on the lawn where the walk meets the porch steps
    bench(pr, m, (-4.5, -30.0), math.pi / 2)
    bench(pr, m, (4.5, -18.0), -math.pi / 2)
    urn(pr, m, (-3.5, -5.6))
    urn(pr, m, (3.5, -5.6))
    pr.obj("GroundsProps-col", coll)
    kit.export(sc, "clubhouse_exterior")
    bpy.ops.wm.save_as_mainfile(filepath=kit.BLEND, compress=True)
    print("remastered exterior: %d lanterns" % len(heads))


if __name__ == "__main__":
    main()
