extends Node3D
## A person the story moves around: walks a path, turns, sits, talks with their hands.
## Paths are lists of points; the actor follows them at a steady pace with a walk
## cycle matched to its speed. skip() jumps straight to the end of whatever it's doing.

signal arrived

const Look := preload("res://scripts/look.gd")
const WALK_REF := 1.7          # the walk animation was authored for this speed

var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var display_name := ""
var path: Array = []
var speed := 1.3
var walk_anim := "Walk"
var idle_anim := "Idle"
var current := ""
var body: AnimatableBody3D
var _turning := false
var _turn_to := 0.0


func setup(model_path: String, name_shown := "", collide := false) -> void:
	display_name = name_shown
	var packed: PackedScene = load(model_path)
	model = packed.instantiate()
	add_child(model)
	Look.apply(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0]
		for a in anim.get_animation_list():
			if not String(a) in ["Serve"]:
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var sk := model.find_children("*", "Skeleton3D", true, false)
	if sk.size() > 0:
		skeleton = sk[0]
	if collide:
		body = AnimatableBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.8
		cs.shape = cap
		cs.position.y = 0.9
		body.add_child(cs)
		add_child(body)
	play(idle_anim)


func play(anim_name: String, blend := 0.3, spd := 1.0) -> void:
	if anim == null:
		return
	if not anim.has_animation(anim_name):
		anim_name = "Idle"
	if anim_name == current and is_equal_approx(anim.speed_scale, spd):
		return
	anim.play(anim_name, blend)
	anim.speed_scale = spd
	current = anim_name


func indoors(on := true) -> void:
	## hats off and hands free when they come inside
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var nm := String(n.name)
		if nm.ends_with("Hat") or nm.ends_with("Prop"):
			(n as MeshInstance3D).visible = not on


func place(pos: Vector3, yaw: float) -> void:
	global_position = pos
	model.rotation.y = yaw
	path.clear()


func yaw() -> float:
	return model.rotation.y


func face_point(p: Vector3, instant := false) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var y := atan2(d.x, d.z)
	if instant:
		model.rotation.y = y
	else:
		_turn_to = y
		_turning = true


func face_yaw(y: float) -> void:
	_turn_to = y
	_turning = true


func walk(points: Array, spd := 1.3, anim_name := "Walk") -> void:
	## Start walking a path. Await `arrived` to know when they get there.
	path = points.duplicate()
	speed = spd
	walk_anim = anim_name
	if path.is_empty():
		arrived.emit()


func is_walking() -> bool:
	return not path.is_empty()


func skip() -> void:
	## Finish the walk at once (used when a player skips a scene).
	if path.is_empty():
		return
	var last: Vector3 = path[path.size() - 1]
	if path.size() >= 2:
		face_point_from(path[path.size() - 2], last)
	global_position = last
	path.clear()
	play(idle_anim)
	arrived.emit()


func face_point_from(a: Vector3, b: Vector3) -> void:
	var d := b - a
	if Vector2(d.x, d.z).length() > 0.01:
		model.rotation.y = atan2(d.x, d.z)


func _physics_process(delta: float) -> void:
	if not path.is_empty():
		var target: Vector3 = path[0]
		var to := target - global_position
		var flat := Vector2(to.x, to.z)
		var step := speed * delta
		if flat.length() <= step or flat.length() < 0.02:
			global_position = target
			path.pop_front()
			if path.is_empty():
				play(idle_anim)
				arrived.emit()
			return
		var dir := to.normalized()
		# keep height changes (stairs, steps) in proportion to how far we walk flat
		global_position += Vector3(flat.normalized().x * step, to.y * step / maxf(flat.length(), 0.001), flat.normalized().y * step)
		var want := atan2(to.x, to.z)
		model.rotation.y = lerp_angle(model.rotation.y, want, 1.0 - exp(-10.0 * delta))
		play(walk_anim, 0.25, clampf(speed / WALK_REF, 0.5, 1.6))
	elif _turning:
		model.rotation.y = lerp_angle(model.rotation.y, _turn_to, 1.0 - exp(-6.0 * delta))
		if absf(angle_difference(model.rotation.y, _turn_to)) < 0.02:
			_turning = false


func hand_node(side := "R") -> Node3D:
	## A node that follows the hand, for lanterns and trays.
	if skeleton == null:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Hand." + side
	skeleton.add_child(ba)
	return ba
