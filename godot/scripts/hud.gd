extends CanvasLayer
## On-screen interface: title card, "press E" prompt, reading panels, fades,
## location banners, subtitles, letterbox bars, the objective line and the sneak eye.

signal panel_closed
signal link_clicked(meta: String)
signal guest_signed(guest_name: String, note: String)

const PARCHMENT := Color("efe4c8")
const INK := Color("1e1812")
const GREEN := Color("1d3a2b")
const BRASS := Color("a88c52")
const BONE := Color("e8e0cc")

var serif: Font
var serif_italic: Font
var serif_bold: Font
var caps: Font
var caps_bold: Font
var fell: Font
var fell_italic: Font
var root: Control
var prompt_box: Control
var prompt_label: Label
var panel: PanelContainer
var panel_title: Label
var panel_body: RichTextLabel
var title_card: VBoxContainer
var mouse_hint: Label
var fade: ColorRect
var gb_panel: PanelContainer
var gb_name: LineEdit
var gb_note: LineEdit
var gb_status: Label
var gb_entries: VBoxContainer
var chime: AudioStreamPlayer
var bars: Array = []
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var sub_box: VBoxContainer
var sub_name: Label
var sub_line: Label
var objective: Label
var timer_label: Label
var card: VBoxContainer
var card_title: Label
var card_sub: Label
var eye: Control
var _banner_tw: Tween
var _sub_tw: Tween
var _obj_tw: Tween


func _font(file: String, fallback_italic := false, fallback_weight := 400) -> Font:
	var path := "res://fonts/" + file
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Georgia", "Garamond", "Palatino Linotype", "Times New Roman", "serif"])
	sys.font_italic = fallback_italic
	sys.font_weight = fallback_weight
	if ResourceLoader.exists(path):
		var f: FontFile = load(path)
		if f != null:
			f.fallbacks = [sys]
			return f
	return sys


func _ready() -> void:
	layer = 10
	serif = _font("CormorantGaramond-Medium.woff2")
	serif_italic = _font("CormorantGaramond-MediumItalic.woff2", true)
	serif_bold = _font("CormorantGaramond-Bold.woff2", false, 700)
	caps = _font("Cinzel-Medium.woff2")
	caps_bold = _font("Cinzel-Bold.woff2", false, 700)
	fell = _font("IMFellEnglish-Regular.woff2")
	fell_italic = _font("IMFellEnglish-Italic.woff2", true)

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_bars()
	_build_title()
	_build_banner()
	_build_objective()
	_build_subtitles()
	_build_prompt()
	_build_mouse_hint()
	_build_eye()
	_build_panel()
	panel_body.meta_clicked.connect(_on_meta)
	_build_guestbook()
	chime = AudioStreamPlayer.new()
	chime.stream = _make_chime()
	chime.volume_db = -6.0
	add_child(chime)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	_build_card()
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(fade, "modulate:a", 0.0, 1.8)


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _shadow(l: Label, strength := 0.85) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, strength))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 12)


func _rule(width: float, color := BRASS) -> Control:
	# a thin line that fades out at both ends
	var c := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 2
	c.texture = gt
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_SCALE
	c.custom_minimum_size = Vector2(width, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func _center(c: Control) -> void:
	c.reset_size()
	c.position.x = (root.size.x - c.size.x) / 2.0


# ------------------------------------------------------------------ title
func _build_title() -> void:
	title_card = VBoxContainer.new()
	title_card.set_anchors_preset(Control.PRESET_CENTER)
	title_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_card.alignment = BoxContainer.ALIGNMENT_CENTER
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.add_theme_constant_override("separation", 10)
	var sub := _label("Picayune, Mississippi", 26, Color(BONE, 0.85), serif_italic)
	var main := _label("THE JEKYLL ISLAND CLUB", 64, BONE, caps)
	var help := _label("W A S D to walk.   Shift to run.   C to sneak.   Mouse to look.   E to use what's in front of you.   R if you get stuck.", 18, Color(BONE, 0.7), serif)
	for l in [sub, main, help]:
		_shadow(l)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_card.add_child(sub)
	title_card.add_child(main)
	title_card.add_child(_rule(560))
	title_card.add_child(help)
	title_card.modulate.a = 0.0
	root.add_child(title_card)


func visible_title(on: bool) -> void:
	title_card.visible = on
	fade.modulate.a = 0.0


func show_title() -> void:
	title_card.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(title_card, "modulate:a", 1.0, 2.0)
	tw.tween_interval(6.0)
	tw.tween_property(title_card, "modulate:a", 0.0, 2.5)


# ------------------------------------------------------------------ location banner
func _build_banner() -> void:
	banner = VBoxContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_top = 120
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("separation", 6)
	banner_title = _label("", 42, BONE, caps)
	banner_sub = _label("", 22, Color(BONE, 0.8), serif_italic)
	for l in [banner_title, banner_sub]:
		_shadow(l)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(_rule(420))
	banner.add_child(banner_title)
	banner.add_child(banner_sub)
	banner.add_child(_rule(420))
	banner.modulate.a = 0.0
	root.add_child(banner)


func show_location(title: String, sub := "") -> void:
	banner_title.text = title.to_upper()
	banner_sub.text = sub
	banner_sub.visible = sub != ""
	_center(banner)
	if _banner_tw:
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.tween_interval(0.5)
	_banner_tw.tween_property(banner, "modulate:a", 1.0, 1.2)
	_banner_tw.tween_interval(3.2)
	_banner_tw.tween_property(banner, "modulate:a", 0.0, 1.6)


# ------------------------------------------------------------------ objective
func _build_objective() -> void:
	objective = _label("", 21, Color(BONE, 0.92), serif_italic)
	_shadow(objective)
	objective.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective.offset_left = 40
	objective.offset_top = 32
	objective.modulate.a = 0.0
	root.add_child(objective)


func set_objective(text: String) -> void:
	if _obj_tw:
		_obj_tw.kill()
	_obj_tw = create_tween()
	if text == "":
		_obj_tw.tween_property(objective, "modulate:a", 0.0, 0.6)
		return
	_obj_tw.tween_property(objective, "modulate:a", 0.0, 0.25)
	_obj_tw.tween_callback(_set_objective_text.bind(text))
	_obj_tw.tween_property(objective, "modulate:a", 1.0, 0.8)


func _set_objective_text(text: String) -> void:
	objective.text = "◆  " + text


func set_timer(text: String, urgent := false) -> void:
	## a second line under the objective: a countdown, a tally of photographs
	if timer_label == null:
		timer_label = _label("", 19, Color(BONE, 0.85), serif_italic)
		_shadow(timer_label)
		timer_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		timer_label.offset_left = 64
		timer_label.offset_top = 64
		root.add_child(timer_label)
	timer_label.text = text
	timer_label.visible = text != ""
	timer_label.add_theme_color_override("font_color", Color("e0a070") if urgent else Color(BONE, 0.85))


# ------------------------------------------------------------------ subtitles
func _build_subtitles() -> void:
	sub_box = VBoxContainer.new()
	sub_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub_box.offset_bottom = -150
	sub_box.offset_top = -150
	sub_box.alignment = BoxContainer.ALIGNMENT_END
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_box.add_theme_constant_override("separation", 2)
	sub_name = _label("", 19, BRASS.lightened(0.2), caps)
	sub_line = _label("", 27, BONE, serif)
	sub_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_line.custom_minimum_size = Vector2(1000, 0)
	for l in [sub_name, sub_line]:
		_shadow(l, 0.95)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_box.add_child(sub_name)
	sub_box.add_child(sub_line)
	sub_box.modulate.a = 0.0
	root.add_child(sub_box)


func say(speaker: String, line: String, seconds := -1.0) -> float:
	## Shows a line of dialogue. Returns how long it stays up, so callers can await it.
	if seconds < 0.0:
		seconds = clampf(1.6 + line.length() * 0.055, 2.4, 9.0)
	sub_name.text = speaker.to_upper()
	sub_name.visible = speaker != ""
	sub_line.text = line
	_center(sub_box)
	sub_box.position.y = root.size.y - 150.0 - sub_box.size.y
	if _sub_tw:
		_sub_tw.kill()
	sub_box.modulate.a = 1.0
	_sub_tw = create_tween()
	_sub_tw.tween_interval(seconds)
	_sub_tw.tween_property(sub_box, "modulate:a", 0.0, 0.35)
	return seconds + 0.35


func clear_subtitle() -> void:
	if _sub_tw:
		_sub_tw.kill()
	sub_box.modulate.a = 0.0


# ------------------------------------------------------------------ letterbox
func _build_bars() -> void:
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.anchor_left = 0.0
		r.anchor_right = 1.0
		if top:
			r.anchor_top = 0.0
			r.anchor_bottom = 0.0
		else:
			r.anchor_top = 1.0
			r.anchor_bottom = 1.0
		root.add_child(r)
		bars.append(r)


func letterbox(on: bool, seconds := 0.8) -> void:
	var h := get_viewport().get_visible_rect().size.y * 0.11 if on else 0.0
	for i in bars.size():
		var r: ColorRect = bars[i]
		var tw := create_tween()
		if i == 0:
			tw.tween_property(r, "offset_bottom", h, seconds)
		else:
			tw.tween_property(r, "offset_top", -h, seconds)


# ------------------------------------------------------------------ chapter card
func _build_card() -> void:
	card = VBoxContainer.new()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 12)
	card_title = _label("", 50, BONE, caps)
	card_sub = _label("", 26, Color(BONE, 0.85), fell_italic)
	for l in [card_title, card_sub]:
		_shadow(l)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(card_title)
	card.add_child(_rule(520))
	card.add_child(card_sub)
	card.modulate.a = 0.0
	root.add_child(card)


func show_card(title: String, sub: String, seconds := 4.5) -> float:
	## A title card, usually over black between scenes. Returns total time.
	card_title.text = title.to_upper()
	card_sub.text = sub
	card.reset_size()
	card.position = (root.size - card.size) / 2.0
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 1.2)
	tw.tween_interval(seconds)
	tw.tween_property(card, "modulate:a", 0.0, 1.2)
	return seconds + 2.4


# ------------------------------------------------------------------ prompt
func _build_prompt() -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.02, 0.62)
	sb.content_margin_left = 34
	sb.content_margin_right = 38
	sb.content_margin_top = 7
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := PanelContainer.new()
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0, 0, 0, 0.0)
	ks.border_color = BRASS
	ks.set_border_width_all(1)
	ks.set_corner_radius_all(3)
	ks.content_margin_left = 9
	ks.content_margin_right = 9
	ks.content_margin_top = 0
	ks.content_margin_bottom = 1
	key.add_theme_stylebox_override("panel", ks)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(_label("E", 19, BRASS.lightened(0.25), caps))
	h.add_child(key)
	prompt_label = _label("", 24, BONE, serif)
	h.add_child(prompt_label)
	bg.add_child(h)
	box.add_child(_rule(460, Color(BRASS, 0.75)))
	box.add_child(bg)
	box.add_child(_rule(460, Color(BRASS, 0.75)))
	box.visible = false
	prompt_box = box
	root.add_child(box)


func set_prompt(text: String) -> void:
	if text == "":
		prompt_box.visible = false
		return
	if prompt_label.text != text or not prompt_box.visible:
		prompt_label.text = text
		prompt_box.reset_size()
		prompt_box.position = Vector2((root.size.x - prompt_box.size.x) / 2.0, root.size.y - 80.0 - prompt_box.size.y)
	prompt_box.visible = true


func _build_mouse_hint() -> void:
	mouse_hint = _label("Click to look around", 20, BONE, serif_italic)
	_shadow(mouse_hint)
	mouse_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mouse_hint.offset_top = 24
	mouse_hint.visible = false
	root.add_child(mouse_hint)


# ------------------------------------------------------------------ sneak eye
func _build_eye() -> void:
	eye = Control.new()
	eye.set_script(preload("res://scripts/sneak_eye.gd"))
	eye.custom_minimum_size = Vector2(120, 60)
	eye.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	eye.offset_left = -60
	eye.offset_right = 60
	eye.offset_top = -330
	eye.offset_bottom = -270
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye.visible = false
	root.add_child(eye)


func set_sneak(on: bool, detection := 0.0) -> void:
	eye.visible = on
	if on:
		eye.set("detection", detection)


# ------------------------------------------------------------------ reading panel
func _paper_box() -> StyleBox:
	var tex: Texture2D = load("res://textures/paper_albedo.jpg")
	if tex != null:
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.modulate_color = Color(1.0, 0.97, 0.9)
		st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		st.content_margin_left = 44
		st.content_margin_right = 44
		st.content_margin_top = 32
		st.content_margin_bottom = 28
		return st
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 32
	sb.content_margin_bottom = 28
	return sb


func _frame(inner: Control) -> PanelContainer:
	# a dark leather edge around the parchment
	var outer := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a120c")
	sb.border_color = BRASS.darkened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 36
	outer.add_theme_stylebox_override("panel", sb)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _paper_box())
	outer.add_child(paper)
	paper.add_child(inner)
	return outer


func _build_panel() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel = _frame(v)
	panel_title = _label("", 34, GREEN, caps)
	v.add_child(panel_title)
	var r := _rule(300, Color(BRASS.darkened(0.3), 0.9))
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(r)
	panel_body = RichTextLabel.new()
	panel_body.bbcode_enabled = true
	panel_body.fit_content = true
	panel_body.scroll_active = false
	panel_body.custom_minimum_size = Vector2(700, 0)
	panel_body.add_theme_font_override("normal_font", serif)
	panel_body.add_theme_font_override("italics_font", serif_italic)
	panel_body.add_theme_font_override("bold_font", serif_bold)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size"]:
		panel_body.add_theme_font_size_override(k, 24)
	panel_body.add_theme_color_override("default_color", INK)
	panel_body.add_theme_constant_override("line_separation", 4)
	v.add_child(panel_body)

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	var btn := _button("Close   Esc")
	btn.pressed.connect(close_panel)
	h.add_child(btn)
	v.add_child(h)
	panel.visible = false
	root.add_child(panel)


func show_panel(title: String, body: String) -> void:
	panel_title.text = title
	panel_body.text = body
	panel.visible = true
	panel.modulate.a = 0.0
	call_deferred("_fit", panel)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)


func close_panel() -> void:
	if not panel.visible and not gb_panel.visible:
		return
	panel.visible = false
	gb_panel.visible = false
	panel_closed.emit()


func fade_to(alpha: float, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", alpha, seconds)
	return tw


func _field_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.45)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _style_field(c: Control) -> void:
	c.add_theme_font_override("font", serif)
	c.add_theme_font_size_override("font_size", 23)
	c.add_theme_color_override("font_color", INK)
	c.add_theme_stylebox_override("normal", _field_box())
	c.add_theme_stylebox_override("focus", _field_box())


func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", caps)
	btn.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("1a120c") if state != "hover" else Color("2e2016")
		bs.border_color = BRASS
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(2)
		bs.content_margin_left = 18
		bs.content_margin_right = 18
		bs.content_margin_top = 8
		bs.content_margin_bottom = 9
		btn.add_theme_stylebox_override(state, bs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, BONE)
	return btn


# ------------------------------------------------------------------ guest book
func _build_guestbook() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(700, 0)
	gb_panel = _frame(v)
	v.add_child(_label("The Guest Book", 34, GREEN, caps))
	var intro := _label("Everybody who comes through signs the book. Put your name down and say what brought you in.", 23, INK, serif)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	gb_name = LineEdit.new()
	gb_name.placeholder_text = "Your name"
	gb_name.max_length = 40
	_style_field(gb_name)
	gb_name.text_submitted.connect(_on_name_submitted)
	v.add_child(gb_name)
	gb_note = LineEdit.new()
	gb_note.placeholder_text = "A short note, then press Enter"
	gb_note.max_length = 280
	_style_field(gb_note)
	gb_note.text_submitted.connect(_on_note_submitted)
	v.add_child(gb_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	gb_status = _label("", 21, GREEN, serif_italic)
	gb_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gb_status)
	var sign_btn := _button("Sign the book")
	sign_btn.pressed.connect(_on_sign_pressed)
	var close_btn := _button("Close   Esc")
	close_btn.pressed.connect(close_panel)
	row.add_child(sign_btn)
	row.add_child(close_btn)
	v.add_child(row)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 240)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gb_entries = VBoxContainer.new()
	gb_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gb_entries.add_theme_constant_override("separation", 4)
	sc.add_child(gb_entries)
	v.add_child(sc)
	gb_panel.visible = false
	root.add_child(gb_panel)


func _on_name_submitted(_t: String) -> void:
	gb_note.grab_focus()


func _on_note_submitted(_t: String) -> void:
	_on_sign_pressed()


func show_guestbook(entries: Array) -> void:
	refresh_guestbook(entries)
	gb_note.text = ""
	gb_status.text = ""
	gb_panel.visible = true
	gb_panel.modulate.a = 0.0
	call_deferred("_fit", gb_panel)
	var tw := create_tween()
	tw.tween_property(gb_panel, "modulate:a", 1.0, 0.25)
	if gb_name.text.strip_edges() == "":
		gb_name.call_deferred("grab_focus")
	else:
		gb_note.call_deferred("grab_focus")


func is_guestbook_open() -> bool:
	return gb_panel.visible


func refresh_guestbook(entries: Array) -> void:
	for c in gb_entries.get_children():
		gb_entries.remove_child(c)
		c.queue_free()
	if entries.is_empty():
		gb_entries.add_child(_label("Fresh page. Be the first name in the book.", 21, INK, serif_italic))
		return
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var head := _label("%s     %s" % [String(e.get("name", "")), String(e.get("date", ""))], 22, GREEN, serif_bold)
		var body := _label(String(e.get("note", "")), 21, INK, serif)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(640, 0)
		gb_entries.add_child(head)
		gb_entries.add_child(body)
		gb_entries.add_child(HSeparator.new())


func _on_sign_pressed() -> void:
	var n := gb_name.text.strip_edges()
	var note := gb_note.text.strip_edges()
	if n == "":
		gb_status.text = "Put your name down first."
		gb_name.grab_focus()
		return
	if note == "":
		gb_status.text = "Add a short note, then sign."
		gb_note.grab_focus()
		return
	guest_signed.emit(n, note)
	gb_note.text = ""
	gb_status.text = "Signed. Thank you, %s." % n
	gb_note.grab_focus()


func is_open() -> bool:
	return panel.visible or gb_panel.visible


func play_chime() -> void:
	chime.play()


func _make_chime() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 1.8)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var v := (sin(TAU * 1318.5 * t) + 0.45 * sin(TAU * 1975.5 * t) + 0.2 * sin(TAU * 2637.0 * t)) * exp(-3.0 * t) * 0.4
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


var _toast: Label
var _toast_tw: Tween

func toast(text: String, seconds := 4.5) -> void:
	if _toast == null:
		_toast = _label("", 25, BONE, serif_italic)
		_shadow(_toast)
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(_toast)
	_toast.text = text
	_center(_toast)
	_toast.position.y = 70
	_toast.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(seconds)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 1.0)


func _on_meta(meta: Variant) -> void:
	link_clicked.emit(str(meta))


func update_panel(title: String, body: String) -> void:
	panel_title.text = title
	panel_body.text = body
	call_deferred("_fit", panel)


func _fit(c: Control) -> void:
	await get_tree().process_frame
	if c == panel:
		panel_body.fit_content = true
		panel_body.scroll_active = false
		panel_body.custom_minimum_size = Vector2(720, 0)
		c.reset_size()
		await get_tree().process_frame
		var max_h := c.get_parent_area_size().y * 0.88
		if c.size.y > max_h:
			var extra := c.size.y - panel_body.size.y
			panel_body.fit_content = false
			panel_body.scroll_active = true
			panel_body.custom_minimum_size = Vector2(720, max_h - extra)
	c.reset_size()
	c.position = (c.get_parent_area_size() - c.size) / 2.0
