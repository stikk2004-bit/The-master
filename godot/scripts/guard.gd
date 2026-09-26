extends "res://scripts/actor.gd"
## A watchman on patrol with a bull's-eye lantern. The lantern throws a beam ahead of him; step
## into it and he has you in a moment. Outside the beam he still sees in a wide cone, far under a
## lamp and not far at all in the dark, and he hears running feet.
##
## Two ways to patrol: a fixed round (arm with a route), or roam(): pick somewhere across the yard,
## away from where the other watchmen are and aren't headed, and walk there by the yard's walkable
## map. When he stops he swings the lantern side to side. When he half sees something he walks over
## to look, and tells the others (alarmed), and the nearest one comes too.
## watching = false keeps him walking his round without taking any notice of anyone.

signal caught
signal spoke(line: String)
signal alarmed(where: Vector3)

const EYE := 1.6
const FOV := deg_to_rad(60.0)          # half-angle he can make things out in
const BEAM_ANGLE := deg_to_rad(19.0)   # half-angle of the lantern beam
const BEAM_RANGE := 17.0
const DARK_SIGHT := 6.0                # a man standing in the dark, how far off he makes him out
const LAMP_SIGHT := 15.0               # the same man under a lamp
const LANTERN := 7.0                   # beam brightness

var route: Array = []
var route_i := 0
var wait_left := 0.0
var detection := 0.0
var state := "patrol"
var beam: SpotLight3D
var lantern: OmniLight3D
var last_seen := Vector3.ZERO
var player: Node3D = null
var lamps: Array = []                  # [Vector3 position, float reach] lamps that light the ground
var lines_suspicious := ["Who's there?", "Somebody over there?"]
var lines_clear := ["Rats in the freight again.", "Must be the wind."]
var active := true
var watching := true
var patrol_speed := 1.15
var pauses := {}                       # route index -> seconds he stops there (otherwise now and then)
var spots: Array = []                  # roaming: the places he may walk to
var others: Array = []                 # roaming: the other watchmen, to keep apart from
var nav_map: RID
var target := Vector3.INF
var sweep := 0.0
var _recent: Array = []
var _sweep_t := 0.0
var _said := false
var _search := 0.0
var _seed := 0.0


func arm(route_points: Array, player_node: Node3D, lamp_list: Array, with_lantern := true) -> void:
	route = route_points
	player = player_node
	lamps = lamp_list
	walk_anim = "LanternWalk" if with_lantern else "Walk"
	idle_anim = "LookAround" if with_lantern else "Idle"
	_seed = randf() * 100.0
	if not route.is_empty():
		global_position = route[0]
		route_i = 1 % route.size()
	var hand := hand_node("R") if with_lantern else null
	if hand:
		# the lantern itself: a small warm glow in his hand
		lantern = OmniLight3D.new()
		lantern.light_color = Color("ffb45a")
		lantern.light_energy = 0.7
		lantern.omni_range = 2.6
		lantern.omni_attenuation = 1.4
		lantern.position = Vector3(0.0, -0.18, 0.0)
		hand.add_child(lantern)
		# and the beam it throws ahead of him, through the fog
		beam = SpotLight3D.new()
		beam.light_color = Color("ffc877")
		beam.light_energy = LANTERN
		beam.spot_range = BEAM_RANGE
		beam.spot_angle = rad_to_deg(BEAM_ANGLE)
		beam.spot_angle_attenuation = 0.6
		beam.spot_attenuation = 1.1
		beam.light_volumetric_fog_energy = 4.0
		beam.shadow_enabled = true
		add_child(beam)
		_aim_beam()


func roam(spot_list: Array, other_guards: Array, map: RID) -> void:
	## patrol by picking places across the yard instead of a fixed round
	spots = spot_list
	others = other_guards
	nav_map = map
	target = Vector3.INF


func look_yaw() -> float:
	## where he's looking: the way he faces, plus the swing of the lantern
	return model.rotation.y + sweep


func _aim_beam() -> void:
	if beam == null:
		return
	var y := look_yaw()
	var fwd := Vector3(sin(y), 0.0, cos(y))
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	beam.global_position = global_position + Vector3(0, 1.05, 0) + fwd * 0.35 - right * 0.22
	var aim := Vector3(sin(y), -0.2, cos(y)).normalized()
	beam.look_at(beam.global_position + aim, Vector3.UP)


func light_at(p: Vector3) -> float:
	## how lit a spot is by the yard's lamps, 0 dark .. 1 standing under one
	var best := 0.0
	for L in lamps:
		var lp: Vector3 = L[0]
		var reach: float = L[1]
		var d := Vector2(p.x - lp.x, p.z - lp.z).length()
		best = maxf(best, clampf(1.0 - d / reach, 0.0, 1.0))
	return best


func _hidden_from_me(p: Vector3) -> bool:
	if player == null:
		return false
	if player.get("hidden") == true:
		return global_position.distance_to(p) > 1.3
	return false


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var ex: Array[RID] = []
	if body:
		ex.append(body.get_rid())
	if player is CollisionObject3D:
		ex.append((player as CollisionObject3D).get_rid())
	q.exclude = ex
	return space.intersect_ray(q).is_empty()


func in_beam(p: Vector3, crouched: bool) -> bool:
	if beam == null:
		return false
	var target_pt := p + Vector3(0, 0.5 if crouched else 1.0, 0)
	var to := target_pt - beam.global_position
	if to.length() > BEAM_RANGE:
		return false
	var dir := -beam.global_transform.basis.z
	return dir.angle_to(to) < BEAM_ANGLE * 1.08


func sees(p: Vector3, crouched: bool) -> float:
	## 0 if the player can't be seen; otherwise how strongly, 0..~1.7
	if _hidden_from_me(p):
		return 0.0
	var eye := global_position + Vector3(0, EYE, 0)
	var target_pt := p + Vector3(0, 0.55 if crouched else 1.1, 0)
	var to := target_pt - eye
	var dist := to.length()
	if in_beam(p, crouched):
		if _clear_line(beam.global_position, target_pt):
			return (0.8 + (1.0 - dist / BEAM_RANGE) * 0.9) * (0.85 if crouched else 1.0)
	var y := look_yaw()
	var fwd := Vector3(sin(y), 0.0, cos(y))
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var ang := acos(clampf(fwd.dot(flat), -1.0, 1.0))
	var fov := FOV * (1.25 if state != "patrol" else 1.0)
	if ang > fov:
		return 0.0
	var reach := lerpf(DARK_SIGHT, LAMP_SIGHT, light_at(p)) * (0.6 if crouched else 1.0)
	if p.y - global_position.y > 2.0:
		reach *= 0.5                    # nobody looks up
	if dist > reach:
		return 0.0
	if not _clear_line(eye, target_pt):
		return 0.0
	var closeness := 1.0 - dist / reach
	var centered := 1.0 - ang / fov
	return clampf(0.25 + closeness * 0.9 + centered * 0.25, 0.0, 1.5)


func hears(p: Vector3, noise: float) -> float:
	if _hidden_from_me(p):
		return 0.0
	var d := (p - global_position).length()
	var radius := 9.0 * noise
	if d > radius:
		return 0.0
	return 1.0 - d / radius


func _physics_process(delta: float) -> void:
	if lantern:
		lantern.light_energy = 0.7 * (0.93 + 0.07 * sin(Time.get_ticks_msec() * 0.011 + _seed) * sin(Time.get_ticks_msec() * 0.0037))
	# the lantern swings side to side while he stands and looks, and settles ahead when he walks
	var want_sweep := 0.0
	if not is_walking() and (wait_left > 0.0 or state == "suspicious" and _search > 0.0):
		_sweep_t += delta
		want_sweep = 0.75 * sin(_sweep_t * 1.1 + _seed)
	else:
		want_sweep = 0.12 * sin(Time.get_ticks_msec() * 0.0021 + _seed)
	sweep = lerpf(sweep, want_sweep, 1.0 - exp(-4.0 * delta))
	_aim_beam()
	if not active or player == null:
		super._physics_process(delta)
		return
	var crouched: bool = player.get("sneaking") == true
	var noise: float = float(player.get("noise"))
	var s := sees(player.global_position, crouched) if watching else 0.0
	var h := hears(player.global_position, noise) if watching else 0.0
	if s > 0.0 or h > 0.0:
		last_seen = player.global_position
		detection += (s * 1.2 + h * 0.6) * delta
	else:
		detection -= 0.2 * delta
	detection = clampf(detection, 0.0, 1.0)

	match state:
		"patrol":
			if detection > 0.3:
				_become_suspicious(last_seen, true)
			elif not spots.is_empty():
				_roam(delta)
			else:
				_patrol(delta)
		"suspicious":
			if detection >= 1.0:
				state = "alert"
				path.clear()
				caught.emit()
			elif not is_walking():
				face_yaw(atan2(last_seen.x - global_position.x, last_seen.z - global_position.z))
				_search -= delta
				if _search <= 0.0 and detection < 0.15:
					state = "patrol"
					_said = false
					target = Vector3.INF
					spoke.emit(lines_clear[randi() % lines_clear.size()])
					_resume()
		"alert":
			face_point(player.global_position)
	super._physics_process(delta)


func _become_suspicious(where: Vector3, loud: bool) -> void:
	state = "suspicious"
	_search = 4.0
	_sweep_t = 0.0
	if not _said:
		_said = true
		spoke.emit(lines_suspicious[randi() % lines_suspicious.size()])
	if loud:
		alarmed.emit(where)
	# walk over for a closer look, most of the way
	var here := global_position
	var go := here.lerp(where, 0.75) if here.distance_to(where) > 3.0 else here
	walk(_nav_path(here, go), 1.55, walk_anim)


func investigate(where: Vector3) -> void:
	## another watchman called out: come and have a look
	if not active or state != "patrol":
		return
	last_seen = where
	_become_suspicious(where, false)


func _patrol(delta: float) -> void:
	if route.is_empty() or is_walking():
		return
	if wait_left > 0.0:
		wait_left -= delta
		play(idle_anim)
		return
	_sweep_t = 0.0
	var tgt: Vector3 = route[route_i]
	var here := route_i
	route_i = (route_i + 1) % route.size()
	walk([tgt], patrol_speed, walk_anim)
	if pauses.has(here):
		wait_left = float(pauses[here])
	elif pauses.is_empty() and randf() < 0.45:
		wait_left = randf_range(2.0, 4.5)


func _roam(delta: float) -> void:
	if is_walking():
		return
	if wait_left > 0.0:
		wait_left -= delta
		play(idle_anim)
		return
	_sweep_t = 0.0
	target = _pick_spot()
	walk(_nav_path(global_position, target), patrol_speed, walk_anim)
	wait_left = randf_range(1.5, 5.0) if randf() < 0.7 else 0.0


func _pick_spot() -> Vector3:
	## somewhere not too near, not too far, and well away from the other watchmen and where they're going
	var best := Vector3.INF
	var best_score := -1e9
	for i in spots.size():
		if _recent.has(i):
			continue
		var s: Vector3 = spots[i]
		var d_self := global_position.distance_to(s)
		var crowd := 30.0
		for g in others:
			if g == self or not is_instance_valid(g):
				continue
			crowd = minf(crowd, s.distance_to((g as Node3D).global_position))
			var gt: Vector3 = g.target
			if gt != Vector3.INF:
				crowd = minf(crowd, s.distance_to(gt))
		var score := minf(crowd, 22.0) + randf() * 9.0
		if d_self < 6.0:
			score -= 25.0
		elif d_self > 38.0:
			score -= (d_self - 38.0) * 0.6
		if score > best_score:
			best_score = score
			best = s
			_last_pick = i
	_recent.append(_last_pick)
	if _recent.size() > 4:
		_recent.pop_front()
	return best if best != Vector3.INF else global_position


var _last_pick := -1


func _nav_path(from: Vector3, to: Vector3) -> Array:
	## a walkable way from here to there, or straight at it when there's no map
	if nav_map.is_valid():
		var pts := NavigationServer3D.map_get_path(nav_map, from, to, true)
		if pts.size() >= 2:
			var out := []
			for k in range(1, pts.size()):
				out.append(pts[k])
			return out
	return [to]


func _resume() -> void:
	if not spots.is_empty():
		target = Vector3.INF
		return
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
	target = Vector3.INF
	_recent.clear()
	sweep = 0.0
	if index >= 0 and not route.is_empty():
		route_i = (index + 1) % route.size()
	play(idle_anim)
