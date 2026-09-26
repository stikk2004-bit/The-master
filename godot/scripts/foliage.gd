extends RefCounted
## Dresses Blender's smooth canopy and lawn shapes with thousands of leaf, needle,
## moss and grass cards, scattered over those surfaces when a level loads.

const CardShader := preload("res://shaders/foliage.gdshader")

## Blender material -> how to dress it
##   card: texture in res://textures/, size: card size in meters (w, h), density: cards per square meter,
##   mode: "canopy" (faces out from the surface), "hang" (drapes straight down), "grass" (stands up, crossed)
const SPECS := {
	"OakLeaves": {"card": "card_oak", "size": Vector2(1.5, 1.5), "density": 2.2, "mode": "canopy", "tint": "d8e0c8", "max": 2200},
	"Shrub": {"card": "card_shrub", "size": Vector2(0.8, 0.8), "density": 5.0, "mode": "canopy", "tint": "e0e8d0", "max": 3000},
	"PineNeedles": {"card": "card_pine", "size": Vector2(1.2, 1.2), "density": 3.0, "mode": "canopy", "tint": "d0d8c0", "max": 150},
	"PalmettoGreen": {"card": "card_palmetto", "size": Vector2(0.9, 0.9), "density": 3.0, "mode": "canopy", "tint": "e8f0d8", "max": 30},
	"SpanishMoss": {"card": "card_moss", "size": Vector2(0.7, 1.6), "density": 3.5, "mode": "hang", "tint": "d0d4c4", "max": 900},
	"Lawn": {"card": "card_grass", "size": Vector2(0.55, 0.5), "density": 1.6, "mode": "grass", "tint": "c8ccb4", "max": 60000},
}
const CHUNK := 18.0
## surfaces grass must not grow through
const PAVED := ["BrickWalk", "RedClay", "Asphalt", "Concrete", "PorchFloor", "PorchWood", "Brick", "Siding", "Trim"]
const PAVE_CELL := 0.5

static var _mats := {}


static func _material(spec: Dictionary) -> ShaderMaterial:
	var key := String(spec["card"])
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = CardShader
	m.set_shader_parameter("card_tex", load("res://textures/" + key + ".png"))
	m.set_shader_parameter("tint", Color(String(spec.get("tint", "ffffff"))))
	match String(spec["mode"]):
		"grass":
			m.set_shader_parameter("anchor_bottom", 1.0)
			m.set_shader_parameter("wind", 0.08)
			m.set_shader_parameter("wind_speed", 1.6)
			m.set_shader_parameter("roughness", 0.85)
			m.set_shader_parameter("alpha_cut", 0.4)
		"hang":
			m.set_shader_parameter("anchor_top", 1.0)
			m.set_shader_parameter("wind", 0.12)
			m.set_shader_parameter("wind_speed", 0.7)
			m.set_shader_parameter("translucency", 0.5)
		_:
			m.set_shader_parameter("wind", 0.035)
	_mats[key] = m
	return m


static func dress(root: Node, parent: Node3D, seed_value := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var per_kind := {}   # material name -> {chunk key -> Array[Transform3D]}
	var paved := _paved_cells(root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(si)
			if mat == null or not SPECS.has(mat.resource_name):
				continue
			var name := mat.resource_name
			var spec: Dictionary = SPECS[name]
			var arrays := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx = PackedInt32Array(range(verts.size()))
			# triangle areas in world space, for fair sampling
			var tris := []
			var total := 0.0
			var cum := PackedFloat32Array()
			for t in range(0, idx.size(), 3):
				var a := xf * verts[idx[t]]
				var b := xf * verts[idx[t + 1]]
				var c := xf * verts[idx[t + 2]]
				var area := (b - a).cross(c - a).length() * 0.5
				if area <= 1e-6:
					continue
				tris.append([a, b, c])
				total += area
				cum.append(total)
			if tris.is_empty():
				continue
			var count := mini(int(total * float(spec["density"])), int(spec["max"]))
			var bucket: Dictionary = per_kind.get(name, {})
			for k in count:
				var pick := cum.bsearch(rng.randf() * total)
				pick = clampi(pick, 0, tris.size() - 1)
				var tri: Array = tris[pick]
				var u := rng.randf()
				var v := rng.randf()
				if u + v > 1.0:
					u = 1.0 - u
					v = 1.0 - v
				var a3: Vector3 = tri[0]
				var b3: Vector3 = tri[1]
				var c3: Vector3 = tri[2]
				var p := a3 + (b3 - a3) * u + (c3 - a3) * v
				var nrm := (b3 - a3).cross(c3 - a3).normalized()
				if String(spec["mode"]) == "grass" and paved.has(Vector2i(floori(p.x / PAVE_CELL), floori(p.z / PAVE_CELL))):
					continue
				var tfs := _transforms(spec, p, nrm, rng)
				for tf in tfs:
					var ck := "%d,%d" % [floori(p.x / CHUNK), floori(p.z / CHUNK)]
					if not bucket.has(ck):
						bucket[ck] = []
					(bucket[ck] as Array).append(tf)
			per_kind[name] = bucket
	for name in per_kind.keys():
		var spec: Dictionary = SPECS[name]
		var quad := QuadMesh.new()
		quad.size = spec["size"]
		if String(spec["mode"]) == "grass":
			quad.center_offset = Vector3(0.0, (spec["size"] as Vector2).y * 0.5, 0.0)
		elif String(spec["mode"]) == "hang":
			quad.center_offset = Vector3(0.0, -(spec["size"] as Vector2).y * 0.5, 0.0)
		var mat := _material(spec)
		var bucket: Dictionary = per_kind[name]
		for ck in bucket.keys():
			var list: Array = bucket[ck]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = quad
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat
			if String(spec["mode"]) == "grass":
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 42.0
				mmi.visibility_range_end_margin = 6.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			parent.add_child(mmi)


static func _paved_cells(root: Node) -> Dictionary:
	# mark every half-meter cell covered by a path, porch or wall, seen from above
	var cells := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(si)
			if mat == null or not PAVED.has(mat.resource_name):
				continue
			var arrays := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx = PackedInt32Array(range(verts.size()))
			for t in range(0, idx.size(), 3):
				var a := xf * verts[idx[t]]
				var b := xf * verts[idx[t + 1]]
				var c := xf * verts[idx[t + 2]]
				_raster(cells, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
	return cells


static func _raster(cells: Dictionary, a: Vector2, b: Vector2, c: Vector2) -> void:
	var lo := Vector2i(floori(minf(a.x, minf(b.x, c.x)) / PAVE_CELL), floori(minf(a.y, minf(b.y, c.y)) / PAVE_CELL))
	var hi := Vector2i(floori(maxf(a.x, maxf(b.x, c.x)) / PAVE_CELL), floori(maxf(a.y, maxf(b.y, c.y)) / PAVE_CELL))
	if (hi.x - lo.x) * (hi.y - lo.y) > 40000:
		return
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-6:
		return
	for gx in range(lo.x, hi.x + 1):
		for gz in range(lo.y, hi.y + 1):
			var p := Vector2((gx + 0.5) * PAVE_CELL, (gz + 0.5) * PAVE_CELL)
			var w0 := (b - p).cross(c - p) / area
			var w1 := (c - p).cross(a - p) / area
			var w2 := 1.0 - w0 - w1
			if w0 >= -0.15 and w1 >= -0.15 and w2 >= -0.15:
				cells[Vector2i(gx, gz)] = true


static func _transforms(spec: Dictionary, p: Vector3, nrm: Vector3, rng: RandomNumberGenerator) -> Array:
	var out := []
	var s := rng.randf_range(0.75, 1.25)
	match String(spec["mode"]):
		"canopy":
			# face roughly outward, spun at random about that direction
			var z := (nrm + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.6), rng.randf_range(-0.6, 0.6))).normalized()
			var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
			var x := up.cross(z).normalized()
			var y := z.cross(x).normalized()
			var b := Basis(x, y, z).rotated(z, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
			out.append(Transform3D(b, p + nrm * 0.05))
		"hang":
			var yaw := rng.randf_range(0.0, TAU)
			var b2 := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
			out.append(Transform3D(b2, p - Vector3(0, 0.05, 0)))
		"grass":
			var yaw2 := rng.randf_range(0.0, TAU)
			var tilt := Basis(Vector3(1, 0, 0), rng.randf_range(-0.12, 0.12))
			var b3 := (Basis(Vector3.UP, yaw2) * tilt).scaled(Vector3(s, s * rng.randf_range(0.7, 1.3), s))
			out.append(Transform3D(b3, p))
			out.append(Transform3D(Basis(Vector3.UP, yaw2 + PI / 2.0) * tilt.scaled(Vector3(s, s, s)), p))
	return out
