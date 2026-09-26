extends "res://scripts/actor.gd"
## A watchman on patrol, usually with a lantern. He sees in a cone ahead of him, farther in
## lamplight, and hears footsteps. Seen long enough and you're caught.
## watching = false keeps him walking his round without taking any notice (the car's steward
## only minds you in the lounge, Arthur only when he looks up from his writing).

signal caught
signal spoke(line: String)

const SIGHT := 14.0
const FOV := deg_to_rad(62.0)          # half-angle
const EYE := 1.6
const LANTERN := 4.0                   # lantern brightness
const LANTERN_REACH := 8.0             # how far a lantern lights you up for him

var route: Array = []
var route_i := 0
var wait_left := 0.0
var detection := 0.0
var state := "patrol"
var lantern: OmniLight3D
var last_seen := Vector3.ZERO
var player: Node3D = null
var lamps: Array = []                  # [Vector3 position, float reach] lamps that light the ground
var lines_suspicious := ["Who's there?", "Somebody over there?"]
var lines_clear := ["Rats in the freight again.", "Must be the wind."]
var active := true
var watching := true
var patrol_speed := 1.1
var pauses := {}                       # route index -> seconds he stops there (otherwise now and then)
var _said := false
var _search := 0.0


func arm(route_points: Array, player_node: Node3D, lamp_list: Array, with_lantern := true) -> void:
	route = route_points
	player = player_node
	lamps = lamp_list
	walk_anim = "LanternWalk" if with_lantern else "Walk"
	idle_anim = "LookAround" if with_lantern else "Idle"
	if not route.is_empty():
		global_position = route[0]
		route_i = 1 % route.size()
	var hand := hand_node("R") if with_lantern else null
	if hand:
		lantern = OmniLight3D.new()
		lantern.light_color = Color("ffb45a")
		lantern.light_energy = LANTERN
		lantern.omni_range = 9.0
		lantern.omni_attenuation = 1.2
		lantern.light_volumetric_fog_energy = 2.0
		lantern.shadow_enabled = true
		lantern.position = Vector3(0.0, -0.18, 0.0)
		hand.add_child(lantern)


func light_at(p: Vector3) -> float:
	## how lit a spot is, 0 dark .. 1 standing under a lamp
	var best := 0.0
	for L in lamps:
		var lp: Vector3 = L[0]
		var reach: float = L[1]
		var d := Vector2(p.x - lp.x, p.z - lp.z).length()
		best = maxf(best, clampf(1.0 - d / reach, 0.0, 1.0))
	if lantern:
		var d2 := (p - lantern.global_position).length()
		best = maxf(best, clampf(1.0 - d2 / LANTERN_REACH, 0.0, 1.0))
	return best


func sees(p: Vector3, crouched: bool) -> float:
	## 0 if the player can't be seen; otherwise how strongly, 0..1
	var eye := global_position + Vector3(0, EYE, 0)
	var target := p + Vector3(0, 0.55 if crouched else 1.1, 0)
	var to := target - eye
	var dist := to.length()
	var lit := light_at(p)
	var reach := SIGHT * lerpf(0.47, 1.0, lit) * (0.62 if crouched else 1.0)
	if dist > reach:
		return 0.0
	var fwd := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var ang := acos(clampf(fwd.dot(flat), -1.0, 1.0))
	var fov := FOV * (1.25 if state == "suspicious" else 1.0)
	if ang > fov:
		return 0.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, target)
	var ex: Array[RID] = []
	if body:
		ex.append(body.get_rid())
	if player is CollisionObject3D:
		ex.append((player as CollisionObject3D).get_rid())
	q.exclude = ex
	if not space.intersect_ray(q).is_empty():
		return 0.0
	var closeness := 1.0 - dist / reach
	var centered := 1.0 - ang / fov
	return clampf(0.25 + closeness * 0.9 + centered * 0.25, 0.0, 1.5)


func hears(p: Vector3, noise: float) -> float:
	var d := (p - global_position).length()
	var radius := 9.0 * noise
	if d > radius:
		return 0.0
	return 1.0 - d / radius


func _physics_process(delta: float) -> void:
	if lantern:
		lantern.light_energy = LANTERN * (0.93 + 0.07 * sin(Time.get_ticks_msec() * 0.011 + 1.3) * sin(Time.get_ticks_msec() * 0.0037))
	if not active or player == null:
		super._physics_process(delta)
		return
	var crouched: bool = player.get("sneaking") == true
	var noise: float = float(player.get("noise"))
	var s := sees(player.global_position, crouched) if watching else 0.0
	var h := hears(player.global_position, noise) if watching else 0.0
	if s > 0.0 or h > 0.0:
		last_seen = player.global_position
		detection += (s * 1.15 + h * 0.6) * delta
	else:
		detection -= 0.18 * delta
	detection = clampf(detection, 0.0, 1.0)

	match state:
		"patrol":
			if detection > 0.3:
				state = "suspicious"
				_search = 3.5
				path.clear()
				play("LookAround", 0.3)
				face_point(last_seen)
				if not _said:
					_said = true
					spoke.emit(lines_suspicious[randi() % lines_suspicious.size()])
			else:
				_patrol(delta)
		"suspicious":
			face_point(last_seen)
			if detection >= 1.0:
				state = "alert"
				caught.emit()
			elif detection < 0.12:
				_search -= delta
				if _search <= 0.0:
					state = "patrol"
					_said = false
					spoke.emit(lines_clear[randi() % lines_clear.size()])
					_resume()
		"alert":
			face_point(player.global_position)
	super._physics_process(delta)


func _patrol(delta: float) -> void:
	if route.is_empty() or is_walking():
		return
	if wait_left > 0.0:
		wait_left -= delta
		play("LookAround")
		return
	var target: Vector3 = route[route_i]
	var here := route_i
	route_i = (route_i + 1) % route.size()
	walk([target], patrol_speed, walk_anim)
	if pauses.has(here):
		wait_left = float(pauses[here])
	elif pauses.is_empty() and randf() < 0.45:
		wait_left = randf_range(2.0, 4.5)


func _resume() -> void:
	if route.is_empty():
		return
	# head back toward the nearest point on his round
	var best := 0
	var bd := 1e9
	for i in route.size():
		var d := (route[i] as Vector3).distance_to(global_position)
		if d < bd:
			bd = d
			best = i
	route_i = best


func reset_to(p: Vector3, index := -1) -> void:
	global_position = p
	detection = 0.0
	state = "patrol"
	_said = false
	path.clear()
	wait_left = 0.0
	if index >= 0 and not route.is_empty():
		route_i = (index + 1) % route.size()
	play(idle_anim)
