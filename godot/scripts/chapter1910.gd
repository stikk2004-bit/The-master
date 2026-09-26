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
## The player's part: slip past the yard's four watchmen and board at the car's dark front
## steps before the train leaves; serve the coffee in a borrowed steward's jacket; take
## pictures of Arthur's papers with a pocket Kodak while the real steward makes his rounds;
## and on the island, once the men go out "duck hunting", photograph the chalkboard and the
## notes and walk off with the clean copy. Get caught and that part starts over.

const ActorScript := preload("res://scripts/actor.gd")
const GuardScript := preload("res://scripts/guard.gd")
const Sound := preload("res://scripts/sound.gd")
const Look := preload("res://scripts/look.gd")
const Foliage := preload("res://scripts/foliage.gd")
const Markers := preload("res://scripts/markers.gd")

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
const DEPART_SECONDS := 210.0      # three and a half minutes to get aboard
const ROUNDS_SECONDS := 180.0      # the steward's rounds before he turns the lamps down
const EXPOSURE := 2.2              # seconds to hold still for a picture by lamplight

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
var _caught_busy := false
var _stealth_on := false
var _clock := 0.0
var _clock_on := false
var _clock_text := ""
var _clock_out: Callable = Callable()
var _expose_key := ""
var _expose_t := 0.0
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
	while a.is_walking() and not skipping:
		await get_tree().process_frame
	if skipping:
		a.skip()


func begin_scene() -> void:
	in_scene = true
	skipping = false
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


func _move_player(points: Array, spd: float) -> void:
	## walk the player along a path by script (up steps, through a door); physics is off meanwhile
	player.set_physics_process(false)
	player._play("Walk")
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
			if flat.length() > 0.05:
				player.model.rotation.y = lerp_angle(player.model.rotation.y, atan2(to.x, to.z), 0.25)
			if player.anim:
				player.anim.speed_scale = clampf(spd / 1.7, 0.6, 1.4)
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
	stage = "hoboken"
	main.go_to("hoboken", Vector3.ZERO, 0.0)


func build(level_name: String, lvl: Node3D) -> void:
	level = lvl
	marks.clear()
	actors.clear()
	guards.clear()
	lamp_list.clear()
	window_scroll.clear()
	beacons.clear()
	_stealth_on = false
	_clock_on = false
	_expose_key = ""
	_arthur_state = ""
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
	player.set_kodak(false)
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
func _build_hoboken() -> void:
	main._air("night1910")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	_load("res://models/hoboken_yard.glb")
	train_node = _load("res://models/hoboken_train.glb", _moving_train_mats())
	_load("res://models/hoboken_boxcars.glb")
	rear_door = train_node.find_child("RearDoor", true, false) as Node3D
	front_door = train_node.find_child("FrontDoor", true, false) as Node3D
	main._safety_floor()
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
	# four watchmen: the yard detective between the tracks, the brakeman along the train,
	# the night watchman at the edge of the crate lane, the conductor south of the car
	var det := _guard("res://models/npc_yardman.glb", "The yard detective", _route("detective", [0, 1, 2, 3, 4, 5]))
	det.lines_suspicious = ["Who's there?", "Somebody by those crates?", "Come on out where I can see you."]
	det.lines_clear = ["Rats in the freight again.", "Nobody. Just this fog."]
	var brk := _guard("res://models/npc_brakeman.glb", "The brakeman", _route("brakeman", [0, 1, 2, 3, 4, 5, 6]))
	brk.lines_suspicious = ["Hey. Somebody down there?", "Hello?"]
	brk.lines_clear = ["Hm. Nothing.", "Getting jumpy in my old age."]
	var wat := _guard("res://models/npc_watchman.glb", "The night watchman", _route("watchman", [0, 1, 2, 3, 2, 1]))
	wat.lines_suspicious = ["Who's that in the freight?", "I hear you. Come on out."]
	wat.lines_clear = ["Cats. It's always cats.", "Nobody. Nobody ever is."]
	wat.pauses = {0: 5.0, 3: 6.0}
	wat.patrol_speed = 0.95
	var con := _guard("res://models/npc_conductor.glb", "The conductor", _route("conductor", [0, 1, 2, 3]))
	con.lines_suspicious = ["Is somebody back there by the Senator's car?", "Who goes there?"]
	con.lines_clear = ["Nobody. Good.", "Just the steam."]
	con.pauses = {0: 6.0, 2: 5.0}
	con.patrol_speed = 0.9
	# the motor cab
	cab = main._instance("res://models/motorcar.glb")
	cab.visible = false
	for side in [-0.55, 0.55]:
		var hl := SpotLight3D.new()
		hl.light_color = Color("ffe0a8")
		hl.light_energy = 3.0
		hl.spot_range = 16.0
		hl.spot_angle = 28.0
		hl.position = Vector3(side, 1.12, -2.4)
		hl.light_volumetric_fog_energy = 2.5
		cab.add_child(hl)
	player.place(mk("player_start"), _yaw_to(mk("player_start"), mk("rear_door")))
	player.sneaking = true
	player.can_sneak = true
	_play_ambience("yard")


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
	begin_scene()
	shot(mk("cam_wide"), mk("cam_wide_look"), 55.0)
	await wait(hud.show_card("Hoboken, New Jersey", "The night of November 22, 1910", 3.5) - 1.0)
	await line("", "They were told to come one at a time, as quietly as they could, and to leave their last names at home.")
	await glide(mk("cam_watch"), mk("cam_watch_look"), 5.0)
	hud.set_objective("Watch the Senator's car.")
	var i := 0
	for entry in ARRIVALS:
		await _arrival(String(entry[0]), entry[1], i)
		i += 1
	# the porter goes up the train to find the conductor, leaving the rear platform
	var porter = actors["porter"]
	porter.walk([mk("rear_approach") + Vector3(0.6, 0, 6.0), mk("porter") + Vector3(0.8, 0, -40.0)], 1.4)
	await line("", "The blinds were down. Only thin threads of amber light showed where the windows were.")
	cab.visible = false
	end_scene()
	stage = "stealth"
	_arm_stealth()


func _boarding_path() -> Array:
	## down the platform, up the steps of the observation platform, to the rear door
	var p := [mk("step_bottom"), mk("step_top"), mk("rear_approach")]
	for k in 5:
		p.append(mk("rear_step_%d" % k))
	p.append(mk("rear_door"))
	return p


func _arrival(key: String, talk: Array, i: int) -> void:
	var a = actors[key]
	var porter = actors["porter"]
	var spd := _speed(key)
	# the cab rolls in from the east and stops at the foot of the platform steps
	cab.visible = true
	var cin := mk("cab_in")
	var cstop := mk("cab_stop")
	cab.global_position = cin
	cab.rotation.y = PI / 2.0
	await _drive(cab, cin, cstop, 3.2)
	a.visible = true
	a.place(cstop + Vector3(0.4, 0.0, -0.9), 0.0)
	a.walk(_boarding_path(), spd)
	_drive(cab, cstop, mk("cab_out"), 5.0)
	if i == 0:
		await glide(mk("cam_watch") + Vector3(1.5, 0.3, -2.5), mk("rear_approach") + Vector3(0, 1.2, 0), 3.0)
	while a.is_walking() and a.global_position.distance_to(mk("rear_approach")) > 1.2 and not skipping:
		await get_tree().process_frame
	porter.face_point(a.global_position)
	for t in talk:
		await line(String(t[0]), String(t[1]))
	# the first man up the steps, we watch from the platform
	if i == 0 and not skipping:
		shot(mk("cam_rear"), mk("cam_rear_look"), 48.0)
	await until_arrived(a)
	# the door opens, he steps in, it shuts behind him
	await _swing(rear_door, -1.35, 0.6)
	a.walk([mk("rear_inside")], spd * 0.8)
	await until_arrived(a)
	a.visible = false
	_swing(rear_door, 0.0, 0.8)
	porter.face_yaw(-PI / 2.0)
	if i == 0 and not skipping:
		shot(mk("cam_watch") + Vector3(1.5, 0.3, -2.5), mk("rear_approach") + Vector3(0, 1.2, 0), 50.0)
	if skipping:
		cab.global_position = mk("cab_out")


func _drive(node: Node3D, from: Vector3, to: Vector3, seconds: float) -> void:
	if skipping:
		node.global_position = to
		return
	var t := 0.0
	while t < 1.0 and not skipping:
		t = minf(1.0, t + get_process_delta_time() / seconds)
		var e := t * t * (3.0 - 2.0 * t)
		node.global_position = from.lerp(to, e)
		await get_tree().process_frame
	node.global_position = to


func _arm_stealth() -> void:
	_stealth_on = true
	for g in guards:
		g.active = true
	player.sneaking = true
	hud.set_objective("Cross the tracks to the front steps of the Senator's car. Stay out of the lamplight.  (C to sneak)")
	_set_clock(DEPART_SECONDS, "The train leaves in", _missed_train)
	_add(mk("vestibule") + Vector3(0, 0.5, 0), 1.3, "Climb aboard", _board, "board")
	if beacons.is_empty():
		_beacon(mk("steps_marker"), "board")
	await wait(1.0)
	await thought("The front steps of the Senator's car, where the lamps don't reach. Low and slow.")


func _on_guard_spoke(text: String, g) -> void:
	if _stealth_on or stage == "car_photos":
		hud.say(g.display_name, text, 2.4)


func _on_caught(g) -> void:
	if _caught_busy:
		return
	if stage == "car_photos":
		_car_caught(g.display_name)
		return
	if not _stealth_on:
		return
	_yard_reset(g.display_name, "Hey! You there! Stop right where you are!", "Caught", "Nobody was meant to see this car tonight. Try again.")


func _missed_train() -> void:
	if _caught_busy or not _stealth_on:
		return
	_yard_reset("The conductor", "Board!", "Too late", "The train pulled out without you. Try again, and don't dawdle.")


func _yard_reset(who: String, shout: String, title: String, sub: String) -> void:
	_caught_busy = true
	_stealth_on = false
	_clock_on = false
	for gg in guards:
		gg.active = false
	player.enabled = false
	hud.say(who, shout, 2.5)
	await get_tree().create_timer(1.8).timeout
	await hud.fade_to(1.0, 0.8).finished
	hud.show_card(title, sub, 1.6)
	await get_tree().create_timer(2.6).timeout
	player.place(mk("player_start"), _yaw_to(mk("player_start"), mk("rear_door")))
	player.sneaking = true
	for g in guards:
		g.reset_to(g.route[0], 0)
		g.active = true
	player.enabled = true
	_stealth_on = true
	_caught_busy = false
	_set_clock(DEPART_SECONDS, "The train leaves in", _missed_train)
	await hud.fade_to(0.0, 1.0).finished


func _board() -> void:
	if not _stealth_on:
		return
	_stealth_on = false
	_stop_clock()
	_clear_beacons()
	main.interactables.clear()
	for g in guards:
		g.active = false
	hud.set_sneak(false)
	hud.set_objective("")
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
	var worst := 0.0
	for g in guards:
		if g.active:
			worst = maxf(worst, g.detection)
	if _stealth_on and not _caught_busy:
		hud.set_sneak(player.sneaking or worst > 0.05, worst)
	elif stage == "car_photos" and not _caught_busy:
		hud.set_sneak(worst > 0.05, worst)
	if _clock_on and not _caught_busy and not in_scene:
		_clock -= delta
		var s := int(ceil(maxf(_clock, 0.0)))
		var extra := ""
		if stage == "car_photos":
			extra = "   ·   " + _tally(CAR_PHOTOS)
		hud.set_timer("%s %d:%02d%s" % [_clock_text, int(s / 60.0), s % 60, extra], _clock < 30.0)
		if _clock <= 0.0:
			_clock_on = false
			if _clock_out.is_valid():
				_clock_out.call()
	if stage == "car_photos":
		_car_watch()
	if _expose_key != "":
		_expose_tick(delta)
	if stage == "room_photos" or stage == "room_copy":
		_arthur_tick(delta)
	var pulse := 0.22 + 0.12 * sin(Time.get_ticks_msec() * 0.003)
	for b in beacons:
		if is_instance_valid(b[0]):
			(b[0] as Sprite3D).modulate.a = pulse
	for w in window_scroll:
		var m: ShaderMaterial = w
		m.set_shader_parameter("offset", fmod(float(m.get_shader_parameter("offset")) + delta * 0.09, 1.0))


# ================================================================== THE POCKET KODAK
## Press E at something worth a picture and keep holding it: a time exposure by lamplight.
## Let go too soon and the picture's spoiled. Whoever is watching gets a good look meanwhile.
func _start_exposure(key: String) -> void:
	if _expose_key != "" or in_scene or _caught_busy or photos.has(key):
		return
	_expose_key = key
	_expose_t = 0.0
	main.busy = true
	player.enabled = false
	player.set_carrying(false)
	player.set_kodak(true)
	var target := _photo_pos(key)
	_face_player_to(target)
	hud.set_prompt("Hold E and keep still...")


func _photo_pos(key: String) -> Vector3:
	match key:
		"chalkboard":
			return mk("chalk_spot") + Vector3(-1.0, 1.5, 0.0)
		"notes_paul":
			return mk("notes_paul")
		"notes_abe":
			return mk("notes_abe")
	return mk("valise") + Vector3(0.3, 0.8, 0.0)


func _expose_tick(delta: float) -> void:
	if not Input.is_action_pressed("interact"):
		_end_exposure(false)
		return
	_expose_t += delta
	hud.set_prompt("Hold still...  " + "|".repeat(int(_expose_t / EXPOSURE * 12.0)))
	if _expose_t >= EXPOSURE:
		_end_exposure(true)


func _end_exposure(done: bool) -> void:
	var key := _expose_key
	_expose_key = ""
	player.set_kodak(false)
	main.busy = false
	player.enabled = true
	hud.set_prompt("")
	if not done:
		hud.toast("You moved. That one's spoiled.", 2.0)
		return
	Sound.one_shot(self, "shutter", -6.0)
	photos.append(key)
	var info: Array = PHOTOS[key]
	hud.toast("Photograph: " + String(info[0]), 2.5)
	_after_photo(key)


func _after_photo(key: String) -> void:
	if stage == "car_photos":
		_drop_interactable("valise")
		var left := []
		for k in CAR_PHOTOS:
			if not photos.has(k):
				left.append(k)
		if left.is_empty():
			_drop_beacon("valise")
			_car_done()
		else:
			var nxt := String(left[0])
			var info: Array = PHOTOS[nxt]
			_add(mk("valise") + Vector3(0, 0.8, 0), 1.1, "Photograph " + String(info[0]).to_lower() + "  (hold E)", _start_exposure.bind(nxt), "valise")
	elif stage == "room_photos":
		_drop_interactable(key)
		_drop_beacon(key)
		hud.set_timer(_tally(ROOM_PHOTOS))
		var all_done := true
		for k in ROOM_PHOTOS:
			if not photos.has(k):
				all_done = false
		if all_done:
			_room_copy()


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
	await thought("A little big in the shoulders. And a folding pocket Kodak in the pocket. Somebody's going to want proof of this.")


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
	hud.set_objective("Photograph what's in Arthur's valise. The steward mustn't catch you back in the lounge.")
	_set_clock(ROUNDS_SECONDS, "Lamps down in", _lamps_down)
	_drop_interactable("valise")
	_clear_beacons()
	var info: Array = PHOTOS[String(CAR_PHOTOS[0])]
	_add(mk("valise") + Vector3(0, 0.8, 0), 1.1, "Photograph " + String(info[0]).to_lower() + "  (hold E)", _start_exposure.bind(String(CAR_PHOTOS[0])), "valise")
	_beacon(mk("valise") + Vector3(0, 1.6, 0), "valise")
	for k in CAR_PHOTOS:
		if photos.has(k):
			_after_photo(String(k))


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
	if _expose_key != "":
		_expose_key = ""
		player.set_kodak(false)
	var st = guards[0]
	st.active = false
	player.enabled = false
	main.busy = true
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
	await thought("Four exposures. Close the valise, just the way it was.")
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
	for a in actors.values():
		await until_arrived(a)
		a.visible = false


func _door_when_near() -> void:
	## the front door swings open as the first of them reaches the porch
	var opened := false
	while not opened and stage == "jekyll" and is_instance_valid(level):
		for a in actors.values():
			if (a as Node3D).global_position.z < 3.0 and (a as Node3D).visible:
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
	_arthur_sit()
	_clear_beacons()
	hud.set_objective("Photograph the chalkboard and both sets of notes. Only while Arthur's head is down.")
	hud.set_timer(_tally(ROOM_PHOTOS))
	_add(mk("chalk_spot") + Vector3(0, 1.0, 0), 1.4, "Photograph the chalkboard  (hold E)", _start_exposure.bind("chalkboard"), "chalkboard")
	_add(mk("notes_paul"), 1.3, "Photograph Paul's notes  (hold E)", _start_exposure.bind("notes_paul"), "notes_paul")
	_add(mk("notes_abe"), 1.3, "Photograph Abe's notes  (hold E)", _start_exposure.bind("notes_abe"), "notes_abe")
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
	var risky := _expose_key != ""
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
	if _expose_key != "":
		_expose_key = ""
		player.set_kodak(false)
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
	body += "[b]From Arthur's valise, on the train[/b]\n"
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
	body += "[i]Accounts differ on some details, including exactly who else was there. The scenes you just played are a dramatization: the lines, the photographs and the stolen copy are imagined. The meeting, the men, the cover story and the plan are not.[/i]\n\n"
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
		"valise":
			player.place(mk("desk_stand"), 0.0)
			player.set_outfit("waiter")
			player.set_kodak(true)
			_face_player_to(_photo_pos("outline"))
		"room":
			player.place(mk("notes_paul") + Vector3(0.6, -0.8, -0.7), 0.0)
			player.set_carrying(false)
			player.set_kodak(true)
			_face_player_to(mk("notes_paul"))


# ------------------------------------------------------------------ a run-through for testing
## godot --headless --path godot -- --autotest
## Plays the whole chapter with every scene skipped, to catch script errors.
func autotest() -> void:
	print("AUTOTEST start")
	start()
	await _settle("hoboken")
	skipping = true
	await _until(_is_stage.bind("stealth"), 60.0)
	print("AUTOTEST arrivals done, stealth armed: ", _stealth_on, ", clock ", _clock)
	for g in guards:
		print("  guard ", g.display_name, " at ", g.global_position)
	print("  rear door ", rear_door != null, ", front door ", front_door != null, ", beacons ", beacons.size())
	# a caught and a missed train, to exercise the resets
	_on_caught(guards[0])
	await _until(_not_caught, 15.0)
	print("AUTOTEST caught reset, clock back to ", int(_clock))
	_missed_train()
	await _until(_not_caught, 15.0)
	player.global_position = mk("vestibule")
	await get_tree().create_timer(0.5).timeout
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
	print("AUTOTEST car photos armed, steward active: ", guards[0].active)
	player.global_position = mk("desk_stand")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_car_watch()
	print("  steward minds the lounge: ", guards[0].watching)
	_car_caught("The steward")
	await _until(_not_caught, 15.0)
	for k in CAR_PHOTOS:
		_expose_key = String(k)
		_end_exposure(true)
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
	print("AUTOTEST room photos armed")
	for k in ROOM_PHOTOS:
		_expose_key = String(k)
		_end_exposure(true)
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
	print("AUTOTEST done, progress: ", main.progress.get("ch1910", false), ", photos ", photos.size())
	get_tree().quit()


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
## A careful simulated player: waits in the shadows at the start of each stretch until no
## watchman is near it or looking its way, then sneaks the whole stretch. Reports detection
## along the way. Then a careless run in the open.
func stealthtest() -> void:
	start()
	await _settle("hoboken")
	skipping = true
	await _until(_is_stage.bind("stealth"), 120.0)
	await get_tree().create_timer(0.5).timeout
	# Blender (x, y) points, converted to Godot (x, 0, -y); each stretch starts somewhere dark
	var legs := [
		[Vector2(-14.2, -21.0), Vector2(-13.8, -12.0)],
		[Vector2(-13.8, -12.0), Vector2(-13.6, -3.0), Vector2(-13.4, 2.0)],
		[Vector2(-13.4, 2.0), Vector2(-12.4, 9.5), Vector2(-9.0, 13.2), Vector2(-7.0, 15.4), Vector2(-6.2, 16.6)],
		[Vector2(-6.2, 16.6), Vector2(-5.2, 13.4), Vector2(-2.0, 12.0), Vector2(0.4, 10.2), Vector2(1.0, 8.6)],
	]
	var caught_count := [0]
	for g in guards:
		g.caught.connect(_count_caught.bind(caught_count))
	player.sneaking = true
	player.enabled = false
	var t0 := Time.get_ticks_msec()
	var peak := 0.0
	var y: float = player.global_position.y
	for li in legs.size():
		var pts := []
		for v in legs[li]:
			pts.append(Vector3(v.x, y, -v.y))
		var start_at: Vector3 = pts[0]
		var waited := 0.0
		while waited < 60.0:
			var clear := true
			for g in guards:
				if not _leg_clear(g, pts):
					clear = false
			if clear:
				break
			player.global_position = start_at
			player.noise = 0.0
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
			for g in guards:
				peak = maxf(peak, g.detection)
		for k in range(1, pts.size()):
			var a3: Vector3 = pts[k - 1]
			var b3: Vector3 = pts[k]
			var dist := a3.distance_to(b3)
			var tt := 0.0
			while tt < dist / 1.35:
				tt += get_physics_process_delta_time()
				var p := a3.lerp(b3, clampf(tt * 1.35 / dist, 0.0, 1.0))
				player.global_position = Vector3(p.x, y, p.z)
				player.noise = 0.08
				for g in guards:
					peak = maxf(peak, g.detection)
				await get_tree().physics_frame
		print("STEALTH stretch ", li + 1, " done after waiting %.1fs, peak detection %.2f, caught %d, clock %d" % [waited, peak, caught_count[0], int(_clock)])
	var closest := 1e9
	for g in guards:
		if g.display_name == "The night watchman":
			for pt in g.route:
				for li in 3:
					for k in range(1, (legs[li] as Array).size()):
						var a2: Vector2 = legs[li][k - 1]
						var b2: Vector2 = legs[li][k]
						closest = minf(closest, _seg_dist(pt, Vector3(a2.x, 0, -a2.y), Vector3(b2.x, 0, -b2.y)))
	print("STEALTH careful run: %.0fs, peak %.2f, caught %d" % [(Time.get_ticks_msec() - t0) / 1000.0, peak, caught_count[0]])
	print("STEALTH night watchman's round keeps %.1f m off the way through the crates" % closest)
	print("STEALTH reached vestibule: ", player.global_position.distance_to(mk("vestibule")) < 1.4)
	# careless: stand up and walk down the middle of track A under the detective's nose
	_caught_busy = false
	_stealth_on = true
	for g in guards:
		g.reset_to(g.global_position)
		g.active = true
	player.sneaking = false
	var det = guards[0]
	player.global_position = det.global_position + Vector3(sin(det.model.rotation.y), 0, cos(det.model.rotation.y)) * 6.0
	var before: int = caught_count[0]
	var w := 0.0
	while w < 8.0 and caught_count[0] == before:
		player.noise = 0.35
		await get_tree().physics_frame
		w += get_physics_process_delta_time()
	print("STEALTH careless run caught: ", caught_count[0] > before, " after %.1fs" % w)
	get_tree().quit()


func _leg_clear(g, pts: Array) -> bool:
	## a watchman is no threat to a stretch if he's well away from it, or not looking its way
	var gp: Vector3 = g.global_position
	var near := 1e9
	for k in range(1, pts.size()):
		near = minf(near, _seg_dist(gp, pts[k - 1], pts[k]))
	if near < 7.0:
		return false
	if near > 15.0:
		return true
	var fwd := Vector3(sin(g.model.rotation.y), 0.0, cos(g.model.rotation.y))
	for p in pts:
		var to: Vector3 = (p as Vector3) - gp
		to.y = 0.0
		if acos(clampf(fwd.dot(to.normalized()), -1.0, 1.0)) < deg_to_rad(80.0):
			return false
	return true


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
