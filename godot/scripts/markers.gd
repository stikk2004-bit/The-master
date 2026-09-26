extends RefCounted
## Turns the empties placed in Blender into things the game uses:
##   LIGHT_<kind>_<n>  a light of that kind (see KINDS)
##   MARK_<name>       a named position and facing, returned in a dictionary

## kind -> [color, energy, reach, casts shadows, flickers, lights the ground for guards (reach) or 0]
const KINDS := {
	"gas": ["ffb060", 1.5, 8.0, false, true, 7.5],
	"yard": ["ffae58", 1.8, 10.0, true, true, 9.0],
	"street": ["ffb060", 1.7, 10.0, true, true, 9.0],
	"window": ["ffa850", 0.9, 7.0, false, false, 6.0],
	"clock": ["fff0d0", 0.6, 9.0, false, false, 0.0],
	"lantern": ["ffb060", 1.0, 5.5, false, true, 4.0],
	"red": ["ff2010", 0.7, 3.0, false, false, 2.5],
	"headlamp": ["ffe8b8", 3.0, 16.0, false, false, 12.0],
	"firebox": ["ff7020", 1.6, 5.0, false, true, 3.0],
	"blinds": ["ffa850", 1.0, 5.0, false, false, 0.0],
	"coach": ["ffae60", 0.4, 7.0, false, false, 0.0],
	"sconce": ["ffc070", 0.9, 4.5, false, true, 0.0],
	"ceiling": ["ffd090", 1.1, 6.0, true, false, 0.0],
	"chandelier": ["ffd090", 1.5, 9.0, true, false, 0.0],
	"fire": ["ff8a30", 2.4, 8.0, true, true, 0.0],
	"daylight": ["c8d4dc", 1.2, 7.0, false, false, 0.0],
	"stove": ["ff7a30", 0.9, 3.5, false, true, 0.0],
	"sunset": ["ffa050", 1.4, 16.0, false, false, 0.0],
	"picture": ["ffd8a0", 0.5, 2.6, false, false, 0.0],
	"banker": ["ffe0a8", 0.9, 4.0, true, false, 0.0],
	"plaque": ["ffd8a0", 1.6, 5.0, true, false, 0.0],
	"screen_green": ["60ff90", 0.5, 3.0, false, false, 0.0],
	"screen_amber": ["ffb050", 0.5, 3.0, false, false, 0.0],
	"pendant": ["ffd090", 1.0, 6.0, true, false, 0.0],
}


static func dress(root: Node, main, lamps: Array = []) -> Dictionary:
	var marks := {}
	for n in root.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("MARK_"):
			marks[_plain(nm.substr(5))] = (n as Node3D).global_transform
		elif nm.begins_with("LIGHT_"):
			var rest := nm.substr(6)
			var kind := ""
			for k in KINDS.keys():
				if rest.begins_with(String(k) + "_") and String(k).length() > kind.length():
					kind = String(k)
			if kind == "":
				kind = "gas"
			var p := (n as Node3D).global_position
			var digits := rest.substr(kind.length() + 1).split("_")[0]
			var idx := int(digits) if digits.is_valid_int() else 0
			var spec: Array = KINDS[kind]
			var shadow: bool = spec[3] or (kind == "gas" and idx % 3 == 0)
			var l: OmniLight3D = main._omni(p, Color(String(spec[0])), float(spec[1]), float(spec[2]), bool(spec[4]), shadow)
			if kind == "fire":
				l.light_volumetric_fog_energy = 2.5
			if float(spec[5]) > 0.0:
				lamps.append([p, float(spec[5])])
	return marks


static func _plain(key: String) -> String:
	# Blender numbers repeated names (seat_frank.001 comes through as seat_frank_001)
	key = key.split(".")[0]
	if key.length() > 4 and key[key.length() - 4] == "_" and key.right(3).is_valid_int():
		key = key.left(key.length() - 4)
	return key


static func yaw_of(t: Transform3D) -> float:
	## the facing of a mark, as a model yaw (a Blender empty faces its local +Y)
	var f := -t.basis.z
	return atan2(f.x, f.z)
