"""Modeling kit for the environment scripts: a mesh builder, materials, scenes and export.

Everything is built in real meters. Blender (x, y, z) becomes Godot (x, z, -y).
Name an object with -col for mesh + collision or -colonly for an invisible collider.
Materials only carry a flat color here; the game lays textures on them by name (look.gd).
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BLEND = os.path.join(ROOT, "blender", "JekyllClubGame.blend")
EXPORTS = os.path.join(ROOT, "exports")
MODELS = os.path.join(ROOT, "godot", "models")


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mat(name, hexcol, rough=0.8, metal=0.0, emit=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    col = srgb(hexcol)
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    m.diffuse_color = (*col, 1)
    return m


def img_mat(name, path, rough=0.8, emit=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if emit:
        nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emit
    return m


class MB:
    """Collect primitives into one mesh with per-face materials."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []
        self.facing = []   # (face, intended normal) for flat pictures and panels

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _tag(self, verts, m):
        i = self._mi(m)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = i

    def box(self, mn, mx, m):
        mn, mx = Vector(mn), Vector(mx)
        c = (mn + mx) / 2
        s = mx - mn
        g = bmesh.ops.create_cube(self.bm, size=1.0, matrix=Matrix.Translation(c) @ Matrix.Diagonal((s.x, s.y, s.z, 1)))
        self._tag(g["verts"], m)
        return g["verts"]

    def boxc(self, c, s, m, rz=0.0, rx=0.0, ry=0.0):
        R = Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
        g = bmesh.ops.create_cube(self.bm, size=1.0, matrix=Matrix.Translation(Vector(c)) @ R @ Matrix.Diagonal((s[0], s[1], s[2], 1)))
        self._tag(g["verts"], m)
        return g["verts"]

    def bbox(self, mn, mx, m, bevel=0.02, segs=1):
        """Box with softened edges: reads as carpentry, catches light on its edges."""
        vs = self.box(mn, mx, m)
        edges = list({e for v in vs for e in v.link_edges})
        try:
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
        except TypeError:
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=segs, profile=0.5, affect="EDGES")
        return vs

    def cyl(self, c, r1, r2, h, m, seg=12, rot=None, caps=True):
        M = Matrix.Translation(Vector(c))
        if rot is not None:
            M = M @ rot
        g = bmesh.ops.create_cone(self.bm, cap_ends=caps, segments=seg, radius1=r1, radius2=r2, depth=h, matrix=M @ Matrix.Translation((0, 0, h / 2)))
        self._tag(g["verts"], m)
        return g["verts"]

    def rod(self, a, b, r, m, seg=8, r2=None):
        a, b = Vector(a), Vector(b)
        d = b - a
        rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        return self.cyl(a, r, r if r2 is None else r2, d.length, m, seg=seg, rot=rot)

    def sphere(self, c, r, m, sub=2, scale=(1, 1, 1)):
        g = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r, matrix=Matrix.Translation(Vector(c)) @ Matrix.Diagonal((*scale, 1)))
        self._tag(g["verts"], m)
        return g["verts"]

    def quad(self, pts, m, uv=None):
        vs = [self.bm.verts.new(p) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self._mi(m)
        if uv:
            for lp, t in zip(f.loops, uv):
                lp[self.uv].uv = t
        # remember which way the points were wound, so normal fixing can't turn it around
        f.normal_update()
        self.facing.append((f, f.normal.copy()))
        return f

    def lathe(self, center, profile, m, seg=24, caps=True):
        """Revolve [(radius, height)...] around the vertical axis at center."""
        c = Vector(center)
        rows = []
        for r, h in profile:
            row = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                row.append(self.bm.verts.new(c + Vector((math.cos(a) * r, math.sin(a) * r, h))))
            rows.append(row)
        mi = self._mi(m)
        for j in range(len(rows) - 1):
            for i in range(seg):
                a, b = rows[j], rows[j + 1]
                try:
                    f = self.bm.faces.new([a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]])
                    f.material_index = mi
                except ValueError:
                    pass
        if caps:
            for row in (rows[0], rows[-1]):
                try:
                    f = self.bm.faces.new(row)
                    f.material_index = mi
                except ValueError:
                    pass

    def arch_window(self, c, w, h, m_frame, m_glass, facing, depth=0.08):
        """Window: frame, mullions and glass, flush on a wall facing +/-X or +/-Y."""
        c = Vector(c)
        fx, fy = facing
        if abs(fx) > 0.5:
            ax = Vector((0, 1, 0))
        else:
            ax = Vector((1, 0, 0))
        n = Vector((fx, fy, 0))
        glass = [c + ax * (-w / 2) + Vector((0, 0, -h / 2)) + n * 0.01, c + ax * (w / 2) + Vector((0, 0, -h / 2)) + n * 0.01,
                 c + ax * (w / 2) + Vector((0, 0, h / 2)) + n * 0.01, c + ax * (-w / 2) + Vector((0, 0, h / 2)) + n * 0.01]
        if (ax.cross(Vector((0, 0, 1)))).dot(n) < 0:
            glass = glass[::-1]
        self.quad(glass, m_glass, uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
        t = 0.05
        for s in (-1, 1):
            self._frame_bar(c + ax * (s * (w / 2 + t / 2)) + n * depth / 2, ax * t + Vector((0, 0, h + 2 * t)) + n * depth, m_frame)
            self._frame_bar(c + Vector((0, 0, s * (h / 2 + t / 2))) + n * depth / 2, ax * (w + 2 * t) + Vector((0, 0, t)) + n * depth, m_frame)
        self._frame_bar(c + n * depth / 2, ax * 0.03 + Vector((0, 0, h)) + n * depth * 0.6, m_frame)
        self._frame_bar(c + Vector((0, 0, h * 0.1)) + n * depth / 2, ax * w + Vector((0, 0, 0.03)) + n * depth * 0.6, m_frame)

    def _frame_bar(self, c, size, m):
        s = Vector((abs(size.x), abs(size.y), abs(size.z)))
        self.boxc(c, (max(s.x, 0.01), max(s.y, 0.01), max(s.z, 0.01)), m)

    def obj(self, name, collection, smooth=False, loc=(0, 0, 0), autosmooth=False):
        loose = {f for f, _ in self.facing}
        solid = [f for f in self.bm.faces if f not in loose]
        bmesh.ops.recalc_face_normals(self.bm, faces=solid)
        for f, n in self.facing:
            if f.is_valid:
                f.normal_update()
                if f.normal.dot(n) < 0:
                    f.normal_flip()
        bmesh.ops.remove_doubles(self.bm, verts=[v for v in self.bm.verts if not any(f in loose for f in v.link_faces)], dist=1e-5)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for mm in self.mats:
            me.materials.append(mm)
        for p in me.polygons:
            p.use_smooth = smooth
        o = bpy.data.objects.new(name, me)
        o.location = loc
        collection.objects.link(o)
        return o


def text_mesh(name, body, size, loc, rot, material, collection, extrude=0.01, align="CENTER", font=None):
    cd = bpy.data.curves.new(name, "FONT")
    cd.body = body
    cd.size = size
    cd.align_x = align
    cd.align_y = "CENTER"
    cd.extrude = extrude
    if font:
        cd.font = bpy.data.fonts.load(font, check_existing=True)
    o = bpy.data.objects.new(name, cd)
    o.location = loc
    o.rotation_euler = rot
    cd.materials.append(material)
    collection.objects.link(o)
    return o


def new_scene(name):
    old = bpy.data.scenes.get(name)
    if old:
        for ob in list(old.objects):
            data = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            try:
                if data is not None and data.users == 0:
                    if isinstance(data, bpy.types.Mesh):
                        bpy.data.meshes.remove(data)
                    elif isinstance(data, bpy.types.Curve):
                        bpy.data.curves.remove(data)
            except ReferenceError:
                pass
        bpy.data.scenes.remove(old)
    sc = bpy.data.scenes.new(name)
    for w in bpy.context.window_manager.windows:
        w.scene = sc
    return sc


def relink_images():
    """Pictures saved with the owner's Windows paths (C:/Users/.../JekyllClubGame/...) are pointed at the same
    files in this checkout, then every picture path is stored relative to the .blend, so it opens anywhere."""
    for im in bpy.data.images:
        if im.source != "FILE" or im.packed_file:
            continue
        p = im.filepath.replace("\\", "/")
        if "/JekyllClubGame/" in p and not os.path.exists(bpy.path.abspath(im.filepath)):
            local = os.path.join(ROOT, *p.split("/JekyllClubGame/", 1)[1].split("/"))
            if os.path.exists(local):
                im.filepath = local
                im.reload()
    bpy.ops.file.make_paths_relative()


def export(sc, fname, images=True):
    """images=False leaves pictures out of the file; the game lays them on by material name (look.gd IMG)."""
    if images:
        relink_images()
    for w in bpy.context.window_manager.windows:
        w.scene = sc
    for d in (EXPORTS, MODELS):
        os.makedirs(d, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(d, fname + ".glb"), export_format="GLB", use_active_scene=True,
                                  export_apply=True, export_lights=False, export_cameras=False, export_animations=False,
                                  export_image_format="AUTO" if images else "NONE")


def rng_seed(s):
    import random
    return random.Random(s)
