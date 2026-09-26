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

const ActorScript := preload("res://scripts/actor.gd")
const GuardScript := preload("res://scripts/guard.gd")
const Sound := preload("res://scripts/sound.gd")
const Look := preload("res://scripts/look.gd")
const Foliage := preload("res://scripts/foliage.gd")

const MEN := {
	"nelson": {"model": "res://models/npc_aldrich.glb", "name": "Nelson"},
	"arthur": {"model": "res://models/npc_shelton.glb", "name": "Arthur"},
	"abe": {"model": "res://models/npc_andrew.glb", "name": "Abe"},
	"paul": {"model": "res://models/npc_warburg.glb", "name": "Paul"},
	"frank": {"model": "res://models/npc_vanderlip.glb", "name": "Frank"},
	"harry": {"model": "res://models/npc_davison.glb", "name": "Harry"},
	"ben": {"model": "res://models/npc_strong.glb", "name": "Ben"},
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
const LAMP_REACH := {"gas": 7.5, "yard": 9.0, "street": 9.0, "window": 6.0, "lantern": 4.0, "clock": 0.0, "red": 2.5, "blinds": 0.0, "coach": 0.0, "headlamp": 12.0, "firebox": 3.0}

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
var stage := ""
var served := {}
var guards: Array = []
var cab: Node3D
var train_node: Node3D
var lamp_list: Array = []
var ambience: AudioStreamPlayer
var window_scroll: Array = []
var _caught_busy := false
var _depart_timer := 0.0
var _stealth_on := false


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
	await wait(hud.say(who, text))


func thought(text: String) -> void:
	if skipping:
		return
	await wait(hud.say("", "[ " + text + " ]"))


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


func mk(name: String) -> Vector3:
	var t: Transform3D = marks.get(name, Transform3D.IDENTITY)
	return t.origin


func mk_yaw(name: String) -> float:
	var t: Transform3D = marks.get(name, Transform3D.IDENTITY)
	# Blender empties face their local +Y; in Godot that is -Z after the axis swap
	var f := -t.basis.z
	return atan2(f.x, f.z)


func _dress(root: Node) -> void:
	## Turn Blender's LIGHT_ and MARK_ empties into lights and named positions.
	for n in root.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("MARK_"):
			# Blender numbers repeated names (seat_frank.001); the game wants the plain name
			var key := nm.substr(5).split(".")[0]
			if key.length() > 4 and key[key.length() - 4] == "_" and key.right(3).is_valid_int():
				key = key.left(key.length() - 4)
			marks[key] = (n as Node3D).global_transform
		elif nm.begins_with("LIGHT_"):
			var parts := nm.split("_")
			var kind := parts[1] if parts.size() > 1 else "gas"
			var p := (n as Node3D).global_position
			_light(kind, p, int(parts[2]) if parts.size() > 2 and parts[2].is_valid_int() else 0)


func _light(kind: String, p: Vector3, idx: int) -> void:
	var spec: Array = {
		"gas": ["ffb060", 1.5, 8.0, idx % 3 == 0],
		"yard": ["ffae58", 1.8, 10.0, true],
		"street": ["ffb060", 1.7, 10.0, true],
		"window": ["ffa850", 0.9, 7.0, false],
		"clock": ["fff0d0", 0.6, 9.0, false],
		"lantern": ["ffb060", 0.9, 5.0, false],
		"red": ["ff2010", 0.7, 3.0, false],
		"headlamp": ["ffe8b8", 3.0, 16.0, false],
		"firebox": ["ff7020", 1.6, 5.0, false],
		"blinds": ["ffa850", 1.0, 5.0, false],
		"coach": ["ffae60", 0.4, 7.0, false],
		"sconce": ["ffc070", 0.9, 4.5, false],
		"ceiling": ["ffd090", 1.1, 6.0, true],
		"chandelier": ["ffd090", 1.5, 9.0, true],
		"fire": ["ff8a30", 2.4, 8.0, true],
		"daylight": ["c8d4dc", 1.2, 7.0, false],
		"stove": ["ff7a30", 0.9, 3.5, false],
	}.get(kind, ["ffb060", 1.0, 6.0, false])
	var l: OmniLight3D = main._omni(p, Color(String(spec[0])), float(spec[1]), float(spec[2]), kind in ["gas", "yard", "street", "fire", "lantern", "stove", "sconce"], bool(spec[3]))
	if LAMP_REACH.has(kind) and LAMP_REACH[kind] > 0.0:
		lamp_list.append([p, float(LAMP_REACH[kind])])
	if kind == "fire":
		l.light_volumetric_fog_energy = 2.5


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


func _play_ambience(kind: String) -> void:
	ambience.stream = Sound.loop(kind)
	ambience.play()


# ------------------------------------------------------------------ entry and exit
func start() -> void:
	served.clear()
	stage = "hoboken"
	main.go_to("hoboken", Vector3.ZERO, 0.0)


func build(level_name: String, lvl: Node3D) -> void:
	level = lvl
	marks.clear()
	actors.clear()
	guards.clear()
	lamp_list.clear()
	window_scroll.clear()
	_stealth_on = false
	player.set_carrying(false)
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
	player.set_outfit("club")
	player.can_sneak = true
	hud.set_objective("")
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
		var a := _actor(key)
		a.visible = false
		a.place(mk("cab_out") + Vector3(0, -30, 0), 0.0)
	# the watchmen
	var det := Node3D.new()
	det.set_script(GuardScript)
	level.add_child(det)
	det.setup("res://models/npc_yardman.glb", "The yard detective", true)
	det.lines_suspicious = ["Who's there?", "Somebody by those crates?", "Come on out where I can see you."]
	det.lines_clear = ["Rats in the freight again.", "Nobody. Just this fog."]
	var brk := Node3D.new()
	brk.set_script(GuardScript)
	level.add_child(brk)
	brk.setup("res://models/npc_brakeman.glb", "The brakeman", true)
	brk.lines_suspicious = ["Hey. Somebody down there?", "Hello?"]
	brk.lines_clear = ["Hm. Nothing.", "Getting jumpy in my old age."]
	var droute := []
	for i in 6:
		droute.append(mk("detective_%d" % i))
	var broute := []
	for i in 7:
		broute.append(mk("brakeman_%d" % i))
	det.arm(droute, player, lamp_list)
	brk.arm(broute, player, lamp_list)
	for g in [det, brk]:
		g.active = false
		g.caught.connect(_on_caught.bind(g))
		g.spoke.connect(_on_guard_spoke.bind(g))
		guards.append(g)
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


func _arrival(key: String, talk: Array, i: int) -> void:
	var a = actors[key]
	var porter = actors["porter"]
	# the cab rolls in from the east and stops at the foot of the platform steps
	cab.visible = true
	var cin := mk("cab_in")
	var cstop := mk("cab_stop")
	cab.global_position = cin
	cab.rotation.y = PI / 2.0
	await _drive(cab, cin, cstop, 3.2)
	a.visible = true
	a.place(cstop + Vector3(0.4, 0.0, -0.9), 0.0)
	a.walk([mk("step_bottom"), mk("step_top"), mk("rear_approach"), mk("rear_board"), mk("rear_door")], 1.35)
	_drive(cab, cstop, mk("cab_out"), 5.0)
	if i == 0:
		await glide(mk("cam_watch") + Vector3(1.5, 0.3, -2.5), mk("rear_approach") + Vector3(0, 1.2, 0), 3.0)
	while a.is_walking() and a.global_position.distance_to(mk("rear_approach")) > 1.2 and not skipping:
		await get_tree().process_frame
	porter.face_point(a.global_position)
	for t in talk:
		await line(String(t[0]), String(t[1]))
	await until_arrived(a)
	a.visible = false
	porter.face_yaw(-PI / 2.0)
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
	_depart_timer = 300.0
	for g in guards:
		g.active = true
	player.sneaking = true
	hud.set_objective("Slip aboard at the car's dark front end. Stay out of the lamplight.  (C to sneak)")
	main.add_interactable(mk("vestibule") + Vector3(0, 0.5, 0), 1.4, "Climb aboard", _board)
	await wait(1.0)
	await thought("The front of the Senator's car, where the lamps don't reach. Low and slow.")


func _on_guard_spoke(text: String, g) -> void:
	if _stealth_on:
		hud.say(g.display_name, text, 2.4)


func _on_caught(g) -> void:
	if _caught_busy or not _stealth_on:
		return
	_caught_busy = true
	_stealth_on = false
	for gg in guards:
		gg.active = false
	player.enabled = false
	hud.say(g.display_name, "Hey! You there! Stop right where you are!", 2.5)
	await get_tree().create_timer(1.8).timeout
	await hud.fade_to(1.0, 0.8).finished
	hud.show_card("Caught", "Nobody was meant to see this car tonight. Try again.", 1.6)
	await get_tree().create_timer(2.6).timeout
	player.place(mk("player_start"), _yaw_to(mk("player_start"), mk("rear_door")))
	player.sneaking = true
	var r := [mk("detective_0"), mk("brakeman_0")]
	for k in guards.size():
		guards[k].reset_to(r[k])
		guards[k].active = true
	player.enabled = true
	_stealth_on = true
	_caught_busy = false
	await hud.fade_to(0.0, 1.0).finished


func _board() -> void:
	if not _stealth_on:
		return
	_stealth_on = false
	main.interactables.clear()
	for g in guards:
		g.active = false
	hud.set_sneak(false)
	hud.set_objective("")
	begin_scene()
	shot(mk("cam_wide") + Vector3(-6, 3, 0), train_node.global_position + Vector3(4, 2, -20), 50.0)
	player.visible = false
	await thought("Up the steps and into the dark between the cars. Nobody turned around.")
	Sound.one_shot(self, "whistle")
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
	if _stealth_on and not _caught_busy:
		var worst := 0.0
		for g in guards:
			worst = maxf(worst, g.detection)
		hud.set_sneak(player.sneaking or worst > 0.05, worst)
		_depart_timer -= delta
		if _depart_timer <= 0.0:
			_depart_timer = 300.0
			_on_caught(guards[0])
	for w in window_scroll:
		var m: ShaderMaterial = w
		m.set_shader_parameter("offset", fmod(float(m.get_shader_parameter("offset")) + delta * 0.09, 1.0))


# ================================================================== THE PRIVATE CAR
func _build_privatecar() -> void:
	main._air("train")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	_load("res://models/private_car.glb")
	main._safety_floor()
	_window_view()
	var seats := {"frank": "seat_frank", "harry": "seat_harry", "paul": "seat_paul", "ben": "seat_ben",
		"nelson": "seat_nelson", "abe": "seat_abe", "arthur": "seat_arthur"}
	for key in seats.keys():
		var a := _actor(key)
		a.idle_anim = "SitTalk" if key in ["frank", "harry", "nelson"] else ("SitDrink" if key in ["ben", "abe"] else "Sit")
		a.indoors()
		a.place(mk(seats[key]), mk_yaw(seats[key]))
		a.play(a.idle_anim, 0.0, randf_range(0.85, 1.1))
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
	await thought("A little big in the shoulders. Nobody looks twice at a steward.")


func _tray() -> void:
	main.interactables.clear()
	player.set_carrying(true)
	hud.set_objective("Serve the gentlemen. Keep your head down and your ears open.")
	served.clear()
	for key in ["frank", "harry", "paul", "ben", "nelson", "abe", "arthur"]:
		var a = actors[key]
		main.add_interactable(a.global_position + Vector3(0, 0.6, 0), 1.35, "Serve the gentleman", _serve.bind(key))


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
	player.face(atan2(a.global_position.x - player.global_position.x, a.global_position.z - player.global_position.z))
	player.play_once("Serve")
	await get_tree().create_timer(0.9).timeout
	match key:
		"frank":
			await line("Frank", "Thank you. Wilbur, pass the sugar.")
			await line("Harry", "Here you are, Orville.")
			await thought("Orville and Wilbur. The Wright brothers.")
			await line("Frank", "On the theory that we are always right.")
		"harry":
			await line("Harry", "Just set it there, thank you.")
			await line("Harry", "If anybody asks, Paul, we are going duck hunting.")
			await line("Paul", "I have never shot a duck in my life.")
			await line("Harry", "Neither has Frank. Don't tell anybody.")
		"paul":
			await line("Paul", "Danke. Thank you.")
			await line("Paul", "In Europe the reserves sit in one great pool, Ben, and the pool is lent wherever the panic is. Here every bank hoards its own.")
			await line("Ben", "So when trouble comes, every bank grabs for the same cash at once.")
		"ben":
			await line("Ben", "Thank you.")
			await line("Ben", "Nelson, how long do we have on the island?")
			await line("Nelson", "As long as it takes, Ben.")
		"nelson":
			await line("Nelson", "You're new.")
			await thought("Don't look up.")
			await line("Nelson", "Well. Leave the pot.")
			await line("Nelson", "Abe, when we get there we work until it's written. Nobody leaves the island before then.")
		"abe":
			await line("Abe", "Thank you. Arthur, did you bring the European figures?")
			await line("Arthur", "Every table the commission gathered, Abe. Two trunks of them.")
		"arthur":
			await line("Arthur", "Thank you. Senator, the drafts are in the valise when you... I mean, Nelson. Sorry.")
			await line("Nelson", "First names, Arthur. Even for me.")
	main.busy = false
	player.enabled = true
	if served.size() >= 7:
		_car_done()


func _car_done() -> void:
	player.set_carrying(false)
	begin_scene()
	shot(mk("cam_peek"), mk("cam_peek_look"), 48.0)
	await line("Nelson", "Gentlemen, get some sleep. We reach Brunswick tomorrow, and there may be newspapermen at the station.")
	await line("Harry", "Leave them to me.")
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
		a.walk([Vector3(off.x, 0.3, 6.0 + off.z * 0.5), Vector3(off.x * 0.5, 1.0, 2.4)], 1.1)
	player.place(start + Vector3(0.0, 0.0, 8.0), 0.0)
	player.can_sneak = false
	_play_ambience("marsh")


func _run_jekyll() -> void:
	hud.show_location("Jekyll Island, Georgia", "Late November, 1910")
	hud.set_objective("Follow them up to the clubhouse.")
	main.add_interactable(Vector3(0.0, 1.5, 1.0), 1.6, "Go inside after them", _enter_meeting)
	await wait(2.0)
	await thought("Live oaks and moss, and not another soul on the island.")
	for a in actors.values():
		await until_arrived(a)
		a.visible = false


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
	for key in MEN.keys():
		var a := _actor(key)
		var seat: String = "seat_" + String(key)
		a.idle_anim = "SitWrite" if key in ["arthur", "abe"] else ("SitTalk" if key in ["nelson", "paul", "frank"] else "Sit")
		a.indoors()
		a.place(mk(seat), mk_yaw(seat))
		a.play(a.idle_anim, 0.0, randf_range(0.85, 1.1))
	player.place(mk("mt_spawn"), mk_yaw("mt_spawn"))
	player.set_carrying(true)
	player.can_sneak = false
	_play_ambience("fire")


func _run_meeting() -> void:
	hud.show_location("The Clubhouse", "Jekyll Island, November 1910")
	hud.set_objective("Pour the coffee. Listen to the plan take shape.")
	served.clear()
	for key in ["paul", "abe", "frank", "nelson"]:
		var a = actors[key]
		main.add_interactable(a.global_position + Vector3(0, 0.6, 0), 1.4, "Pour the gentleman's coffee", _pour.bind(key))
	await wait(1.5)
	await thought("They've been at it since breakfast. The chalkboard is filling up.")


func _pour(key: String) -> void:
	if served.has(key) or in_scene:
		return
	served[key] = true
	var keep := []
	for it in main.interactables:
		if (it["cb"] as Callable).get_bound_arguments() != [key]:
			keep.append(it)
	main.interactables = keep
	main.busy = true
	player.enabled = false
	var a = actors[key]
	player.face(atan2(a.global_position.x - player.global_position.x, a.global_position.z - player.global_position.z))
	player.play_once("Serve")
	await get_tree().create_timer(0.9).timeout
	match key:
		"paul":
			await line("Paul", "One reserve, held in common, Nelson. A central bank, the way every country in Europe has one.")
			await line("Nelson", "Say 'central bank' on the floor of the Senate and the plan dies that afternoon. We'll call it an association. A National Reserve Association.")
		"abe":
			await line("Abe", "Then spread it out. Fifteen districts, a branch in each, so the farmer in Kansas and the banker in Boston both have a door to knock on.")
			await line("Ben", "And the branches rediscount good commercial paper. A sound bank can always turn its loans into cash.")
		"frank":
			await line("Frank", "The notes have to stretch. More currency at harvest, when the crops move, and back again after. The old system could not bend at all.")
			await line("Paul", "An elastic currency. That is the whole point.")
		"nelson":
			await line("Abe", "Who sits on the board?")
			await line("Harry", "The banks own it, so the banks elect most of the board.")
			await line("Abe", "Washington will want a say.")
			await line("Nelson", "Washington gets a few seats. That's as far as I can carry it.")
	main.busy = false
	player.enabled = true
	if served.size() >= 4:
		_meeting_done()


func _meeting_done() -> void:
	player.set_carrying(false)
	begin_scene()
	shot(mk("cam_table"), mk("cam_table_look"), 46.0)
	await line("Arthur", "A Suggested Plan for Monetary Legislation. That's what we'll call the report.")
	await line("Nelson", "Good. Burn the scraps, gentlemen. Not a word of this leaves the island.")
	hud.fade_to(1.0, 1.0)
	await wait(1.1)
	for key in MEN.keys():
		actors[key].visible = false
	skipping = false
	hud.fade_to(0.0, 1.0)
	end_scene()
	hud.set_objective("They left one clean copy on the table.")
	main.add_interactable(mk("draft"), 1.3, "Read the draft", _read_draft)


func _read_draft() -> void:
	main.open_panel("A Suggested Plan for Monetary Legislation",
		"[i]What the men drafted on Jekyll Island, and what became of it.[/i]\n\n"
		+ "In January 1911 Senator Nelson Aldrich put the plan before his National Monetary Commission. It called for a [b]National Reserve Association[/b]: one reserve owned by the banks, fifteen districts with a branch in each, notes that could grow and shrink with the needs of trade, and a board chosen mostly by the banks, with a few members named by the government.\n\n"
		+ "Congress never passed it. Aldrich left the Senate in 1911, and by 1913 the Democrats held the House, the Senate and the White House. They were not going to pass a bill with his name on it.\n\n"
		+ "But a good deal of it came back. The [b]Federal Reserve Act[/b], signed by President Woodrow Wilson on December 23, 1913, kept the regional idea, with twelve Reserve Banks instead of fifteen, and the elastic currency. It put a Federal Reserve Board appointed by the President over the whole thing. The Reserve Banks opened for business in November 1914.\n\n"
		+ "For years the men kept quiet about the trip. The journalist B. C. Forbes wrote about it in 1916, and Frank Vanderlip told the story himself in 1935.\n\n"
		+ "[i]Accounts differ on some details, including exactly who else was there. The scenes you just played are a dramatization: the lines are imagined, the facts are not.[/i]\n\n"
		+ main._link("present", "Walk back out into the present day"))
	main.panel_kind = "draft"


func on_link(meta: String) -> bool:
	if meta == "present":
		main.hud.close_panel()
		leave_to_present()
		return true
	return false


# ------------------------------------------------------------------ a run-through for testing
## godot --headless --path godot -- --autotest
## Plays the whole chapter with every scene skipped, to catch script errors.
func autotest() -> void:
	print("AUTOTEST start")
	start()
	await _settle("hoboken")
	skipping = true
	await _until(func() -> bool: return stage == "stealth", 60.0)
	print("AUTOTEST arrivals done, stealth armed: ", _stealth_on)
	for g in guards:
		print("  guard ", g.display_name, " at ", g.global_position)
	player.global_position = mk("vestibule")
	await get_tree().create_timer(0.5).timeout
	_board()
	skipping = true
	await _settle("privatecar")
	print("AUTOTEST in the private car, men: ", actors.size())
	_peek()
	skipping = true
	await _until(func() -> bool: return not in_scene, 20.0)
	await _jacket()
	print("AUTOTEST outfit: ", player.outfit)
	_tray()
	for key in ["frank", "harry", "paul", "ben", "nelson", "abe", "arthur"]:
		skipping = true
		await _serve(key)
	skipping = true
	await _settle("jekyll")
	print("AUTOTEST on Jekyll, men: ", actors.size())
	skipping = true
	for a in actors.values():
		a.skip()
	_enter_meeting()
	await _settle("meeting")
	print("AUTOTEST in the meeting room")
	for key in ["paul", "abe", "frank", "nelson"]:
		skipping = true
		await _pour(key)
	skipping = true
	await _until(func() -> bool: return not in_scene, 20.0)
	_read_draft()
	await get_tree().create_timer(0.5).timeout
	on_link("present")
	await get_tree().create_timer(3.0).timeout
	print("AUTOTEST done, progress: ", main.progress.get("ch1910", false))
	get_tree().quit()


func _settle(level_name: String) -> void:
	await _until(func() -> bool: return main.level != null and String(main.level.name) == level_name and not main.busy, 30.0)
	await get_tree().create_timer(1.0).timeout


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= timeout:
		print("AUTOTEST timed out waiting")


## godot --headless --path godot -- --stealthtest
## A careful simulated player: waits in cover until both watchmen are far from the next
## stretch, then sneaks it. Reports detection along the way. Then a careless run in the open.
func stealthtest() -> void:
	start()
	await _settle("hoboken")
	skipping = true
	await _until(func() -> bool: return stage == "stealth", 120.0)
	await get_tree().create_timer(0.5).timeout
	# Blender (x, y) route points, converted to Godot (x, 0, -y)
	var route := [Vector2(-14.2, -21.0), Vector2(-13.8, -12.0), Vector2(-12.0, -6.0), Vector2(-13.4, 2.0), Vector2(-12.4, 9.5),
		Vector2(-9.0, 13.2), Vector2(-6.2, 13.2), Vector2(-2.0, 12.8), Vector2(1.4, 9.8), Vector2(2.0, 8.8)]
	var caught_count := [0]
	for g in guards:
		g.caught.connect(func() -> void: caught_count[0] += 1)
	player.sneaking = true
	player.enabled = false
	var t0 := Time.get_ticks_msec()
	var peak := 0.0
	for i in range(1, route.size()):
		var a3 := Vector3(route[i - 1].x, player.global_position.y, -route[i - 1].y)
		var b3 := Vector3(route[i].x, player.global_position.y, -route[i].y)
		# wait for a gap
		var waited := 0.0
		while waited < 40.0:
			var clear := true
			for g in guards:
				var d := _seg_dist(g.global_position, a3, b3)
				if d < 11.0:
					clear = false
			if clear:
				break
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
		var dist := a3.distance_to(b3)
		var tt := 0.0
		while tt < dist / 1.35:
			tt += get_physics_process_delta_time()
			var p := a3.lerp(b3, clampf(tt * 1.35 / dist, 0.0, 1.0))
			player.global_position = Vector3(p.x, player.global_position.y, p.z)
			player.noise = 0.08
			for g in guards:
				peak = maxf(peak, g.detection)
			await get_tree().physics_frame
		print("STEALTH leg ", i, " done after waiting %.1fs, peak detection %.2f, caught %d" % [waited, peak, caught_count[0]])
	print("STEALTH careful run: %.0fs, peak %.2f, caught %d" % [(Time.get_ticks_msec() - t0) / 1000.0, peak, caught_count[0]])
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


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (ap - ab * t).length()
