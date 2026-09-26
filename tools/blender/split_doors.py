"""Split the clubhouse's double doors into leaves the game can swing open.

    python tools/blender/split_doors.py

Each door object keeps its frame and transom; each leaf becomes its own object named
<door>_SwingP or <door>_SwingN with its origin on the hinge line. The game turns a leaf about
its vertical axis, positive (P) or negative (N), when you walk through (main.gd _through_door).
Behind each doorway goes a thin lit panel, so an open door shows light, not wall.
Safe to run more than once: it puts split doors back together first.
"""
import os
import sys

import bpy  # noqa: I001  (bpy has to load before bmesh)
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402
from kit import mat  # noqa: E402

# door: (scene, how the leaves sit, glow material)
#   "x": leaves side by side along x, the doorway faces +y or -y (swing: +1 = toward +y)
#   "y": leaves side by side along y, the doorway faces +x or -x (swing: +1 = toward +x)
DOORS = {
    "Door_Front": ("Clubhouse_Exterior", "x", -1, "GlassLit"),
    "Door_Exit": ("Lobby", "x", 1, "DoorDusk"),
    "Door_Library": ("Lobby", "y", 1, "GlassLit"),
    "Door_Trading": ("Lobby", "y", 1, "GlassLit"),
    "Door_Studio": ("Lobby", "y", -1, "GlassLit"),
    "Door_Honey": ("Lobby", "y", -1, "GlassLit"),
    "Door_Exit.001": ("Library", "x", 1, "GlassLit"),
}


def parts(bm):
    """Connected groups of faces."""
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, part = [f], set()
        while stack:
            g = stack.pop()
            if g.index in part:
                continue
            part.add(g.index)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in part:
                        stack.append(h)
        seen |= part
        out.append(part)
    return out


def bounds(bm, idx):
    vs = {v for i in idx for v in bm.faces[i].verts}
    lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
    hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
    return lo, hi


def rejoin(sc, name):
    """Merge any leaves from an earlier run back into the door, and drop the old glow."""
    door = sc.objects[name]
    for o in [o for o in sc.objects if o.name.startswith(name.replace(".", "_") + "_Swing") or o.name == name + "_Glow"]:
        if o.name.endswith("_Glow"):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        bm = bmesh.new()
        bm.from_mesh(door.data)
        other = o.data.copy()
        other.transform(door.matrix_world.inverted() @ o.matrix_world)
        # materials: map the leaf's slots onto the door's
        remap = []
        for m in other.materials:
            if m.name not in [dm.name for dm in door.data.materials]:
                door.data.materials.append(m)
            remap.append([dm.name for dm in door.data.materials].index(m.name))
        for p in other.polygons:
            p.material_index = remap[p.material_index] if remap else 0
        bm.from_mesh(other)
        bm.to_mesh(door.data)
        bm.free()
        bpy.data.meshes.remove(other)
        bpy.data.objects.remove(o, do_unlink=True)


def split(sc, name, axis, swing, glow_name):
    door = sc.objects[name]
    me = door.data
    M = door.matrix_world
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(M)
    groups = parts(bm)
    lo_all, hi_all = bounds(bm, set().union(*groups))
    across = 0 if axis == "x" else 1          # the axis the leaves sit side by side on
    depth = 1 - across                         # the axis the doorway faces along
    mid = (lo_all[across] + hi_all[across]) / 2
    span = hi_all[across] - lo_all[across]
    leaves = {-1: [], 1: []}
    for g in groups:
        lo, hi = bounds(bm, g)
        wide = (hi[across] - lo[across]) > span * 0.7
        high = lo.z > 2.75
        if wide or high:
            continue                           # frame, backing panel or transom: stays put
        c = (lo[across] + hi[across]) / 2
        leaves[-1 if c < mid else 1].append(g)
    if not leaves[-1] or not leaves[1]:
        bm.free()
        print("  %s: no leaves found" % name)
        return
    # the leaves' own extent, and the room face of the door slab (the biggest piece of each leaf)
    leaf_idx = set(i for g in leaves[-1] + leaves[1] for i in g)
    llo, lhi = bounds(bm, leaf_idx)
    slab = max(leaves[-1], key=lambda g: (bounds(bm, g)[1][across] - bounds(bm, g)[0][across]) * (bounds(bm, g)[1].z - bounds(bm, g)[0].z))
    slo, shi = bounds(bm, slab)
    face_front = shi[depth] if swing > 0 else slo[depth]
    face_back = slo[depth] if swing > 0 else shi[depth]
    # whatever is right behind the doorway (a backing panel, the wall): look through the gap between the leaves
    for w in bpy.context.window_manager.windows:
        w.scene = sc
    dg = bpy.context.evaluated_depsgraph_get()
    o = Vector((0.0, 0.0, llo.z + 0.7))
    o[across] = mid
    o[depth] = face_front + swing * 0.6
    dvec = Vector((0.0, 0.0, 0.0))
    dvec[depth] = -swing
    hit, loc, *_ = sc.ray_cast(dg, o, dvec, distance=2.0)
    behind = loc[depth] if hit and abs(loc[depth] - face_front) > 0.02 else face_back
    for side, gs in leaves.items():
        idx = set(i for g in gs for i in g)
        lo, hi = bounds(bm, idx)
        hinge = Vector((0.0, 0.0, lo.z))
        hinge[across] = lo[across] if side < 0 else hi[across]
        hinge[depth] = face_front
        # which way turns this leaf toward the swing side: leaf runs +across from a -side hinge
        # along x (doorway faces y): turning +90 takes +x to +y; along y (doorway faces x): turning +90 takes +y to -x
        if axis == "x":
            sgn = swing * (1 if side < 0 else -1)
        else:
            sgn = -swing * (1 if side < 0 else -1)
        nb = bmesh.new()
        vmap = {}
        uvl = bm.loops.layers.uv.active
        nuv = nb.loops.layers.uv.new("UVMap") if uvl else None
        for i in idx:
            f = bm.faces[i]
            vs = []
            for v in f.verts:
                if v not in vmap:
                    vmap[v] = nb.verts.new(v.co - hinge)
                vs.append(vmap[v])
            try:
                nf = nb.faces.new(vs)
            except ValueError:
                continue
            nf.material_index = f.material_index
            nf.smooth = f.smooth
            if uvl:
                for a, b in zip(f.loops, nf.loops):
                    b[nuv].uv = a[uvl].uv
        nme = bpy.data.meshes.new(name + "_leaf")
        nb.to_mesh(nme)
        nb.free()
        for m in me.materials:
            nme.materials.append(m)
        leaf = bpy.data.objects.new("%s_Swing%s" % (name.replace(".", "_"), "P" if sgn > 0 else "N"), nme)
        leaf.location = hinge
        sc.collection.objects.link(leaf)
        if leaf.name.endswith(".001"):
            leaf.name = leaf.name[:-4] + ("B" if side > 0 else "A")
    # take the leaves out of the door itself
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in leaf_idx], context="FACES")
    bm.transform(M.inverted())
    bm.to_mesh(me)
    bm.free()
    # a lit panel just behind the closed leaves
    g = kit.MB()
    gm = bpy.data.materials.get(glow_name) or mat(glow_name, "#6a7a9a", 0.5, 0.0, "#6a7a9a", 0.6)
    a0, a1 = llo[across] + 0.02, lhi[across] - 0.02
    d = behind + swing * 0.004
    z0, z1 = llo.z, min(lhi.z, 2.9)
    if axis == "x":
        pts = [(a0, d, z0), (a1, d, z0), (a1, d, z1), (a0, d, z1)]
    else:
        pts = [(d, a0, z0), (d, a1, z0), (d, a1, z1), (d, a0, z1)]
    if swing > 0:
        pts = pts[::-1] if axis == "x" else pts
    else:
        pts = pts if axis == "x" else pts[::-1]
    g.quad(pts, gm, uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    g.obj(name + "_Glow", sc.collection)
    print("  %s: leaves %d + %d" % (name, len(leaves[-1]), len(leaves[1])))


def main():
    bpy.ops.wm.open_mainfile(filepath=kit.BLEND)
    done = []
    for name, (scene, axis, swing, glow) in DOORS.items():
        sc = bpy.data.scenes[scene]
        if name not in sc.objects:
            print("  missing", name)
            continue
        rejoin(sc, name)
        split(sc, name, axis, swing, glow)
        if scene not in done:
            done.append(scene)
    for scene, fname in (("Clubhouse_Exterior", "clubhouse_exterior"), ("Lobby", "lobby"), ("Library", "library")):
        kit.export(bpy.data.scenes[scene], fname)
    bpy.ops.wm.save_as_mainfile(filepath=kit.BLEND, compress=True)


if __name__ == "__main__":
    main()
