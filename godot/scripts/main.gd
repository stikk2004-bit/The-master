extends Node3D
## The Jekyll Island Club: rooms, lighting, the player, and everything you can use.

const SPAWN_EXTERIOR := Vector3(0.0, 0.5, 32.0)
const SPAWN_PORCH := Vector3(0.0, 1.0, 3.2)
const SPAWN_LOBBY := Vector3(0.0, 0.1, -2.9)
const SPAWN_LIBRARY := Vector3(0.0, 0.1, -2.6)
const LOBBY_FROM_LIBRARY := Vector3(-7.6, 0.1, -4.0)
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")
const Lessons := preload("res://scripts/lessons.gd")
const MoneySimScript := preload("res://scripts/money_sim.gd")
const NpcScript := preload("res://scripts/npc.gd")
const Look := preload("res://scripts/look.gd")
const Foliage := preload("res://scripts/foliage.gd")
const ChapterScript := preload("res://scripts/chapter1910.gd")
const RoomsScript := preload("res://scripts/rooms.gd")
const Sound := preload("res://scripts/sound.gd")
const CHAPTER_LEVELS := ["hoboken", "privatecar", "jekyll", "meeting"]
const PostShader := preload("res://shaders/post.gdshader")
const SETTINGS_PATH := "user://settings.json"
const HOODED_ROUTE := [Vector3(-6, 0, 9), Vector3(-15, 0, 14), Vector3(-17, 0, 28), Vector3(-12, 0, 42), Vector3(-5, 0, 46), Vector3(5, 0, 44), Vector3(14, 0, 36), Vector3(16, 0, 24), Vector3(12, 0, 14), Vector3(5, 0, 8)]
const HOODED_LINES := ["\"Ask who made the money in your pocket. Then ask why.\"", "\"Every dollar in that bank was somebody's loan once.\"", "\"The men who met on that island in 1910 kept it quiet. You don't have to.\"", "\"Watch the flows, not the pile.\"", "He doesn't answer. He just nods toward the Library."]
const GUESTBOOK_PATH := "user://guestbook.json"
const PROGRESS_PATH := "user://progress.json"
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const ROMAN := ["I", "II", "III", "IV"]
const LETTERS := ["A", "B", "C", "D"]

var player
var hud
var env: Environment
var sun: DirectionalLight3D
var level: Node3D
var interactables: Array = []
var current: Dictionary = {}
var ui_open := false
var busy := false
var flicker_lights: Array = []
var guestbook: Array = []
var kids_mode := false
var ledger_loans: Array = []
var ledger_next := 0
var ledger_note := ""
var panel_kind := ""
var progress: Dictionary = {}
var quiz_pick: Dictionary = {}
var sim: Control = null
var npc = null
var npc_it: Dictionary = {}
var npc_line := 0
var quality := 2
var light_gain := 1.0
var shot: Dictionary = {}
var chapter: Node
var rooms: Node
var after_panel: Callable = Callable()
var ambience: AudioStreamPlayer
var gave_ticket := false
var _ticket_taken := false   # the chapter is on its way; more presses do nothing
var _hooded_next := 0        # msec: the hooded figure's next line can't come before this


func _ready() -> void:
	randomize()
	_load_settings()
	_parse_shot_args()
	_setup_input()
	_setup_environment()
	_setup_post()
	hud = HudScript.new()
	add_child(hud)
	hud.panel_closed.connect(_on_panel_closed)
	hud.guest_signed.connect(_on_guest_signed)
	hud.link_clicked.connect(_on_link)
	_load_guestbook()
	_load_progress()
	player = PlayerScript.new()
	add_child(player)
	chapter = ChapterScript.new()
	add_child(chapter)
	chapter.main = self
	chapter.hud = hud
	chapter.player = player
	rooms = RoomsScript.new()
	add_child(rooms)
	rooms.main = self
	rooms.hud = hud
	rooms.player = player
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -10.0
	add_child(ambience)
	if OS.get_cmdline_user_args().has("--roomtest"):
		_build_level("lobby")
		player.place(SPAWN_LOBBY, 0.0)
		rooms.roomtest()
		return
	if OS.get_cmdline_user_args().has("--stealthtest"):
		_build_level("exterior")
		chapter.stealthtest()
		return
	if OS.get_cmdline_user_args().has("--autotest"):
		_build_level("exterior")
		player.place(SPAWN_EXTERIOR, 0.0)
		chapter.autotest()
		return
	if shot.is_empty():
		_build_level("exterior")
		player.place(SPAWN_EXTERIOR, 0.0)
		hud.show_title()
	else:
		_run_shot()


# ---------- input ----------
func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("run", [KEY_SHIFT])
	_bind("jump", [KEY_SPACE])
	_bind("interact", [KEY_E])
	_bind("unstuck", [KEY_R])
	_bind("sneak", [KEY_C, KEY_CTRL])
	_bind("quality", [KEY_F9])
	_bind("camera", [KEY_Q])
	_bind("throw", [KEY_F])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ---------- light and air ----------
func _setup_environment() -> void:
	env = Environment.new()
	Look.setup(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)


func _setup_post() -> void:
	# vignette and grain, under the HUD
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = PostShader
	rect.material = sm
	layer.add_child(rect)


func _air(preset: String) -> void:
	Look.apply_preset(env, sun, preset, quality)
	light_gain = float(Look.PRESETS[preset].get("gain", 1.3))


func _outdoor_air() -> void:
	_air("dusk")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)


func _indoor_air() -> void:
	_air("interior")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)


func _ambience(kind: String) -> void:
	var st := Sound.loop(kind)
	if ambience.stream != st or not ambience.playing:
		ambience.stream = st
		ambience.play()


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var data = JSON.parse_string(FileAccess.open(SETTINGS_PATH, FileAccess.READ).get_as_text())
	if data is Dictionary:
		quality = clampi(int(data.get("quality", 2)), 0, 2)


func _save_settings() -> void:
	FileAccess.open(SETTINGS_PATH, FileAccess.WRITE).store_string(JSON.stringify({"quality": quality}))


func _cycle_quality() -> void:
	quality = (quality + 2) % 3
	Look.apply_quality(env, quality)
	_save_settings()
	hud.toast(["Graphics: low. Faster on older machines.", "Graphics: medium.", "Graphics: high. Fog, bounce light, the works."][quality], 3.0)


# ---------- rooms ----------
func go_to(level_name: String, pos: Vector3, facing: float) -> void:
	if busy:
		return
	busy = true
	player.enabled = false
	hud.set_prompt("")
	await hud.fade_to(1.0, 0.45).finished
	_build_level(level_name)
	var story := CHAPTER_LEVELS.has(level_name)
	if not story and pos != Vector3.INF:
		player.place(pos, facing)
	await get_tree().create_timer(0.2).timeout
	player.enabled = true
	busy = false
	hud.fade_to(0.0, 0.8)
	if story:
		chapter.after_enter(level_name)


func _build_level(level_name: String) -> void:
	if level:
		remove_child(level)
		level.queue_free()
	interactables.clear()
	flicker_lights.clear()
	npc = null
	npc_it = {}
	current = {}
	level = Node3D.new()
	level.name = level_name
	add_child(level)
	if CHAPTER_LEVELS.has(level_name):
		ambience.stop()
		chapter.build(level_name, level)
		return
	chapter.ambience.stop()
	match level_name:
		"exterior":
			_build_exterior()
		"lobby":
			_build_lobby()
		"library":
			_build_library()
		"honey":
			rooms.level = level
			rooms.build_honey()
			player.place(rooms.mk("hy_spawn"), 0.0)
		"studio":
			rooms.level = level
			rooms.build_studio()
			player.place(rooms.mk("dr_spawn"), 0.0)
		"trading":
			rooms.level = level
			rooms.build_trading()
			player.place(rooms.mk("tf_spawn"), 0.0)


func _instance(path: String, extra := {}) -> Node3D:
	var packed: PackedScene = load(path)
	var n: Node3D = packed.instantiate()
	level.add_child(n)
	_ensure_collision(n)
	Look.apply(n, extra)
	return n


func _ensure_collision(root: Node) -> void:
	# Godot normally handles -col / -colonly names on import. If not, do it here.
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.ends_with("-colonly"):
			mi.create_trimesh_collision()
			mi.visible = false
		elif nm.ends_with("-col"):
			mi.create_trimesh_collision()
	# make every mesh collider solid from both sides, so a flipped face can never become a hole
	for n in root.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape is ConcavePolygonShape3D:
			(cs.shape as ConcavePolygonShape3D).backface_collision = true


func _dust(center: Vector3, extents: Vector3, amount := 220) -> void:
	## motes drifting in the lamplight: only the ones near a light show up
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3(0, -0.004, 0)
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.05
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.15
	pm.turbulence_noise_speed_random = 0.2
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.92, 0.78, 0.55)
	m.disable_receive_shadows = true
	q.material = m
	p.draw_pass_1 = q
	p.position = center
	p.visibility_aabb = AABB(-extents * 1.5, extents * 3.0)
	level.add_child(p)


func _safety_floor() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	body.position.y = -1.5
	level.add_child(body)


func _omni(pos: Vector3, col: Color, energy: float, reach: float, flicker := true, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy * light_gain
	l.omni_range = reach
	l.omni_attenuation = 1.1
	l.light_volumetric_fog_energy = 1.6
	l.light_specular = 0.6
	if shadow and quality >= 1:
		l.shadow_enabled = true
		l.shadow_blur = 1.5
		l.shadow_bias = 0.05
	level.add_child(l)
	if flicker:
		flicker_lights.append({"light": l, "base": energy * light_gain, "seed": randf() * 100.0})
	return l


func add_interactable(pos: Vector3, radius: float, prompt: String, cb: Callable) -> void:
	interactables.append({"pos": pos, "r": radius, "prompt": prompt, "cb": cb})


# ---------- out front ----------
func _build_exterior() -> void:
	_ticket_taken = false
	_outdoor_air()
	var grounds := _instance("res://models/clubhouse_exterior.glb")
	Foliage.dress(grounds, level, 7)
	_safety_floor()
	for z in [12.0, 24.0, 36.0, 48.0]:
		for x in [-3.2, 3.2]:
			_omni(Vector3(x, 3.45, z), Color("ffc07a"), 0.8, 12.0)
	for x in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		_omni(Vector3(x, 2.5, 1.7), Color("ffc46e"), 0.45, 6.0, false)
		_omni(Vector3(x, 6.5, 1.3), Color("ffc46e"), 0.35, 5.5, false)
	_omni(Vector3(-1.95, 2.7, 0.8), Color("ffd08a"), 0.5, 5.0)
	_omni(Vector3(1.95, 2.7, 0.8), Color("ffd08a"), 0.5, 5.0)
	_add_fireflies()
	_ambience("crickets")
	add_interactable(Vector3(0.0, 1.5, 1.0), 1.5, "Go inside", _enter_lobby)
	add_interactable(Vector3(7.5, 1.0, 16.0), 2.8, "Read the club sign", _on_sign)
	npc = NpcScript.new()
	level.add_child(npc)
	npc.setup(HOODED_ROUTE, player)
	npc_it = {"pos": npc.global_position, "r": 2.4, "prompt": "Speak to the hooded figure", "cb": _talk_hooded}
	interactables.append(npc_it)


func _talk_hooded() -> void:
	## one line per press, never faster than a line a second, and the ticket comes with the third
	## line in the same breath (nothing waits on a timer to pop up over whatever comes next)
	if _ticket_taken:
		return
	if gave_ticket:
		_take_ticket()
		return
	var now := Time.get_ticks_msec()
	if now < _hooded_next:
		return
	_hooded_next = now + 1100
	var said: String = HOODED_LINES[npc_line % HOODED_LINES.size()]
	npc_line += 1
	if npc_line >= 3:
		gave_ticket = true
		said += "\n\nHe holds out an old railroad ticket. Hoboken, November 22, 1910."
		if not npc_it.is_empty():
			npc_it["prompt"] = "Take the old railroad ticket"
	hud.toast(said, 6.0)


func _take_ticket() -> void:
	if _ticket_taken or Time.get_ticks_msec() < _hooded_next:
		return
	_ticket_taken = true
	hud.toast("\"Watch who gets on that car. Listen to what they call each other.\"", 2.4)
	await get_tree().create_timer(2.5).timeout
	hud.clear_toast()
	chapter.start()


func _enter_lobby() -> void:
	await _through_door("Door_Front", "lobby", SPAWN_LOBBY, 0.0)
	hud.show_location("The Grand Lobby", "The Jekyll Island Club")


func swing_door(door: String, open := true, seconds := 0.7) -> bool:
	## Turn a door's leaves on their hinges. The leaves are Blender objects named <door>_SwingP / _SwingN
	## (tools/blender/split_doors.py); P turns them one way about their hinge, N the other.
	if level == null:
		return false
	var leaves := level.find_children(door + "_Swing*", "Node3D", true, false)
	if leaves.is_empty():
		return false
	var tw := create_tween().set_parallel(true)
	for n in leaves:
		var nd := n as Node3D
		var sgn := 1.0 if String(nd.name).contains("SwingP") else -1.0
		tw.tween_property(nd, "rotation:y", sgn * 1.4 if open else 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Sound.one_shot(self, "door", -8.0)
	return true


func _through_door(door: String, level_name: String, pos: Vector3, facing: float) -> void:
	## open the door, then go through it
	if busy:
		return
	if swing_door(door):
		busy = true
		player.enabled = false
		hud.set_prompt("")
		await get_tree().create_timer(0.5).timeout
		busy = false
	go_to(level_name, pos, facing)


func _add_fireflies() -> void:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 6.0
	p.preprocess = 6.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(42.0, 1.2, 30.0)
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.35
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color("f6e27a")
	m.emission_enabled = true
	m.emission = Color("f6e27a")
	m.emission_energy_multiplier = 5.0
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0.0, 1.4, 30.0)
	p.visibility_aabb = AABB(Vector3(-46, -4, -34), Vector3(92, 8, 68))
	level.add_child(p)


# ---------- the Grand Lobby ----------
func _build_lobby() -> void:
	_indoor_air()
	_instance("res://models/lobby.glb")
	_safety_floor()
	_ambience("room")
	_dust(Vector3(0.0, 2.2, -7.0), Vector3(9.0, 2.0, 6.0), 320)
	_omni(Vector3(0.0, 4.0, -7.0), Color("ffcf8a"), 1.3, 20.0)
	_omni(Vector3(-2.2, 1.9, -11.3), Color("ffd89a"), 0.5, 6.0)
	_omni(Vector3(0.0, 2.8, -12.6), Color("ffcf8a"), 0.5, 8.0, false)
	for y in [4.0, 10.0]:
		for s2 in [-1.5, 1.5]:
			_omni(Vector3(-9.6, 2.65, -(y + s2)), Color("ffd08a"), 0.25, 5.0)
			_omni(Vector3(9.6, 2.65, -(y + s2)), Color("ffd08a"), 0.25, 5.0)
	add_interactable(Vector3(0.0, 1.0, -0.9), 1.4, "Step back outside", _exit_to_porch)
	add_interactable(Vector3(-0.3, 1.0, -10.3), 1.7, "Sign the guest book", _open_guestbook)
	add_interactable(Vector3(2.0, 1.0, -10.3), 1.0, "Ring the desk bell", _on_bell)
	add_interactable(Vector3(1.0, 1.0, -10.3), 0.75, "Pick up the old railroad ticket on the desk", _desk_ticket)
	add_interactable(Vector3(-6.5, 1.0, -12.8), 1.9, "Read the notice board", _on_notices)
	add_interactable(Vector3(6.45, 1.0, -12.8), 1.9, "Look at the framed prints", _on_prints)
	add_interactable(Vector3(-9.0, 1.0, -4.0), 1.2, "Go into the Library", _enter_library)
	add_interactable(Vector3(-9.0, 1.0, -10.0), 1.2, "Go into the Trading Floor", _door_trading)
	add_interactable(Vector3(9.0, 1.0, -4.0), 1.2, "Go into the Drafting Room", _door_studio)
	add_interactable(Vector3(9.0, 1.0, -10.0), 1.2, "Go into the Honey House", _door_honey)


func _exit_to_porch() -> void:
	await _through_door("Door_Exit", "exterior", SPAWN_PORCH, PI)
	hud.show_location("The Grounds", "Dusk, Picayune, Mississippi")


func _enter_library() -> void:
	await _through_door("Door_Library", "library", SPAWN_LIBRARY, 0.0)
	hud.show_location("The Library", "The four studies")


func _door_trading() -> void:
	await _through_door("Door_Trading", "trading", Vector3.INF, 0.0)
	hud.show_location("The Trading Floor", "Jekyll Island Trading")


func _door_studio() -> void:
	await _through_door("Door_Studio", "studio", Vector3.INF, 0.0)
	hud.show_location("The Drafting Room", "Jekyll Studio")


func _door_honey() -> void:
	await _through_door("Door_Honey", "honey", Vector3.INF, 0.0)
	hud.show_location("The Honey House", "Jekyll's 40 Acre Farm")


func _exit_room(pos: Vector3, yaw: float) -> void:
	go_to("lobby", pos, yaw)
	hud.show_location("The Grand Lobby", "The Jekyll Island Club")


func _desk_ticket() -> void:
	open_panel("An old railroad ticket",
		"[i]Hoboken, N.J.  November 22, 1910.  One passenger, private car, rear of the southbound train.[/i]\n\n"
		+ "Somebody tucked it under the edge of the guest book. On the back, in pencil: [i]First names only.[/i]\n\n"
		+ "The men who met on Jekyll Island that month kept it quiet for years. This is your way onto that platform.\n\n"
		+ _link("ride1910", "Go to Hoboken, 1910"))


func _on_bell() -> void:
	hud.play_chime()
	hud.toast("Nobody at the desk this minute. Leave a note in the guest book.")


func _on_notices() -> void:
	open_panel("On the board",
		"Lessons are free and open to the public. Kids are who we built this for, so bring them.\n\n"
		+ "[b]What is money, really?[/b]\nThe first lesson. Where money came from, what it is now, and why a dollar is worth anything at all.\n\n"
		+ "[b]Where new money comes from[/b]\nA pretend bank with play money, and what happens the minute it makes a loan.\n\n"
		+ "[b]Teachers, we'll come to you[/b]\nAny school in Pearl River County. Tell us the grade and how long you've got. jekyllsclub@gmail.com\n\n"
		+ "[i]Dates go up here once they're set with the library and the schools.[/i]")


func _on_prints() -> void:
	open_panel("The club's marks",
		"The heron and the lighthouse are the island the club takes its name from. Four marks carry the club's meaning.\n\n"
		+ "[b]Oak tree.[/b]  Strength, growth, and long-term thinking.\n"
		+ "[b]Acorn.[/b]  Potential, beginnings, and the starting point of learning.\n"
		+ "[b]Torch.[/b]  Knowledge, clarity, and guidance.\n"
		+ "[b]Seven feathers.[/b]  The founding members.")


func _on_sign() -> void:
	open_panel("The Jekyll Island Club",
		"[i]Picayune, Mississippi[/i]\n\n"
		+ "We teach kids and grown folks about money: what it is, and how it actually gets made today.\n\n"
		+ "The name goes back to November 1910, when a few bankers and a senator met quietly at the Jekyll Island Club in Georgia and drafted the plan that became the Federal Reserve. We took the name because how money works shouldn't be decided at a quiet meeting. We teach it out loud, starting with the kids.\n\n"
		+ "[b]What we study, in order:[/b] understanding money, systems thinking, personal financial awareness, and self-improvement through structured learning.\n\n"
		+ "Membership is by invitation, and it always starts with a conversation. [i]jekyllsclub@gmail.com[/i]")


# ---------- guest book, saved on this computer ----------
func _load_guestbook() -> void:
	if not FileAccess.file_exists(GUESTBOOK_PATH):
		return
	var f := FileAccess.open(GUESTBOOK_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		guestbook = data


func _save_guestbook() -> void:
	var f := FileAccess.open(GUESTBOOK_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(guestbook))


func _open_guestbook() -> void:
	_lock_for_ui()
	hud.show_guestbook(guestbook)


func _on_guest_signed(guest_name: String, note: String) -> void:
	var d := Time.get_datetime_dict_from_system()
	var date := "%s %d, %d" % [MONTHS[int(d["month"]) - 1], int(d["day"]), int(d["year"])]
	guestbook.append({"name": guest_name, "note": note, "date": date})
	_save_guestbook()
	hud.refresh_guestbook(guestbook)


# ---------- panels and prompts ----------
func _lock_for_ui() -> void:
	ui_open = true
	player.enabled = false
	hud.set_prompt("")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func open_panel(title: String, body: String) -> void:
	panel_kind = ""
	_lock_for_ui()
	hud.show_panel(title, body)


func _on_panel_closed() -> void:
	ui_open = false
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if after_panel.is_valid():
		var cb := after_panel
		after_panel = Callable()
		cb.call()


func _process(delta: float) -> void:
	chapter.tick(delta)
	var t := Time.get_ticks_msec() / 1000.0
	for f in flicker_lights:
		var l: OmniLight3D = f["light"]
		var s: float = f["seed"]
		var base: float = f["base"]
		l.light_energy = base * (0.95 + 0.05 * sin(t * 7.3 + s) * sin(t * 3.1 + s * 2.0))

	if npc != null and is_instance_valid(npc) and not npc_it.is_empty():
		npc_it["pos"] = npc.global_position + Vector3(0.0, 1.0, 0.0)
	hud.mouse_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not ui_open
	if ui_open or busy or player == null:
		return
	var best: Dictionary = {}
	var best_d := 1.0e9
	var pp: Vector3 = player.global_position
	for it in interactables:
		var pos: Vector3 = it["pos"]
		var r: float = it["r"]
		var d := Vector2(pp.x - pos.x, pp.z - pos.z).length()
		if d < r and absf(pp.y - pos.y) < 3.0 and d < best_d:
			best = it
			best_d = d
	current = best
	if best.is_empty():
		hud.set_prompt("")
	else:
		hud.set_prompt(String(best["prompt"]))


func _unhandled_input(event: InputEvent) -> void:
	if chapter.in_scene:
		if event.is_action_pressed("ui_cancel"):
			chapter.request_skip()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("jump"):
			chapter.request_advance()
			get_viewport().set_input_as_handled()
		return
	# a conversation outside a cutscene (pouring the coffee): E moves it along too
	if chapter.talking and busy and event.is_action_pressed("interact"):
		chapter.request_advance()
		get_viewport().set_input_as_handled()
		return
	if sim != null:
		if event.is_action_pressed("ui_cancel"):
			sim.close_machine()
			get_viewport().set_input_as_handled()
		return
	if ui_open:
		if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("interact") and not hud.is_guestbook_open()):
			hud.close_panel()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quality"):
		_cycle_quality()
		get_viewport().set_input_as_handled()
		return
	if busy:
		return
	if event.is_action_pressed("interact") and not current.is_empty():
		var cb: Callable = current["cb"]
		cb.call()
		get_viewport().set_input_as_handled()


# ---------- the Library ----------
func _build_library() -> void:
	_indoor_air()
	env.ambient_light_color = Color("7a5a44")
	_instance("res://models/library.glb")
	_safety_floor()
	_ambience("room")
	_dust(Vector3(0.0, 2.0, -6.0), Vector3(7.0, 1.8, 5.5), 260)
	_omni(Vector3(0.0, 3.9, -6.0), Color("ffcf8a"), 1.2, 16.0)
	_omni(Vector3(3.6, 1.05, -6.4), Color("ffd89a"), 0.55, 4.5)
	_omni(Vector3(1.2, 3.0, -11.6), Color("ff9a40"), 0.6, 6.0)
	_omni(Vector3(5.2, 3.0, -11.6), Color("ff9a40"), 0.6, 6.0)
	_omni(Vector3(3.2, 2.4, -11.0), Color("8fb0e0"), 0.3, 6.0, false)
	_omni(Vector3(-4.6, 3.2, -9.5), Color("ffcf8a"), 0.45, 7.0, false)
	_omni(Vector3(7.6, 1.6, -2.6), Color("5fe08f"), 0.35, 3.5)
	add_interactable(Vector3(0.0, 1.0, -0.9), 1.4, "Back to the lobby", _exit_library)
	add_interactable(Vector3(-4.6, 1.0, -10.9), 1.9, "Take down a volume", _open_volumes)
	add_interactable(Vector3(5.0, 1.0, -5.3), 1.9, "Open the bank ledger", _open_ledger)
	add_interactable(Vector3(-7.6, 1.0, -3.8), 2.0, "Open the sealed envelope", _open_envelope)
	add_interactable(Vector3(2.8, 1.0, -0.7), 1.0, "Flip the kids mode switch", _toggle_kids)
	add_interactable(Vector3(7.2, 1.0, -2.6), 1.5, "Run the Money Machine", _open_machine.bind(0))


func _exit_library() -> void:
	_through_door("Door_Exit_001", "lobby", LOBBY_FROM_LIBRARY, -PI / 2.0)


func _toggle_kids() -> void:
	kids_mode = not kids_mode
	hud.play_chime()
	hud.toast("Kids mode is on. The books read simpler now." if kids_mode else "Kids mode is off.")


func _link(meta: String, text: String) -> String:
	return "[url=%s][color=#1d3a2b][b]%s[/b][/color][/url]" % [meta, text]


func _kids_line() -> String:
	return "\n\n" + _link("kids", "Kids mode is on. Switch it off" if kids_mode else "Reading with a kid? Switch on kids mode")


func _show(kind: String, title: String, body: String) -> void:
	if ui_open and sim == null:
		hud.update_panel(title, body)
	else:
		_lock_for_ui()
		hud.show_panel(title, body)
	panel_kind = kind


func _on_link(meta: String) -> void:
	if meta == "ride1910":
		hud.close_panel()
		chapter.start()
		return
	if chapter.on_link(meta):
		return
	if rooms.on_link(meta):
		return
	var parts := meta.split(":")
	match parts[0]:
		"shelf":
			_open_volumes()
		"vol":
			_open_volume(int(parts[1]))
		"ch":
			_open_chapter(int(parts[1]), int(parts[2]))
		"q":
			_answer(int(parts[1]), int(parts[2]), int(parts[3]))
		"machine":
			_open_machine(int(parts[1]))
		"kids":
			kids_mode = not kids_mode
			_refresh_panel()
		"ledger":
			_open_ledger()
		"lend":
			_ledger_lend()
		"repay":
			_ledger_repay()
		"reset":
			ledger_loans.clear()
			ledger_next = 0
			ledger_note = "Back to the start. Everybody's savings, and nothing else." if kids_mode else "Back to the start: $500 of deposits, backed by $500 of reserves."
			_render_ledger()


func _refresh_panel() -> void:
	var parts := panel_kind.split(":")
	match parts[0]:
		"vol":
			_open_volume(int(parts[1]))
		"ch":
			_open_chapter(int(parts[1]), int(parts[2]))
		"ledger":
			_render_ledger()
		_:
			_open_volumes()


# ----- progress, saved on this computer -----
func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		progress = data


func _save_progress() -> void:
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(progress))


func _done_count(v: int) -> int:
	var n := 0
	var chs: Array = Lessons.VOLUMES[v]["chapters"]
	for c in chs.size():
		if progress.has("%d-%d" % [v, c]):
			n += 1
	return n


# ----- the four studies -----
func _open_volumes() -> void:
	var body := "Four volumes, one for each study, in the order we teach them. A chapter gets a check once you answer its question right.\n\n"
	for v in Lessons.VOLUMES.size():
		var vol: Dictionary = Lessons.VOLUMES[v]
		var chs: Array = vol["chapters"]
		body += _link("vol:%d" % v, "Volume %s: %s" % [ROMAN[v], vol["title"]]) + "     [i]%d of %d done[/i]\n" % [_done_count(v), chs.size()]
	body += "\n" + _link("machine:0", "Or try the Money Machine by the door")
	body += _kids_line()
	_show("shelf", "The four studies", body)


func _open_volume(v: int) -> void:
	v = clampi(v, 0, Lessons.VOLUMES.size() - 1)
	var vol: Dictionary = Lessons.VOLUMES[v]
	var chs: Array = vol["chapters"]
	var body := "[i]%s[/i]\n\n" % vol["blurb"]
	for c in chs.size():
		var ch: Dictionary = chs[c]
		var mark := "[color=#2f7a4a][b]✓[/b][/color]  " if progress.has("%d-%d" % [v, c]) else "      "
		body += mark + _link("ch:%d:%d" % [v, c], "%d. %s" % [c + 1, ch["title"]]) + "\n"
	body += "\n" + _link("shelf", "Back to the shelf") + _kids_line()
	_show("vol:%d" % v, "Volume %s: %s" % [ROMAN[v], vol["title"]], body)


func _open_chapter(v: int, c: int) -> void:
	var vol: Dictionary = Lessons.VOLUMES[v]
	var chs: Array = vol["chapters"]
	var ch: Dictionary = chs[c]
	var key := "%d-%d" % [v, c]
	var body := "[i]Volume %s, chapter %d of %d[/i]\n\n" % [ROMAN[v], c + 1, chs.size()]
	body += String(ch["kid"] if kids_mode else ch["grown"])
	var sim_step: int = ch["sim"]
	if sim_step >= 0:
		body += "\n\n" + _link("machine:%d" % sim_step, "See it happen in the Money Machine")
	body += "\n\n[b]Check yourself.[/b]  " + String(ch["q"]) + "\n"
	var opts: Array = ch["options"]
	var answer: int = ch["answer"]
	var picked: int = quiz_pick.get(key, -1)
	for i in opts.size():
		var label := "%s)  %s" % [LETTERS[i], opts[i]]
		if picked == answer:
			body += "      " + (("[b]%s[/b]" % label) if i == answer else label) + "\n"
		else:
			body += "      " + _link("q:%d:%d:%d" % [v, c, i], label) + "\n"
	if picked == answer:
		body += "\n[color=#2f7a4a][b]That's right.[/b][/color]  " + String(ch["why"]) + "\n"
	elif picked >= 0:
		body += "\n[color=#8c2a1c][b]Not quite.[/b][/color]  Give it another look and try again.\n"
	elif progress.has(key):
		body += "\n[i]You've passed this one before.[/i]\n"
	body += "\n" + _link("vol:%d" % v, "Back to the chapters")
	if c + 1 < chs.size():
		body += "        " + _link("ch:%d:%d" % [v, c + 1], "Next chapter")
	elif v + 1 < Lessons.VOLUMES.size():
		body += "        " + _link("vol:%d" % (v + 1), "On to Volume %s" % ROMAN[v + 1])
	body += _kids_line()
	_show("ch:%d:%d" % [v, c], String(ch["title"]), body)


func _answer(v: int, c: int, i: int) -> void:
	var key := "%d-%d" % [v, c]
	quiz_pick[key] = i
	var chs: Array = Lessons.VOLUMES[v]["chapters"]
	var ch: Dictionary = chs[c]
	if i == int(ch["answer"]) and not progress.has(key):
		progress[key] = true
		_save_progress()
		hud.play_chime()
	_open_chapter(v, c)


# ----- the Money Machine -----
func _open_machine(step: int) -> void:
	if sim != null:
		return
	hud.panel.visible = false
	_lock_for_ui()
	sim = MoneySimScript.new()
	sim.kids = kids_mode
	sim.step = step
	hud.add_child(sim)
	sim.closed.connect(_close_machine)


func _close_machine() -> void:
	if sim != null:
		sim.queue_free()
		sim = null
	_on_panel_closed()


# ----- the bank ledger on the reading table -----
const BORROWERS := [
	{"who": "a bakery on Main Street", "why": "a new oven", "kid": "the bakery, so it can buy a bigger oven", "amt": 200},
	{"who": "a family", "why": "a used truck", "kid": "a family that needs a truck", "amt": 300},
	{"who": "a beekeeper", "why": "twenty new hives", "kid": "a beekeeper who wants more beehives", "amt": 150},
	{"who": "a lawn service", "why": "a zero-turn mower", "kid": "a lawn mowing business", "amt": 250}
]


func _money(n: int) -> String:
	var s := str(n)
	if n >= 1000:
		s = "%d,%03d" % [n / 1000, n % 1000]
	return "$" + s


func _open_ledger() -> void:
	ledger_note = ""
	_render_ledger()


func _ledger_lend() -> void:
	if ledger_loans.size() >= 4:
		ledger_note = "The bank says four loans is plenty for today. Try paying one back." if kids_mode else "Real banks can't lend forever. Rules about capital, and whether anybody wants to borrow, put a ceiling on it. Try paying one back."
		_render_ledger()
		return
	var b: Dictionary = BORROWERS[ledger_next % BORROWERS.size()]
	ledger_next += 1
	ledger_loans.append(b)
	var amt: int = b["amt"]
	if kids_mode:
		ledger_note = "The bank lent %s to %s. Nobody's savings went down. The bank just typed new money into their account." % [_money(amt), b["kid"]]
	else:
		ledger_note = "The bank lent %s to %s for %s. No one's savings were handed over. The loan and the new deposit showed up together, and the town has %s more money than it did a second ago." % [_money(amt), b["who"], b["why"], _money(amt)]
	_render_ledger()


func _ledger_repay() -> void:
	if ledger_loans.is_empty():
		ledger_note = "Nobody owes the bank anything yet. Make a loan first." if kids_mode else "No loans on the books yet. Make one first."
	else:
		ledger_loans.pop_front()
		ledger_note = "The loan got paid back, so that money disappears. It goes back to where it came from: nowhere." if kids_mode else "The loan was repaid. The loan and the deposit that paid it both come off the books, and that money stops existing. Lending makes money. Paying it back unmakes it."
	_render_ledger()


func _render_ledger() -> void:
	var k := kids_mode
	var left := "What the bank has" if k else "What the bank owns"
	var right := "Money in people's accounts" if k else "What the bank owes"
	var rows := "[cell][b]%s[/b]      [/cell][cell][b]%s[/b][/cell]" % [left, right]
	rows += "[cell]%s  %s      [/cell][cell]%s  %s[/cell]" % ["Cash in the vault" if k else "Reserves", _money(500), "Everybody's savings" if k else "Townspeople's deposits", _money(500)]
	var total := 500
	for b in ledger_loans:
		var amt: int = b["amt"]
		total += amt
		rows += "[cell]%s %s  %s      [/cell][cell]Account of %s  %s[/cell]" % ["IOU from" if k else "Loan to", b["who"], _money(amt), b["who"], _money(amt)]
	var bills := ""
	for i in total / 50:
		bills += "[color=#5d7a4c]■[/color]"
	var intro := "You run the only bank in a little town. Everybody's savings add up to $500. Lend some money and see what happens." if k else "You run the only bank in a small town. The townspeople have $500 on deposit, and the bank holds $500 in reserves against it. Make a loan and watch both sides of the books."
	var body := intro + "\n\n[table=2]" + rows + "[/table]\n\n"
	body += "[b]Money in town: %s[/b]\n%s\n\n" % [_money(total), bills]
	if ledger_note != "":
		body += "[i]%s[/i]\n\n" % ledger_note
	body += _link("lend", "Lend some money" if k else "Make a loan") + "        " + _link("repay", "Pay one back" if k else "Repay the oldest loan") + "        " + _link("reset", "Start over")
	body += "\n\n" + _link("machine:1", "See the whole picture in the Money Machine: banks, the government, and the Fed")
	body += _kids_line()
	_show("ledger", "Be the bank" if k else "The bank ledger", body)


# ----- the sealed envelope -----
func _open_envelope() -> void:
	_show("envelope", "By invitation",
		"[i]Membership in the club is by invitation, and it always starts with a conversation.[/i]\n\n"
		+ "Anybody can sit in on a lesson. If you'd like to talk about joining, for yourself or for your kids, write the club and tell us who you are and what you're trying to understand. We'll write back with a time to talk.\n\n"
		+ "After that conversation, you sit in on three meetings on a first-name basis, with no dues and no commitment. Then your full name goes on the roll. The members decide who's asked to stay. Rank is given by the members, and it carries no fee.\n\n"
		+ "[b]jekyllsclub@gmail.com[/b]")


# ---------- screenshots for development ----------
# godot --path godot -- --shot level=lobby pos=0,1.6,-3 look=0,1.4,-10 out=/tmp/lobby.png [frames=90]
#   swing=Door_Library opens a door first; setup=rear|front|valise|room stages a chapter moment (chapter1910 shot_setup)
func _parse_shot_args() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--shot"):
		return
	for a in args:
		var kv := String(a).split("=", true, 1)
		if kv.size() == 2:
			shot[kv[0]] = kv[1]


func _vec(txt: String) -> Vector3:
	var p := txt.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _run_shot() -> void:
	var lvl := String(shot.get("level", "exterior"))
	_build_level(lvl)
	var ppos := _vec(String(shot.get("player", "0,0,0")))
	player.place(ppos, float(shot.get("yaw", "0")))
	if shot.has("pos"):
		var cam := Camera3D.new()
		cam.fov = float(shot.get("fov", "62"))
		cam.far = 800.0
		add_child(cam)
		cam.global_position = _vec(String(shot["pos"]))
		cam.look_at(_vec(String(shot.get("look", "0,1,0"))))
		cam.current = true
		if shot.has("flash"):
			# a work light at the camera, for looking at shapes in the dark
			var wl := OmniLight3D.new()
			wl.omni_range = 30.0
			wl.light_energy = float(shot["flash"])
			cam.add_child(wl)
	player.enabled = false
	hud.visible_title(false)
	if shot.has("swing"):
		swing_door(String(shot["swing"]), true, 0.05)
	if shot.has("setup"):
		chapter.shot_setup(String(shot["setup"]))
	if shot.has("debug"):
		print("HUD root ", hud.root.size, " mission ", hud.mission.size, " anchors ", hud.mission.anchor_right, ",", hud.mission.anchor_bottom, " finder ", hud.mission.finder.size)
		for k in chapter.marks.keys():
			print("MARK ", k, " ", (chapter.marks[k] as Transform3D).origin)
		for k in chapter.actors.keys():
			var a = chapter.actors[k]
			print("ACTOR ", k, " ", a.global_position, " visible=", a.visible, " yaw=", a.model.rotation.y)
	if shot.has("hud"):
		# show every piece of the interface at once, for checking the look
		hud.show_location("The Grand Lobby", "The Jekyll Island Club")
		hud.set_objective("Slip aboard at the car's dark front end. Stay out of the lamplight.")
		hud.say("Nelson", "Nobody writes a last name down on this trip. Not on a menu card, not on a telegram.", 20.0)
		hud.set_prompt("Serve the gentleman")
		hud.set_sneak(true, 0.55)
		hud.letterbox(true, 0.1)
	var frames := int(shot.get("frames", "60"))
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(shot.get("out", "/tmp/shot.png")))
	get_tree().quit()
