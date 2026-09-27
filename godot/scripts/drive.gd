extends CharacterBody3D
## Jekyll's motorcar: W and S for the throttle and the brake (and reverse), A and D to steer,
## E to get out once she's stopped. A chase camera rides behind.
## The model faces its local -Z (as exported from Blender), so the heading is rotation.y.

signal exit_requested

const Sound := preload("res://scripts/sound.gd")

const MAX_SPEED := 11.0        # a little under 25 miles an hour
const REVERSE := 3.0
const ACCEL := 3.2
const BRAKE := 8.0
const DRAG := 0.9
const STEER_MAX := 0.5
const WHEELBASE := 2.7
const GRAVITY := 14.0

var driving := false
var speed := 0.0
var steer := 0.0
var cam: Camera3D
var model: Node3D
var engine: AudioStreamPlayer3D


func setup(car_model: Node3D) -> void:
	model = car_model
	if model.get_parent():
		model.get_parent().remove_child(model)
	add_child(model)
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 1.5, 3.9)
	cs.shape = box
	cs.position = Vector3(0, 0.95, 0.1)
	add_child(cs)
	floor_snap_length = 0.3
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 800.0
	cam.top_level = true
	add_child(cam)
	engine = AudioStreamPlayer3D.new()
	engine.stream = Sound.loop("motor")
	engine.volume_db = -14.0
	engine.unit_size = 6.0
	add_child(engine)


func start_driving() -> void:
	driving = true
	speed = 0.0
	_place_cam(1.0)
	cam.current = true
	if engine.stream:
		engine.play()


func stop_driving() -> void:
	driving = false
	speed = 0.0
	velocity = Vector3.ZERO
	engine.stop()


func forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


func _unhandled_input(event: InputEvent) -> void:
	if driving and event.is_action_pressed("interact"):
		# at a crawl she's easy to hop out of: the brake goes on and out you get
		if absf(speed) < 3.0:
			exit_requested.emit()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	if driving:
		var throttle := Input.get_axis("move_back", "move_forward")
		var turn := Input.get_axis("move_right", "move_left")
		if throttle > 0.0:
			speed += (ACCEL if speed >= 0.0 else BRAKE) * throttle * delta
		elif throttle < 0.0:
			speed += (BRAKE if speed > 0.0 else ACCEL * 0.6) * throttle * delta
		else:
			speed = move_toward(speed, 0.0, DRAG * delta)
		speed = clampf(speed, -REVERSE, MAX_SPEED)
		steer = move_toward(steer, turn * STEER_MAX * (1.0 - 0.45 * absf(speed) / MAX_SPEED), 2.2 * delta)
	else:
		speed = move_toward(speed, 0.0, BRAKE * delta)
		steer = move_toward(steer, 0.0, 2.0 * delta)
	rotation.y += speed / WHEELBASE * tan(steer) * delta
	var f := forward()
	velocity.x = f.x * speed
	velocity.z = f.z * speed
	move_and_slide()
	if get_slide_collision_count() > 0 and is_on_wall():
		speed *= 0.6
	if engine.playing:
		engine.pitch_scale = 0.7 + absf(speed) / MAX_SPEED * 0.9


func _process(delta: float) -> void:
	if driving:
		_place_cam(1.0 - exp(-4.0 * delta))


func _place_cam(k: float) -> void:
	var f := forward()
	var want := global_position - f * 6.8 + Vector3(0, 2.7, 0)
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(global_position + f * 3.0 + Vector3(0, 1.2, 0), Vector3.UP)
