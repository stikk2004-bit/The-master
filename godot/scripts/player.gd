extends CharacterBody3D
## Third-person player: WASD relative to the camera, mouse orbit, Shift to run, C to sneak.
## Can change clothes (the steward's jacket on the train), carry a tray and hold up a pocket Kodak.
## The tray and the camera follow the left hand but stay level, whatever the arm is doing.

const WALK_SPEED := 2.3
const RUN_SPEED := 6.0
const SNEAK_SPEED := 1.35
const JUMP_VELOCITY := 4.6
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const STEP_HEIGHT := 0.4
const Look := preload("res://scripts/look.gd")
const OUTFITS := {"club": "res://models/player.glb", "waiter": "res://models/player_waiter.glb"}

signal served

var enabled := true
var can_sneak := true
var sneaking := false
var carrying := false
var outfit := "club"
var noise := 0.0              # 0 silent .. 1 loud; guards listen for this
var spawn_point := Vector3.ZERO
var yaw := 0.0
var pitch := -0.28

var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var model: Node3D
var anim: AnimationPlayer
var tray: Node3D
var kodak: Node3D
var holding_kodak := false
var _skel: Skeleton3D
var _hand := -1
var current_anim := ""
var one_shot := ""
var last_safe := Vector3.ZERO
var _safe_timer := 0.0
var _pivot_h := 1.55


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)

	_load_model(outfit)

	cam_pivot = Node3D.new()
	cam_pivot.position.y = _pivot_h
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 4.2
	spring.margin = 0.25
	cam_pivot.add_child(spring)
	spring.add_excluded_object(get_rid())
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 800.0
	spring.add_child(cam)
	cam.current = true
	cam_pivot.rotation.y = yaw
	spring.rotation.x = pitch
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# after the animation has moved the hand this frame
	process_priority = 10


func _load_model(which: String) -> void:
	var facing := PI
	if model:
		facing = model.rotation.y
		remove_child(model)
		model.queue_free()
		if tray:
			tray.queue_free()
		tray = null
		if kodak:
			kodak.queue_free()
		kodak = null
	var packed: PackedScene = load(OUTFITS[which])
	model = packed.instantiate()
	add_child(model)
	Look.apply(model)
	model.rotation.y = facing
	anim = null
	current_anim = ""
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0]
		for n in ["Idle", "Walk", "Run", "SneakIdle", "SneakWalk", "CarryIdle", "CarryWalk"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished)
		_play("Idle")
	outfit = which
	_skel = null
	_hand = -1
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.size() > 0:
		_skel = found[0]
		_hand = _skel.find_bone("Hand.L")
	if carrying:
		_attach_tray()
	if holding_kodak:
		set_kodak(true)


func set_outfit(which: String) -> void:
	if which != outfit:
		_load_model(which)


func set_carrying(on: bool) -> void:
	carrying = on
	if on:
		_attach_tray()
	elif tray:
		tray.queue_free()
		tray = null


func _attach_tray() -> void:
	if tray != null or _hand < 0:
		return
	tray = Node3D.new()
	tray.top_level = true
	add_child(tray)
	# a silver tray with two glasses on it
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color("c8c4bc")
	silver.metallic = 1.0
	silver.roughness = 0.25
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.19
	cyl.height = 0.012
	cyl.radial_segments = 32
	disc.mesh = cyl
	disc.material_override = silver
	tray.add_child(disc)
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.19
	tor.outer_radius = 0.205
	tor.rings = 32
	rim.mesh = tor
	rim.material_override = silver
	rim.position.y = 0.008
	tray.add_child(rim)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.9, 0.95, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var drink := StandardMaterial3D.new()
	drink.albedo_color = Color("8a4a18")
	drink.roughness = 0.1
	for x in [-0.07, 0.08]:
		var g := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.035
		gm.bottom_radius = 0.028
		gm.height = 0.09
		g.mesh = gm
		g.material_override = glass
		g.position = Vector3(x, 0.05, 0.02 * x * 10.0)
		tray.add_child(g)
		var d := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.03
		dm.bottom_radius = 0.026
		dm.height = 0.05
		d.mesh = dm
		d.material_override = drink
		d.position = g.position + Vector3(0, -0.015, 0)
		tray.add_child(d)


func set_kodak(on: bool) -> void:
	## the folding pocket Kodak, held at the waist and looked down into, the way they were
	holding_kodak = on
	if not on:
		if kodak:
			kodak.queue_free()
		kodak = null
		return
	if kodak != null or _hand < 0:
		return
	kodak = Node3D.new()
	kodak.top_level = true
	add_child(kodak)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("1a1614")
	leather.roughness = 0.55
	var nickel := StandardMaterial3D.new()
	nickel.albedo_color = Color("b8b4ac")
	nickel.metallic = 1.0
	nickel.roughness = 0.3
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.05, 0.16)
	body.mesh = bm
	body.material_override = leather
	body.position = Vector3(0, 0.03, 0)
	kodak.add_child(body)
	# the bellows and lens standing out the front
	var bel := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.07, 0.06, 0.07)
	bel.mesh = bb
	bel.material_override = leather
	bel.position = Vector3(0, 0.03, 0.11)
	kodak.add_child(bel)
	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.018
	lm.bottom_radius = 0.018
	lm.height = 0.02
	lens.mesh = lm
	lens.material_override = nickel
	lens.rotation.x = PI / 2.0
	lens.position = Vector3(0, 0.03, 0.155)
	kodak.add_child(lens)


func _process(_delta: float) -> void:
	# keep the tray and the camera level in the left hand
	if _skel == null or _hand < 0 or (tray == null and kodak == null):
		return
	var hand := _skel.global_transform * _skel.get_bone_global_pose(_hand)
	var palm := hand * Vector3(0.0, 0.08, 0.0)
	var level := Basis(Vector3.UP, model.global_rotation.y)
	if tray:
		tray.global_transform = Transform3D(level, palm + Vector3(0.0, 0.035, 0.0))
	if kodak:
		kodak.global_transform = Transform3D(level, palm + Vector3(0.0, 0.02, 0.0))


func play_once(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		one_shot = anim_name
		anim.play(anim_name, 0.2)
		current_anim = anim_name


func _on_anim_finished(anim_name: StringName) -> void:
	if String(anim_name) == one_shot:
		one_shot = ""
		current_anim = ""
		if anim_name == &"Serve":
			served.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * MOUSE_SENS
		pitch = clampf(pitch - mm.relative.y * MOUSE_SENS, -1.15, 0.35)
		cam_pivot.rotation.y = yaw
		spring.rotation.x = pitch
	elif event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring.spring_length = maxf(1.8, spring.spring_length - 0.4)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring.spring_length = minf(10.0, spring.spring_length + 0.4)
	elif event.is_action_pressed("unstuck"):
		respawn()
	elif event.is_action_pressed("sneak") and can_sneak and not carrying:
		sneaking = not sneaking
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input := Vector2.ZERO
	var running := false
	if enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		running = Input.is_action_pressed("run") and not carrying
		if running and sneaking:
			sneaking = false
		if Input.is_action_just_pressed("jump") and is_on_floor() and not carrying:
			velocity.y = JUMP_VELOCITY
			sneaking = false

	var speed := RUN_SPEED if running else (SNEAK_SPEED if sneaking else WALK_SPEED)
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, 28.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 28.0 * delta)
	move_and_slide()
	if enabled and dir.length() > 0.1 and is_on_floor() and is_on_wall():
		_try_step(dir * speed * delta)
	if is_on_floor():
		_safe_timer += delta
		if _safe_timer > 0.5:
			last_safe = global_position
			_safe_timer = 0.0

	if dir.length() > 0.1:
		var target := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, 1.0 - exp(-12.0 * delta))

	var hspeed := Vector2(velocity.x, velocity.z).length()
	# how loud we are: a run carries, a sneak barely whispers
	var want_noise := 0.0
	if hspeed > 0.3:
		want_noise = 1.0 if running else (0.08 if sneaking else 0.35)
	noise = move_toward(noise, want_noise, delta * 3.0)

	# the camera settles lower while sneaking
	var want_h := 1.05 if sneaking else _pivot_h
	cam_pivot.position.y = move_toward(cam_pivot.position.y, want_h, delta * 1.8)

	if one_shot != "":
		return
	var want := "Idle"
	if holding_kodak:
		want = "CarryIdle"
	elif carrying:
		want = "CarryWalk" if hspeed > 0.3 else "CarryIdle"
	elif sneaking:
		want = "SneakWalk" if hspeed > 0.2 else "SneakIdle"
	elif hspeed > 0.3:
		want = "Run" if running else "Walk"
	if not is_on_floor() and velocity.y > 0.5:
		want = "Run"
	_play(want)
	if anim:
		if want in ["Walk", "CarryWalk"]:
			anim.speed_scale = clampf(hspeed / 1.7, 0.6, 1.8)
		elif want == "Run":
			anim.speed_scale = clampf(hspeed / 3.9, 0.8, 1.8)
		elif want == "SneakWalk":
			anim.speed_scale = clampf(hspeed / 1.0, 0.6, 1.6)
		else:
			anim.speed_scale = 1.0

	if global_position.y < -1.2:
		respawn()


func _play(anim_name: String) -> void:
	if anim == null or anim_name == current_anim:
		return
	if not anim.has_animation(anim_name):
		anim_name = "Idle"
		if anim_name == current_anim:
			return
	anim.play(anim_name, 0.22)
	current_anim = anim_name


func place(pos: Vector3, facing_yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	yaw = facing_yaw
	cam_pivot.rotation.y = yaw
	model.rotation.y = yaw + PI
	spawn_point = pos
	last_safe = pos


func face(facing_yaw: float) -> void:
	model.rotation.y = facing_yaw + PI


func _try_step(motion: Vector3) -> void:
	# climb anything up to STEP_HEIGHT tall instead of getting hung up on it
	var up := Vector3(0.0, STEP_HEIGHT, 0.0)
	var fwd := motion.normalized() * maxf(motion.length(), 0.08)
	if test_move(global_transform, up):
		return
	if test_move(global_transform.translated(up), fwd):
		return
	global_position += up + fwd


func respawn() -> void:
	var target := last_safe if last_safe != Vector3.ZERO else spawn_point
	global_position = target + Vector3(0.0, 0.3, 0.0)
	velocity = Vector3.ZERO
