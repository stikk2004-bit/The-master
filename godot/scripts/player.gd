extends CharacterBody3D
## Third-person player: WASD relative to the camera, mouse orbit, Shift to run.

const WALK_SPEED := 2.3
const RUN_SPEED := 6.0
const JUMP_VELOCITY := 4.6
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const STEP_HEIGHT := 0.4

var enabled := true
var spawn_point := Vector3.ZERO
var yaw := 0.0
var pitch := -0.28

var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var model: Node3D
var anim: AnimationPlayer
var current_anim := ""
var last_safe := Vector3.ZERO
var _safe_timer := 0.0


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

	var packed: PackedScene = load("res://models/player.glb")
	model = packed.instantiate()
	add_child(model)
	model.rotation.y = PI
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0]
		for n in ["Idle", "Walk", "Run"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")

	cam_pivot = Node3D.new()
	cam_pivot.position.y = 1.55
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
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input := Vector2.ZERO
	var running := false
	if enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		running = Input.is_action_pressed("run")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	var speed := RUN_SPEED if running else WALK_SPEED
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
	var want := "Idle"
	if hspeed > 0.3:
		want = "Run" if running else "Walk"
	if not is_on_floor() and velocity.y > 0.5:
		want = "Run"
	_play(want)
	if anim:
		if want == "Walk":
			anim.speed_scale = clampf(hspeed / 1.7, 0.6, 1.8)
		elif want == "Run":
			anim.speed_scale = clampf(hspeed / 3.9, 0.8, 1.8)
		else:
			anim.speed_scale = 1.0

	if global_position.y < -1.2:
		respawn()


func _play(anim_name: String) -> void:
	if anim == null or anim_name == current_anim or not anim.has_animation(anim_name):
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
