extends Control
## How near you are to being seen, as a railroad signal lamp: a dark green lens while nobody has
## noticed you, amber as somebody starts to, red when you're as good as caught. A thin ring round
## the lens fills up with how much they've seen.

const GREEN := Color("3f8a52")
const AMBER := Color("e8a23c")
const RED := Color("d8341f")

var detection := 0.0:
	set(v):
		detection = clampf(v, 0.0, 1.0)
		queue_redraw()

var _shown := 0.0
var _plate: StyleBoxFlat


func _ready() -> void:
	_plate = StyleBoxFlat.new()
	_plate.bg_color = Color(0.075, 0.07, 0.065, 0.93)
	_plate.border_color = Color("6e5f44")
	_plate.set_border_width_all(2)
	_plate.set_corner_radius_all(9)
	_plate.shadow_color = Color(0, 0, 0, 0.5)
	_plate.shadow_size = 8


func _process(delta: float) -> void:
	var before := _shown
	_shown = move_toward(_shown, detection, delta * 2.5)
	if absf(_shown - before) > 0.0001 or detection >= 1.0 or _shown > 0.4:
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, 6)
	var r := minf(size.x, size.y) * 0.24
	var t := Time.get_ticks_msec() / 1000.0
	var col := GREEN.lerp(AMBER, smoothstep(0.12, 0.5, _shown)).lerp(RED, smoothstep(0.68, 0.95, _shown))
	var glow := 0.2 + 0.8 * clampf(_shown * 1.3, 0.0, 1.0)
	if detection >= 1.0:
		glow *= 0.55 + 0.45 * sin(t * 11.0)
	# the handle over the top
	draw_arc(c + Vector2(0, -r * 1.55), r * 0.62, PI, TAU, 18, Color("3a342c"), 3.5, true)
	# the lamp body: an iron case with a brass edge
	draw_style_box(_plate, Rect2(c - Vector2(r * 1.5, r * 1.55), Vector2(r * 3.0, r * 3.0)))
	# the light it throws, then the lens itself
	for i in 4:
		draw_circle(c, r * (1.05 + 0.28 * float(i + 1)), Color(col, 0.07 * glow))
	draw_circle(c, r * 1.08, Color("8a7650"))
	draw_circle(c, r, col.darkened(0.72))
	draw_circle(c, r * 0.9, Color(col, 0.3 + 0.7 * glow))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.32), r * 0.22, Color(1, 1, 1, 0.1 + 0.2 * glow))
	for k in 3:
		draw_arc(c, r * (0.32 + 0.2 * float(k)), 0.0, TAU, 28, Color(1, 1, 1, 0.09), 1.0, true)
	# the hood shading the top of the lens
	draw_arc(c, r * 1.13, PI + 0.15, TAU - 0.15, 24, Color(0.05, 0.045, 0.04, 0.9), r * 0.2, true)
	# how much they've seen, filling round the lens
	if _shown > 0.02:
		draw_arc(c, r * 1.32, -PI / 2.0, -PI / 2.0 + TAU * _shown, 48, Color(col, 0.95), 3.0, true)
