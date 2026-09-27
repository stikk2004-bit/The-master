extends Node
## The Jekyll Island affair, November 1910: the night at Hoboken, the Senator's private
## car, the island, and the room where the plan got written.
##
## History, as the men themselves later told it: they were told to come to the terminal one
## at a time, as quietly as they could, and to leave their last names behind. Aboard the
## Senator's private car they called each other Nelson, Paul, Ben and Abe; Frank Vanderlip
## and Harry Davison went further and became Orville and Wilbur, "on the theory that we were
## always right." They told anyone who asked that they were going duck hunting.
## The lines below are imagined. The facts around them are not.
##
## The player's part: a letter and a man who calls himself Jekyll (made up; the history around
## him is not), a drive down River Street, then a camera and seven faces to get on film while the
## yard's watchmen roam with their lanterns. Board at the car's dark front steps. Pour the coffee in
## a borrowed steward's jacket and photograph the papers in Arthur's valise while the real steward
## makes his rounds. On the island, once the men go out "duck hunting", photograph the chalkboard
## and the notes and walk off with the clean copy. Get caught and that part starts over.

const ActorScript := preload("res://scripts/actor.gd")
const GuardScript := preload("res://scripts/guard.gd")
const Sound := preload("res://scripts/sound.gd")
const Look := preload("res://scripts/look.gd")
const Foliage := preload("res://scripts/foliage.gd")
const Markers := preload("res://scripts/markers.gd")
const DriveScript := preload("res://scripts/drive.gd")

## each man walks at his own pace (meters a second): the Senator slowest, Harry quickest
const MEN := {
	"nelson": {"model": "res://models/npc_aldrich.glb", "name": "Nelson", "speed": 1.0},
	"arthur": {"model": "res://models/npc_shelton.glb", "name": "Arthur", "speed": 1.15},
	"abe": {"model": "res://models/npc_andrew.glb", "name": "Abe", "speed": 1.5},
	"paul": {"model": "res://models/npc_warburg.glb", "name": "Paul", "speed": 1.25},
	"frank": {"model": "res://models/npc_vanderlip.glb", "name": "Frank", "speed": 1.42},
	"harry": {"model": "res://models/npc_davison.glb", "name": "Harry", "speed": 1.55},
	"ben": {"model": "res://models/npc_strong.glb", "name": "Ben", "speed": 1.35},
}
## the order they came down the platform, and what was said as each one boarded
const ARRIVALS := [
	["nelson", [["The porter", "Evening, Senator."], ["Nelson", "Not tonight. Tonight it's just Nelson."]]],
	["arthur", [["Nelson", "Arthur. You have the papers?"], ["Arthur", "Every one of them, Nelson."]]],
	["abe", [["Arthur", "Evening, Abe."], ["Abe", "Evening. Nobody followed me that I could tell."]]],
	["paul", [["Nelson", "Paul. You found us."], ["Paul", "In the dark, and with no last names. A strange way to fix a country's money."]]],
	["frank", [["Frank", "I brought a shotgun, like the letter said. I have not fired one in years."], ["The porter", "I'll take the case, sir."]]],
	["harry", [["Harry", "Is Orville aboard yet?"], ["The porter", "Sir?"], ["Harry", "Never mind. He'll know who I mean."]]],
	["ben", [["Nelson", "That's all of us. Ben, get in out of the cold."], ["Nelson", "Tell the conductor we're ready."]]],
]
## who they were, for the prints. Full names here: the pictures are for Jekyll, not for them.
const WHO := {
	"nelson": ["Nelson W. Aldrich", "Senator from Rhode Island. Chairman of the National Monetary Commission, and the host."],
	"arthur": ["Arthur B. Shelton", "The Senator's private secretary. He kept the papers."],
	"abe": ["A. Piatt Andrew", "Assistant Secretary of the Treasury. An economist from Harvard."],
	"paul": ["Paul M. Warburg", "Partner at Kuhn, Loeb and Company. Born in Hamburg; he knew European central banking best."],
	"frank": ["Frank A. Vanderlip", "President of the National City Bank of New York."],
	"harry": ["Henry P. Davison", "Partner at J. P. Morgan and Company."],
	"ben": ["Benjamin Strong", "Vice president of the Bankers Trust Company."],
}
## the yard's watchmen: model, name, the spot he starts at, what he says when he half sees you, and when he gives up
const WATCHMEN := [
	["res://models/npc_yardman.glb", "The yard detective", 12, ["Who's there?", "Somebody by those crates?", "Come on out where I can see you."], ["Rats in the freight again.", "Nobody. Just this fog."]],
	["res://models/npc_brakeman.glb", "The brakeman", 23, ["Hey. Somebody down there?", "Hello?"], ["Hm. Nothing.", "Getting jumpy in my old age."]],
	["res://models/npc_watchman.glb", "The night watchman", 8, ["Who's that in the freight?", "I hear you. Come on out."], ["Cats. It's always cats.", "Nobody. Nobody ever is."]],
	["res://models/npc_conductor.glb", "The conductor", 3, ["Is somebody back there by the Senator's car?", "Who goes there?"], ["Nobody. Good.", "Just the steam."]],
	["res://models/npc_yardman.glb", "The railroad bull", 18, ["You. Stop right there.", "I see you moving."], ["Hm.", "Not tonight, whoever you are."]],
]
const FILM := 12                   # exposures on Jekyll's roll
const STONES := 3                  # stones Jekyll hands you; two more are hidden in the yard
const MISSION_SECONDS := 420.0     # from the freight gate until the train pulls out
const FIRST_CAB := 16.0
const CAB_GAP := 40.0
const ROUNDS_SECONDS := 180.0      # the steward's rounds before he turns the lamps down

## what the pocket Kodak can bring home. The papers are imagined; what they describe is not.
const PHOTOS := {
	"outline": ["The outline", "An outline in Arthur's hand: one reserve for the whole country, owned by the banks, with branches around it."],
	"figures": ["The European figures", "A table from the Monetary Commission's studies: how the banks of England, France and Germany hold their reserves."],
	"panic": ["Notes on 1907", "A page on the Panic of 1907: the runs, the trust companies that closed, the cash nobody could find."],
	"names": ["The list", "A list of the men aboard, with no last names on it. Nelson, Arthur, Abe, Paul, Frank, Harry, Ben."],
	"chalkboard": ["The chalkboard", "One reserve held in common. Fifteen districts. Notes that stretch at harvest time. A board mostly chosen by the banks."],
	"notes_paul": ["Paul's notes", "Paul's notes, in a neat European hand: a central reserve, and the discounting of good commercial paper."],
	"notes_abe": ["Abe's notes", "Abe's notes on drawing the districts, so every part of the country has a branch close by."],
}
const CAR_PHOTOS := ["outline", "figures", "panic", "names"]
const ROOM_PHOTOS := ["chalkboard", "notes_paul", "notes_abe"]

var main
var hud
var player
var level: Node3D
var marks := {}
var actors := {}
var cine: Camera3D
var skipping := false
var advancing := false
var in_scene := false
var talking := false
var stage := ""
var served := {}
var guards: Array = []
var cab: Node3D
var train_node: Node3D
var rear_door: Node3D
var front_door: Node3D
var lamp_list: Array = []
var ambience: AudioStreamPlayer
var window_scroll: Array = []
var beacons: Array = []            # faint markers over where to go: [Node3D, key]
var photos: Array = []             # keys of the pictures taken so far, in order
var have_copy := false
var spots: Array = []              # where the yard's watchmen may roam
var motorcar: CharacterBody3D
var driving := false
var film := FILM
var _boarded := {}
var _run := 0
var _next_cab := 0
var _gate_hint := false
var _routes: Array = []            # how each of the seven comes tonight: street, station or yard
var _spot_seen := {}               # when each roaming spot was last looked at, shared by the watchmen
const PERCHES := [
	["res://models/npc_watchman.glb", "The switchman", "perch_tower", [-1.571, 3.142, 2.36, 1.571, -2.36]],
	["res://models/npc_brakeman.glb", "The man on the shed roof", "perch_shed", [1.571, 2.36, 0.785]],
]
## travelers off the late train who look a good deal like the seven, and aren't
const LOOKALIKES := ["res://models/npc_andrew.glb", "res://models/npc_strong.glb", "res://models/npc_vanderlip.glb", "res://models/npc_davison.glb"]
const TRAVELER_PATHS := [[0, 1, 2], [5, 1, 3, 4], [0, 3, 4], [5, 1, 2]]
var _piles: Array = []             # [Node3D, mark name] stones lying about the yard
var _caught_busy := false
var _clock := 0.0
var _clock_on := false
var _clock_text := ""
var _clock_out: Callable = Callable()
var _arthur_state := ""            # writing, looking, window, walking
var _arthur_t := 0.0
var _arthur_seen := 0.0
var _shot_t := 0.0
var _beacon_tex: Texture2D


func _ready() -> void:
	cine = Camera3D.new()
	cine.fov = 50.0
	cine.far = 900.0
	add_child(cine)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -8.0
	add_child(ambience)


# ------------------------------------------------------------------ small tools
func wait(seconds: float) -> void:
	advancing = false
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and not skipping and not advancing:
		await get_tree().process_frame
	advancing = false


func line(who: String, text: String) -> void:
	if skipping:
		return
	talking = true
	await wait(hud.say(who, text))
	talking = false
	hud.clear_subtitle()


func thought(text: String) -> void:
	if skipping:
		return
	talking = true
	await wait(hud.say("", "[ " + text + " ]"))
	talking = false


func until_arrived(a) -> void:
	## wait for someone to finish walking; stops quietly if the room they were in is gone
	while is_instance_valid(a) and a.is_walking() and not skipping:
		await get_tree().process_frame
	if skipping and is_instance_valid(a):
		a.skip()


func begin_scene() -> void:
	in_scene = true
	skipping = false
	player.set_camera_up(false)
	main.busy = true
	player.enabled = false
	hud.set_prompt("")
	hud.letterbox(true)
	hud.set_sneak(false)
	cine.current = true


func end_scene() -> void:
	in_scene = false
	skipping = false
	hud.clear_subtitle()
	hud.letterbox(false)
	player.cam.current = true
	main.busy = false
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func request_skip() -> void:
	if in_scene:
		skipping = true
		hud.clear_subtitle()


func request_advance() -> void:
	## E moves the conversation along one line
	advancing = true


func shot(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	cine.global_position = pos
	cine.fov = fov
	if pos.distance_to(look) > 0.01:
		cine.look_at(look)


func glide(to_pos: Vector3, look: Vector3, seconds: float) -> void:
	## move the camera while keeping it on a point
	if skipping:
		shot(to_pos, look, cine.fov)
		return
	var from := cine.global_position
	var t := 0.0
	while t < 1.0 and not skipping:
		t = minf(1.0, t + get_process_delta_time() / seconds)
		var e := t * t * (3.0 - 2.0 * t)
		cine.global_position = from.lerp(to_pos, e)
		cine.look_at(look)
		await get_tree().process_frame
	shot(to_pos, look, cine.fov)


func _yaw_to(from: Vector3, to: Vector3) -> float:
	## the player's camera yaw that looks from one point toward another
	var d := to - from
	return atan2(-d.x, -d.z)


func _face_player_to(p: Vector3) -> void:
	## turn the player's body toward a point (face() takes a camera yaw)
	player.face(_yaw_to(player.global_position, p))


func mk(name: String) -> Vector3:
	var t: Transform3D = marks.get(name, Transform3D.IDENTITY)
	return t.origin


func mk_yaw(name: String) -> float:
	return Markers.yaw_of(marks.get(name, Transform3D.IDENTITY))


func _dress(root: Node) -> void:
	## Blender's LIGHT_ and MARK_ empties become lights and named positions
	var found: Dictionary = Markers.dress(root, main, lamp_list)
	marks.merge(found, true)


func _load(path: String, extra := {}) -> Node3D:
	var n: Node3D = main._instance(path, extra)
	_dress(n)
	return n


func _actor(key: String, collide := false) -> Node3D:
	var a := Node3D.new()
	a.set_script(ActorScript)
	level.add_child(a)
	var info: Dictionary = MEN.get(key, {"model": key, "name": ""})
	a.setup(String(info["model"]), String(info["name"]), collide)
	actors[key] = a
	return a


func _speed(key: String) -> float:
	var info: Dictionary = MEN.get(key, {})
	return float(info.get("speed", 1.3))


func _guard(model: String, shown: String, route: Array, with_lantern := true, collide := true) -> Node3D:
	var g := Node3D.new()
	g.set_script(GuardScript)
	level.add_child(g)
	g.setup(model, shown, collide)
	g.arm(route, player, lamp_list, with_lantern)
	g.active = false
	g.caught.connect(_on_caught.bind(g))
	g.spoke.connect(_on_guard_spoke.bind(g))
	guards.append(g)
	return g


func _route(prefix: String, order: Array) -> Array:
	var out := []
	for i in order:
		out.append(mk("%s_%d" % [prefix, int(i)]))
	return out


func _swing(door: Node3D, angle: float, seconds := 0.7) -> void:
	## turn one of the car's doors on its hinge
	if door == null:
		return
	if skipping:
		door.rotation.y = angle
		return
	if absf(angle) > 0.01:
		Sound.one_shot(self, "door", -10.0)
	var tw := create_tween()
	tw.tween_property(door, "rotation:y", angle, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _move_player(points: Array, spd: float, anim_name := "Walk") -> void:
	## walk the player along a path by script (up steps, through a door, up a ladder); physics is off meanwhile
	player.set_physics_process(false)
	player._play(anim_name)
	for p in points:
		var target: Vector3 = p
		while not skipping:
			var here: Vector3 = player.global_position
			var to := target - here
			var dist := to.length()
			var step := spd * get_process_delta_time()
			if dist <= step or dist < 0.01:
				player.global_position = target
				break
			player.global_position += to / dist * step
			var flat := Vector2(to.x, to.z)
			if flat.length() > 0.05 and anim_name != "Climb":
				player.model.rotation.y = lerp_angle(player.model.rotation.y, atan2(to.x, to.z), 0.25)
			if player.anim:
				player.anim.speed_scale = clampf(spd / 1.7, 0.6, 1.4) if anim_name == "Walk" else 1.0
			await get_tree().process_frame
		if skipping:
			player.global_position = points[points.size() - 1]
			break
	player._play("Idle")
	player.set_physics_process(true)


func _steam(p: Vector3, amount := 60, big := false) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.amount = amount
	ps.lifetime = 5.0 if big else 2.5
	ps.preprocess = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0 if big else 45.0
	pm.initial_velocity_min = 1.2 if big else 0.4
	pm.initial_velocity_max = 2.2 if big else 1.0
	pm.gravity = Vector3(0.25, 0.3, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.scale_min = 1.0
	pm.scale_max = 2.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4) if big else Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.75, 0.74, 0.72)
	m.albedo_texture = _puff()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.disable_receive_shadows = true
	q.material = m
	ps.draw_pass_1 = q
	ps.position = p
	ps.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 20, 16))
	return ps


static var _puff_tex: Texture2D

func _puff() -> Texture2D:
	if _puff_tex:
		return _puff_tex
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_puff_tex = gt
	return gt


func _beacon(p: Vector3, key := "") -> Sprite3D:
	## a faint pale diamond over the place to go; it shows through walls, the way a memory would
	if _beacon_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := absf(x - 31.5) / 31.5 + absf(y - 31.5) / 31.5
				var a := clampf((1.0 - d) * 3.0, 0.0, 1.0) * (0.55 + 0.45 * clampf((0.75 - d) * 4.0, 0.0, 1.0))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_beacon_tex = ImageTexture.create_from_image(img)
	var s := Sprite3D.new()
	s.texture = _beacon_tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.pixel_size = 0.0045
	s.modulate = Color(1.0, 0.9, 0.7, 0.3)
	s.position = p
	level.add_child(s)
	beacons.append([s, key])
	return s


func _drop_beacon(key: String) -> void:
	var keep := []
	for b in beacons:
		if String(b[1]) == key and is_instance_valid(b[0]):
			(b[0] as Node).queue_free()
		else:
			keep.append(b)
	beacons = keep


func _clear_beacons() -> void:
	for b in beacons:
		if is_instance_valid(b[0]):
			(b[0] as Node).queue_free()
	beacons.clear()


func _play_ambience(kind: String) -> void:
	ambience.stream = Sound.loop(kind)
	ambience.play()


func _set_clock(seconds: float, text: String, on_out: Callable) -> void:
	_clock = seconds
	_clock_text = text
	_clock_out = on_out
	_clock_on = true


func _stop_clock() -> void:
	_clock_on = false
	hud.set_timer("")


func _tally(keys: Array) -> String:
	var n := 0
	for k in keys:
		if photos.has(k):
			n += 1
	return "Photographs: %d of %d" % [n, keys.size()]


func _drop_interactable(tag: String) -> void:
	var keep := []
	for it in main.interactables:
		if String(it.get("tag", "")) != tag:
			keep.append(it)
	main.interactables = keep


func _add(pos: Vector3, radius: float, prompt: String, cb: Callable, tag := "") -> void:
	main.add_interactable(pos, radius, prompt, cb)
	main.interactables[main.interactables.size() - 1]["tag"] = tag


# ------------------------------------------------------------------ entry and exit
func start() -> void:
	served.clear()
	photos.clear()
	have_copy = false
	player.has_camera = false
	hud.mission.set_item("")
	stage = "hoboken"
	main.go_to("hoboken", Vector3.ZERO, 0.0)


func build(level_name: String, lvl: Node3D) -> void:
	_run += 1              # anything still waiting on the last room gives up
	_base_exposure = -1.0
	_boost = 1.0
	_night_air = []
	hud.mission.show_map(false)
	level = lvl
	marks.clear()
	actors.clear()
	guards.clear()
	lamp_list.clear()
	window_scroll.clear()
	beacons.clear()
	_clock_on = false
	_arthur_state = ""
	driving = false
	hud.mission.set_clock("", -1.0)
	hud.mission.set_slots(0)
	hud.mission.show_finder(false)
	player.set_camera_up(false)
	if player.hidden:
		player.unhide(player.global_position, player.yaw)
	if not player.shutter.is_connected(_on_shutter):
		player.shutter.connect(_on_shutter)
	if not player.camera_toggled.is_connected(_on_camera_toggled):
		player.camera_toggled.connect(_on_camera_toggled)
	if not player.throw_stone.is_connected(_on_throw):
		player.throw_stone.connect(_on_throw)
	_piles.clear()
	rear_door = null
	front_door = null
	hud.set_timer("")
	player.set_carrying(false)
	player.set_kodak(false)
	player.visible = true
	player.set_physics_process(true)
	match level_name:
		"hoboken":
			_build_hoboken()
		"privatecar":
			_build_privatecar()
		"jekyll":
			_build_jekyll()
		"meeting":
			_build_meeting()


func after_enter(level_name: String) -> void:
	## called once the fade from black has begun
	match level_name:
		"hoboken":
			_run_hoboken()
		"privatecar":
			_run_privatecar()
		"jekyll":
			_run_jekyll()
		"meeting":
			_run_meeting()


func leave_to_present() -> void:
	stage = ""
	ambience.stop()
	player.set_carrying(false)
	player.set_camera_up(false)
	player.set_kodak(false)
	player.has_camera = false
	player.stones = 0
	hud.mission.set_item("")
	hud.mission.set_clock("", -1.0)
	player.set_outfit("club")
	player.can_sneak = true
	hud.set_objective("")
	hud.set_timer("")
	hud.set_sneak(false)
	main.progress["ch1910"] = true
	main._save_progress()
	main.go_to("exterior", main.SPAWN_PORCH, PI)
	await get_tree().create_timer(1.2).timeout
	hud.show_location("The Grounds", "Picayune, Mississippi. The present day.")


# ================================================================== HOBOKEN
## River Street first: a letter, Jekyll by his motorcar, a drive down to the yard's freight gate.
## Through the gate the clock starts. The seven come by cab one at a time while you're in the yard,
## and each has to be on film before he goes in at the Senator's rear door. Five watchmen roam
## the yard with bull's-eye lanterns. All seven taken, you board at the car's dark front steps.
func _build_hoboken() -> void:
	main._air("night1910")
	_night_air = [main.env.tonemap_exposure, main.env.ambient_light_energy]
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	_load("res://models/hoboken_yard.glb")
	train_node = _load("res://models/hoboken_train.glb", _moving_train_mats())
	_load("res://models/hoboken_boxcars.glb")
	rear_door = train_node.find_child("RearDoor", true, false) as Node3D
	front_door = train_node.find_child("FrontDoor", true, false) as Node3D
	main._safety_floor()
	_bake_nav()
	level.add_child(_steam(mk("stack") + Vector3(0, 0.3, 0), 70, true))
	level.add_child(_steam(mk("cylinder_L"), 30))
	level.add_child(_steam(mk("cylinder_R"), 30))
	# the porter waits at the rear of the Senator's car
	var porter := _actor("res://models/npc_porter.glb", true)
	actors["porter"] = porter
	porter.display_name = "The porter"
	porter.place(mk("porter"), -PI / 2.0)
	# the seven, waiting offstage until their cabs pull up
	for key in MEN.keys():
		var a := _actor(String(key))
		a.visible = false
		a.place(mk("cab_out") + Vector3(0, -30, 0), 0.0)
	# Jekyll, by his motorcar at the corner
	var jk := _actor("res://models/npc_jekyll.glb", true)
	actors["jekyll"] = jk
	jk.display_name = "Jekyll"
	jk.place(mk("jekyll"), mk_yaw("jekyll"))
	# the yard's watchmen: they roam, spread out, and swing their lanterns
	spots.clear()
	var i := 0
	while marks.has("spot_%d" % i):
		spots.append(mk("spot_%d" % i))
		i += 1
	var map := level.get_world_3d().navigation_map
	for k in WATCHMEN.size():
		var spec: Array = WATCHMEN[k]
		var start: Vector3 = spots[int(spec[2]) % maxi(spots.size(), 1)] if not spots.is_empty() else mk("gate_in")
		var g := _guard(String(spec[0]), String(spec[1]), [start])
		g.lines_suspicious = spec[3]
		g.lines_clear = spec[4]
		g.alarmed.connect(_on_alarm.bind(g))
		g.active = true
		g.watching = false
	_spot_seen.clear()
	for g in guards:
		g.roam(spots, guards, map, _spot_seen)
	# two more up high: in the switchman's tower and on the freight shed's roof
	for spec in PERCHES:
		var pm := String(spec[2])
		if not marks.has(pm):
			continue
		var pg := _guard(String(spec[0]), String(spec[1]), [mk(pm)])
		pg.lines_suspicious = ["Something moving down there.", "Who's that by the freight?"]
		pg.lines_clear = ["Hm.", "Shadows."]
		pg.alarmed.connect(_on_alarm.bind(pg))
		pg.perch(spec[3])
		pg.active = true
		pg.watching = false
	# the lookalikes, waiting in the station until the mission starts
	for d in LOOKALIKES.size():
		var la := _actor(String(LOOKALIKES[d]))
		actors["decoy_%d" % d] = la
		la.display_name = "A traveler"
		la.visible = false
		la.place(mk("cab_out") + Vector3(0, -30, 0), 0.0)
	# the motor cab that brings them
	cab = main._instance("res://models/motorcar.glb")
	cab.visible = false
	_headlamps(cab)
	# Jekyll's motorcar, which you drive
	motorcar = CharacterBody3D.new()
	motorcar.set_script(DriveScript)
	level.add_child(motorcar)
	var body_model: Node3D = main._instance("res://models/motorcar.glb")
	motorcar.setup(body_model)
	_headlamps(body_model)
	motorcar.global_position = mk("jcar")
	motorcar.rotation.y = mk_yaw("jcar") + PI
	motorcar.exit_requested.connect(_leave_car)
	_add_yard_spots()
	_lay_stones()
	player.place(mk("street_start"), _yaw_to(mk("street_start"), mk("street_start") + Vector3(1, 0, 0)))
	player.sneaking = false
	player.can_sneak = true
	_play_ambience("yard")


func _headlamps(car: Node3D) -> void:
	for side in [-0.55, 0.55]:
		var hl := SpotLight3D.new()
		hl.light_color = Color("ffe0a8")
		hl.light_energy = 7.0
		hl.spot_range = 30.0
		hl.spot_angle = 30.0
		hl.spot_attenuation = 0.8
		hl.position = Vector3(side, 1.12, -2.4)
		hl.rotation.x = -0.06
		hl.light_volumetric_fog_energy = 2.5
		hl.shadow_enabled = true
		car.add_child(hl)
	# the carbide glow off the brass and the lamps themselves, so the car reads in the dark
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffd9a0")
	glow.light_energy = 0.9
	glow.omni_range = 5.5
	glow.position = Vector3(0.0, 1.6, -1.8)
	car.add_child(glow)


func _bake_nav() -> void:
	## the walkable ground of the yard, so the watchmen can go anywhere a man can walk
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 32.0
	nm.cell_size = 0.25
	nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.filter_baking_aabb = AABB(Vector3(-30.0, -0.6, -80.0), Vector3(46.0, 4.0, 108.0))
	# the tarp wagon has no collision (you crawl under it), so keep the watchmen from walking through it
	if marks.has("hide_tarp"):
		var ob := NavigationObstacle3D.new()
		ob.affect_navigation_mesh = true
		ob.avoidance_enabled = false
		ob.height = 2.0
		ob.vertices = PackedVector3Array([Vector3(-1.3, 0, -2.0), Vector3(1.3, 0, -2.0), Vector3(1.3, 0, 2.0), Vector3(-1.3, 0, 2.0)])
		level.add_child(ob)
		ob.global_position = mk("hide_tarp") + Vector3(0.1, 0.0, 0.0)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, level)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var map := level.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.25)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nm
	level.add_child(region)


func _moving_train_mats() -> Dictionary:
	# the train rolls away at the end, so its textures ride along with it
	var out := {}
	for nm in ["TR_Maroon", "TR_Green", "TR_Black", "TR_Roof", "TR_Iron", "TR_Brass"]:
		var spec: Array = Look.MATS[nm]
		var opts: Dictionary = (spec[2] as Dictionary).duplicate()
		opts["obj"] = true
		out[nm] = [spec[0], spec[1], opts]
	return out


func _run_hoboken() -> void:
	stage = "street"
	begin_scene()
	shot(mk("cam_jekyll") + Vector3(-6.0, 1.5, 3.0), mk("jcar") + Vector3(0, 1.0, 0), 50.0)
	await wait(hud.show_card("Hoboken, New Jersey", "The night of November 22, 1910", 3.5) - 1.0)
	end_scene()
	main.after_panel = _after_letter
	main.open_panel("A letter, slipped under your door",
		"[i]Friend,[/i]\n\n"
		+ "Tonight seven men will board Senator Aldrich's private car in the Hoboken yards, one at a time and quiet as church mice. They are leaving their last names at home.\n\n"
		+ "I want a photograph of every one of them before he gets aboard, and I want nobody to know it was taken.\n\n"
		+ "The railroad's watchmen walk that yard all night with bull's-eye lanterns. Keep out of the light.\n\n"
		+ "I'll be on River Street by the motorcar.\n\n"
		+ "[i]J.[/i]")


func _after_letter() -> void:
	hud.set_objective("Find the man waiting by the motorcar on River Street.")
	_beacon(mk("jekyll") + Vector3(0, 2.5, 0), "jekyll")
	_add(mk("jekyll"), 2.4, "Talk to the man by the motorcar", _talk_jekyll, "jekyll")


func _talk_jekyll() -> void:
	_drop_interactable("jekyll")
	_drop_beacon("jekyll")
	var jk = actors["jekyll"]
	jk.face_point(player.global_position)
	_face_player_to(jk.global_position)
	begin_scene()
	shot(mk("cam_jekyll"), mk("cam_jekyll_look"), 42.0)
	jk.play("Talk", 0.3)
	await line("Jekyll", "You came. Good. Call me Jekyll. It isn't my name either, which puts me in fine company tonight.")
	await line("Jekyll", "Seven of them, coming to the Senator's car one at a time. Some by motor cab, some on foot, and no two nights the same way. Bankers, a man from the Treasury, and the Senator himself.")
	await line("Jekyll", "I want every face on film before it goes through that door. All seven. Miss one and the night's wasted.")
	await line("Jekyll", "Here. A folding pocket Kodak and a fresh roll. Twelve exposures. Don't spend them on the fog.")
	await line("Jekyll", "The railroad keeps its own men in that yard, and they carry bull's-eye lanterns. Stay out of the beam, and don't run where they can hear you.")
	await line("Jekyll", "And these. Three good stones off the riverbank. Pitch one past a watchman and he'll go see what landed.")
	await line("Jekyll", "I drew you the yard, best I remember it. The walks are lit and the watchmen know it. Keep to the dark between them.")
	await line("Jekyll", "Take my motorcar down to the freight gate at the end of the street. The first cab is due any minute, and the train won't wait on you.")
	jk.play("Idle", 0.3)
	end_scene()
	_give_camera()
	player.stones = STONES
	_update_item()
	hud.toast("You have a folding pocket Kodak and three stones.   Q holds the camera up, click takes a picture, wheel zooms.   F throws a stone.", 8.0)
	hud.set_objective("Drive the motorcar down River Street to the yard's freight gate.")
	_add(motorcar.global_position, 2.8, "Get in the motorcar", _get_in, "car")
	_beacon(mk("gate_out") + Vector3(0, 2.8, 0), "gate")


func _get_in() -> void:
	_drop_interactable("car")
	player.set_camera_up(false)
	player.visible = false
	player.enabled = false
	player.set_physics_process(false)
	motorcar.add_collision_exception_with(player)
	player.global_position = motorcar.global_position
	motorcar.start_driving()
	_boost_exposure(1.7)
	driving = true
	_gate_hint = false
	hud.set_objective("Drive down River Street to the freight gate.   W go, S brake, A and D steer, E get out.")
	# pull up anywhere near the gate and E gets you out
	var park := mk("park")
	_add(Vector3(park.x, park.y + 1.0, park.z), 9.0, "Get out of the motorcar", _leave_car, "getout")


func _leave_car() -> void:
	if not driving:
		return
	motorcar.stop_driving()
	driving = false
	_restore_exposure()
	_drop_interactable("getout")
	var right: Vector3 = motorcar.global_transform.basis.x
	var fwd: Vector3 = motorcar.forward()
	var out: Vector3 = motorcar.global_position - right * 1.7 + Vector3(0, 0.1, 0)
	for cand in [motorcar.global_position - right * 1.7, motorcar.global_position + right * 1.7, motorcar.global_position - fwd * 3.2]:
		var c: Vector3 = cand + Vector3(0, 0.1, 0)
		var across_fence: bool = c.x > -28.6 and c.x < 14.0 and c.z < 27.6
		if not across_fence and not player._overlaps_at(c):
			out = c
			break
	out = player.free_spot(out)
	player.visible = true
	player.enabled = true
	player.set_physics_process(true)
	player.place(out, motorcar.rotation.y)
	player.cam.current = true
	_add(motorcar.global_position, 2.8, "Get back in the motorcar", _get_in, "car")
	if stage == "street":
		hud.set_objective("Slip into the yard through the freight gate.")
		_drop_beacon("gate")
		_beacon(mk("gate_in") + Vector3(0, 2.6, 0), "gate")


func _add_yard_spots() -> void:
	## hiding places and ladders
	_add(mk("hide_tarp_out"), 1.7, "Crawl under the tarp", _hide.bind("tarp"), "hide")
	_add(mk("hide_boxcar_out"), 1.7, "Climb into the empty boxcar", _hide.bind("boxcar"), "hide")
	_add(mk("hide_shed_out"), 1.7, "Step into the dark doorway", _hide.bind("shed"), "hide")
	for i in 4:
		if marks.has("ladder_%d_bottom" % i):
			_add(mk("ladder_%d_bottom" % i), 1.1, "Climb the ladder", _climb.bind(i, true), "ladder")
			_add(mk("ladder_%d_top" % i), 1.2, "Climb down the ladder", _climb.bind(i, false), "ladder")


func _hide(which: String) -> void:
	if player.hidden or _caught_busy:
		return
	var spot := "hide_" + which
	var eye := {"tarp": 0.7, "boxcar": 1.5, "shed": 1.55}
	player.hide_at(mk(spot), mk_yaw(spot) + PI, float(eye.get(which, 1.0)))
	_add(mk(spot), 1.0, "Come out", _unhide.bind(which), "leave")
	hud.toast("Hidden. They can't see you here, and you can still use the camera. E to come out.", 3.5)


func _unhide(which: String) -> void:
	if not player.hidden:
		return
	_drop_interactable("leave")
	player.set_camera_up(false)
	var spot := "hide_" + which
	player.unhide(mk(spot + "_out"), mk_yaw(spot) + PI)


func _climb(i: int, up: bool) -> void:
	if player.hidden or _caught_busy or main.busy:
		return
	player.set_camera_up(false)
	main.busy = true
	player.enabled = false
	var bottom := mk("ladder_%d_bottom" % i)
	var top := mk("ladder_%d_top" % i)
	# the rungs are on the end of the car, just behind the foot of the ladder
	var foot := Vector3(bottom.x, bottom.y, bottom.z - 0.3)
	var high := Vector3(bottom.x, top.y + 0.05, bottom.z - 0.3)
	var over := Vector3(bottom.x + 0.2, top.y + 0.05, bottom.z - 1.0)
	if up:
		await _move_player([foot], 1.4)
		player.face(_yaw_to(foot, foot + Vector3(0, 0, -1)))
		await _move_player([high], 1.1, "Climb")
		await _move_player([over, top], 1.3)
	else:
		await _move_player([over], 1.3)
		player.face(_yaw_to(foot, foot + Vector3(0, 0, -1)))
		await _move_player([high, foot], 1.3, "Climb")
		await _move_player([bottom], 1.4)
	main.busy = false
	player.enabled = true


func _start_mission() -> void:
	stage = "yard"
	_yard_air()
	_drop_interactable("car")
	_drop_beacon("gate")
	for g in guards:
		g.watching = true
	film = FILM
	_update_item()
	for k in MEN.keys():
		photos.erase(String(k))
	_boarded.clear()
	_next_cab = 0
	_run += 1
	_routes = ["street", "street", "station", "station", "yard", "yard", ["street", "station", "yard"][randi() % 3]]
	_routes.shuffle()
	for i in LOOKALIKES.size():
		_traveler_loop(i, _run)
	hud.mission.set_slots(7)
	hud.set_objective("Photograph all seven men before they go into the Senator's car.   Q for the camera.")
	hud.set_timer(_tally(MEN.keys()))
	_set_clock(MISSION_SECONDS, "The train leaves in", _missed_train)
	await thought("The Senator's car is the maroon one at the back of the train, with the brass rail. The cabs pull up at the platform steps.")


func _yard_schedule() -> void:
	## the cabs come on time whether you're ready or not
	var elapsed := MISSION_SECONDS - _clock
	if _next_cab < ARRIVALS.size() and elapsed >= FIRST_CAB + _next_cab * CAB_GAP:
		_arrival_live(_next_cab, _run)
		_next_cab += 1


func _boarding_path() -> Array:
	## from the platform steps to the rear of the car, then up its steps to the rear door
	return [mk("step_bottom"), mk("step_top"), mk("rear_approach")]


func _steps_path() -> Array:
	var p := []
	for k in 5:
		p.append(mk("rear_step_%d" % k))
	p.append(mk("rear_door"))
	return p


func _arrival_live(i: int, run: int) -> void:
	## one of the seven comes: by cab from the street, out of the station, or on foot across the yard
	var entry: Array = ARRIVALS[i]
	var key := String(entry[0])
	var talk: Array = entry[1]
	var a = actors[key]
	var porter = actors["porter"]
	var spd := _speed(key)
	var how := String(_routes[i]) if i < _routes.size() else "street"
	var to_talk := []
	var after := _steps_path()
	match how:
		"station":
			a.visible = true
			a.place(mk("station_walk_0"), PI)
			to_talk = [mk("station_walk_1"), mk("station_walk_2"), mk("rear_approach")]
		"yard":
			a.visible = true
			a.place(mk("yard_walk_0"), PI)
			for k in range(1, 6):
				to_talk.append(mk("yard_walk_%d" % k))
			after = []
			for k in 5:
				after.append(mk("west_step_%d" % k))
			after.append(mk("rear_door"))
		_:
			cab.visible = true
			var cin := mk("cab_in")
			var cstop := mk("cab_stop")
			cab.global_position = cin
			cab.rotation.y = PI / 2.0
			await _drive(cab, cin, cstop, 3.2)
			if run != _run or not is_instance_valid(a):
				return
			a.visible = true
			a.place(cstop + Vector3(0.4, 0.0, -0.9), 0.0)
			to_talk = _boarding_path()
			_drive(cab, cstop, mk("cab_out"), 5.0)
	a.walk(to_talk, spd)
	await until_arrived(a)
	if run != _run or not is_instance_valid(a):
		return
	if how != "yard":
		porter.face_point(a.global_position)
		a.face_point(porter.global_position)
	a.play("TipHat", 0.2)
	for t in talk:
		var dur: float = hud.say(String(t[0]), String(t[1]))
		await get_tree().create_timer(dur).timeout
		if run != _run or not is_instance_valid(a):
			return
	a.walk(after, spd)
	await until_arrived(a)
	if run != _run or not is_instance_valid(a):
		return
	await _swing(rear_door, -1.35, 0.6)
	a.walk([mk("rear_inside")], spd * 0.8)
	await until_arrived(a)
	if run != _run or not is_instance_valid(a):
		return
	a.visible = false
	_boarded[key] = true
	_swing(rear_door, 0.0, 0.8)
	porter.face_yaw(-PI / 2.0)
	if not photos.has(key) and (stage == "yard" or stage == "board"):
		_yard_reset("", "", "He's aboard", "%s went in before you got his picture. Jekyll wanted all seven. Try again." % String(MEN[key]["name"]))


func _traveler_loop(i: int, run: int) -> void:
	## a lookalike off the late train: out onto the platform, along it, and into an ordinary coach; again and again
	var la = actors.get("decoy_%d" % i)
	if la == null:
		return
	await get_tree().create_timer(randf_range(4.0, 20.0) + 9.0 * i).timeout
	while run == _run and is_instance_valid(la) and stage in ["yard", "board"]:
		var route: Array = TRAVELER_PATHS[(i + randi() % 2) % TRAVELER_PATHS.size()]
		var pts := []
		for n in route:
			pts.append(mk("traveler_%d" % int(n)))
		la.visible = true
		la.place(pts[0], PI)
		la.walk(pts.slice(1), randf_range(1.1, 1.5))
		await until_arrived(la)
		if run != _run or not is_instance_valid(la):
			return
		la.visible = false
		la.place(mk("cab_out") + Vector3(0, -30, 0), 0.0)
		await get_tree().create_timer(randf_range(10.0, 26.0)).timeout


func _drive(node: Node3D, from: Vector3, to: Vector3, seconds: float) -> void:
	if skipping:
		node.global_position = to
		return
	var t := 0.0
	while t < 1.0 and not skipping and is_instance_valid(node):
		t = minf(1.0, t + get_process_delta_time() / seconds)
		var e := t * t * (3.0 - 2.0 * t)
		node.global_position = from.lerp(to, e)
		await get_tree().process_frame
	if is_instance_valid(node):
		node.global_position = to


func _all_seven() -> void:
	stage = "board"
	hud.set_objective("All seven on film. Now get aboard at the dark front steps of the Senator's car, before it pulls out.")
	_add(mk("vestibule") + Vector3(0, 0.5, 0), 1.3, "Climb aboard", _board, "board")
	_beacon(mk("steps_marker"), "board")
	await thought("Seven faces. Jekyll will want to see these. Now, how do I get on that train?")


func _on_alarm(where: Vector3, g) -> void:
	## one watchman calls out; the nearest other one comes to have a look too
	var best = null
	var bd := 26.0
	for o in guards:
		if o == g:
			continue
		var d: float = (o as Node3D).global_position.distance_to(where)
		if d < bd:
			bd = d
			best = o
	if best != null:
		best.investigate(where)


func _on_guard_spoke(text: String, g) -> void:
	if stage in ["yard", "board", "car_photos"]:
		hud.say(g.display_name, text, 2.4)


func _on_caught(g) -> void:
	if _caught_busy:
		return
	if stage == "car_photos":
		_car_caught(g.display_name)
		return
	if stage != "yard" and stage != "board":
		return
	hud.mission.show_map(false)
	_yard_reset(g.display_name, "Hey! You there! Stop right where you are!", "Caught", "Nobody was meant to see this car tonight. Try again.")


func _missed_train() -> void:
	if _caught_busy or (stage != "yard" and stage != "board"):
		return
	_yard_reset("The conductor", "Board!", "Too late", "The train pulled out without you. Try again, and don't dawdle.")


func _yard_reset(who: String, shout: String, title: String, sub: String) -> void:
	## back to the freight gate: the cabs start over, the film's fresh, the watchmen scatter
	if _caught_busy:
		return
	_caught_busy = true
	_clock_on = false
	player.set_camera_up(false)
	for gg in guards:
		gg.active = false
	player.enabled = false
	if shout != "":
		hud.say(who, shout, 2.5)
	await get_tree().create_timer(1.8).timeout
	await hud.fade_to(1.0, 0.8).finished
	hud.show_card(title, sub, 1.8)
	await get_tree().create_timer(2.8).timeout
	_run += 1
	for k in MEN.keys():
		var a = actors[String(k)]
		a.visible = false
		a.place(mk("cab_out") + Vector3(0, -30, 0), 0.0)
	cab.visible = false
	if rear_door:
		rear_door.rotation.y = 0.0
	_drop_interactable("board")
	_drop_beacon("board")
	_drop_interactable("leave")
	if player.hidden:
		player.unhide(mk("gate_in"), 0.0)
	player.place(mk("gate_in"), 0.0)
	player.sneaking = true
	for k in guards.size():
		var g = guards[k]
		if g.perched:
			g.reset_to(g.home)
		else:
			var spec: Array = WATCHMEN[k % WATCHMEN.size()]
			g.reset_to(spots[int(spec[2]) % spots.size()] if not spots.is_empty() else g.global_position)
		g.active = true
		g.watching = true
	for i in LOOKALIKES.size():
		var la = actors["decoy_%d" % i]
		la.visible = false
		la.place(mk("cab_out") + Vector3(0, -30, 0), 0.0)
	player.stones = STONES
	_lay_stones()
	player.enabled = true
	_caught_busy = false
	_start_mission()
	await hud.fade_to(0.0, 1.0).finished


func _board() -> void:
	if stage != "board" or _caught_busy:
		return
	stage = "boarding"
	_stop_clock()
	_clear_beacons()
	main.interactables.clear()
	for g in guards:
		g.active = false
	hud.set_sneak(false)
	hud.set_objective("")
	hud.set_timer("")
	hud.mission.set_slots(0)
	if player.hidden:
		player.unhide(mk("vestibule"), 0.0)
	begin_scene()
	shot(mk("cam_board"), mk("cam_board_look"), 46.0)
	player.sneaking = false
	# up the step box and the four iron steps; the door swings in, and in you go
	player.place(mk("board_0"), _yaw_to(mk("board_0"), mk("board_7")))
	player.face(_yaw_to(mk("board_0"), mk("board_7")))
	await _move_player([mk("board_1"), mk("board_2"), mk("board_3"), mk("board_4"), mk("board_5")], 1.0)
	await _swing(front_door, 1.4, 0.7)
	await _move_player([mk("board_6"), mk("board_7")], 1.1)
	player.visible = false
	await _swing(front_door, 0.0, 0.6)
	await thought("In the dark between the cars. Nobody turned around.")
	Sound.one_shot(self, "whistle")
	shot(mk("cam_wide") + Vector3(-6, 3, 0), train_node.global_position + Vector3(4, 2, -20), 50.0)
	await wait(1.4)
	# the train pulls out, north into the fog
	var from := train_node.global_position
	var t := 0.0
	var dur := 11.0
	while t < dur and not skipping:
		t += get_process_delta_time()
		var d := 0.08 * t * t
		train_node.global_position = from + Vector3(0, 0, -d)
		cine.look_at(train_node.global_position + Vector3(4, 2, 10))
		await get_tree().process_frame
	player.visible = true
	skipping = false
	hud.fade_to(1.0, 1.2)
	await get_tree().create_timer(1.3).timeout
	await wait(hud.show_card("Southbound", "The Senator's car, somewhere past Philadelphia. Well after midnight.", 3.0))
	end_scene()
	stage = "privatecar"
	main.go_to("privatecar", Vector3.ZERO, 0.0)


func tick(delta: float) -> void:
	## called from main every frame
	if hud.mission.map_open:
		if _map_ok() and not in_scene:
			_update_map()
		else:
			hud.mission.show_map(false)
	var worst := 0.0
	for g in guards:
		if g.active and g.watching:
			worst = maxf(worst, g.detection)
	if (stage == "yard" or stage == "board") and not _caught_busy:
		hud.set_sneak(player.sneaking or worst > 0.05, worst)
	elif stage == "car_photos" and not _caught_busy:
		hud.set_sneak(worst > 0.05, worst)
	if driving:
		# the player rides along, so the gate's prompt comes up when the car gets there
		player.global_position = motorcar.global_position
		if not _gate_hint and motorcar.global_position.distance_to(mk("gate_out")) < 10.0:
			_gate_hint = true
			hud.set_objective("This is the freight gate. Stop, press E to get out, and walk in through the gate.")
	if stage == "street" and not driving and not _caught_busy and player.has_camera:
		# at the freight gate on foot, or in the yard any other way, and the clock starts
		var pp: Vector3 = player.global_position
		var inside := pp.x > -28.4 and pp.x < 13.6 and pp.z < 26.9 and pp.z > -78.0
		var gate := mk("gate_out").distance_to(pp) < 6.0 or mk("gate_in").distance_to(pp) < 6.0
		if inside or gate:
			_start_mission()
	if _clock_on and not _caught_busy and not in_scene:
		_clock -= delta
		hud.mission.set_clock(_clock_text, maxf(_clock, 0.0))
		if stage == "yard" or stage == "board":
			_yard_schedule()
		if _clock <= 0.0:
			_clock_on = false
			if _clock_out.is_valid():
				_clock_out.call()
	if stage == "car_photos":
		_car_watch()
	if stage == "room_photos" or stage == "room_copy":
		_arthur_tick(delta)
	if player.camera_up:
		hud.mission.set_finder(film, player.zoom, not _framed_subject().is_empty())
	var pulse := 0.22 + 0.12 * sin(Time.get_ticks_msec() * 0.003)
	for b in beacons:
		if is_instance_valid(b[0]):
			(b[0] as Sprite3D).modulate.a = pulse
	for w in window_scroll:
		var m: ShaderMaterial = w
		m.set_shader_parameter("offset", fmod(float(m.get_shader_parameter("offset")) + delta * 0.09, 1.0))


# ================================================================== STONES
## F throws one where you're looking. Where it lands it clatters, and any watchman within earshot
## walks over to see what it was, and stands there a while swinging his lantern.
func _on_throw(from: Vector3, vel: Vector3) -> void:
	_update_item()
	var rb := RigidBody3D.new()
	rb.mass = 0.4
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	rb.continuous_cd = true
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.06
	cs.shape = sph
	rb.add_child(cs)
	rb.add_child(_stone_mesh(0.065))
	level.add_child(rb)
	rb.global_position = from
	rb.add_collision_exception_with(player)
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	rb.body_entered.connect(_stone_landed.bind(rb))


func _stone_mesh(r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.6
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("6d665c")
	m.roughness = 0.95
	mi.material_override = m
	return mi


func _stone_landed(_other: Node, rb: RigidBody3D) -> void:
	if not is_instance_valid(rb) or rb.has_meta("landed"):
		return
	rb.set_meta("landed", true)
	var at := rb.global_position
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://sounds/stone.wav")
	snd.unit_size = 8.0
	snd.volume_db = 2.0
	level.add_child(snd)
	snd.global_position = at
	snd.finished.connect(snd.queue_free)
	snd.play()
	var heard := 0
	for g in guards:
		if not g.active:
			continue
		if (g as Node3D).global_position.distance_to(at) < 17.0:
			g.heard_noise(at)
			heard += 1
	if heard == 0 and stage in ["yard", "board"]:
		hud.toast("Nobody near enough to hear that one.", 2.0)


func _lay_stones() -> void:
	## two more stones hidden in the yard: on top of a crate stack, and up on the empty boxcar's roof
	for p in _piles:
		if is_instance_valid(p[0]):
			(p[0] as Node).queue_free()
	_piles.clear()
	_drop_interactable("stones")
	for k in 2:
		var mk_name := "stones_%d" % k
		if not marks.has(mk_name):
			continue
		var pile := Node3D.new()
		level.add_child(pile)
		pile.global_position = mk(mk_name)
		for j in 3:
			var s := _stone_mesh(0.05 + 0.015 * j)
			s.position = Vector3(0.07 * j - 0.07, 0.04, 0.05 * (j % 2))
			pile.add_child(s)
		_piles.append([pile, mk_name])
		_add(mk(mk_name) + Vector3(0, 0.3, 0), 0.75, "Pick up a good throwing stone", _pick_stone.bind(k), "stones")


func _pick_stone(k: int) -> void:
	for p in _piles:
		if String(p[1]) == "stones_%d" % k and is_instance_valid(p[0]):
			(p[0] as Node).queue_free()
	var keep := []
	for it in main.interactables:
		if (it["cb"] as Callable).get_bound_arguments() != [k] or String(it.get("tag", "")) != "stones":
			keep.append(it)
	main.interactables = keep
	player.stones += 1
	_update_item()
	hud.toast("A good throwing stone.  You have %d." % player.stones, 2.5)


# ================================================================== THE POCKET KODAK
## An item once Jekyll hands it over: Q holds it up, the wheel zooms, a click takes the picture.
## Whatever is nearest the middle of the viewfinder, big enough in the frame and in plain sight,
## is what the picture is of. A subject is [key, point, size in meters, farthest it can be].
func _give_camera() -> void:
	player.has_camera = true
	film = FILM
	_update_item()


func _map_ok() -> bool:
	return player != null and player.has_camera and stage in ["street", "yard", "board"]


func toggle_map() -> void:
	## M: Jekyll's sketch of the yard, held up at the side of your view. The yard doesn't stop for it.
	if hud.mission.map_open:
		hud.mission.show_map(false)
		return
	if not _map_ok() or in_scene or _caught_busy:
		return
	if player.camera_up:
		player.set_camera_up(false)
	hud.mission.show_map(true)
	_update_map()


func _update_map() -> void:
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector3(0, 0, -1)
	if cam:
		fwd = -cam.global_transform.basis.z
	hud.mission.set_map_player(player.global_position, fwd)


func _update_item() -> void:
	var t := ""
	if player.has_camera:
		t = "Q   Pocket Kodak   ·   %d exposures left" % film
	if player.stones > 0 or stage in ["yard", "board", "street"] and player.has_camera:
		t += "\nF   Stones   ·   %d" % player.stones
	if _map_ok():
		t += "\nM   Jekyll's sketch of the yard"
	hud.mission.set_item(t)


var _base_exposure := -1.0   # the room's own exposure (the yard lifts it a little); boosts ride on top
var _boost := 1.0
var _night_air := []          # the night preset's exposure and ambient, as River Street has them


func _boost_exposure(factor: float) -> void:
	_boost = factor
	_apply_exposure()


func _restore_exposure() -> void:
	_boost = 1.0
	_apply_exposure()


func _apply_exposure() -> void:
	var env: Environment = main.env
	if env == null:
		return
	if _base_exposure < 0.0:
		_base_exposure = env.tonemap_exposure
	env.tonemap_exposure = _base_exposure * _boost


func _yard_air() -> void:
	## past the gate your eyes have got used to the dark: the yard reads a little lighter than the street
	var env: Environment = main.env
	if env == null or _night_air.is_empty():
		return
	_base_exposure = float(_night_air[0]) * 1.3
	env.ambient_light_energy = float(_night_air[1]) * 1.6
	_apply_exposure()


func _on_camera_toggled(on: bool) -> void:
	hud.mission.show_finder(on)
	# through the lens your eye opens up to the dark, so the faces can be made out
	if on:
		hud.mission.set_finder(film, player.zoom, false)
		hud.mission.show_map(false)
		_boost_exposure(2.4 if stage in ["yard", "board"] else (3.0 if stage == "street" else 1.4))
	else:
		_restore_exposure()


func _subjects() -> Array:
	var out := []
	match stage:
		"yard", "board":
			for k in MEN.keys():
				var key := String(k)
				if photos.has(key) or _boarded.has(key):
					continue
				var a = actors.get(key)
				if a == null or not is_instance_valid(a) or not (a as Node3D).visible:
					continue
				out.append([key, (a as Node3D).global_position, 1.8, 70.0])
			for i in LOOKALIKES.size():
				var la = actors.get("decoy_%d" % i)
				if la != null and is_instance_valid(la) and (la as Node3D).visible:
					out.append(["decoy_%d" % i, (la as Node3D).global_position, 1.8, 70.0])
		"car_photos":
			for k in CAR_PHOTOS:
				if not photos.has(k):
					out.append([String(k), _paper_pos(String(k)), 0.3, 2.6])
		"room_photos":
			if not photos.has("chalkboard"):
				out.append(["chalkboard", mk("chalk_spot") + Vector3(-0.8, 1.2, 0.0), 1.4, 9.0])
			if not photos.has("notes_paul"):
				out.append(["notes_paul", mk("notes_paul"), 0.3, 2.4])
			if not photos.has("notes_abe"):
				out.append(["notes_abe", mk("notes_abe"), 0.3, 2.4])
	return out


func _framed_subject() -> Array:
	## the subject nearest the middle of the viewfinder that's big enough and in plain sight
	var cam: Camera3D = player.fp_cam
	var fr: Rect2 = hud.mission.frame_rect()
	if fr.size.y < 1.0:
		return []
	var right := cam.global_transform.basis.x
	var space := cam.get_world_3d().direct_space_state
	var best := []
	var best_d := 1e9
	for s in _subjects():
		var p: Vector3 = s[1]
		var sz: float = s[2]
		var reach: float = s[3]
		var mid := p + Vector3(0, sz * 0.55 if sz > 1.0 else 0.0, 0)
		if cam.global_position.distance_to(mid) > reach or cam.is_position_behind(mid):
			continue
		var c2 := cam.unproject_position(mid)
		if not fr.has_point(c2):
			continue
		var span := cam.unproject_position(mid + right * sz * 0.5).distance_to(cam.unproject_position(mid - right * sz * 0.5))
		if span / fr.size.y < (0.16 if sz > 1.0 else 0.2):
			continue
		# in plain sight: nothing solid between the lens and it (what's behind it doesn't count)
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, mid)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and cam.global_position.distance_to(hit["position"] as Vector3) < cam.global_position.distance_to(mid) - 0.6:
			continue
		var d := c2.distance_to(fr.get_center())
		if d < best_d:
			best_d = d
			best = s
	return best


func _on_shutter() -> void:
	if not player.camera_up or _caught_busy or in_scene:
		return
	if film <= 0:
		hud.toast("Out of film.", 2.0)
		return
	film -= 1
	_update_item()
	var s := _framed_subject()
	Sound.one_shot(self, "shutter", -4.0)
	var tex := await _grab_frame()
	hud.mission.shutter_flash()
	if s.is_empty():
		hud.mission.show_print(tex, "Nothing much", "Fog and lamplight. That one's wasted.", "")
		_after_miss()
		return
	_record_photo(String(s[0]), tex)


func _grab_frame() -> Texture2D:
	## what the viewfinder saw, without the viewfinder
	hud.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.visible = true
	if img == null or img.is_empty():
		return _blank_print()
	var fr: Rect2 = hud.mission.frame_rect()
	var vs := get_viewport().get_visible_rect().size
	var sc := Vector2(float(img.get_width()) / vs.x, float(img.get_height()) / vs.y)
	var r := Rect2i(Vector2i(fr.position * sc), Vector2i(fr.size * sc)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x < 8 or r.size.y < 8:
		return _blank_print()
	var crop := img.get_region(r)
	crop.resize(480, 320, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(crop)


func _blank_print() -> Texture2D:
	var img := Image.create(48, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.18, 0.15))
	return ImageTexture.create_from_image(img)


func _record_photo(key: String, tex: Texture2D) -> void:
	if key.begins_with("decoy"):
		hud.mission.show_print(tex, "A stranger", "Just a traveler off the late train. Not one of the seven, and that's film you won't get back.", "")
		_after_miss()
		return
	photos.append(key)
	var title := ""
	var sub := ""
	var stamp := ""
	var slot := -1
	var caption := ""
	if WHO.has(key):
		var who: Array = WHO[key]
		title = String(who[0])
		sub = String(who[1])
		var n := 0
		for k in MEN.keys():
			if photos.has(String(k)):
				n += 1
		stamp = "%d of 7" % n
		slot = n - 1
		caption = String(MEN[key]["name"])
	else:
		var info: Array = PHOTOS[key]
		title = String(info[0])
		sub = String(info[1])
	hud.mission.show_print(tex, title, sub, stamp, slot, caption)
	_after_photo(key)


func _after_photo(key: String) -> void:
	match stage:
		"yard", "board":
			hud.set_timer(_tally(MEN.keys()))
			var n := 0
			for k in MEN.keys():
				if photos.has(String(k)):
					n += 1
			if n >= 7 and stage == "yard":
				_all_seven()
		"car_photos":
			hud.set_timer(_tally(CAR_PHOTOS))
			var all_done := true
			for k in CAR_PHOTOS:
				if not photos.has(k):
					all_done = false
			if all_done:
				_drop_beacon("valise")
				_car_done()
		"room_photos":
			_drop_beacon(key)
			hud.set_timer(_tally(ROOM_PHOTOS))
			var all_done := true
			for k in ROOM_PHOTOS:
				if not photos.has(k):
					all_done = false
			if all_done:
				_room_copy()


func _after_miss() -> void:
	if film > 0:
		return
	match stage:
		"yard":
			_yard_reset("", "", "Out of film", "The roll ran out before you had all seven. Try again, and make every picture count.")
		"car_photos":
			_car_caught("", "The roll ran out before you had every page. Try again.")
		"room_photos":
			_room_caught("The roll ran out before you had it all. Try again.")


func _paper_pos(key: String) -> Vector3:
	## the papers spread on the lounge desk by Arthur's valise
	var v := mk("valise")
	match key:
		"outline":
			return v + Vector3(-0.05, 0.775, 0.55)
		"figures":
			return v + Vector3(0.17, 0.775, 0.28)
		"panic":
			return v + Vector3(-0.08, 0.775, 0.02)
	return v + Vector3(0.05, 1.01, -0.3)


func _lay_papers() -> void:
	## loose sheets on the desk, written close, for the camera to find
	var img := Image.create(64, 84, false, Image.FORMAT_RGB8)
	img.fill(Color("e8dcc0"))
	for row in range(8, 78, 5):
		var x := 6
		while x < 58:
			var w := randi_range(3, 9)
			for dx in w:
				if x + dx < 58:
					img.set_pixel(x + dx, row, Color("3a3024"))
			x += w + randi_range(2, 4)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.9
	for k in CAR_PHOTOS:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.21, 0.28)
		mi.mesh = pm
		mi.material_override = mat
		mi.position = _paper_pos(String(k)) + Vector3(0, 0.003, 0)
		mi.rotation.y = randf_range(-0.4, 0.4)
		level.add_child(mi)


# ================================================================== THE PRIVATE CAR
func _build_privatecar() -> void:
	main._air("train")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	_load("res://models/private_car.glb")
	main._safety_floor()
	main._dust(Vector3(0.0, 1.5, 0.0), Vector3(1.5, 1.0, 10.0), 180)
	_window_view()
	var seats := {"frank": "seat_frank", "harry": "seat_harry", "paul": "seat_paul", "ben": "seat_ben",
		"nelson": "seat_nelson", "abe": "seat_abe", "arthur": "seat_arthur"}
	for key in seats.keys():
		var k := String(key)
		var a := _actor(k)
		a.idle_anim = "SitTalk" if k in ["frank", "harry", "nelson"] else ("SitDrink" if k in ["ben", "abe"] else "Sit")
		a.indoors()
		a.place(mk(String(seats[key])), mk_yaw(String(seats[key])))
		a.play(a.idle_anim, 0.0, randf_range(0.85, 1.1))
	# the real steward, forward in the baggage car for now
	var st := _guard("res://models/npc_steward.glb", "The steward", _route("stew", [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]), false, false)
	st.lines_suspicious = ["Who's back there?", "Can I help you, friend?"]
	st.lines_clear = ["Hm. Thought I saw somebody.", "Must be the lamps."]
	st.pauses = {0: 9.0, 5: 6.0}
	st.patrol_speed = 1.2
	st.visible = false
	st.place(mk("stew_0") + Vector3(0, -20, 0), 0.0)
	_lay_papers()
	player.place(mk("pc_spawn"), mk_yaw("pc_spawn"))
	player.sneaking = false
	player.can_sneak = true
	_play_ambience("train")


func _window_view() -> void:
	## the dark country sliding past the windows
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D view : source_color, repeat_enable, filter_linear_mipmap;
uniform float offset = 0.0;
uniform float bright = 0.8;
void fragment() {
	vec2 uv = vec2(UV.x * 1.0 + offset, UV.y);
	ALBEDO = texture(view, uv).rgb * bright;
}"""
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(60.0, 6.0)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("view", load("res://textures/night_scroll.png"))
		m.set_shader_parameter("offset", 0.0 if side < 0 else 0.5)
		mi.material_override = m
		mi.position = Vector3(side * 6.0, 1.6, 0.0)
		mi.rotation.y = side * PI / 2.0
		level.add_child(mi)
		window_scroll.append(m)


func _run_privatecar() -> void:
	hud.show_location("The Senator's Private Car", "Southbound, November 1910")
	hud.set_objective("Get close enough to hear them. Try the pantry door.")
	main.add_interactable(mk("peek"), 1.2, "Listen at the pantry door", _peek)
	await wait(1.5)
	await thought("The pantry. Warm, smells like coffee. Voices past the door.")


func _peek() -> void:
	main.interactables.clear()
	begin_scene()
	shot(mk("cam_peek"), mk("cam_peek_look"), 42.0)
	await line("Nelson", "Nobody writes a last name down on this trip. Not on a menu card, not on a telegram.")
	await line("Harry", "The newspapers would have a fine time with this car, Nelson.")
	await line("Paul", "In 1907 the whole country ran for its cash at the same moment, and there was nowhere to borrow it.")
	await line("Ben", "Harry and I sat up nights that fall deciding which banks could be saved. I don't care to do it again.")
	await line("Nelson", "That's why we're here. Congress asked my commission for a plan, and I mean to bring it one.")
	await line("Frank", "Then we will need more coffee. Where has that steward got to?")
	end_scene()
	hud.set_objective("Find the steward's jacket in the galley.")
	main.add_interactable(mk("jacket"), 1.1, "Put on the steward's white jacket", _jacket)
	await thought("He's gone forward to the baggage car. His spare jacket is on the hook.")


func _jacket() -> void:
	main.interactables.clear()
	main.busy = true
	await hud.fade_to(1.0, 0.4).finished
	player.set_outfit("waiter")
	player.can_sneak = false
	player.sneaking = false
	await get_tree().create_timer(0.3).timeout
	await hud.fade_to(0.0, 0.5).finished
	main.busy = false
	hud.set_objective("Take the coffee tray from the counter.")
	main.add_interactable(mk("tray"), 1.1, "Take the coffee tray", _tray)
	await thought("A little big in the shoulders. Nobody looks twice at a steward, and Jekyll's Kodak fits the pocket.")


func _tray() -> void:
	main.interactables.clear()
	player.set_carrying(true)
	hud.set_objective("Frank and the Senator asked for coffee. Keep your head down and your ears open.")
	served.clear()
	for key in ["frank", "nelson"]:
		var a = actors[key]
		main.add_interactable(a.global_position + Vector3(0, 0.6, 0), 1.35, "Pour the gentleman's coffee", _serve.bind(key))


func _serve(key: String) -> void:
	if served.has(key) or in_scene:
		return
	served[key] = true
	# take this man off the list of people to serve
	var keep := []
	for it in main.interactables:
		if (it["cb"] as Callable).get_bound_arguments() != [key]:
			keep.append(it)
	main.interactables = keep
	main.busy = true
	player.enabled = false
	var a = actors[key]
	_face_player_to(a.global_position)
	player.play_once("Serve")
	await get_tree().create_timer(0.9).timeout
	match key:
		"frank":
			await line("Frank", "Thank you. Wilbur, pass the sugar.")
			await line("Harry", "Here you are, Orville.")
			await thought("Orville and Wilbur. The Wright brothers.")
			await line("Frank", "On the theory that we are always right.")
			await line("Harry", "And if anybody asks, Paul, we are going duck hunting.")
			await line("Paul", "I have never shot a duck in my life.")
			await line("Harry", "Neither has Frank. Don't tell anybody.")
		"nelson":
			await line("Nelson", "You're new.")
			await thought("Don't look up.")
			await line("Nelson", "Well. Leave the pot.")
			await line("Nelson", "Arthur, keep that valise where you can see it. What's in it doesn't exist yet.")
			await line("Arthur", "It hasn't left my elbow since Washington, Nelson.")
	main.busy = false
	player.enabled = true
	if served.size() >= 2:
		_car_night()


func _car_night() -> void:
	## the men turn in; Arthur dozes off by his valise; the real steward comes back
	player.set_carrying(false)
	begin_scene()
	shot(mk("cam_peek"), mk("cam_peek_look"), 48.0)
	await line("Nelson", "Gentlemen, get some sleep. We reach Brunswick tomorrow, and there may be newspapermen at the station.")
	await line("Harry", "Leave them to me.")
	hud.fade_to(1.0, 1.0)
	await wait(1.1)
	skipping = false
	for k in MEN.keys():
		if String(k) != "arthur":
			(actors[k] as Node3D).visible = false
	var arthur = actors["arthur"]
	arthur.idle_anim = "Sit"
	arthur.play("Sit", 0.3, 0.6)
	player.place(mk("pc_reset"), mk_yaw("pc_reset"))
	shot(mk("cam_lounge"), mk("cam_lounge_look"), 50.0)
	hud.fade_to(0.0, 1.0)
	await line("", "One by one they went off to their berths. Arthur stayed where he was, on the sofa by his valise, and nodded off.")
	await thought("The steward's back from the baggage car, making his rounds. He'll turn the lamps down in a few minutes.")
	end_scene()
	stage = "car_photos"
	photos.clear()
	_arm_car()


func _arm_car() -> void:
	var st = guards[0]
	st.visible = true
	st.reset_to(mk("stew_0"), 0)
	st.active = true
	st.watching = false
	film = 8
	_update_item()
	hud.set_objective("Photograph the four papers by Arthur's valise.   Q for the camera. The steward mustn't catch you back in the lounge.")
	hud.set_timer(_tally(CAR_PHOTOS))
	_set_clock(ROUNDS_SECONDS, "The steward turns the lamps down in", _lamps_down)
	_clear_beacons()
	_beacon(mk("valise") + Vector3(0, 1.6, 0), "valise")


func _car_watch() -> void:
	## the steward minds you only in the lounge, where the gentlemen are sleeping
	if stage != "car_photos" or guards.is_empty():
		return
	guards[0].watching = player.global_position.z < -5.05


func _lamps_down() -> void:
	if stage == "car_photos":
		_car_caught("The steward", "The steward came to turn the lamps down and found you still in the lounge. Try again.")


func _car_caught(who: String, sub := "The steward caught a stranger in a white jacket going through Arthur's valise. Try again.") -> void:
	if _caught_busy:
		return
	_caught_busy = true
	_clock_on = false
	player.set_camera_up(false)
	var st = guards[0]
	st.active = false
	player.enabled = false
	main.busy = true
	if who != "":
		hud.say(who, "Say. Who are you? You're not with this car.", 2.5)
	await get_tree().create_timer(1.8).timeout
	await hud.fade_to(1.0, 0.8).finished
	hud.show_card("Caught", sub, 1.8)
	await get_tree().create_timer(2.8).timeout
	for k in CAR_PHOTOS:
		photos.erase(k)
	player.place(mk("pc_reset"), mk_yaw("pc_reset"))
	main.busy = false
	player.enabled = true
	_caught_busy = false
	_arm_car()
	await hud.fade_to(0.0, 1.0).finished


func _car_done() -> void:
	stage = "car_done"
	_stop_clock()
	_clear_beacons()
	main.interactables.clear()
	for g in guards:
		g.active = false
	hud.set_sneak(false)
	hud.set_timer("")
	player.set_camera_up(false)
	await thought("All four. Close the valise, just the way it was.")
	begin_scene()
	shot(mk("cam_lounge"), mk("cam_lounge_look"), 50.0)
	hud.fade_to(1.0, 1.5)
	await wait(1.6)
	skipping = false
	await wait(hud.show_card("Brunswick, Georgia", "The next day", 2.5))
	await line("", "The way they told it later, a few newspapermen were waiting at the Brunswick station. Harry went out and talked with them. He came back and said they would print nothing.")
	await line("", "A launch took them across to Jekyll Island. The club was closed for the season. They had it to themselves.")
	end_scene()
	stage = "jekyll"
	main.go_to("jekyll", Vector3.ZERO, 0.0)


# ================================================================== JEKYLL ISLAND
func _build_jekyll() -> void:
	main._air("jekyll")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	var grounds: Node3D = main._instance("res://models/clubhouse_exterior.glb")
	Foliage.dress(grounds, level, 11)
	for n in grounds.find_children("Sign*", "Node3D", true, false):
		(n as Node3D).visible = false
	for n in grounds.find_children("Art_Ribbon*", "Node3D", true, false):
		(n as Node3D).visible = false
	main._safety_floor()
	# no gaslight in the morning, just the grey day
	var start := Vector3(0.0, 0.4, 30.0)
	var keys := ["nelson", "arthur", "abe", "paul", "frank", "harry", "ben"]
	for i in keys.size():
		var a := _actor(keys[i])
		var off := Vector3((i % 2) * 1.2 - 0.6, 0.0, float(i) * 1.6)
		a.place(start + off + Vector3(0, 0, -6.0), PI)
		a.walk([Vector3(off.x, 0.3, 6.0 + off.z * 0.5), Vector3(off.x * 0.5, 1.0, 2.4), Vector3(0.0, 1.0, 0.7), Vector3(0.0, 1.0, -0.8)], _speed(keys[i]))
	player.place(start + Vector3(0.0, 0.0, 8.0), 0.0)
	player.can_sneak = false
	_play_ambience("marsh")


func _run_jekyll() -> void:
	hud.show_location("Jekyll Island, Georgia", "Late November, 1910")
	hud.set_objective("Follow them up to the clubhouse.")
	main.add_interactable(Vector3(0.0, 1.5, 1.0), 1.6, "Go inside after them", _enter_meeting)
	_door_when_near()
	await wait(2.0)
	await thought("Live oaks and moss, and not another soul on the island.")
	var here := level
	for a in actors.values():
		await until_arrived(a)
		if level != here or not is_instance_valid(a):
			return
		a.visible = false


func _door_when_near() -> void:
	## the front door swings open as the first of them reaches the porch
	var opened := false
	var here := level
	while not opened and stage == "jekyll" and level == here:
		for a in actors.values():
			if is_instance_valid(a) and (a as Node3D).global_position.z < 3.0 and (a as Node3D).visible:
				opened = true
		if skipping:
			opened = true
		await get_tree().process_frame
	if stage == "jekyll":
		main.swing_door("Door_Front")


func _enter_meeting() -> void:
	main.interactables.clear()
	stage = "meeting"
	main.go_to("meeting", Vector3.ZERO, 0.0)


# ================================================================== THE MEETING ROOM
func _build_meeting() -> void:
	main._air("interior")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	_load("res://models/meeting_room.glb")
	main._safety_floor()
	main._dust(Vector3(0.0, 1.9, 0.0), Vector3(5.3, 1.7, 3.3), 260)
	for key in MEN.keys():
		var k := String(key)
		var a := _actor(k)
		var seat: String = "seat_" + k
		a.idle_anim = "SitWrite" if k in ["arthur", "abe"] else ("SitTalk" if k in ["nelson", "paul", "frank"] else "Sit")
		a.indoors()
		a.place(mk(seat), mk_yaw(seat))
		a.play(a.idle_anim, 0.0, randf_range(0.85, 1.1))
	player.place(mk("mt_spawn"), mk_yaw("mt_spawn"))
	player.set_carrying(true)
	player.can_sneak = false
	_play_ambience("fire")


func _run_meeting() -> void:
	hud.show_location("The Clubhouse", "Jekyll Island, November 1910")
	hud.set_objective("Pour Nelson's coffee. Listen to the plan take shape.")
	served.clear()
	var a = actors["nelson"]
	main.add_interactable(a.global_position + Vector3(0, 0.6, 0), 1.5, "Pour the gentleman's coffee", _pour.bind("nelson"))
	await wait(1.5)
	await thought("They've been at it since breakfast. The chalkboard is filling up.")


func _pour(key: String) -> void:
	if served.has(key) or in_scene:
		return
	served[key] = true
	main.interactables.clear()
	main.busy = true
	player.enabled = false
	var a = actors[key]
	_face_player_to(a.global_position)
	player.play_once("Serve")
	await get_tree().create_timer(0.9).timeout
	main.busy = false
	player.enabled = true
	_plan_scene()


func _plan_scene() -> void:
	player.set_carrying(false)
	begin_scene()
	shot(mk("cam_table"), mk("cam_table_look"), 46.0)
	await line("Paul", "One reserve, held in common, Nelson. A central bank, the way every country in Europe has one.")
	await line("Nelson", "Say 'central bank' on the floor of the Senate and the plan dies that afternoon. We'll call it an association. A National Reserve Association.")
	await line("Abe", "Then spread it out. Fifteen districts, a branch in each, so the farmer in Kansas and the banker in Boston both have a door to knock on.")
	await line("Ben", "And the branches rediscount good commercial paper. A sound bank can always turn its loans into cash.")
	await line("Frank", "The notes have to stretch. More currency at harvest, when the crops move, and back again after. The old system could not bend at all.")
	await line("Paul", "An elastic currency. That is the whole point.")
	await line("Abe", "Who sits on the board?")
	await line("Harry", "The banks own it, so the banks elect most of the board.")
	await line("Abe", "Washington will want a say.")
	await line("Nelson", "Washington gets a few seats. That's as far as I can carry it.")
	await line("Arthur", "A Suggested Plan for Monetary Legislation. That's what we'll call the report.")
	await line("Nelson", "Good. Arthur, make us a clean copy. The rest of you, get your guns. If anybody on this island asks, we came here to shoot ducks.")
	await line("Harry", "And we might even hit one.")
	# out they go, each at his own pace; Arthur stays and writes
	shot(mk("cam_door"), mk("cam_door_look"), 55.0)
	var leaving := ["nelson", "harry", "frank", "paul", "ben", "abe"]
	for i in leaving.size():
		var k := String(leaving[i])
		var m = actors[k]
		m.idle_anim = "Idle"
		m.play("Idle", 0.3)
		m.walk([mk("mt_door") + Vector3(0.3 * (i % 2), 0, -0.3), mk("mt_out")], _speed(k))
		await wait(0.9)
	for k in leaving:
		await until_arrived(actors[k])
		(actors[k] as Node3D).visible = false
	end_scene()
	_arm_room()


func _arm_room() -> void:
	stage = "room_photos"
	for k in ROOM_PHOTOS:
		photos.erase(k)
	have_copy = false
	film = 8
	_update_item()
	_arthur_sit()
	_clear_beacons()
	hud.set_objective("Photograph the chalkboard and both sets of notes.   Q for the camera. Keep it down whenever Arthur looks up.")
	hud.set_timer(_tally(ROOM_PHOTOS))
	_beacon(mk("chalk_spot") + Vector3(-0.6, 2.9, 0), "chalkboard")
	_beacon(mk("notes_paul") + Vector3(0, 0.9, 0), "notes_paul")
	_beacon(mk("notes_abe") + Vector3(0, 0.9, 0), "notes_abe")
	await thought("Arthur's copying it out fair. Every so often he looks up. Don't be holding a camera when he does.")


# ------------------------------------------------------------------ Arthur at his writing
func _arthur_sit() -> void:
	var a = actors["arthur"]
	a.visible = true
	a.place(mk("seat_arthur"), mk_yaw("seat_arthur"))
	a.idle_anim = "SitWrite"
	a.play("SitWrite", 0.3)
	_arthur_state = "writing"
	_arthur_t = randf_range(5.0, 8.0)
	_arthur_seen = 0.0
	_shot_t = 14.0


func _arthur_tick(delta: float) -> void:
	if _caught_busy or in_scene:
		return
	var a = actors["arthur"]
	_arthur_t -= delta
	match _arthur_state:
		"writing":
			if _arthur_t <= 0.0:
				_arthur_state = "looking"
				_arthur_t = randf_range(2.2, 3.4)
				a.idle_anim = "Sit"
				a.play("Sit", 0.25)
		"looking":
			if _arthur_t <= 0.0:
				_arthur_state = "writing"
				_arthur_t = randf_range(5.0, 8.5)
				a.idle_anim = "SitWrite"
				a.play("SitWrite", 0.3)
		"window":
			if _arthur_t <= 0.0:
				_arthur_state = "walking"
				a.walk([mk("seat_arthur")], _speed("arthur"))
		"walking":
			if not a.is_walking():
				if have_copy:
					_room_caught("Arthur came back to the table and the clean copy was gone. So were you, almost. Try again.")
					return
				_arthur_sit()
				_shot_t = randf_range(18.0, 24.0)
	# while he looks up, a camera held up in plain view gets noticed quickly
	var risky: bool = player.camera_up
	if _arthur_state == "looking" and risky:
		_arthur_seen += delta * 1.7
	else:
		_arthur_seen = maxf(0.0, _arthur_seen - delta * 0.8)
	hud.set_sneak(_arthur_state == "looking" or _arthur_seen > 0.05, maxf(_arthur_seen, 0.12 if _arthur_state == "looking" else 0.0))
	if _arthur_seen >= 1.0:
		_room_caught("Arthur looked up and saw the camera. Try again.")
		return
	# once the pictures are taken, a shot out on the marsh draws him to the window
	if stage == "room_copy" and _arthur_state in ["writing", "looking"]:
		_shot_t -= delta
		if _shot_t <= 0.0:
			_arthur_to_window()


func _room_copy() -> void:
	stage = "room_copy"
	hud.set_timer("")
	player.set_camera_up(false)
	hud.set_objective("Now the clean copy, on the table by Arthur. Take it when he isn't looking, and get out the door.")
	_add(mk("draft"), 1.3, "Take the clean copy", _take_copy, "copy")
	_beacon(mk("draft") + Vector3(0, 0.8, 0), "copy")
	_shot_t = 4.0
	await thought("Not from under his nose. Wait for a reason for him to get up.")


func _arthur_to_window() -> void:
	if _arthur_state == "window" or _arthur_state == "walking":
		return
	Sound.one_shot(self, "shot", -3.0)
	var a = actors["arthur"]
	a.idle_anim = "Idle"
	a.play("Idle", 0.3)
	await line("Arthur", "Well, I'll be. One of them actually fired that thing.")
	a.walk([mk("arthur_window")], _speed("arthur"))
	_arthur_state = "window"
	_arthur_t = 11.0
	await until_arrived(a)
	a.face_yaw(mk_yaw("arthur_window"))


func _take_copy() -> void:
	if have_copy or _caught_busy:
		return
	if _arthur_state != "window":
		_room_caught("You reached for the copy right in front of him. Arthur was not asleep. Try again.")
		return
	have_copy = true
	Sound.one_shot(self, "shutter", -18.0)
	_drop_interactable("copy")
	_drop_beacon("copy")
	hud.toast("The clean copy: A Suggested Plan for Monetary Legislation", 3.0)
	hud.set_objective("Out the door before Arthur turns around.")
	_add(mk("mt_door"), 1.2, "Slip out the door", _slip_out, "door")
	_beacon(mk("mt_door") + Vector3(0, 2.4, 0), "door")


func _slip_out() -> void:
	if not have_copy or _caught_busy:
		return
	stage = "room_done"
	_clear_beacons()
	main.interactables.clear()
	hud.set_sneak(false)
	hud.set_objective("")
	_meeting_done()


func _room_caught(sub: String) -> void:
	if _caught_busy:
		return
	_caught_busy = true
	player.set_camera_up(false)
	player.enabled = false
	main.busy = true
	hud.say("Arthur", "What on earth are you doing?", 2.2)
	await get_tree().create_timer(1.6).timeout
	await hud.fade_to(1.0, 0.8).finished
	hud.show_card("Caught", sub, 1.8)
	await get_tree().create_timer(2.8).timeout
	main.interactables.clear()
	player.place(mk("mt_spawn"), mk_yaw("mt_spawn"))
	main.busy = false
	player.enabled = true
	_caught_busy = false
	hud.set_sneak(false)
	_arm_room()
	await hud.fade_to(0.0, 1.0).finished


func _meeting_done() -> void:
	begin_scene()
	shot(mk("cam_door"), mk("cam_door_look"), 55.0)
	hud.fade_to(1.0, 1.2)
	await wait(1.3)
	skipping = false
	for key in MEN.keys():
		(actors[key] as Node3D).visible = false
	end_scene()
	main.busy = true
	_read_evidence()


func _read_evidence() -> void:
	var body := "[i]What you brought back from 1910. The papers are imagined; what they describe is not.[/i]\n\n"
	body += "[b]On the platform at Hoboken[/b]\n"
	for k in MEN.keys():
		if photos.has(String(k)):
			var who: Array = WHO[String(k)]
			body += "[b]" + String(who[0]) + ".[/b] " + String(who[1]) + "\n"
	body += "\n[b]From Arthur's valise, on the train[/b]\n"
	for k in CAR_PHOTOS:
		if photos.has(k):
			var info: Array = PHOTOS[k]
			body += "[b]" + String(info[0]) + ".[/b] " + String(info[1]) + "\n"
	body += "\n[b]From the room on Jekyll Island[/b]\n"
	for k in ROOM_PHOTOS:
		if photos.has(k):
			var info2: Array = PHOTOS[k]
			body += "[b]" + String(info2[0]) + ".[/b] " + String(info2[1]) + "\n"
	if have_copy:
		body += "[b]The clean copy.[/b] A Suggested Plan for Monetary Legislation, in Arthur's hand.\n"
	body += "\n[b]What became of it[/b]\n\n"
	body += "In January 1911 Senator Nelson Aldrich put the plan before his National Monetary Commission. It called for a [b]National Reserve Association[/b]: one reserve owned by the banks, fifteen districts with a branch in each, notes that could grow and shrink with the needs of trade, and a board chosen mostly by the banks, with a few members named by the government.\n\n"
	body += "Congress never passed it. Aldrich left the Senate in 1911, and by 1913 the Democrats held the House, the Senate and the White House. They were not going to pass a bill with his name on it.\n\n"
	body += "But a good deal of it came back. The [b]Federal Reserve Act[/b], signed by President Woodrow Wilson on December 23, 1913, kept the regional idea, with twelve Reserve Banks instead of fifteen, and the elastic currency. It put a Federal Reserve Board appointed by the President over the whole thing. The Reserve Banks opened for business in November 1914.\n\n"
	body += "For years the men kept quiet about the trip. The journalist B. C. Forbes wrote about it in 1916, and Frank Vanderlip told the story himself in 1935.\n\n"
	body += "[i]Accounts differ on some details, including exactly who else was there. The scenes you just played are a dramatization: Jekyll, the lines, the photographs and the stolen copy are imagined. The meeting, the men, the cover story and the plan are not.[/i]\n\n"
	body += main._link("present", "Walk back out into the present day")
	main.busy = false
	main.open_panel("The Evidence", body)
	main.panel_kind = "draft"


func on_link(meta: String) -> bool:
	if meta == "present":
		main.hud.close_panel()
		leave_to_present()
		return true
	return false


# ------------------------------------------------------------------ staged moments for screenshots
func shot_setup(what: String) -> void:
	## --shot ... setup=<what>: freeze a moment of the chapter to look at
	match what:
		"rear":
			# two of them on the observation platform steps, the rear door open
			var n = actors["nelson"]
			n.visible = true
			n.place(mk("rear_step_2"), 0.0)
			n.face_point_from(mk("rear_step_2"), mk("rear_step_4"))
			n.play("Walk", 0.0, 0.6)
			var ar = actors["arthur"]
			ar.visible = true
			ar.place(mk("rear_step_0") + Vector3(0.4, 0, 0.9), 0.0)
			ar.face_point_from(mk("rear_approach"), mk("rear_step_0"))
			ar.play("Walk", 0.0, 0.7)
			if rear_door:
				rear_door.rotation.y = -1.35
		"front":
			# the player halfway up the front steps, the vestibule door swung in
			player.place(mk("board_4"), 0.0)
			player.face(_yaw_to(mk("board_3"), mk("board_7")))
			player._play("Walk")
			if front_door:
				front_door.rotation.y = 1.4
			_beacon(mk("steps_marker"), "board")
		"yard", "map":
			# the yard as you find it once you're through the gate; map: with Jekyll's sketch held up
			_give_camera()
			stage = "yard"
			_yard_air()
			hud.mission.set_slots(7)
			hud.mission.set_clock("The train leaves in", 361.0)
			hud.set_objective("Photograph all seven men before they go into the Senator's car.   Q for the camera.")
			_update_item()
			if what == "map":
				hud.mission.show_map(true)
				_update_map()
		"finder":
			# looking through the Kodak at a man on the platform, from under the tarp
			var n = actors["nelson"]
			n.visible = true
			n.place(mk("rear_approach"), -PI / 2.0)
			player.has_camera = true
			_give_camera()
			stage = "yard"
			hud.mission.set_slots(7)
			hud.mission.set_clock("The train leaves in", 312.0)
			hud.set_objective("Photograph all seven men before they go into the Senator's car.   Q for the camera.")
			player.hide_at(mk("hide_tarp"), mk_yaw("hide_tarp") + PI, 0.7)
			player.yaw = _yaw_to(mk("hide_tarp"), mk("rear_approach"))
			player.set_camera_up(true)
			player.fp_pitch = 0.02
			player.zoom = 1.6
		"jekyll":
			stage = "street"
			hud.set_objective("Find the man waiting by the motorcar on River Street.")


# ------------------------------------------------------------------ a run-through for testing
## godot --headless --path godot -- --autotest
## Plays the whole chapter with every scene skipped, to catch script errors.
func autotest() -> void:
	print("AUTOTEST start")
	start()
	await _settle("hoboken")
	await _until(_is_stage.bind("street"), 20.0, true)
	await get_tree().create_timer(0.5).timeout
	main.hud.close_panel()
	await get_tree().create_timer(0.3).timeout
	print("AUTOTEST on River Street: watchmen ", guards.size(), ", spots ", spots.size(), ", walkable map ", _nav_ok(), ", Jekyll ", actors.has("jekyll"))
	skipping = true
	await _talk_jekyll()
	await _until(_not_in_scene, 20.0, true)
	skipping = false
	print("  camera: ", player.has_camera, ", film ", film)
	_get_in()
	print("  driving: ", driving)
	motorcar.global_position = mk("park")
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("  at the gate: hint ", _gate_hint, ", prompt offered ", String(main.current.get("prompt", "")))
	_leave_car()
	await get_tree().process_frame
	await get_tree().process_frame
	print("  got out by the gate: stage ", stage, ", clock ", int(_clock))
	player.global_position = mk("gate_in")
	await _until(_is_stage.bind("yard"), 5.0)
	print("AUTOTEST in the yard: clock ", int(_clock), ", watchmen watching ", guards[0].watching)
	print("  HUD root ", hud.root.size, " mission ", hud.mission.size, " finder ", hud.mission.finder.size, " frame ", hud.mission.frame_rect())
	await get_tree().create_timer(2.0).timeout
	var moving := 0
	for g in guards:
		if g.is_walking():
			moving += 1
	print("  watchmen on the move: ", moving, " of ", guards.size())
	# pitch a stone near the first watchman and see if he goes to look
	print("  stones in pocket: ", player.stones, ", hidden piles: ", _piles.size())
	var g0: Node3D = guards[0]
	_on_throw(g0.global_position + Vector3(3.0, 2.0, 0.0), Vector3(0.0, -3.0, 0.0))
	await get_tree().create_timer(1.5).timeout
	print("  after the stone: watchman ", guards[0].state, ", walking ", guards[0].is_walking())
	_pick_stone(0)
	print("  picked up a hidden stone: ", player.stones)
	# hide, climb, come down
	_hide("tarp")
	print("  hidden under the tarp: ", player.hidden, ", seen by the detective: ", guards[0].sees(player.global_position, true))
	_unhide("tarp")
	skipping = true
	await _climb(0, true)
	print("  up the boxcar ladder, standing at height %.1f" % player.global_position.y)
	await _climb(0, false)
	skipping = false
	# a watchman catches you: back to the gate, the cabs start over
	_on_caught(guards[0])
	await _until(_not_caught, 15.0)
	print("AUTOTEST caught reset: clock ", int(_clock), ", photos ", photos.size(), ", film ", film)
	# a man walks up the platform; hold the camera on him
	_clock = MISSION_SECONDS - FIRST_CAB - 0.2
	await _until(_man_visible.bind("nelson"), 10.0)
	await get_tree().create_timer(3.0).timeout
	var n = actors["nelson"]
	print("  nelson came by the ", _routes[0], " way")
	# his way in is random, so stand off him from whichever side has a clear view
	var framed := []
	for off in [Vector3(-9, 0, 0), Vector3(9, 0, 0), Vector3(0, 0, 9), Vector3(0, 0, -9), Vector3(-6, 0, 6), Vector3(6, 0, -6)]:
		player.global_position = n.global_position + off
		player.yaw = _yaw_to(player.global_position, n.global_position)
		player.set_camera_up(true)
		player.fp_pitch = -0.05
		await get_tree().process_frame
		await get_tree().process_frame
		framed = _framed_subject()
		if not framed.is_empty():
			break
	print("  framed in the viewfinder: ", framed[0] if not framed.is_empty() else "nobody")
	if framed.is_empty():
		var cam: Camera3D = player.fp_cam
		var mid: Vector3 = (n as Node3D).global_position + Vector3(0, 1.0, 0)
		print("    frame ", hud.mission.frame_rect(), " man at ", cam.unproject_position(mid), " behind ", cam.is_position_behind(mid), " cam ", cam.global_position, " current ", cam.current, " vp ", get_viewport().get_visible_rect().size)
	player.set_camera_up(false)
	for k in MEN.keys():
		if not photos.has(String(k)):
			_record_photo(String(k), _blank_print())
	print("AUTOTEST all seven: stage ", stage, ", photos ", photos.size())
	player.global_position = mk("vestibule")
	_board()
	skipping = true
	await _settle("privatecar")
	print("AUTOTEST in the private car, men: ", actors.size())
	_peek()
	skipping = true
	await _until(_not_in_scene, 20.0)
	await _jacket()
	print("AUTOTEST outfit: ", player.outfit)
	_tray()
	for key in ["frank", "nelson"]:
		skipping = true
		await _serve(key)
	await _until(_is_stage.bind("car_photos"), 30.0, true)
	print("AUTOTEST car photos armed, steward active: ", guards[0].active, ", film ", film)
	player.global_position = mk("desk_stand")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_car_watch()
	print("  steward minds the lounge: ", guards[0].watching)
	player.yaw = _yaw_to(player.global_position, _paper_pos("outline"))
	player.set_camera_up(true)
	player.fp_pitch = -0.9
	await get_tree().process_frame
	await get_tree().process_frame
	var fr2 := _framed_subject()
	print("  framed on the desk: ", fr2[0] if not fr2.is_empty() else "nothing")
	if fr2.is_empty():
		var cam2: Camera3D = player.fp_cam
		for s in _subjects():
			var p2: Vector3 = s[1]
			print("    ", s[0], " at ", p2, " dist %.2f" % cam2.global_position.distance_to(p2), " screen ", cam2.unproject_position(p2), " behind ", cam2.is_position_behind(p2), " cam ", cam2.global_position, " player ", player.global_position)
	player.set_camera_up(false)
	_car_caught("The steward")
	await _until(_not_caught, 15.0)
	for k in CAR_PHOTOS:
		_record_photo(String(k), _blank_print())
	skipping = true
	await _settle("jekyll")
	print("AUTOTEST on Jekyll, men: ", actors.size(), ", photos ", photos.size())
	skipping = true
	for a in actors.values():
		a.skip()
	_enter_meeting()
	await _settle("meeting")
	print("AUTOTEST in the meeting room")
	skipping = true
	await _pour("nelson")
	await _until(_is_stage.bind("room_photos"), 40.0, true)
	print("AUTOTEST room photos armed, film ", film)
	for k in ROOM_PHOTOS:
		_record_photo(String(k), _blank_print())
	print("AUTOTEST stage ", stage)
	skipping = true
	await _arthur_to_window()
	_take_copy()
	print("AUTOTEST took the copy: ", have_copy)
	_slip_out()
	await get_tree().create_timer(3.0).timeout
	print("AUTOTEST evidence panel open: ", main.ui_open)
	on_link("present")
	await get_tree().create_timer(3.0).timeout
	print("AUTOTEST done, progress: ", main.progress.get("ch1910", false), ", photos ", photos.size(), ", camera put away: ", not player.has_camera)
	get_tree().quit()


func _man_visible(key: String) -> bool:
	return (actors[key] as Node3D).visible


func _nav_ok() -> bool:
	if spots.size() < 2:
		return false
	var map := level.get_world_3d().navigation_map
	var pts := NavigationServer3D.map_get_path(map, spots[0], spots[spots.size() - 2], true)
	return pts.size() >= 2


func _is_stage(s: String) -> bool:
	return stage == s


func _not_caught() -> bool:
	return not _caught_busy


func _not_in_scene() -> bool:
	return not in_scene


func _settle(level_name: String) -> void:
	await _until(_level_ready.bind(level_name), 40.0, true)
	await get_tree().create_timer(1.0).timeout


func _level_ready(level_name: String) -> bool:
	return main.level != null and String(main.level.name) == level_name and not main.busy


func _until(cond: Callable, timeout: float, skip := false) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		if skip:
			skipping = true
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= timeout:
		print("AUTOTEST timed out waiting")


## godot --headless --path godot -- --stealthtest
## Watches the yard's watchmen for a minute from under the tarp: how far they roam, how well they
## spread out, whether a hidden player stays hidden. Then stands up in a lantern beam to be sure
## that gets you caught.
func stealthtest() -> void:
	start()
	await _settle("hoboken")
	await _until(_is_stage.bind("street"), 20.0, true)
	await get_tree().create_timer(0.5).timeout
	main.hud.close_panel()
	skipping = true
	await _talk_jekyll()
	await _until(_not_in_scene, 20.0, true)
	skipping = false
	player.global_position = mk("gate_in")
	await _until(_is_stage.bind("yard"), 5.0)
	_next_cab = 99
	var caught_count := [0]
	for g in guards:
		g.caught.connect(_count_caught.bind(caught_count))
	_hide("tarp")
	var visited := {}
	var near_sum := 0.0
	var near_min := 1e9
	var samples := 0
	var t := 0.0
	var peak := 0.0
	while t < 60.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		for g in guards:
			peak = maxf(peak, g.detection)
			for i in spots.size():
				if (g as Node3D).global_position.distance_to(spots[i]) < 1.5:
					visited[i] = true
		if int(t * 4.0) != int((t - get_physics_process_delta_time()) * 4.0):
			for g in guards:
				var nd := 1e9
				for o in guards:
					if o != g:
						nd = minf(nd, (g as Node3D).global_position.distance_to((o as Node3D).global_position))
				near_sum += nd
				near_min = minf(near_min, nd)
				samples += 1
	print("STEALTH watchmen reached %d of %d places in a minute" % [visited.size(), spots.size()])
	print("STEALTH nearest other watchman: %.1f m on average, %.1f m at the closest" % [near_sum / maxf(samples, 1.0), near_min])
	print("STEALTH hidden under the tarp for a minute: peak notice %.2f, caught %d" % [peak, caught_count[0]])
	var tarp := mk("hide_tarp")
	var walk_near := NavigationServer3D.map_get_closest_point(level.get_world_3d().navigation_map, tarp)
	print("STEALTH nearest a watchman can walk to the tarp hide: %.1f m" % Vector2(walk_near.x - tarp.x, walk_near.z - tarp.z).length())
	_unhide("tarp")
	# careless: stand up in a watchman's lantern beam
	var g0 = guards[0]
	var y := g0.look_yaw() as float
	player.sneaking = false
	player.global_position = (g0 as Node3D).global_position + Vector3(sin(y), 0.0, cos(y)) * 7.0
	var before: int = caught_count[0]
	var w := 0.0
	while w < 8.0 and caught_count[0] == before:
		await get_tree().physics_frame
		w += get_physics_process_delta_time()
		player.global_position = (g0 as Node3D).global_position + Vector3(sin(g0.look_yaw()), 0.0, cos(g0.look_yaw())) * 7.0
	print("STEALTH standing in the lantern beam, caught: ", caught_count[0] > before, " after %.1fs" % w)
	get_tree().quit()


func _count_caught(box: Array) -> void:
	box[0] += 1
	var who := ""
	for g in guards:
		if g.detection >= 1.0:
			who = g.display_name
	print("  CAUGHT by ", who, " at ", player.global_position)


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (ap - ab * t).length()
