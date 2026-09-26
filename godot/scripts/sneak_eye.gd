extends Control
## The sneak eye: closed while nobody has noticed you, opening as someone does.

var detection := 0.0:
	set(v):
		detection = clampf(v, 0.0, 1.0)
		queue_redraw()

var _shown := 0.0


func _process(delta: float) -> void:
	var before := _shown
	_shown = move_toward(_shown, detection, delta * 2.5)
	if absf(_shown - before) > 0.0001 or detection >= 1.0:
		queue_redraw()


func _lids(open: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var t := float(i) / n
		var x := (t - 0.5) * w
		pts.append(Vector2(x, -sin(t * PI) * h * open))
	for i in range(n, -1, -1):
		var t := float(i) / n
		var x := (t - 0.5) * w
		pts.append(Vector2(x, sin(t * PI) * h * open))
	return pts


func _draw() -> void:
	var c := size / 2.0
	var w := size.x * 0.9
	var h := size.y * 0.42
	var open := 0.08 + 0.92 * _shown
	var col := Color("cfc6b0").lerp(Color("e0a040"), smoothstep(0.2, 0.7, _shown)).lerp(Color("d23a28"), smoothstep(0.8, 1.0, _shown))
	if detection >= 1.0:
		col.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 90.0)
	# soft dark plate behind the eye so it reads on bright ground
	draw_circle(c, h * 1.25, Color(0, 0, 0, 0.35))
	var outline := _lids(maxf(open, 0.12), w, h)
	var shifted := PackedVector2Array()
	for p in outline:
		shifted.append(p + c)
	shifted.append(shifted[0])
	draw_polyline(shifted, col, 2.0, true)
	if open > 0.2:
		var iris := h * 0.62 * smoothstep(0.2, 0.6, open)
		draw_circle(c, iris, Color(col, 0.35))
		draw_arc(c, iris, 0.0, TAU, 32, col, 1.5, true)
		draw_circle(c, iris * 0.42, col)
	else:
		# closed: just the lash line
		draw_line(c - Vector2(w * 0.5, 0), c + Vector2(w * 0.5, 0), col, 2.0, true)
