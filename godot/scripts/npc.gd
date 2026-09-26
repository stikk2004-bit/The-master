extends Node3D
## A hooded figure in black who walks a loop around the grounds.
## Stops now and then, and turns to face you when you come close.

const SPEED := 1.25
const NOTICE_DISTANCE := 2.8
const Look := preload("res://scripts/look.gd")

var waypoints: Array = []
var idx := 0
var wait := 0.0
var player: Node3D = null
var model: Node3D
var anim: AnimationPlayer
var body: AnimatableBody3D
var current_anim := ""


func setup(points: Array, player_node: Node3D) -> void:
	waypoints = points
	player = player_node
	idx = 1 % maxi(1, points.size())
	if points.size() > 0:
		var p: Vector3 = points[0]
		global_position = Vector3(p.x, 0.2, p.z)


func _ready() -> void:
	var packed: PackedScene = load("res://models/hooded_figure.glb")
	model = packed.instantiate()
	add_child(model)
	Look.apply(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0]
		for n in ["Idle", "Walk"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")
	# so the player bumps into him instead of walking through
	body = AnimatableBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	add_child(body)


func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return
	var pos := global_position
	pos.y = _ground(pos)
	if player != null and Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length() < NOTICE_DISTANCE:
		global_position = pos
		_face(player.global_position, delta, 5.0)
		_play("Idle")
		return
	if wait > 0.0:
		wait -= delta
		global_position = pos
		_play("Idle")
		return
	var target: Vector3 = waypoints[idx]
	var to := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	if to.length() < 0.35:
		idx = (idx + 1) % waypoints.size()
		if randf() < 0.4:
			wait = randf_range(2.5, 6.0)
		return
	var stepv := to.normalized() * SPEED * delta
	pos.x += stepv.x
	pos.z += stepv.z
	global_position = pos
	_face(target, delta, 4.0)
	_play("Walk")


func _face(target: Vector3, delta: float, turn_speed: float) -> void:
	var d := Vector2(target.x - global_position.x, target.z - global_position.z)
	if d.length() < 0.01:
		return
	var want := atan2(d.x, d.y)
	model.rotation.y = lerp_angle(model.rotation.y, want, 1.0 - exp(-turn_speed * delta))


func _ground(pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 1.5, 0.0), pos + Vector3(0.0, -4.0, 0.0))
	var ex: Array[RID] = [body.get_rid()]
	if player is CollisionObject3D:
		ex.append((player as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return pos.y
	var hp: Vector3 = hit["position"]
	return hp.y


func _play(anim_name: String) -> void:
	if anim == null or anim_name == current_anim or not anim.has_animation(anim_name):
		return
	anim.play(anim_name, 0.35)
	anim.speed_scale = 0.78 if anim_name == "Walk" else 1.0
	current_anim = anim_name
