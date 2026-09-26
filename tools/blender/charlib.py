"""Character builder for The Jekyll Island Club.

People are built from lofted rings (like a tailor's pattern turned into tubes), so every
piece has clean topology, UVs laid out in real meters for cloth textures, and skin weights
that blend smoothly across joints. One 22-bone skeleton is shared by every character, so
every animation plays on everyone.

Blender axes: Z up, characters face -Y. In Godot that is +Z forward.
Material names start with CH_<texture>_ so the game knows which cloth to lay on them.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector


# ------------------------------------------------------------------ small helpers
def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def cmat(name, hexcol, rough=0.8, metal=0.0, emit=None, strength=0.0):
    """Character material. name like 'CH_wool_charcoal'."""
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
    m.diffuse_color = (*col, 1)
    return m


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


# ------------------------------------------------------------------ skeleton
BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0.2, 0), None),
    ("Hips", (0, 0, 0.96), (0, 0, 1.06), "Root"),
    ("Spine", (0, 0, 1.06), (0, 0, 1.24), "Hips"),
    ("Chest", (0, 0, 1.24), (0, 0, 1.44), "Spine"),
    ("Neck", (0, -0.01, 1.46), (0, -0.015, 1.55), "Chest"),
    ("Head", (0, -0.015, 1.55), (0, -0.015, 1.78), "Neck"),
]
for s, sx in (("L", 1), ("R", -1)):
    BONES += [
        ("Shoulder." + s, (0.035 * sx, 0.0, 1.42), (0.17 * sx, 0.01, 1.435), "Chest"),
        ("UpperArm." + s, (0.19 * sx, 0.01, 1.42), (0.215 * sx, 0.025, 1.13), "Shoulder." + s),
        ("LowerArm." + s, (0.215 * sx, 0.025, 1.13), (0.23 * sx, -0.005, 0.875), "UpperArm." + s),
        ("Hand." + s, (0.23 * sx, -0.005, 0.875), (0.235 * sx, -0.015, 0.72), "LowerArm." + s),
        ("UpperLeg." + s, (0.095 * sx, 0.0, 0.94), (0.1 * sx, 0.0, 0.51), "Hips"),
        ("LowerLeg." + s, (0.1 * sx, 0.0, 0.51), (0.1 * sx, 0.025, 0.09), "UpperLeg." + s),
        ("Foot." + s, (0.1 * sx, 0.025, 0.09), (0.1 * sx, -0.11, 0.028), "LowerLeg." + s),
        ("Toe." + s, (0.1 * sx, -0.11, 0.028), (0.1 * sx, -0.18, 0.024), "Foot." + s),
    ]


class Body:
    """Proportions for one person. k scales everything; build widens the middle."""

    def __init__(self, height=1.80, build=1.0, belly=0.0, shoulders=1.0):
        self.k = height / 1.80
        self.build = build
        self.belly = belly
        self.shoulders = shoulders

    def p(self, v):
        v = Vector(v)
        return Vector((v.x * self.build ** 0.3 * self.shoulders ** 0.5, v.y, v.z)) * self.k

    def bone(self, name):
        for b in BONES:
            if b[0] == name:
                h, t = Vector(b[1]), Vector(b[2])
                if name.startswith(("Shoulder", "UpperArm", "LowerArm", "Hand")):
                    h = Vector((h.x * self.shoulders, h.y, h.z))
                    t = Vector((t.x * self.shoulders, t.y, t.z))
                return h * self.k, t * self.k
        raise KeyError(name)


def make_armature(name, body, collection):
    arm = bpy.data.armatures.new(name + "_Rig")
    ob = bpy.data.objects.new(name + "Rig", arm)
    collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, _, _, parent in BONES:
        h, t = body.bone(bname)
        eb = arm.edit_bones.new(bname)
        eb.head = h
        eb.tail = t
        eb.roll = 0.0
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


# ------------------------------------------------------------------ the loft
class Part:
    """Collects rings of vertices into one mesh with UVs (meters) and skin weights."""

    def __init__(self):
        self.verts = []      # Vector
        self.uvs = []        # per vertex (u, v) in meters
        self.weights = []    # per vertex {bone: w}
        self.faces = []      # (vertex indices, material key, uv override or None)
        self.mats = []

    def mat_index(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def add_vert(self, co, uv, w):
        self.verts.append(Vector(co))
        self.uvs.append(uv)
        self.weights.append(dict(w))
        return len(self.verts) - 1

    def loft(self, rings, seg, material, cap_start=True, cap_end=True, face_mat=None, seam_back=True):
        """rings: list of dicts with
             c: center, r: right axis, f: forward axis (unit vectors), rx, rf: radii,
             w: {bone: weight} or callable(point) -> {bone: weight},
             shape: optional callable(theta, ring_index) -> (radius multiplier, extra outward meters)
           theta = 0 points along f (the front), increasing toward r.
           face_mat: optional callable(theta_mid, ring_i, point) -> material or None."""
        rows = []
        vdist = 0.0
        prev_c = None
        for ri, R in enumerate(rings):
            c = Vector(R["c"])
            if prev_c is not None:
                vdist += (c - prev_c).length
            prev_c = c
            r_ax = Vector(R["r"]).normalized()
            f_ax = Vector(R["f"]).normalized()
            row = []
            # perimeter estimate for u in meters
            per = math.pi * (3 * (R["rx"] + R["rf"]) - math.sqrt((3 * R["rx"] + R["rf"]) * (R["rx"] + 3 * R["rf"])))
            for i in range(seg + 1):
                th = 2 * math.pi * i / seg + (math.pi if seam_back else 0.0)
                mul, extra = 1.0, 0.0
                if "shape" in R and R["shape"]:
                    mul, extra = R["shape"](th % (2 * math.pi), ri)
                d = f_ax * math.cos(th) * R["rf"] + r_ax * math.sin(th) * R["rx"]
                dn = d.normalized() if d.length > 1e-9 else f_ax
                p = c + d * mul + dn * extra
                w = R["w"](p) if callable(R["w"]) else R["w"]
                row.append(self.add_vert(p, (per * i / seg, vdist), w))
            rows.append(row)
        for ri in range(len(rows) - 1):
            a, b = rows[ri], rows[ri + 1]
            for i in range(seg):
                th = 2 * math.pi * (i + 0.5) / seg + (math.pi if seam_back else 0.0)
                m = material
                if face_mat:
                    mid = (self.verts[a[i]] + self.verts[a[i + 1]] + self.verts[b[i]] + self.verts[b[i + 1]]) / 4
                    mm = face_mat(th % (2 * math.pi), ri, mid)
                    if mm is not None:
                        m = mm
                self.faces.append(([a[i], a[i + 1], b[i + 1], b[i]], m))
        if cap_start:
            self._cap(rows[0], material, flip=True)
        if cap_end:
            self._cap(rows[-1], material, flip=False)
        return rows

    def _cap(self, row, material, flip):
        ring = row[:-1]
        c = sum((self.verts[i] for i in ring), Vector()) / len(ring)
        w = self.weights[ring[0]]
        ci = self.add_vert(c, (0.0, 0.0), w)
        for i in range(len(ring)):
            a, b = ring[i], ring[(i + 1) % len(ring)]
            self.faces.append(([ci, b, a] if flip else [ci, a, b], material))

    def blob(self, center, radii, material, w, seg=16, rings=10, deform=None, axes=None):
        """Ellipsoid (optionally deformed). deform(dir_local) -> outward meters."""
        center = Vector(center)
        ax = axes or (Vector((1, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)))  # right, forward, up
        rows = []
        for j in range(rings + 1):
            phi = math.pi * j / rings  # 0 top, pi bottom
            row = []
            for i in range(seg + 1):
                th = 2 * math.pi * i / seg
                dl = Vector((math.sin(phi) * math.sin(th), math.sin(phi) * math.cos(th), math.cos(phi)))
                off = deform(dl) if deform else 0.0
                p = center + ax[0] * dl.x * (radii[0] + off) + ax[1] * dl.y * (radii[1] + off) + ax[2] * dl.z * (radii[2] + off)
                ww = w(p) if callable(w) else w
                row.append(self.add_vert(p, (th * radii[0], phi * radii[2]), ww))
            rows.append(row)
        for j in range(rings):
            for i in range(seg):
                a, b = rows[j], rows[j + 1]
                if j == 0:
                    self.faces.append(([a[i], b[i + 1], b[i]], material))
                elif j == rings - 1:
                    self.faces.append(([a[i], a[i + 1], b[i]], material))
                else:
                    self.faces.append(([a[i], a[i + 1], b[i + 1], b[i]], material))
        return rows

    def build(self, name, collection, rig, smooth=True, subdiv=0):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        # layers first: adding a layer later would invalidate the vertex handles
        uvl = bm.loops.layers.uv.new("UVMap")
        dl = bm.verts.layers.deform.verify()
        bvs = [bm.verts.new(v) for v in self.verts]
        bm.verts.ensure_lookup_table()
        names = [b[0] for b in BONES]
        for vi, w in enumerate(self.weights):
            tot = sum(w.values()) or 1.0
            for bn, bw in w.items():
                if bw > 1e-4:
                    bvs[vi][dl][names.index(bn)] = bw / tot
        for idx, m in self.faces:
            try:
                f = bm.faces.new([bvs[i] for i in idx])
            except ValueError:
                continue
            f.material_index = self.mat_index(m)
            for lp, vi in zip(f.loops, idx):
                lp[uvl].uv = self.uvs[vi]
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(m)
        for p in me.polygons:
            p.use_smooth = smooth
        ob = bpy.data.objects.new(name, me)
        collection.objects.link(ob)
        for bn in names:
            ob.vertex_groups.new(name=bn)
        # vertex groups were written through the deform layer by index; names line up with BONES
        if subdiv:
            md = ob.modifiers.new("Sub", "SUBSURF")
            md.levels = subdiv
            md.render_levels = subdiv
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier=md.name)
        ob.parent = rig
        md = ob.modifiers.new("Armature", "ARMATURE")
        md.object = rig
        return ob


# ------------------------------------------------------------------ weights
def wblend(a, b, t):
    t = max(0.0, min(1.0, t))
    if a == b:
        return {a: 1.0}
    return {a: 1.0 - t, b: t}


def w_along(z, spans):
    """spans: list of (z_top, bone) from top to bottom; blends between neighbors near each boundary."""
    for i in range(len(spans) - 1):
        z0, b0 = spans[i]
        z1, b1 = spans[i + 1]
        if z >= z1:
            return wblend(b1, b0, (z - z1) / max(z0 - z1, 1e-6))
    return {spans[-1][1]: 1.0}


# ------------------------------------------------------------------ garment pieces
def ring_frame():
    return Vector((1, 0, 0)), Vector((0, -1, 0))


def torso_w(body):
    k = body.k

    def w(p):
        z = p.z / k
        if z > 1.43:
            return wblend("Chest", "Neck", (z - 1.43) / 0.08)
        if z > 1.26:
            return {"Chest": 1.0}
        if z > 1.12:
            return wblend("Spine", "Chest", (z - 1.12) / 0.14)
        if z > 1.0:
            return wblend("Hips", "Spine", (z - 1.0) / 0.12)
        return {"Hips": 1.0}
    return w


def skirt_w(body, reach=1.0):
    """Coat tails and skirts: hips at the waist, then share with the leg on their own side."""
    k = body.k

    def w(p):
        z = p.z / k
        t = smoothstep(0.92, 0.55, z) * 0.85 * reach
        side = smoothstep(-0.05, 0.05, p.x)
        return {"Hips": 1.0 - t, "UpperLeg.L": t * side, "UpperLeg.R": t * (1 - side)}
    return w


def add_torso(part, body, coat_mat, opts):
    """The coat or jacket body from the waist to the shoulders, with a V opening showing
    shirt and tie, lapel ridges, and buttons. opts keys: shirt, tie, vest, v_depth, lapel,
    top (collar height), buttons, button_mat, pocket_mat."""
    k = body.k
    b = body.build
    bel = body.belly
    sh = body.shoulders
    R, F = ring_frame()
    levels = [
        # z, half width, half depth
        (0.90, 0.165, 0.118),
        (0.96, 0.163 + bel * 0.02, 0.118 + bel * 0.04),
        (1.04, 0.158 + bel * 0.03, 0.118 + bel * 0.06),
        (1.12, 0.160 + bel * 0.02, 0.120 + bel * 0.05),
        (1.20, 0.172, 0.125 + bel * 0.02),
        (1.28, 0.185, 0.128),
        (1.35, 0.196 * sh, 0.126),
        (1.395, 0.204 * sh, 0.118),
        (1.425, 0.19 * sh, 0.104),
        (1.45, 0.15 * sh, 0.088),
        (1.47, 0.1, 0.072),
        (1.485, 0.068, 0.062),
    ]
    v_depth = opts.get("v_depth", 1.22)
    top = opts.get("top", 1.485)
    lapel = opts.get("lapel", 0.012)

    def v_half_angle(z):
        # the opening narrows as it goes down, closing at v_depth
        return max(0.0, (z - v_depth) / (1.47 - v_depth)) * 0.42

    def shape(th, ri):
        z = levels[min(ri, len(levels) - 1)][0]
        mul = 1.0
        # flatter front, rounder back
        front = math.cos(th)
        mul *= 1.0 - 0.06 * max(front, 0.0) ** 3
        # shoulder blades
        if z > 1.28:
            mul *= 1.0 + 0.03 * max(-front, 0.0)
        extra = 0.0
        a = v_half_angle(z)
        d = abs(((th + math.pi) % (2 * math.pi)) - math.pi)
        if a > 0 and lapel > 0:
            extra += lapel * math.exp(-((d - a - 0.08) / 0.07) ** 2)
            if d < a:
                extra -= 0.012
        return mul, extra

    def face_mat(th, ri, mid):
        z = mid.z / k
        d = abs(((th + math.pi) % (2 * math.pi)) - math.pi)
        a = v_half_angle(z)
        if d < a:
            if opts.get("tie") and d < 0.1 and z < 1.46:
                return opts["tie"]
            if opts.get("vest") and z < 1.40:
                return opts["vest"]
            return opts.get("shirt", coat_mat)
        if opts.get("pocket_mat") and 1.315 < z < 1.345 and 0.55 < th < 0.85:
            return opts["pocket_mat"]
        return None

    rings = []
    for z, hx, hf in levels:
        if z > top + 1e-6:
            break
        rings.append({"c": body.p((0, 0.005, z)), "r": R, "f": F,
                      "rx": hx * k * b ** 0.5, "rf": hf * k * b ** 0.5, "w": torso_w(body), "shape": shape})
    part.loft(rings, 32, coat_mat, cap_start=True, cap_end=False, face_mat=face_mat)
    # buttons down the front edge
    bm = opts.get("button_mat")
    if bm and opts.get("buttons", 0):
        n = opts["buttons"]
        for i in range(n):
            z = lerp(v_depth - 0.01, 0.98, i / max(n - 1, 1)) if n > 1 else v_depth - 0.02
            y = -(levels[3][2] * k * b ** 0.5) - 0.004
            part.blob(body.p((0.0, 0, z)) + Vector((0.0, y + 0.004, 0)), (0.011 * k, 0.006 * k, 0.011 * k), bm, torso_w(body), seg=8, rings=5)


def add_skirt(part, body, mat, bottom=0.55, flare=1.18, split=True):
    """Coat tails from the waist down. bottom is the hem height (0.55 = just above the knee)."""
    k = body.k
    b = body.build
    R, F = ring_frame()
    zs = [0.94, 0.90, 0.84, 0.76, 0.68, 0.60, bottom]
    zs = [z for z in zs if z >= bottom]
    if zs[-1] != bottom:
        zs.append(bottom)
    rings = []
    for z in zs:
        t = (0.94 - z) / max(0.94 - bottom, 0.01)
        hx = lerp(0.172, 0.172 * flare + 0.02, t) * k * b ** 0.5
        hf = lerp(0.124, 0.124 * flare + 0.03, t) * k * b ** 0.5

        def shape(th, ri, t=t):
            extra = 0.0
            d = abs(((th + math.pi) % (2 * math.pi)) - math.pi)
            if split:
                # front opening: a slight overlap line where the two panels meet
                extra -= 0.01 * math.exp(-(d / 0.08) ** 2) * t
            # soft folds
            extra += 0.006 * math.sin(th * 7 + 1.3) * t
            return 1.0, extra
        rings.append({"c": body.p((0, 0.01, z)), "r": R, "f": F, "rx": hx, "rf": hf, "w": skirt_w(body), "shape": shape})
    # inner lining so the hem has thickness
    part.loft(rings, 32, mat, cap_start=False, cap_end=False)
    inner = []
    for R0 in reversed(rings):
        R1 = dict(R0)
        R1["rx"] = R0["rx"] - 0.008
        R1["rf"] = R0["rf"] - 0.008
        inner.append(R1)
    part.loft([rings[-1], inner[0]], 32, mat, cap_start=False, cap_end=False)


def add_legs(part, body, trouser_mat, hem=0.1, wide=1.0, boots=False):
    k = body.k
    for s, sx in (("L", 1), ("R", -1)):
        hip, knee = body.bone("UpperLeg." + s)
        _, ankle = body.bone("LowerLeg." + s)
        rings = []
        pts = [
            (0.97, 0.078, 0.09), (0.92, 0.082, 0.092), (0.82, 0.078, 0.086), (0.72, 0.071, 0.077),
            (0.62, 0.064, 0.07), (0.53, 0.058, 0.062), (0.47, 0.056, 0.06), (0.38, 0.058, 0.062),
            (0.28, 0.056, 0.06), (0.19, 0.056, 0.058), (hem, 0.058, 0.06),
        ]
        for z, hx, hf in pts:
            zz = z * k
            if zz > hip.z:
                t = 0.0
                c = Vector((hip.x * 0.75, 0.0, zz))
            elif zz > knee.z:
                t = (hip.z - zz) / (hip.z - knee.z)
                c = hip.lerp(knee, t)
            else:
                t = (knee.z - zz) / (knee.z - ankle.z)
                c = knee.lerp(ankle, t)
            if z > 0.9:
                w = wblend("Hips", "UpperLeg." + s, (0.98 - z) / 0.08 * 0.8 + 0.2)
            elif z > 0.56:
                w = {"UpperLeg." + s: 1.0}
            elif z > 0.46:
                w = wblend("UpperLeg." + s, "LowerLeg." + s, (0.56 - z) / 0.1)
            else:
                w = {"LowerLeg." + s: 1.0}

            def shape(th, ri, z=z):
                # a pressed crease down the front of each leg
                d = abs(((th + math.pi) % (2 * math.pi)) - math.pi)
                return 1.0, 0.004 * math.exp(-(d / 0.18) ** 2) + (0.006 * math.cos(th * 5 + z * 20) if z < 0.3 else 0.0)
            rings.append({"c": c, "r": Vector((1, 0, 0)), "f": Vector((0, -1, 0)), "rx": hx * k * wide * body.build ** 0.35,
                          "rf": hf * k * wide * body.build ** 0.35, "w": w, "shape": shape})
        part.loft(rings, 18, trouser_mat, cap_start=False, cap_end=True)


def add_shoes(part, body, mat, sole_mat=None, boot_top=0.0):
    k = body.k
    for s, sx in (("L", 1), ("R", -1)):
        foot_h, foot_t = body.bone("Foot." + s)
        _, toe_t = body.bone("Toe." + s)
        x = foot_h.x
        # rings run from heel to toe; each ring is a vertical cross-section
        prof = [
            # y, z_center, half width, half height, bone weights
            (0.075, 0.05, 0.034, 0.045, {"Foot." + s: 1.0}),
            (0.05, 0.055, 0.042, 0.055, {"Foot." + s: 1.0}),
            (0.0, 0.058, 0.046, 0.06, {"Foot." + s: 0.7, "LowerLeg." + s: 0.3}),
            (-0.05, 0.05, 0.05, 0.05, {"Foot." + s: 1.0}),
            (-0.1, 0.038, 0.052, 0.038, {"Foot." + s: 0.6, "Toe." + s: 0.4}),
            (-0.145, 0.032, 0.048, 0.032, {"Toe." + s: 1.0}),
            (-0.18, 0.028, 0.038, 0.025, {"Toe." + s: 1.0}),
            (-0.2, 0.026, 0.02, 0.015, {"Toe." + s: 1.0}),
        ]
        rings = []
        for y, zc, hw, hh, w in prof:
            def shape(th, ri, zc=zc, hh=hh):
                # flat sole: squash the bottom half
                c = math.cos(th)
                return (1.0 if c > -0.2 else 1.0), 0.0
            rings.append({"c": Vector((x, y * k, zc * k)), "r": Vector((1, 0, 0)), "f": Vector((0, 0, 1)),
                          "rx": hw * k, "rf": hh * k, "w": w, "shape": shape})
        part.loft(rings, 16, mat, cap_start=True, cap_end=True,
                  face_mat=(lambda th, ri, mid, zlim=0.018 * k: sole_mat if (sole_mat and mid.z < zlim + 0.004) else None))
        if boot_top > 0:
            _, ankle = body.bone("LowerLeg." + s)
            rr = []
            for z in (0.07, 0.12, boot_top):
                rr.append({"c": Vector((x, 0.01 * k, z * k)), "r": Vector((1, 0, 0)), "f": Vector((0, -1, 0)),
                           "rx": 0.05 * k, "rf": 0.055 * k, "w": {"LowerLeg." + s: 1.0}})
            part.loft(rr, 16, mat, cap_start=False, cap_end=True)


def add_arms(part, body, sleeve_mat, cuff_mat=None, hand_mat=None, sleeve_r=1.0, gloves=False):
    k = body.k
    for s, sx in (("L", 1), ("R", -1)):
        sh_h, sh_t = body.bone("Shoulder." + s)
        ua_h, elbow = body.bone("UpperArm." + s)
        _, wrist = body.bone("LowerArm." + s)
        _, hand_t = body.bone("Hand." + s)
        rings = []
        spec = [
            # t along (shoulder start -> wrist), radius, weights
            (-0.06, 0.072, {"Shoulder." + s: 0.6, "Chest": 0.4}),
            (0.0, 0.07, {"Shoulder." + s: 0.5, "UpperArm." + s: 0.5}),
            (0.12, 0.066, {"UpperArm." + s: 1.0}),
            (0.3, 0.062, {"UpperArm." + s: 1.0}),
            (0.45, 0.058, {"UpperArm." + s: 0.75, "LowerArm." + s: 0.25}),
            (0.52, 0.056, {"UpperArm." + s: 0.35, "LowerArm." + s: 0.65}),
            (0.62, 0.054, {"LowerArm." + s: 1.0}),
            (0.82, 0.05, {"LowerArm." + s: 1.0}),
            (0.96, 0.049, {"LowerArm." + s: 1.0}),
            (1.0, 0.049, {"LowerArm." + s: 0.9, "Hand." + s: 0.1}),
        ]
        up_len = (elbow - ua_h).length
        lo_len = (wrist - elbow).length
        for t, r, w in spec:
            if t < 0:
                c = ua_h + (sh_h - ua_h).normalized() * (-t) * 0.5 + Vector((0, 0, 0.01))
                d = (elbow - ua_h).normalized()
            elif t <= 0.5:
                c = ua_h.lerp(elbow, t / 0.5)
                d = (elbow - ua_h).normalized()
            else:
                c = elbow.lerp(wrist, (t - 0.5) / 0.5)
                d = (wrist - elbow).normalized()
            fwd = Vector((0, -1, 0))
            rgt = d.cross(fwd).normalized() if abs(d.dot(fwd)) < 0.99 else Vector((1, 0, 0))
            fwd = rgt.cross(d).normalized()
            rings.append({"c": c, "r": rgt, "f": fwd, "rx": r * k * sleeve_r * body.build ** 0.3, "rf": r * k * sleeve_r * body.build ** 0.3, "w": w})
        # the loft direction runs down the arm; r x f must point along it for outward normals
        part.loft(rings, 16, sleeve_mat, cap_start=True, cap_end=False)
        # sleeve mouth: fold back inward a little so there's no hole
        last = rings[-1]
        inner = dict(last)
        inner["rx"] = last["rx"] * 0.8
        inner["rf"] = last["rf"] * 0.8
        inner["c"] = last["c"] - (wrist - elbow).normalized() * 0.01
        part.loft([last, inner], 16, sleeve_mat, cap_start=False, cap_end=False)
        if cuff_mat:
            c0 = wrist - (wrist - elbow).normalized() * 0.005
            c1 = wrist + (wrist - elbow).normalized() * 0.012
            d = (wrist - elbow).normalized()
            fwd = Vector((0, -1, 0))
            rgt = d.cross(fwd).normalized()
            fwd = rgt.cross(d).normalized()
            part.loft([{"c": c0, "r": rgt, "f": fwd, "rx": 0.042 * k, "rf": 0.04 * k, "w": {"LowerArm." + s: 1.0}},
                       {"c": c1, "r": rgt, "f": fwd, "rx": 0.041 * k, "rf": 0.039 * k, "w": {"Hand." + s: 0.6, "LowerArm." + s: 0.4}}],
                      14, cuff_mat, cap_start=False, cap_end=True)
        add_hand(part, body, s, hand_mat or sleeve_mat, gloves)


def add_hand(part, body, s, mat, gloves=False):
    k = body.k
    wrist, tip = body.bone("Hand." + s)
    d = (tip - wrist).normalized()
    sx = 1 if s == "L" else -1
    side = Vector((sx, 0, 0))
    fwd = Vector((0, -1, 0))
    # palm faces the thigh: its width runs front to back
    rgt = d.cross(fwd).normalized()
    fwd = rgt.cross(d).normalized()
    L = (tip - wrist).length
    w = {"Hand." + s: 1.0}
    rings = []
    spec = [(0.0, 0.022, 0.034), (0.12, 0.024, 0.042), (0.4, 0.022, 0.046), (0.55, 0.02, 0.044), (0.75, 0.017, 0.04), (0.92, 0.013, 0.03), (1.0, 0.008, 0.018)]
    for t, rx, rf in spec:
        c = wrist + d * (t * L) + fwd * (0.004 * k)
        # fingers curl slightly toward the palm side (toward the body)
        c += rgt * (-sx) * (0.012 * k * t * t) * 0.0
        rings.append({"c": c, "r": rgt, "f": fwd, "rx": rx * k * (1.1 if gloves else 1.0), "rf": rf * k * (1.05 if gloves else 1.0), "w": w})
    part.loft(rings, 12, mat, cap_start=True, cap_end=True)
    # thumb, along the front edge of the palm
    base = wrist + d * (0.1 * L) + fwd * (0.03 * k)
    tdir = (d * 0.8 + fwd * 0.45 - rgt * sx * 0.25).normalized()
    tr = tdir.cross(rgt).normalized()
    tf = tr.cross(tdir).normalized()
    thumb = [{"c": base + tdir * (L * t), "r": tr, "f": tf, "rx": r * k, "rf": r * k, "w": w} for t, r in ((0.0, 0.014), (0.2, 0.013), (0.38, 0.011), (0.46, 0.007))]
    part.loft(thumb, 8, mat, cap_start=True, cap_end=True)


def add_neck(part, body, skin_mat):
    k = body.k
    n0, n1 = body.bone("Neck")
    rings = []
    for t, r in ((-0.35, 0.064), (0.0, 0.056), (0.5, 0.054), (1.0, 0.055), (1.25, 0.05)):
        c = n0.lerp(n1, t)
        w = w_along(c.z / k, [(1.58, "Head"), (1.5, "Neck"), (1.45, "Chest")])
        rings.append({"c": c, "r": Vector((1, 0, 0)), "f": Vector((0, -1, 0)), "rx": r * k, "rf": r * k * 1.05, "w": w})
    part.loft(rings, 16, skin_mat, cap_start=True, cap_end=True)


def add_collar(part, body, mat, height=0.06, wing=False):
    """A tall starched collar, the kind every man wore in 1910."""
    k = body.k
    n0, n1 = body.bone("Neck")
    zc0 = n0.z + 0.025 * k
    rings = []
    for z, r in ((zc0, 0.06), (zc0 + height * k * 0.5, 0.058), (zc0 + height * k, 0.059)):
        c = Vector((0, n0.y - 0.004, z))

        def shape(th, ri):
            d = abs(((th + math.pi) % (2 * math.pi)) - math.pi)
            # opening in front, points turned down for wing collars
            return 1.0, (0.004 if d < 0.25 else 0.0)
        rings.append({"c": c, "r": Vector((1, 0, 0)), "f": Vector((0, -1, 0)), "rx": r * k, "rf": r * k * 1.05,
                      "w": w_along(z / k, [(1.6, "Neck"), (1.45, "Chest")]), "shape": shape})
    part.loft(rings, 20, mat, cap_start=False, cap_end=False)
    inner = [dict(R, rx=R["rx"] - 0.004, rf=R["rf"] - 0.004) for R in reversed(rings)]
    part.loft([rings[-1], inner[0]], 20, mat, cap_start=False, cap_end=False)


def add_scarf(part, body, mat):
    """A wool muffler wound once around the neck, both ends hanging down the front."""
    k = body.k
    n0, _ = body.bone("Neck")
    wrap = []
    for z, r in ((1.49, 0.074), (1.51, 0.078), (1.53, 0.074)):
        wrap.append({"c": body.p((0, -0.008, z)), "r": Vector((1, 0, 0)), "f": Vector((0, -1, 0)), "rx": r * k, "rf": r * k * 1.06,
                     "w": w_along(z, [(1.55, "Neck"), (1.45, "Chest")])})
    part.loft(wrap, 20, mat, True, True)
    for sx, drop in ((1, 0.32), (-1, 0.24)):
        tail = []
        for t in range(6):
            u = t / 5
            z = 1.5 - drop * u
            x = sx * (0.035 + 0.01 * u)
            y = -0.135 - 0.01 * u - (0.015 if z > 1.35 else 0.0)
            tail.append({"c": body.p((x, y, z)), "r": Vector((1, 0, 0)), "f": Vector((0, -1, 0)), "rx": 0.035 * k, "rf": 0.008 * k,
                         "w": torso_w(body)(body.p((x, y, z)))})
        part.loft(tail, 8, mat, True, True)


def add_mantle(part, body, mat):
    """A short cape over the shoulders, for the hooded figure."""
    k = body.k
    R, F = ring_frame()
    rings = []
    for z, hx, hf in ((1.5, 0.08, 0.075), (1.46, 0.17, 0.12), (1.4, 0.25, 0.16), (1.3, 0.3, 0.19), (1.16, 0.32, 0.2)):
        def w(p, z=z):
            base = torso_w(body)(p)
            if abs(p.x) > 0.16 * k and z < 1.42:
                side = "L" if p.x > 0 else "R"
                return {"Chest": 0.6, "UpperArm." + side: 0.4}
            return base

        def shape(th, ri):
            return 1.0, 0.01 * math.sin(th * 9) * (ri / 4)
        rings.append({"c": body.p((0, 0.01, z)), "r": R, "f": F, "rx": hx * k, "rf": hf * k, "w": w, "shape": shape})
    part.loft(rings, 32, mat, cap_start=True, cap_end=False)


def add_bowtie(part, body, mat):
    k = body.k
    n0, _ = body.bone("Neck")
    c = Vector((0, n0.y - 0.072 * k, n0.z + 0.018 * k))
    w = {"Neck": 0.5, "Chest": 0.5}
    part.blob(c + Vector((0.022 * k, 0, 0)), (0.022 * k, 0.008 * k, 0.014 * k), mat, w, seg=10, rings=6)
    part.blob(c - Vector((0.022 * k, 0, 0)), (0.022 * k, 0.008 * k, 0.014 * k), mat, w, seg=10, rings=6)
    part.blob(c, (0.007 * k, 0.01 * k, 0.009 * k), mat, w, seg=8, rings=5)


# ------------------------------------------------------------------ the head
class Face:
    """Knobs that make one face different from the next."""

    def __init__(self, jaw=1.0, nose=1.0, nose_len=1.0, brow=1.0, cheeks=1.0, chin=1.0, width=1.0, age=0.3, ears=1.0):
        self.jaw = jaw
        self.nose = nose
        self.nose_len = nose_len
        self.brow = brow
        self.cheeks = cheeks
        self.chin = chin
        self.width = width
        self.age = age
        self.ears = ears


def _g(x, z, x0, z0, sx, sz):
    return math.exp(-(((x - x0) / sx) ** 2 + ((z - z0) / sz) ** 2))


def head_center(body):
    h0, h1 = body.bone("Head")
    return h0 + Vector((0, -0.01 * body.k, 0.1 * body.k))


def head_deform(face, k):
    """How far the skin sits out from the egg, by direction (right, forward, up). The head and the
    hair both use it, so hair can lie right on the scalp."""

    def deform(d):
        # d: unit direction in (right, forward, up)
        x, y, z = d.x, d.y, d.z
        front = max(y, 0.0)
        off = 0.0
        # jaw narrows below the cheekbones, back of the skull stays round
        if z < -0.05:
            off -= (0.012 * (1.2 - face.jaw) + 0.01) * smoothstep(-0.05, -0.8, z) * (abs(x) ** 1.2) * 1.4 * k
        off -= 0.012 * smoothstep(0.2, 0.9, -y) * smoothstep(0.0, -0.9, z) * k  # nape
        off += 0.006 * _g(x, z, 0, 0.35, 0.9, 0.35) * smoothstep(-0.2, -0.9, y) * k  # occiput
        if front > 0:
            # brow ridge
            off += 0.007 * face.brow * _g(abs(x), z, 0.3, 0.27, 0.35, 0.08) * front * k
            # eye sockets
            off -= 0.011 * _g(abs(x), z, 0.36, 0.13, 0.17, 0.1) * front * k
            # cheekbones
            off += 0.006 * face.cheeks * _g(abs(x), z, 0.55, -0.02, 0.2, 0.14) * front * k
            # cheeks hollow a touch with age
            off -= 0.004 * face.age * _g(abs(x), z, 0.45, -0.28, 0.18, 0.15) * front * k
            # nose: a ridge from the brow to a tip, wings at the bottom
            ridge = _g(x, z, 0, 0.02 - 0.08 * (face.nose_len - 1), 0.09 * face.nose, 0.2 * face.nose_len)
            off += 0.027 * face.nose * ridge * front ** 4 * k
            off += 0.009 * face.nose * _g(x, z, 0, -0.14 * face.nose_len, 0.07, 0.05) * front ** 3 * k
            off += 0.006 * _g(abs(x), z, 0.1, -0.15 * face.nose_len, 0.05, 0.04) * front ** 3 * k
            # under the nose, then lips
            off -= 0.004 * _g(x, z, 0, -0.24, 0.1, 0.03) * front * k
            off += 0.005 * _g(x, z, 0, -0.31, 0.22, 0.035) * front ** 2 * k
            off -= 0.003 * _g(x, z, 0, -0.355, 0.24, 0.012) * front ** 2 * k
            off += 0.004 * _g(x, z, 0, -0.39, 0.2, 0.03) * front ** 2 * k
            # chin
            off += 0.012 * face.chin * _g(x, z, 0, -0.62, 0.22, 0.12) * front ** 2 * k
            # temples
            off -= 0.004 * _g(abs(x), z, 0.75, 0.3, 0.12, 0.2) * k
        return off

    return deform


def add_head(part, body, face, skin_mat, eye_mat, brow_mat, lip_mat=None):
    """A face pushed out of an egg: brow, sockets, cheekbones, nose, lips, jaw and chin."""
    k = body.k
    c = head_center(body)
    rx, rf, rz = 0.077 * k * face.width, 0.097 * k, 0.112 * k
    w = {"Head": 1.0}
    deform = head_deform(face, k)
    part.blob(c, (rx, rf, rz), skin_mat, w, seg=36, rings=28, deform=deform)
    # eyes, set back in the sockets
    for sx in (1, -1):
        ex = c + Vector((0.034 * k * sx * face.width, -0.078 * k, 0.014 * k))
        part.blob(ex, (0.0125 * k, 0.009 * k, 0.0105 * k), eye_mat, w, seg=10, rings=6)
        # eyebrows
        bcen = c + Vector((0.036 * k * sx * face.width, -0.088 * k, 0.034 * k))
        part.blob(bcen, (0.019 * k, 0.005 * k, 0.0045 * k), brow_mat, w, seg=10, rings=5,
                  axes=(Vector((math.cos(0.12 * sx), 0, -math.sin(0.12 * sx))), Vector((0, -1, 0)), Vector((math.sin(0.12 * sx), 0, math.cos(0.12 * sx)))))
        # ears
        ec = c + Vector((0.078 * k * sx * face.width, 0.004 * k, 0.0))
        part.blob(ec, (0.008 * k * face.ears, 0.018 * k * face.ears, 0.028 * k * face.ears), skin_mat, w, seg=10, rings=8)
    return c


def add_hair(part, body, face, mat, style="short", bald=0.0, gray=False):
    """Hair as a shell lying on the scalp, cut to a hairline. Toward the edge it thins and tucks under
    the skin, so the line reads as hair growing out, not the rim of a cap. bald clears the top of the
    head, receding from the forehead and leaving a fringe over the ears and around the back."""
    k = body.k
    c = head_center(body)
    brx, brf, brz = 0.077 * k * face.width, 0.097 * k, 0.112 * k
    skin = head_deform(face, k)
    w = {"Head": 1.0}
    seg, rings = 72, 40
    bald_dir = Vector((0.0, 0.35, 1.0)).normalized()
    bald_cos = math.cos(0.25 + bald * 0.95)

    def edge(dl):
        """signed distance inside the hair (positive = covered), in head units"""
        x, y, z = dl
        front = max(y, 0.0)
        wav = 0.02 * math.sin(math.atan2(x, y) * 9.0)   # a hairline is never a perfect curve
        line = 0.55 - 0.25 * (1 - front) - 0.55 * max(-y, 0.0) + wav
        if abs(x) > 0.75 and y > -0.3:
            line = min(line, 0.18 + wav)  # above the ears
        d = z - line
        if bald > 0:
            d = min(d, bald_cos - dl.dot(bald_dir) + 0.5 * wav)
        return d

    thick0 = (0.006 + (0.004 if style == "full" else 0.0)) * k
    rows = []
    for j in range(rings + 1):
        phi = math.pi * 0.7 * j / rings
        row = []
        for i in range(seg + 1):
            th = 2 * math.pi * i / seg
            dl = Vector((math.sin(phi) * math.sin(th), math.sin(phi) * math.cos(th), math.cos(phi)))
            e = edge(dl)
            if e > 0:
                thick = thick0
                if style == "parted":
                    thick += 0.004 * k * _g(dl.x, dl.z, -0.35, 0.8, 0.3, 0.3)
                # combed: shallow grooves running front to back
                comb = 1.0 + 0.14 * math.sin(dl.x * 40.0 + 1.5 * math.sin(dl.y * 4.0))
                off = 0.0008 * k + thick * smoothstep(0.0, 0.14, e) * comb
            else:
                off = 0.0008 * k + 0.004 * k * max(e, -0.1) / 0.1  # tucked under the skin
            off += skin(dl)
            p = c + Vector((dl.x * (brx + off), -dl.y * (brf + off), dl.z * (brz + off)))
            row.append((part.add_vert(p, (th * brx, phi * brz), w), e))
        rows.append(row)
    for j in range(rings):
        for i in range(seg):
            q = [rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]]
            if any(v[1] > 0.0 for v in q):
                if j == 0:
                    part.faces.append(([q[0][0], q[2][0], q[3][0]], mat))
                else:
                    part.faces.append(([v[0] for v in q], mat))


def add_mustache(part, body, mat, kind="plain", size=1.0):
    k = body.k
    c = head_center(body)
    w = {"Head": 1.0}
    if kind == "none":
        return
    base = c + Vector((0, -0.094 * k, -0.029 * k))
    n = 11
    for i in range(n):
        t = (i / (n - 1)) * 2 - 1  # -1..1 left to right
        droop = (0.012 if kind == "walrus" else 0.006) * abs(t) ** 1.6 * k * size
        p = base + Vector((t * 0.028 * k * size * (1.2 if kind == "walrus" else 1.0), 0.012 * k * abs(t) ** 2, -droop))
        r = (0.0085 if kind == "walrus" else 0.0055) * k * size * (1.0 - 0.45 * abs(t))
        part.blob(p, (r * 1.2, r, r * 0.9), mat, w, seg=8, rings=5)


def tube(part, pts, r, mat, w, seg=6, closed=False, up=Vector((0, 0, 1))):
    """A round wire through a list of points."""
    n = len(pts)
    rows = []
    for i, p in enumerate(pts):
        a = pts[(i - 1) % n] if (closed or i > 0) else p
        b = pts[(i + 1) % n] if (closed or i < n - 1) else p
        t = (b - a).normalized()
        u = t.cross(up)
        if u.length < 1e-6:
            u = t.cross(Vector((1, 0, 0)))
        u.normalize()
        v = t.cross(u)
        rows.append([part.add_vert(p + (u * math.cos(2 * math.pi * s / seg) + v * math.sin(2 * math.pi * s / seg)) * r,
                                   (s * r, i * r), w) for s in range(seg)])
    for i in range(n if closed else n - 1):
        ra, rb = rows[i], rows[(i + 1) % n]
        for s in range(seg):
            part.faces.append(([ra[s], ra[(s + 1) % seg], rb[(s + 1) % seg], rb[s]], mat))


def add_spectacles(part, body, mat, width=1.0):
    """Round wire spectacles: two rims, a bridge, and arms back over the ears."""
    k = body.k
    c = head_center(body)
    w = {"Head": 1.0}
    R, wire = 0.0165 * k, 0.0014 * k
    fy = -0.1 * k   # the rims sit just in front of the eyes

    def P(x, y, z):
        return c + Vector((x * k * width, y * k, z * k))
    for sx in (1, -1):
        cc = c + Vector((0.034 * k * sx * width, fy, 0.013 * k))
        rim = [cc + Vector((math.cos(2 * math.pi * i / 24) * R, 0, math.sin(2 * math.pi * i / 24) * R * 0.9)) for i in range(24)]
        tube(part, rim, wire, mat, w, closed=True, up=Vector((0, -1, 0)))
        # the arm, hinged at the outer edge of the rim, then along the temple and over the ear
        arm = [P(0.050 * sx, -0.100, 0.015), P(0.064 * sx, -0.096, 0.016), P(0.075 * sx, -0.064, 0.018),
               P(0.083 * sx, -0.032, 0.022), P(0.086 * sx, -0.004, 0.030), P(0.084 * sx, 0.018, 0.028),
               P(0.080 * sx, 0.030, 0.008)]
        tube(part, arm, wire * 0.85, mat, w)
    bridge = [P(0.0175 * s, -0.101 - 0.004 * (1 - abs(s)), 0.018 + 0.004 * (1 - s * s)) for s in (-1, -0.5, 0, 0.5, 1)]
    tube(part, bridge, wire, mat, w)


def add_glasses(part, body, mat):
    """Pince-nez: two small rims and a bridge, sitting on the nose."""
    k = body.k
    c = head_center(body)
    w = {"Head": 1.0}
    for sx in (1, -1):
        cc = c + Vector((0.032 * k * sx, -0.1 * k, 0.012 * k))
        rows = []
        R = 0.014 * k
        for i in range(17):
            a = 2 * math.pi * i / 16
            rows.append(cc + Vector((math.cos(a) * R, 0, math.sin(a) * R * 0.8)))
        for i in range(16):
            p0, p1 = rows[i], rows[i + 1]
            part.blob((p0 + p1) / 2, (0.0016 * k, 0.0016 * k, 0.0016 * k), mat, w, seg=6, rings=3)
    part.blob(c + Vector((0, -0.106 * k, 0.012 * k)), (0.012 * k, 0.0015 * k, 0.0015 * k), mat, w, seg=6, rings=3)


# ------------------------------------------------------------------ hats
def _revolve(part, center, profile, mat, w, seg=32, squash=(1.0, 1.0), shape=None):
    """profile: list of (radius, height) from outside brim edge inward/upward."""
    rows = []
    for ri, (r, h) in enumerate(profile):
        row = []
        for i in range(seg + 1):
            th = 2 * math.pi * i / seg
            dx, dy = math.sin(th), -math.cos(th)
            dz = shape(th, ri) if shape else 0.0
            p = center + Vector((dx * r * squash[0], dy * r * squash[1], h + dz))
            row.append(part.add_vert(p, (th * r, h + ri * 0.01), w))
        rows.append(row)
    for j in range(len(rows) - 1):
        for i in range(seg):
            a, b = rows[j], rows[j + 1]
            part.faces.append(([a[i], b[i], b[i + 1], a[i + 1]], mat))
    return rows


def add_hat(part, body, face, kind, mat, band_mat=None):
    k = body.k
    c = head_center(body)
    w = {"Head": 1.0}
    top = c + Vector((0, 0.004 * k, 0.062 * k))
    sq = (1.0 * face.width, 1.12)
    if kind == "bowler":
        prof = [(0.155, -0.005), (0.14, 0.0), (0.1, 0.004), (0.098, 0.03), (0.097, 0.06), (0.09, 0.085), (0.07, 0.105), (0.04, 0.115), (0.0, 0.118)]
        prof = [(r * k, h * k) for r, h in prof]
        _revolve(part, top, prof, mat, w, squash=sq, shape=lambda th, ri: (0.02 * k * abs(math.sin(th)) ** 2 if ri <= 1 else 0.0))
        if band_mat:
            _revolve(part, top, [(0.1 * k, 0.004 * k), (0.1 * k, 0.026 * k)], band_mat, w, squash=(sq[0] * 1.012, sq[1] * 1.012))
    elif kind == "homburg":
        prof = [(0.16, 0.0), (0.145, 0.004), (0.102, 0.006), (0.1, 0.05), (0.096, 0.1), (0.07, 0.118), (0.03, 0.11), (0.0, 0.1)]
        prof = [(r * k, h * k) for r, h in prof]

        def crease(th, ri):
            if ri <= 1:
                return 0.022 * k * abs(math.sin(th)) ** 2
            if ri >= 5:
                return -0.018 * k * abs(math.cos(th)) ** 0.5 * (1 - abs(math.sin(th)))
            return 0.0
        _revolve(part, top, prof, mat, w, squash=sq, shape=crease)
        if band_mat:
            _revolve(part, top, [(0.103 * k, 0.006 * k), (0.101 * k, 0.03 * k)], band_mat, w, squash=(sq[0] * 1.01, sq[1] * 1.01))
    elif kind == "top":
        prof = [(0.15, 0.012), (0.14, 0.004), (0.098, 0.004), (0.1, 0.06), (0.104, 0.12), (0.106, 0.17), (0.104, 0.172), (0.0, 0.172)]
        prof = [(r * k, h * k) for r, h in prof]
        _revolve(part, top, prof, mat, w, squash=sq, shape=lambda th, ri: (0.018 * k * abs(math.sin(th)) ** 2 if ri <= 1 else 0.0))
        if band_mat:
            _revolve(part, top, [(0.101 * k, 0.005 * k), (0.103 * k, 0.04 * k)], band_mat, w, squash=(sq[0] * 1.01, sq[1] * 1.01))
    elif kind == "boater":
        prof = [(0.17, 0.0), (0.168, 0.006), (0.1, 0.006), (0.1, 0.07), (0.098, 0.074), (0.0, 0.074)]
        prof = [(r * k, h * k) for r, h in prof]
        _revolve(part, top + Vector((0, 0, -0.004 * k)), prof, mat, w, squash=sq)
        if band_mat:
            _revolve(part, top + Vector((0, 0, -0.004 * k)), [(0.101 * k, 0.008 * k), (0.101 * k, 0.03 * k)], band_mat, w, squash=(sq[0] * 1.012, sq[1] * 1.012))
    elif kind == "cap":
        # a flat cap: soft crown pulled forward over a short stiff peak
        prof = [(0.108, -0.01), (0.112, 0.02), (0.11, 0.045), (0.08, 0.07), (0.0, 0.075)]
        prof = [(r * k, h * k) for r, h in prof]
        _revolve(part, top + Vector((0, -0.01 * k, -0.02 * k)), prof, mat, w, squash=(sq[0] * 1.05, sq[1] * 1.08),
                 shape=lambda th, ri: -0.02 * k * max(0.0, -math.cos(th)) if ri >= 2 else 0.0)
        peak = []
        for i in range(9):
            a = math.pi * (i / 8 - 0.5) * 0.8
            peak.append(Vector((math.sin(a) * 0.1 * k, -math.cos(a) * 0.1 * k * 1.1, 0)))
        for i in range(8):
            p0 = top + Vector((0, -0.012 * k, -0.02 * k)) + peak[i]
            p1 = top + Vector((0, -0.012 * k, -0.02 * k)) + peak[i + 1]
            q0 = p0 + Vector((0, -0.055 * k, -0.012 * k)) * (1 - abs(i - 4) / 6)
            q1 = p1 + Vector((0, -0.055 * k, -0.012 * k)) * (1 - abs(i + 1 - 4) / 6)
            ids = [part.add_vert(v, (v.x, v.y), w) for v in (p0, p1, q1, q0)]
            part.faces.append((ids, mat))
    elif kind == "porter":
        prof = [(0.105, -0.004), (0.106, 0.05), (0.102, 0.056), (0.0, 0.058)]
        prof = [(r * k, h * k) for r, h in prof]
        _revolve(part, top + Vector((0, 0, -0.015 * k)), prof, mat, w, squash=sq)
        for i in range(8):
            a0 = math.pi * (i / 8 - 0.5) * 0.9
            a1 = math.pi * ((i + 1) / 8 - 0.5) * 0.9
            base = top + Vector((0, 0, -0.012 * k))
            p0 = base + Vector((math.sin(a0) * 0.106 * k, -math.cos(a0) * 0.106 * k * 1.12, 0))
            p1 = base + Vector((math.sin(a1) * 0.106 * k, -math.cos(a1) * 0.106 * k * 1.12, 0))
            q0 = p0 + Vector((0, -0.045 * k, -0.018 * k)) * math.cos(a0)
            q1 = p1 + Vector((0, -0.045 * k, -0.018 * k)) * math.cos(a1)
            ids = [part.add_vert(v, (v.x, v.y), w) for v in (p0, p1, q1, q0)]
            part.faces.append((ids, band_mat or mat))
    elif kind == "hood":
        # a deep cowl: crown shaped over the skull, peaked at the back, open in front, skirt onto the shoulders
        rows = []
        J = 16
        for j in range(J + 1):
            phi = math.pi * 0.85 * j / J
            row = []
            for i in range(29):
                th = 2 * math.pi * i / 28
                dl = Vector((math.sin(phi) * math.sin(th), math.sin(phi) * math.cos(th), math.cos(phi)))
                grow = 1.3 + 0.35 * max(0.0, (j - 9) / (J - 9))
                back = max(0.0, -dl.y)
                peak = 0.03 * k * back ** 2 * max(0.0, dl.z)
                p = c + Vector((dl.x * 0.09 * k * grow, -dl.y * 0.105 * k * grow + peak * 0.8, dl.z * 0.125 * k * 1.3 + 0.015 * k + peak))
                if j > 10:
                    p.z -= 0.02 * k * (j - 10)
                row.append((part.add_vert(p, (th * 0.12, phi * 0.12), {"Head": 1.0} if j < 11 else {"Neck": 0.5, "Chest": 0.5}), dl))
            rows.append(row)
        for j in range(J):
            for i in range(28):
                q = [rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]]
                open_front = all(dl.y > 0.38 for _, dl in q) and 3 <= j <= 11
                if open_front:
                    continue
                part.faces.append(([x[0] for x in q], mat))


# ------------------------------------------------------------------ props held in the hand
def add_prop(part, body, kind, mats, side="R"):
    k = body.k
    wrist, tip = body.bone("Hand." + side)
    w = {"Hand." + side: 1.0}
    grip = wrist.lerp(tip, 0.55) + Vector((0, -0.01 * k, 0))
    if kind == "gun_case":
        # a long leather gun case slung across the back on a strap: the duck-hunting cover story
        wb = {"Chest": 1.0}
        top = body.p((-0.16, 0.16, 1.42))
        bot = body.p((0.2, 0.18, 0.78))
        d = (bot - top).normalized()
        r = d.cross(Vector((0, 1, 0))).normalized()
        f = r.cross(d).normalized()
        rings = []
        for t, rr in ((-0.02, 0.02), (0.0, 0.038), (0.1, 0.045), (0.8, 0.04), (0.97, 0.034), (1.0, 0.02)):
            c = top.lerp(bot, t)
            ww = {"Chest": 1.0 - max(0.0, t - 0.6) * 1.5, "Hips": max(0.0, t - 0.6) * 1.5}
            rings.append({"c": c, "r": r, "f": f, "rx": rr * k, "rf": rr * k * 0.7, "w": ww})
        part.loft(rings, 12, mats["leather"], True, True)
        # the strap, running from the right shoulder down across the chest to the left hip
        strap = []
        for t in range(9):
            u = t / 8
            x = lerp(-0.17, 0.19, u)
            z = lerp(1.44, 0.92, u)
            y = -0.13 - 0.02 * math.sin(u * math.pi)
            ww = torso_w(body)(body.p((x, y, z)))
            strap.append({"c": body.p((x, y, z)), "r": Vector((0, -1, 0)), "f": Vector((0.8, 0, 0.6)).normalized(), "rx": 0.004 * k, "rf": 0.02 * k, "w": ww})
        part.loft(strap, 6, mats["leather"], True, True)
    elif kind == "valise":
        c = grip + Vector((0, 0, -0.16 * k))
        rings = []
        for z, hw, hd in ((-0.12, 0.2, 0.06), (-0.11, 0.21, 0.07), (0.1, 0.21, 0.07), (0.12, 0.19, 0.05)):
            rings.append({"c": c + Vector((0, 0, z * k)), "r": Vector((0, -1, 0)), "f": Vector((1, 0, 0)), "rx": hw * k, "rf": hd * k, "w": w})
        part.loft(rings, 16, mats["leather"], cap_start=True, cap_end=True)
        part.blob(grip, (0.01 * k, 0.05 * k, 0.012 * k), mats["leather"], w, seg=8, rings=4)
        part.blob(c + Vector((0, 0, 0.11 * k)), (0.012 * k, 0.1 * k, 0.012 * k), mats["brass"], w, seg=6, rings=3)
    elif kind == "cane":
        top = grip + Vector((0, -0.01 * k, 0.03 * k))
        bottom = top + Vector((0.02 * k, -0.12 * k, -0.84 * k))
        d = (bottom - top).normalized()
        r = Vector((1, 0, 0))
        f = d.cross(r).normalized()
        r = f.cross(d).normalized()
        part.loft([{"c": top, "r": r, "f": f, "rx": 0.011 * k, "rf": 0.011 * k, "w": w},
                   {"c": bottom, "r": r, "f": f, "rx": 0.009 * k, "rf": 0.009 * k, "w": w}], 8, mats["wood"], True, True)
        part.blob(top, (0.016 * k, 0.03 * k, 0.014 * k), mats["brass"], w, seg=8, rings=5)
    elif kind == "lantern":
        c = grip + Vector((0, 0, -0.17 * k))
        part.blob(grip + Vector((0, 0, -0.03 * k)), (0.004 * k, 0.03 * k, 0.03 * k), mats["iron"], w, seg=8, rings=5)
        rings = []
        for z, r in ((-0.09, 0.05), (-0.07, 0.055), (-0.06, 0.045), (0.05, 0.045), (0.07, 0.05), (0.1, 0.03), (0.12, 0.012)):
            rings.append({"c": c + Vector((0, 0, z * k)), "r": Vector((1, 0, 0)), "f": Vector((0, -1, 0)), "rx": r * k, "rf": r * k, "w": w})
        part.loft(rings, 12, mats["iron"], True, True,
                  face_mat=lambda th, ri, mid: mats["lamp"] if ri == 2 else None)
    elif kind == "notebook":
        c = grip + Vector((0, -0.03 * k, 0.0))
        part.blob(c, (0.012 * k, 0.05 * k, 0.07 * k), mats["paper"], w, seg=6, rings=4)
