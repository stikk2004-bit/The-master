extends RefCounted
## The game's look: textured materials, sky, fog, light and color grading.
## Rooms are still modeled in Blender with plain colors. When a model loads, apply()
## swaps each Blender material for a textured one by name (see MATS below), keeping
## the Blender color as the average color of the new surface.

const TEX := "res://textures/"
const WorldShader := preload("res://shaders/world.gdshader")
const SkyShader := preload("res://shaders/sky.gdshader")

## Blender material name -> [texture set, meters per repeat, options]
## options:
##   orig     true keeps the Blender color as the surface's average color (default true)
##   tint     "#hex" color to multiply instead (orig is then ignored)
##   desat    0..1 pulls color toward gray (the look runs a little drained)
##   bright   multiplies the result
##   moss, dust, grime, nstr (normal strength), rough (roughness scale), metal, vgrain, obj
const MATS := {
	# ----- out front
	"Siding": ["siding", 2.0, {"desat": 0.3, "bright": 0.8}],
	"SidingWhite": ["siding", 2.6, {"desat": 0.3, "bright": 0.82}],
	"SidingYellow": ["siding", 2.6, {"desat": 0.3, "bright": 0.82}],
	"Trim": ["painted_wood", 1.6, {"desat": 0.25, "bright": 0.8}],
	"TrimWhite": ["painted_wood", 1.6, {"desat": 0.25, "bright": 0.8}],
	"PorchFloor": ["wood_porch", 3.2, {"orig": false, "grime": 0.2}],
	"PorchWood": ["wood_porch", 3.2, {"orig": false}],
	"RoofSlate": ["slate_roof", 3.0, {"orig": false, "moss": 0.35, "grime": 0.0}],
	"RoofTin": ["tin_roof", 2.5, {"orig": false, "grime": 0.0}],
	"Brick": ["brick", 2.2, {"orig": false, "moss": 0.35, "bright": 0.85}],
	"BrickWalk": ["brick", 1.8, {"orig": false, "bright": 0.8, "moss": 0.6, "grime": 0.0}],
	"DoorWood": ["wood_dark", 1.2, {"vgrain": true}],
	"DoorRed": ["painted_wood", 1.2, {"desat": 0.2}],
	"Iron": ["iron", 1.2, {"orig": false}],
	"Brass": ["brass", 0.7, {"orig": false}],
	"ClubGreen": ["painted_wood", 1.0, {"desat": 0.1}],
	"Lawn": ["grass_ground", 4.5, {"orig": false, "grime": 0.0}],
	"Ground": ["grass_ground", 4.5, {"orig": false, "grime": 0.0}],
	"RedClay": ["red_clay", 3.0, {"orig": false, "grime": 0.0}],
	"OakBark": ["bark", 1.8, {"orig": false, "moss": 0.7, "grime": 0.0}],
	"PineBark": ["bark", 1.4, {"orig": false, "tint": "#b8a898", "grime": 0.0}],
	"OakLeaves": ["foliage", 2.2, {"orig": false, "tint": "#5a6048", "grime": 0.0, "rough": 1.1}],
	"PineNeedles": ["foliage", 1.6, {"orig": false, "tint": "#5a6050", "grime": 0.0}],
	"PalmettoGreen": ["palmetto", 1.0, {"orig": false, "grime": 0.0}],
	"Palmetto": ["palmetto", 1.0, {"orig": false, "grime": 0.0}],
	"Shrub": ["foliage", 1.3, {"orig": false, "tint": "#50584a", "grime": 0.0}],
	"GroundsWood": ["wood_porch", 1.2, {"grime": 0.2}],
	"GroundsStone": ["stone_blocks", 1.0, {"orig": false, "moss": 0.6, "bright": 0.85}],
	"SpanishMoss": ["spanish_moss", 1.2, {"orig": false, "grime": 0.0}],
	# ----- the Grand Lobby
	"L_Parquet": ["wood_planks", 3.2, {"orig": false, "bright": 0.75, "grime": 0.25}],
	"L_WallGreen": ["wallpaper", 2.2, {"orig": false, "bright": 0.9}],
	"L_Ceiling": ["plaster", 3.0, {"desat": 0.2, "bright": 0.75, "grime": 0.0}],
	"L_Walnut": ["wood_dark", 1.0, {"nstr": 0.4}],
	"L_WalnutDark": ["wood_dark", 1.0, {"nstr": 0.4}],
	"L_Cream": ["painted_wood", 1.2, {"desat": 0.3, "bright": 0.78}],
	"L_Leather": ["leather", 0.8, {}],
	"L_Cork": ["cork", 0.8, {}],
	"L_Rug": ["rug", 3.6, {"orig": false, "bright": 0.62, "desat": 0.25, "grime": 0.0}],
	"L_Pot": ["red_clay", 0.8, {}],
	"L_Paper": ["paper", 0.5, {"grime": 0.0}],
	# ----- the Library
	"Lib_Oxblood": ["plaster_dark", 2.6, {"grime": 0.5}],
	"Lib_Rug": ["rug", 3.6, {"orig": false, "tint": "#8a7a70", "desat": 0.3, "bright": 0.7, "grime": 0.0}],
	"Lib_RugBorder": ["wool", 1.0, {"grime": 0.0}],
	"Lib_Book0": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book1": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book2": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book3": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book4": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book5": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book6": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book7": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Book8": ["leather", 0.35, {"grime": 0.0}],
	"Lib_Vol_1": ["leather", 0.3, {"grime": 0.0}],
	"Lib_Vol_2": ["leather", 0.3, {"grime": 0.0}],
	"Lib_Vol_3": ["leather", 0.3, {"grime": 0.0}],
	"Lib_Vol_4": ["leather", 0.3, {"grime": 0.0}],
	"Lib_Gilt": ["brass", 0.4, {"orig": false, "grime": 0.0}],
	# ----- Hoboken, 1910
	"HB_Cinder": ["gravel", 3.0, {"tint": "#6a6258", "grime": 0.0}],
	"HB_Ballast": ["gravel", 1.6, {"orig": false, "bright": 0.8, "grime": 0.0}],
	"HB_Tie": ["rough_timber", 1.2, {"tint": "#5a4a3a", "grime": 0.0}],
	"HB_Rail": ["iron", 0.8, {"orig": false}],
	"HB_PlatformTop": ["concrete", 3.0, {"desat": 0.2, "grime": 0.0}],
	"HB_PlatformEdge": ["brick", 1.8, {"orig": false, "bright": 0.7}],
	"HB_Brick": ["brick", 2.2, {"orig": false, "bright": 0.75, "moss": 0.1}],
	"HB_BrickDark": ["brick", 2.4, {"orig": false, "bright": 0.95, "desat": 0.25}],
	"HB_Stone": ["stone_blocks", 2.0, {"desat": 0.2}],
	"HB_Tin": ["tin_roof", 2.2, {"orig": false, "bright": 0.7, "grime": 0.0}],
	"HB_Iron": ["iron", 1.0, {"orig": false}],
	"HB_Crate": ["rough_timber", 1.0, {"grime": 0.25}],
	"HB_CrateDark": ["rough_timber", 1.0, {"grime": 0.0}],
	"HB_Barrel": ["wood_planks", 0.9, {"vgrain": true, "grime": 0.3}],
	"HB_Coal": ["gravel", 1.2, {"tint": "#2a2a2a", "rough": 0.6, "grime": 0.0}],
	"HB_Cobble": ["cobblestone", 2.4, {"orig": false, "bright": 0.7, "grime": 0.0}],
	"HB_Wood": ["wood_porch", 2.0, {"grime": 0.3}],
	"HB_Slate": ["slate_roof", 3.0, {"orig": false, "grime": 0.0}],
	"HB_Fence": ["rough_timber", 1.4, {"vgrain": true}],
	"HB_Path": ["gravel", 1.3, {"tint": "#9a8e76", "grime": 0.0}],
	"HB_Planks": ["wood_planks", 1.4, {"tint": "#6a5642", "grime": 0.25}],
	"HB_SignPaint": ["painted_wood", 0.8, {"grime": 0.15}],
	"HB_Sack": ["linen", 1.0, {"tint": "#7a6c52", "grime": 0.3}],
	"TR_Maroon": ["painted_metal", 2.0, {"nstr": 0.6, "grime": 0.0, "obj": true}],
	"TR_Green": ["painted_metal", 2.0, {"nstr": 0.6, "grime": 0.0, "obj": true}],
	"TR_Black": ["painted_metal", 2.0, {"nstr": 0.5, "grime": 0.0, "obj": true}],
	"TR_Roof": ["tin_roof", 2.0, {"tint": "#3a3634", "grime": 0.0}],
	"TR_Iron": ["iron", 1.0, {"orig": false, "bright": 0.8}],
	"TR_Brass": ["brass", 0.5, {"orig": false}],
	"TR_Boxcar": ["rough_timber", 1.2, {"vgrain": true, "grime": 0.3}],
	"MC_Body": ["painted_metal", 1.2, {"nstr": 0.3, "rough": 0.6, "obj": true, "grime": 0.0}],
	"MC_Trim": ["leather", 0.6, {"obj": true, "grime": 0.0}],
	"MC_Tire": ["leather", 0.4, {"obj": true, "grime": 0.0}],
	"MC_Leather": ["leather", 0.4, {"obj": true, "grime": 0.0}],
	# ----- the private car
	"PC_Mahogany": ["wood_dark", 0.9, {"grime": 0.15, "nstr": 0.4}],
	"PC_Inlay": ["wood_light", 0.8, {"grime": 0.0}],
	"PC_Ceiling": ["plaster", 2.0, {"desat": 0.1, "bright": 0.9, "grime": 0.0}],
	"PC_Gilt": ["brass", 0.4, {"orig": false, "grime": 0.0}],
	"PC_Carpet": ["rug", 2.2, {"tint": "#6a8a70", "desat": 0.2, "bright": 0.6, "grime": 0.0}],
	"PC_Floor": ["wood_planks", 2.0, {}],
	"PC_Tile": ["concrete", 1.2, {"grime": 0.3}],
	"PC_Velvet": ["velvet", 0.5, {"grime": 0.0}],
	"PC_Leather": ["leather", 0.5, {"grime": 0.0}],
	"PC_Linen": ["linen", 0.4, {"grime": 0.0}],
	"PC_Silver": ["iron_clean", 0.3, {"tint": "#e0dcd4", "rough": 0.4, "grime": 0.0}],
	"PC_Iron": ["iron", 0.8, {"orig": false}],
	"PC_Blind": ["linen", 0.4, {"grime": 0.0}],
	"PC_Galley": ["painted_metal", 1.0, {"nstr": 0.5, "grime": 0.3}],
	"PC_JacketWhite": ["linen", 0.3, {"grime": 0.0}],
	"PC_Paper": ["paper", 0.4, {"grime": 0.0}],
	"PC_Valise": ["leather", 0.4, {"grime": 0.0}],
	# ----- the meeting room on Jekyll Island
	"JK_Oak": ["wood_dark", 1.0, {"grime": 0.15, "nstr": 0.4}],
	"JK_Plaster": ["plaster", 3.0, {"desat": 0.35, "bright": 0.8, "grime": 0.3, "nstr": 0.6}],
	"JK_Floor": ["wood_planks", 3.0, {"orig": false, "bright": 0.8}],
	"JK_Ceiling": ["plaster", 2.4, {"grime": 0.0}],
	"JK_Stone": ["stone_blocks", 1.2, {"orig": false, "bright": 0.85}],
	"JK_Brick": ["brick", 1.0, {"orig": false, "bright": 0.4}],
	"JK_Baize": ["velvet", 0.4, {"grime": 0.0}],
	"JK_Leather": ["leather", 0.5, {"grime": 0.0}],
	"JK_Brass": ["brass", 0.4, {"orig": false, "grime": 0.0}],
	"JK_Paper": ["paper", 0.35, {"grime": 0.0}],
	"JK_Rug": ["rug", 3.0, {"orig": false, "bright": 0.6, "desat": 0.2, "grime": 0.0}],
	"JK_Book": ["leather", 0.3, {"grime": 0.0}],
	"JK_Gun": ["wood_dark", 0.5, {"grime": 0.0}],
	# ----- the Honey House
	"HY_Planks": ["wood_planks", 2.4, {"tint": "#b08a60", "vgrain": true, "grime": 0.3}],
	"HY_Floor": ["wood_planks", 2.6, {"orig": false, "bright": 0.9}],
	"HY_Porch": ["wood_porch", 2.6, {"orig": false}],
	"HY_Beam": ["rough_timber", 1.2, {"tint": "#8a6a4a"}],
	"HY_Tin": ["tin_roof", 2.0, {"orig": false, "grime": 0.0}],
	"HY_HiveWhite": ["painted_wood", 0.8, {"desat": 0.1, "grime": 0.2}],
	"HY_HiveTop": ["iron_clean", 0.6, {"orig": false, "tint": "#b0b0ac", "grime": 0.0}],
	"HY_Comb": ["honeycomb", 0.18, {"orig": false, "grime": 0.0, "obj": true}],
	"HY_Lid": ["brass", 0.2, {"orig": false, "grime": 0.0}],
	"HY_Steel": ["iron_clean", 0.8, {"tint": "#c8c8c4", "grime": 0.1}],
	"HY_Iron": ["iron", 0.6, {"orig": false}],
	"HY_Block": ["concrete", 0.6, {}],
	"HY_Veil": ["linen", 0.3, {"grime": 0.0}],
	"HY_Straw": ["straw", 0.3, {"orig": false, "grime": 0.0}],
	"HY_Ground": ["grass_ground", 5.0, {"orig": false, "bright": 0.5, "grime": 0.0}],
	# ----- the Drafting Room
	"DR_Walnut": ["wood_dark", 1.0, {"nstr": 0.4}],
	"DR_Plaster": ["plaster", 3.0, {"desat": 0.1, "grime": 0.2, "nstr": 0.6}],
	"DR_Floor": ["parquet", 2.4, {"orig": false, "bright": 0.8}],
	"DR_Ceiling": ["plaster", 3.0, {"grime": 0.0}],
	"DR_Gilt": ["brass", 0.3, {"orig": false, "grime": 0.0}],
	"DR_Brass": ["brass", 0.3, {"orig": false, "grime": 0.0}],
	"DR_Leather": ["leather", 0.4, {"grime": 0.0}],
	"DR_Paper": ["paper", 0.3, {"grime": 0.0}],
	"DR_Book": ["leather", 0.3, {"grime": 0.0}],
	"DR_Steel": ["iron_clean", 0.4, {"grime": 0.0}],
	"DR_Pot": ["red_clay", 0.6, {}],
	"DR_Plant": ["palmetto", 0.5, {"orig": false, "grime": 0.0}],
	# ----- the Trading Floor
	"TF_Wall": ["wood_dark", 1.2, {"nstr": 0.4, "bright": 0.9}],
	"TF_Floor": ["wood_planks", 2.8, {"orig": false, "bright": 0.45}],
	"TF_Ceiling": ["plaster_dark", 3.0, {"grime": 0.0, "bright": 0.6}],
	"TF_Desk": ["wood_dark", 1.0, {"nstr": 0.4}],
	"TF_Bezel": ["painted_metal", 0.8, {"nstr": 0.3, "grime": 0.1}],
	"TF_Metal": ["iron_clean", 0.6, {"grime": 0.0}],
	"TF_Brass": ["brass", 0.3, {"orig": false, "grime": 0.0}],
	"TF_Leather": ["leather", 0.4, {"grime": 0.0}],
	"TF_Rug": ["wool", 1.0, {"grime": 0.0}],
}

## Glowing Blender materials: [color, emission energy]
const EMIT := {
	"LampGlass": ["ff9a40", 0.22],
	"LampFlame": ["ffa040", 5.0],
	"GlassLit": ["ffb466", 0.6],
	"DoorDusk": ["6a7a9a", 0.5],
	"L_Bulb": ["ffcc80", 2.2],
	"T_Gold": ["ffc070", 1.0],
	"T_Amber": ["f09a30", 1.1],
	"T_Blue": ["c8d8f0", 0.8],
	"T_Green": ["58c080", 0.9],
	"Lib_Flame": ["ff9a3a", 4.0],
	"Lib_LampGreen": ["2a7a4a", 0.6],
	"HB_WindowLit": ["ffb060", 0.9],
	"HB_LampGlass": ["ffb050", 1.2],
	"HB_SwitchRed": ["ff3020", 2.4],
	"HB_SwitchGreen": ["40ff80", 2.0],
	"TR_RedLamp": ["ff2a14", 2.5],
	"TR_Headlamp": ["ffe0a0", 5.0],
	"TR_Firebox": ["ff7020", 2.5],
	"MC_Lamp": ["ffd890", 3.0],
	"PC_Lamp": ["ffc070", 2.2],
	"PC_StoveGlow": ["ff6a20", 2.0],
	"JK_Lamp": ["ffc070", 2.2],
	"JK_Fire": ["ff7020", 4.0],
	"JK_Ember": ["ff4010", 1.4],
}

## Painted pictures that glow: [texture in res://textures/, emission energy]
const IMG := {
	"TR_Blinds": ["blinds.png", 1.6],
	"TR_CoachWindow": ["coach_window.png", 0.5],
	"HB_Skyline": ["skyline.png", 1.1],
	"HB_Clock": ["clock_face.png", 0.5],
	"JK_Window": ["marsh_window.png", 1.3],
	"JK_Chalkboard": ["chalkboard_1910.png", 0.0],
	"HY_Label": ["honey_label.jpg", 0.0],
	"HY_Logo": ["bees_logo.png", 0.0],
	"HY_Sky": ["farm_dusk.png", 1.3],
	"HY_Clipboard": ["clipboard_bees.png", 0.0],
	"DR_Pricing": ["pricing_chalk.png", 0.0],
	"DR_Blueprint": ["blueprint.png", 0.0],
	"DR_Work_roots": ["work_roots.jpg", 0.45],
	"DR_Work_gogit": ["work_go-git-er.jpg", 0.45],
	"DR_Work_tinytides": ["work_tinytides.jpg", 0.45],
	"DR_Work_zv": ["work_zv.jpg", 0.45],
	"DR_Work_prscms": ["work_pearl-river.jpg", 0.45],
	"DR_Work_farm": ["work_40-acre.jpg", 0.45],
	"TF_Plaque": ["plaque_no_course.png", 0.0],
	"TF_ScreenCheckin": ["screen_checkin.png", 1.4],
	"TF_ScreenJournal": ["screen_journal.png", 1.4],
	"TF_ScreenPartner": ["screen_partner.png", 1.4],
	"TF_ScreenMembers": ["screen_members.png", 1.4],
	"TF_Ticker": ["ticker.png", 1.5],
}

static var _tex := {}
static var _mean := {}
static var _made := {}


static func _texset(name: String) -> Array:
	if not _tex.has(name):
		_tex[name] = [
			load(TEX + name + "_albedo.jpg"),
			load(TEX + name + "_normal.jpg"),
			load(TEX + name + "_orm.jpg"),
		]
	return _tex[name]


static func _mean_linear(name: String) -> Color:
	# average color of a texture in linear light, so we can scale a tint to hit a target
	if _mean.has(name):
		return _mean[name]
	var t: Texture2D = _texset(name)[0]
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var steps := 24
	for i in steps:
		for j in steps:
			var c := img.get_pixel(int((i + 0.5) * img.get_width() / steps), int((j + 0.5) * img.get_height() / steps)).srgb_to_linear()
			r += c.r
			g += c.g
			b += c.b
	var n := float(steps * steps)
	var m := Color(r / n, g / n, b / n)
	_mean[name] = m
	return m


static func _hex(h: String) -> Color:
	return Color(h)


static func make(tex_name: String, tile: float, opts: Dictionary, orig_color := Color(1, 1, 1)) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [tex_name, tile, str(opts), orig_color.to_html()]
	if _made.has(key):
		return _made[key]
	var m := ShaderMaterial.new()
	m.shader = WorldShader
	var s := _texset(tex_name)
	m.set_shader_parameter("albedo_tex", s[0])
	m.set_shader_parameter("normal_tex", s[1])
	m.set_shader_parameter("orm_tex", s[2])
	m.set_shader_parameter("macro_tex", load(TEX + "macro.png"))
	m.set_shader_parameter("tile_meters", tile)

	var lin := Color(1, 1, 1)
	if opts.has("tint"):
		lin = _hex(String(opts["tint"])).srgb_to_linear()
	elif opts.get("orig", true):
		var want := orig_color.srgb_to_linear()
		var have := _mean_linear(tex_name)
		lin = Color(want.r / maxf(have.r, 0.01), want.g / maxf(have.g, 0.01), want.b / maxf(have.b, 0.01))
	var desat: float = opts.get("desat", 0.0)
	if desat > 0.0:
		var l := lin.r * 0.2126 + lin.g * 0.7152 + lin.b * 0.0722
		lin = Color(lerpf(lin.r, l, desat), lerpf(lin.g, l, desat), lerpf(lin.b, l, desat))
	var bright: float = opts.get("bright", 1.0)
	lin = Color(lin.r * bright, lin.g * bright, lin.b * bright)
	m.set_shader_parameter("tint", lin.linear_to_srgb())
	m.set_shader_parameter("normal_strength", opts.get("nstr", 1.0))
	m.set_shader_parameter("rough_scale", opts.get("rough", 1.0))
	m.set_shader_parameter("metal_scale", opts.get("metal", 1.0))
	m.set_shader_parameter("moss_amount", opts.get("moss", 0.0))
	m.set_shader_parameter("dust_amount", opts.get("dust", 0.0))
	m.set_shader_parameter("grime_strength", opts.get("grime", 0.35))
	m.set_shader_parameter("vertical_grain", opts.get("vgrain", false))
	m.set_shader_parameter("object_space", opts.get("obj", false))
	if opts.has("emit"):
		m.set_shader_parameter("emission_color", _hex(String(opts["emit"])))
		m.set_shader_parameter("emission_energy", opts.get("emit_energy", 1.0))
	_made[key] = m
	return m


## Cloth and skin on characters: meters per repeat for each texture (their UVs are in meters).
const CLOTH_TILE := {
	"wool": 0.14, "tweed": 0.16, "linen": 0.12, "velvet": 0.12, "leather": 0.25, "skin": 0.12,
	"straw": 0.12, "brass": 0.1, "iron": 0.2, "iron_clean": 0.2, "wood_dark": 0.3, "paper": 0.2,
}


static func cloth(tex_name: String, src: BaseMaterial3D) -> StandardMaterial3D:
	var key := "cloth|%s|%s" % [tex_name, src.resource_name]
	if _made.has(key):
		return _made[key]
	var s := _texset(tex_name)
	var m := StandardMaterial3D.new()
	m.resource_name = src.resource_name
	var want := src.albedo_color.srgb_to_linear()
	var have := _mean_linear(tex_name)
	var lin := Color(want.r / maxf(have.r, 0.01), want.g / maxf(have.g, 0.01), want.b / maxf(have.b, 0.01))
	m.albedo_color = lin.linear_to_srgb()
	m.albedo_texture = s[0]
	m.normal_enabled = true
	m.normal_texture = s[1]
	# fine weaves shimmer at a distance if their bumps are strong
	m.normal_scale = 0.2 if tex_name in ["linen", "wool", "tweed", "velvet"] else 0.5
	m.ao_enabled = true
	m.ao_texture = s[2]
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = s[2]
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = clampf(src.roughness * 1.25, 0.2, 1.0)
	m.metallic = src.metallic
	if src.metallic > 0.1:
		m.metallic_texture = s[2]
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	var tile: float = CLOTH_TILE.get(tex_name, 0.3)
	m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if tex_name == "skin":
		# a touch of light through the skin keeps faces from going gray in lamplight
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.25
		m.rim_enabled = true
		m.rim = 0.15
		m.rim_tint = 0.6
	elif tex_name in ["wool", "velvet", "tweed"]:
		# the soft sheen wool and felt pick up at the edges
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.4
	_made[key] = m
	return m


## Swap Blender materials under root for textured ones. extra overrides MATS for this call.
static func apply(root: Node, extra := {}, object_space := false) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var nm := src.resource_name
			if nm.begins_with("CH_") and src is BaseMaterial3D:
				var tex_name := nm.substr(3, nm.find("__") - 3)
				mi.set_surface_override_material(i, cloth(tex_name, src as BaseMaterial3D))
				continue
			if nm.begins_with("CHX_"):
				continue
			if IMG.has(nm):
				mi.set_surface_override_material(i, _picture(nm))
				continue
			if EMIT.has(nm) and src is BaseMaterial3D:
				mi.set_surface_override_material(i, _glow(src as BaseMaterial3D, EMIT[nm]))
				continue
			var spec = extra.get(nm, MATS.get(nm, null))
			if spec == null:
				_soften(src)
				continue
			var opts: Dictionary = (spec[2] as Dictionary).duplicate()
			if object_space:
				opts["obj"] = true
			var orig := Color(1, 1, 1)
			if src is BaseMaterial3D:
				orig = (src as BaseMaterial3D).albedo_color
			mi.set_surface_override_material(i, make(String(spec[0]), float(spec[1]), opts, orig))


static func _picture(nm: String) -> Material:
	var key := "img|" + nm
	if _made.has(key):
		return _made[key]
	var spec: Array = IMG[nm]
	var tex: Texture2D = load(TEX + String(spec[0]))
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if float(spec[1]) > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = float(spec[1])
	if nm == "TF_Ticker":
		# the ticker crawls along by itself
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded;\nuniform sampler2D tex : source_color, repeat_enable, filter_linear_mipmap;\nuniform float speed = 0.035;\nvoid fragment() {\n\tvec3 c = texture(tex, vec2(UV.x + TIME * speed, UV.y)).rgb;\n\tALBEDO = c;\n\tEMISSION = c * 1.3;\n}"
		sm.shader = sh
		sm.set_shader_parameter("tex", tex)
		_made[key] = sm
		return sm
	if nm == "HY_Logo":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.3
	if nm == "HB_Skyline":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_made[key] = m
	return m


static func _glow(src: BaseMaterial3D, spec: Array) -> StandardMaterial3D:
	var key := "glow|" + src.resource_name
	if _made.has(key):
		return _made[key]
	var m := src.duplicate() as StandardMaterial3D
	var c := Color(String(spec[0]))
	m.albedo_color = c.darkened(0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = float(spec[1])
	m.roughness = 0.25
	_made[key] = m
	return m


static func _soften(src: Material) -> void:
	# materials we leave alone still get pulled toward the palette: less candy, a bit more rough
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		if b.has_meta("softened"):
			return
		b.set_meta("softened", true)
		if b.albedo_texture == null:
			var c := b.albedo_color
			var l := c.get_luminance()
			b.albedo_color = Color(lerpf(c.r, l, 0.15), lerpf(c.g, l, 0.15), lerpf(c.b, l, 0.15), c.a)
		b.roughness = clampf(b.roughness + 0.1, 0.0, 1.0)


# ------------------------------------------------------------------ air, sky, grading
const PRESETS := {
	# Picayune at dusk: low amber sun under a heavy, drifting overcast
	"dusk": {
		"sky": {"zenith_color": "0d1830", "horizon_color": "b0703f", "ground_color": "0e0f0c", "cloud_lit": "e0986a", "cloud_shade": "262838", "cloud_cover": 0.58, "stars": 0.25, "sun_glow": 1.3, "brightness": 1.1},
		"sun": {"color": "ffae76", "energy": 1.5, "rot": Vector3(-9.0, 38.0, 0.0), "fog": 1.6},
		"ambient": {"source": "sky", "energy": 0.8},
		"fog": {"density": 0.014, "albedo": "8a8890", "emission": "000000", "aniso": 0.6, "length": 90.0, "sky_affect": 0.35},
		"depth_fog": {"on": true, "color": "3e3c4c", "density": 0.0035, "sky": 0.25},
		"grade": {"shadow": Color(0.86, 0.95, 1.1), "high": Color(1.07, 0.99, 0.9), "sat": 0.88, "contrast": 1.1, "lift": 0.004},
		"exposure": 1.3, "glow": 0.5,
	},
	# lamplit rooms: warm pools of light, dark corners, dust in the air
	"interior": {
		"bg": "050403",
		"sun": {"on": false},
		"ambient": {"source": "color", "color": "6a5238", "energy": 0.5},
		"fog": {"density": 0.022, "albedo": "a08a6c", "emission": "000000", "aniso": 0.6, "length": 40.0, "sky_affect": 0.0},
		"depth_fog": {"on": false},
		"grade": {"shadow": Color(0.9, 0.97, 1.04), "high": Color(1.08, 0.99, 0.87), "sat": 0.86, "contrast": 1.1, "lift": 0.006},
		"exposure": 1.5, "glow": 0.65, "gain": 1.8,
	},
	# the Honey House: lantern light and the last of the sun through the screen
	"honey": {
		"bg": "050403",
		"sun": {"on": false},
		"ambient": {"source": "color", "color": "6a4a28", "energy": 0.55},
		"fog": {"density": 0.02, "albedo": "b08a58", "emission": "000000", "aniso": 0.6, "length": 40.0, "sky_affect": 0.0},
		"depth_fog": {"on": false},
		"grade": {"shadow": Color(0.92, 0.96, 1.0), "high": Color(1.1, 0.98, 0.82), "sat": 0.9, "contrast": 1.08, "lift": 0.006},
		"exposure": 1.5, "glow": 0.7, "gain": 1.8,
	},
	# the Drafting Room: a warm study
	"studio": {
		"bg": "050403",
		"sun": {"on": false},
		"ambient": {"source": "color", "color": "5a4a38", "energy": 0.5},
		"fog": {"density": 0.015, "albedo": "a08a6c", "emission": "000000", "aniso": 0.6, "length": 40.0, "sky_affect": 0.0},
		"depth_fog": {"on": false},
		"grade": {"shadow": Color(0.9, 0.97, 1.04), "high": Color(1.07, 0.99, 0.88), "sat": 0.88, "contrast": 1.1, "lift": 0.006},
		"exposure": 1.5, "glow": 0.6, "gain": 1.8,
	},
	# the Trading Floor: dark, screen glow, one lamp on the plaque
	"trading": {
		"bg": "020303",
		"sun": {"on": false},
		"ambient": {"source": "color", "color": "2a3430", "energy": 0.4},
		"fog": {"density": 0.025, "albedo": "70807a", "emission": "000000", "aniso": 0.55, "length": 40.0, "sky_affect": 0.0},
		"depth_fog": {"on": false},
		"grade": {"shadow": Color(0.86, 1.0, 0.96), "high": Color(1.06, 0.99, 0.9), "sat": 0.85, "contrast": 1.14, "lift": 0.004},
		"exposure": 1.5, "glow": 0.8, "gain": 1.8,
	},
	# Hoboken, 1910, a November night: cold moon through overcast, coal smoke, gas lamps
	"night1910": {
		"sky": {"zenith_color": "070a14", "horizon_color": "2a3040", "ground_color": "060606", "cloud_lit": "6a7488", "cloud_shade": "12141a", "cloud_cover": 0.66, "stars": 0.5, "moon_size": 0.0016, "moon_dir": Vector3(-0.35, 0.42, -0.84), "sun_glow": 0.0, "brightness": 1.2},
		"sun": {"color": "9ab0e0", "energy": 0.5, "rot": Vector3(-30.0, -150.0, 0.0), "fog": 0.8},
		"ambient": {"source": "color", "color": "3e4a60", "energy": 0.6},
		"fog": {"density": 0.03, "albedo": "70788a", "emission": "000000", "aniso": 0.65, "length": 70.0, "sky_affect": 0.5},
		"depth_fog": {"on": true, "color": "141a22", "density": 0.009, "sky": 0.35},
		"grade": {"shadow": Color(0.88, 0.96, 1.1), "high": Color(1.08, 0.98, 0.86), "sat": 0.75, "contrast": 1.1, "lift": 0.01},
		"exposure": 1.5, "glow": 0.7, "gain": 1.5,
	},
	# inside the private car: brass lamps, mahogany, night rushing past
	"train": {
		"bg": "020304",
		"sun": {"on": false},
		"ambient": {"source": "color", "color": "4a3a2a", "energy": 0.3},
		"fog": {"density": 0.02, "albedo": "a08a70", "emission": "000000", "aniso": 0.6, "length": 20.0, "sky_affect": 0.0},
		"depth_fog": {"on": false},
		"grade": {"shadow": Color(0.92, 0.96, 1.02), "high": Color(1.1, 0.97, 0.82), "sat": 0.85, "contrast": 1.12, "lift": 0.0},
		"exposure": 1.4, "glow": 0.75, "gain": 1.7,
	},
	# Jekyll Island, late November: grey morning off the marsh
	"jekyll": {
		"sky": {"zenith_color": "3a4652", "horizon_color": "9a9c94", "ground_color": "1a1c16", "cloud_lit": "c8c4b8", "cloud_shade": "5a5e62", "cloud_cover": 0.78, "stars": 0.0, "sun_glow": 0.4, "brightness": 1.0},
		"sun": {"color": "e8e0d0", "energy": 0.9, "rot": Vector3(-22.0, 150.0, 0.0), "fog": 1.0},
		"ambient": {"source": "sky", "energy": 0.7},
		"fog": {"density": 0.02, "albedo": "a8aca4", "emission": "000000", "aniso": 0.3, "length": 90.0, "sky_affect": 0.5},
		"depth_fog": {"on": true, "color": "8a8e88", "density": 0.006, "sky": 0.3},
		"grade": {"shadow": Color(0.92, 1.0, 1.02), "high": Color(1.04, 1.0, 0.94), "sat": 0.74, "contrast": 1.08, "lift": 0.01},
		"exposure": 1.0, "glow": 0.4,
	},
}


static func setup(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.3)
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssil_enabled = true
	env.ssil_intensity = 0.8
	env.volumetric_fog_enabled = true
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true


static func apply_preset(env: Environment, sun: DirectionalLight3D, preset: String, quality: int) -> void:
	var p: Dictionary = PRESETS[preset]
	if p.has("sky"):
		var sm := ShaderMaterial.new()
		sm.shader = SkyShader
		var sp: Dictionary = p["sky"]
		for k in sp.keys():
			var v = sp[k]
			if v is String:
				v = Color(v)
			sm.set_shader_parameter(k, v)
		var sky := Sky.new()
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(String(p.get("bg", "000000")))

	var s: Dictionary = p["sun"]
	sun.visible = s.get("on", true)
	if sun.visible:
		sun.light_color = Color(String(s["color"]))
		sun.light_energy = s["energy"]
		sun.rotation_degrees = s["rot"]
		sun.light_volumetric_fog_energy = s.get("fog", 1.0)
		sun.shadow_enabled = true
		sun.shadow_blur = 1.5
		sun.directional_shadow_max_distance = 90.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

	var a: Dictionary = p["ambient"]
	if a["source"] == "sky":
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 1.0
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(String(a["color"]))
	env.ambient_light_energy = a["energy"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG if p.has("sky") else Environment.REFLECTION_SOURCE_DISABLED

	var f: Dictionary = p["fog"]
	env.volumetric_fog_density = f["density"]
	env.volumetric_fog_albedo = Color(String(f["albedo"]))
	env.volumetric_fog_emission = Color(String(f["emission"]))
	env.volumetric_fog_anisotropy = f["aniso"]
	env.volumetric_fog_length = f["length"]
	env.volumetric_fog_sky_affect = f["sky_affect"]
	var df: Dictionary = p["depth_fog"]
	env.fog_enabled = df.get("on", false)
	if env.fog_enabled:
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color(String(df["color"]))
		env.fog_density = df["density"]
		env.fog_sky_affect = df["sky"]
		env.fog_aerial_perspective = 0.4

	env.tonemap_exposure = p["exposure"]
	env.glow_intensity = p["glow"]
	var g: Dictionary = p["grade"]
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.0
	env.adjustment_color_correction = _lut(g["shadow"], g["high"], g["sat"], g["contrast"], g["lift"])
	apply_quality(env, quality)


static func apply_quality(env: Environment, quality: int) -> void:
	# 2 = high (default), 1 = medium, 0 = low
	env.sdfgi_enabled = quality >= 2
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 0.9
	env.ssil_enabled = quality >= 2
	env.ssao_enabled = quality >= 1
	env.volumetric_fog_enabled = quality >= 1
	env.glow_enabled = true
	RenderingServer.environment_set_volumetric_fog_volume_size(96 if quality >= 2 else 64, 64 if quality >= 2 else 48)
	RenderingServer.directional_shadow_atlas_set_size(4096 if quality >= 2 else 2048, true)


static func _lut(shadow: Color, high: Color, sat: float, contrast: float, lift: float) -> ImageTexture3D:
	# a small 3D color table: cool the shadows, warm the lights, drain some saturation, add bite
	var size := 24
	var slices: Array[Image] = []
	for bz in size:
		var img := Image.create(size, size, false, Image.FORMAT_RGB8)
		for gy in size:
			for rx in size:
				var c := Vector3(rx, gy, bz) / float(size - 1)
				var l := c.x * 0.2126 + c.y * 0.7152 + c.z * 0.0722
				c = Vector3(l, l, l).lerp(c, sat)
				c = (c - Vector3(0.5, 0.5, 0.5)) * contrast + Vector3(0.5, 0.5, 0.5)
				var t := clampf(l * 1.4 - 0.2, 0.0, 1.0)
				var tone := Vector3(shadow.r, shadow.g, shadow.b).lerp(Vector3(high.r, high.g, high.b), t)
				c = c * tone + Vector3(lift, lift, lift)
				img.set_pixel(rx, gy, Color(clampf(c.x, 0, 1), clampf(c.y, 0, 1), clampf(c.z, 0, 1)))
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, size, size, size, false, slices)
	return tex
