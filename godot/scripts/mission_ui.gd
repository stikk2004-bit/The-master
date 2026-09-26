extends Control
## The mission layer of the interface: the big countdown at the top, the objective box, the
## camera in your pocket (bottom right), the viewfinder when you hold it up, and the prints that
## come up when a picture is taken, with a strip along the bottom for the ones you still need.

const BRASS := Color("c9a45c")
const BONE := Color("ece3cc")
const PAPER := Color("efe6cf")
const INK := Color("1e1812")
const DANGER := Color("e0613a")

var hud
var clock_box: VBoxContainer
var clock_title: Label
var clock_time: Label
var obj_box: PanelContainer
var obj_head: Label
var obj_text: Label
var obj_sub: Label
var item_box: PanelContainer
var item_label: Label
var finder: Control
var finder_film: Label
var finder_zoom: Label
var finder_hint: Label
var flash: ColorRect
var strip: HBoxContainer
var slots: Array = []
var sepia: ShaderMaterial
var _clock_left := -1.0
var _clock_urgent := 60.0
var _pulse := 0.0
var _obj_tw: Tween
var framed := false


func setup(h) -> void:
	hud = h
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 s = vec3(g * 1.07 + 0.04, g * 0.94 + 0.02, g * 0.74);
	float v = 1.0 - 0.55 * pow(length(UV - vec2(0.5)) * 1.35, 2.2);
	COLOR = vec4(s * v, c.a);
}"""
	sepia = ShaderMaterial.new()
	sepia.shader = sh
	_build_finder()
	_build_clock()
	_build_objective()
	_build_item()
	_build_strip()
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func _panel_style(bg: Color, border: Color, left := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = left
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_right = 1
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	return sb


# ------------------------------------------------------------------ the countdown
func _build_clock() -> void:
	clock_box = VBoxContainer.new()
	clock_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	clock_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clock_box.offset_top = 18
	clock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_box.add_theme_constant_override("separation", -6)
	clock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_title = hud._label("", 17, Color(BRASS, 0.95), hud.caps)
	clock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._shadow(clock_title)
	clock_time = hud._label("", 58, BONE, hud.caps_bold)
	clock_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._shadow(clock_time, 1.0)
	clock_box.add_child(clock_title)
	clock_box.add_child(clock_time)
	clock_box.visible = false
	add_child(clock_box)


func set_clock(title: String, seconds: float, urgent_below := 60.0) -> void:
	## seconds < 0 hides the clock
	_clock_left = seconds
	_clock_urgent = urgent_below
	clock_box.visible = seconds >= 0.0
	if seconds < 0.0:
		return
	clock_title.text = title.to_upper()
	var s := int(ceil(seconds))
	clock_time.text = "%d:%02d" % [int(s / 60.0), s % 60]


func _process(delta: float) -> void:
	if clock_box.visible:
		var urgent := _clock_left < _clock_urgent
		_pulse += delta * (6.0 if _clock_left < 20.0 else 3.2)
		var k := 0.5 + 0.5 * sin(_pulse)
		clock_time.add_theme_color_override("font_color", BONE.lerp(DANGER, 0.55 + 0.45 * k) if urgent else BONE)
		clock_time.pivot_offset = clock_time.size / 2.0
		clock_time.scale = Vector2.ONE * (1.0 + (0.06 * k if urgent else 0.0))
		clock_box.reset_size()
		clock_box.position.x = (size.x - clock_box.size.x) / 2.0


# ------------------------------------------------------------------ the objective
func _build_objective() -> void:
	obj_box = PanelContainer.new()
	obj_box.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.045, 0.04, 0.72), Color(BRASS, 0.8), 4))
	obj_box.position = Vector2(28, 24)
	obj_box.custom_minimum_size = Vector2(380, 0)
	obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	obj_head = hud._label("OBJECTIVE", 15, BRASS, hud.caps_bold)
	obj_text = hud._label("", 23, BONE, hud.serif)
	obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_text.custom_minimum_size = Vector2(380, 0)
	obj_sub = hud._label("", 18, Color(BRASS, 0.95), hud.caps)
	obj_sub.visible = false
	v.add_child(obj_head)
	v.add_child(obj_text)
	v.add_child(obj_sub)
	obj_box.add_child(v)
	obj_box.modulate.a = 0.0
	add_child(obj_box)


func set_objective(text: String) -> void:
	if _obj_tw:
		_obj_tw.kill()
	_obj_tw = create_tween()
	if text == "":
		_obj_tw.tween_property(obj_box, "modulate:a", 0.0, 0.5)
		return
	_obj_tw.tween_property(obj_box, "modulate:a", 0.0, 0.2)
	_obj_tw.tween_callback(_set_obj_text.bind(text))
	_obj_tw.tween_property(obj_box, "modulate", Color(1.6, 1.4, 1.0, 1.0), 0.35)
	_obj_tw.tween_property(obj_box, "modulate", Color(1, 1, 1, 1), 0.9)
	if hud.chime:
		hud.play_chime()


func _set_obj_text(text: String) -> void:
	obj_text.text = text
	obj_box.reset_size()


func set_sub(text: String, urgent := false) -> void:
	## a second line in the objective box: a tally of pictures, a smaller clock
	obj_sub.visible = text != ""
	obj_sub.text = text
	obj_sub.add_theme_color_override("font_color", DANGER if urgent else Color(BRASS, 0.95))
	obj_box.reset_size()


# ------------------------------------------------------------------ the camera in your pocket
func _build_item() -> void:
	item_box = PanelContainer.new()
	item_box.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.045, 0.04, 0.7), Color(BRASS, 0.7)))
	item_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	item_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	item_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	item_box.offset_right = -28
	item_box.offset_bottom = -26
	item_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_label = hud._label("", 20, BONE, hud.serif)
	item_box.add_child(item_label)
	item_box.visible = false
	add_child(item_box)


func set_item(text: String) -> void:
	item_box.visible = text != ""
	item_label.text = text


# ------------------------------------------------------------------ the viewfinder
class Finder extends Control:
	var ui
	var frame := Rect2()

	func _draw() -> void:
		var vw := size.x
		var vh := size.y
		var fw := vw * 0.62
		var fh := minf(fw / 1.5, vh * 0.64)
		fw = fh * 1.5
		frame = Rect2((vw - fw) / 2.0, (vh - fh) / 2.0, fw, fh)
		var dark := Color(0.02, 0.018, 0.015, 0.86)
		draw_rect(Rect2(0, 0, vw, frame.position.y), dark)
		draw_rect(Rect2(0, frame.end.y, vw, vh - frame.end.y), dark)
		draw_rect(Rect2(0, frame.position.y, frame.position.x, fh), dark)
		draw_rect(Rect2(frame.end.x, frame.position.y, vw - frame.end.x, fh), dark)
		draw_rect(frame, Color(0.9, 0.85, 0.72, 0.5), false, 1.5)
		var c: Color = ui.BRASS if ui.framed else Color(0.92, 0.9, 0.85, 0.8)
		var L := fh * 0.12
		for corner in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
			var p: Vector2 = corner
			var sx := 1.0 if p.x < vw / 2.0 else -1.0
			var sy := 1.0 if p.y < vh / 2.0 else -1.0
			var inset := Vector2(sx, sy) * 14.0
			draw_line(p + inset, p + inset + Vector2(sx * L, 0), c, 3.0)
			draw_line(p + inset, p + inset + Vector2(0, sy * L), c, 3.0)
		var ctr := frame.get_center()
		draw_line(ctr - Vector2(14, 0), ctr + Vector2(14, 0), Color(c, 0.7), 1.5)
		draw_line(ctr - Vector2(0, 14), ctr + Vector2(0, 14), Color(c, 0.7), 1.5)


func _build_finder() -> void:
	var f := Finder.new()
	f.ui = self
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finder = f
	finder_film = hud._label("", 20, BONE, hud.caps)
	finder_zoom = hud._label("", 20, BONE, hud.caps)
	finder_hint = hud._label("Click to take the picture   ·   Wheel to zoom   ·   Q to put it away", 18, Color(BONE, 0.8), hud.serif_italic)
	for l in [finder_film, finder_zoom, finder_hint]:
		hud._shadow(l)
		f.add_child(l)
	finder.visible = false
	add_child(finder)
	f.resized.connect(_place_finder_labels)


func _place_finder_labels() -> void:
	var f := finder as Finder
	f.queue_redraw()
	var fr := frame_rect()
	finder_film.reset_size()
	finder_film.position = Vector2(fr.position.x + 26, fr.end.y - finder_film.size.y - 20)
	finder_zoom.reset_size()
	finder_zoom.position = Vector2(fr.end.x - finder_zoom.size.x - 26, fr.end.y - finder_zoom.size.y - 20)
	finder_hint.reset_size()
	finder_hint.position = Vector2(fr.get_center().x - finder_hint.size.x / 2.0, fr.end.y + 8)


func show_finder(on: bool) -> void:
	finder.visible = on
	if on:
		_place_finder_labels()


func set_finder(film: int, zoom: float, is_framed: bool) -> void:
	finder_film.text = "Exposures left  %d" % film
	finder_zoom.text = "%.1fx" % zoom
	if is_framed != framed:
		framed = is_framed
		finder.queue_redraw()
	_place_finder_labels()


func frame_rect() -> Rect2:
	## the picture area of the viewfinder, in screen coordinates (same sums as Finder._draw)
	var sz := size if size.x > 1.0 else get_viewport_rect().size
	var vw := sz.x
	var vh := sz.y
	var fh := minf(vw * 0.62 / 1.5, vh * 0.64)
	var fw := fh * 1.5
	return Rect2((vw - fw) / 2.0, (vh - fh) / 2.0, fw, fh)


func shutter_flash() -> void:
	flash.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.45)


# ------------------------------------------------------------------ the prints
func _build_strip() -> void:
	strip = HBoxContainer.new()
	strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.offset_left = 28
	strip.offset_bottom = -24
	strip.add_theme_constant_override("separation", 8)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.visible = false
	add_child(strip)


func set_slots(count: int) -> void:
	## the row of prints you still need: count empty frames with a question mark in each
	for s in slots:
		(s[0] as Node).queue_free()
	slots.clear()
	strip.visible = count > 0
	for i in count:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.055, 0.05, 0.75)
		sb.border_color = Color(BRASS, 0.6)
		sb.set_border_width_all(1)
		sb.set_content_margin_all(4)
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(84, 56)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.material = sepia
		var q: Label = hud._label("?", 30, Color(BONE, 0.35), hud.caps_bold)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.add_child(q)
		var cap: Label = hud._label("", 14, Color(BONE, 0.9), hud.caps)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pic)
		v.add_child(cap)
		p.add_child(v)
		strip.add_child(p)
		slots.append([p, pic, q, cap])


func fill_slot(i: int, tex: Texture2D, caption: String) -> void:
	if i < 0 or i >= slots.size():
		return
	var s: Array = slots[i]
	(s[1] as TextureRect).texture = tex
	(s[2] as Label).visible = false
	(s[3] as Label).text = caption
	var p := s[0] as Control
	p.pivot_offset = p.size / 2.0
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(1.25, 1.25), 0.15)
	tw.tween_property(p, "scale", Vector2.ONE, 0.3)


func show_print(tex: Texture2D, title: String, sub: String, stamp: String, slot := -1, caption := "") -> void:
	## a print comes up out of the camera: the picture, who it is, then it drops into the strip
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_content_margin_all(14)
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(420, 280)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.material = sepia
	var t: Label = hud._label(title.to_upper(), 26, INK, hud.caps_bold)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d: Label = hud._label(sub, 19, Color(INK, 0.85), hud.serif_italic)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(420, 0)
	v.add_child(pic)
	v.add_child(t)
	v.add_child(d)
	card.add_child(v)
	add_child(card)
	if stamp != "":
		var st: Label = hud._label(stamp, 30, Color("a3281c"), hud.caps_bold)
		st.rotation = -0.22
		st.position = Vector2(300, 18)
		st.modulate.a = 0.0
		pic.add_child(st)
		var tws := create_tween()
		tws.tween_interval(0.7)
		tws.tween_property(st, "modulate:a", 0.9, 0.08)
		tws.parallel().tween_property(st, "scale", Vector2(1.0, 1.0), 0.12).from(Vector2(1.6, 1.6))
	card.reset_size()
	await get_tree().process_frame
	card.reset_size()
	card.pivot_offset = card.size / 2.0
	var rest := Vector2(size.x * 0.64 - card.size.x / 2.0, size.y * 0.42 - card.size.y / 2.0)
	card.position = Vector2(size.x + 40.0, rest.y + 60.0)
	card.rotation = 0.25
	var tw := create_tween()
	tw.tween_property(card, "position", rest, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "rotation", -0.05, 0.45)
	tw.tween_interval(3.0)
	if slot >= 0 and slot < slots.size():
		var target := slots[slot][0] as Control
		var goal := target.global_position + target.size / 2.0 - card.size / 2.0
		tw.tween_property(card, "position", goal, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(card, "scale", Vector2(0.2, 0.2), 0.5)
		tw.parallel().tween_property(card, "rotation", 0.0, 0.5)
		tw.tween_callback(fill_slot.bind(slot, tex, caption))
	else:
		tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)
