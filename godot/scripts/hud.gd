extends CanvasLayer
## On-screen interface: title card, "press E" prompt, reading panels, fades.

signal panel_closed
signal link_clicked(meta: String)
signal guest_signed(guest_name: String, note: String)

const PARCHMENT := Color("f1e7cf")
const INK := Color("1b1510")
const GREEN := Color("1d3a2b")
const BRASS := Color("b8904a")

var serif: SystemFont
var serif_italic: SystemFont
var serif_bold: SystemFont
var prompt_box: PanelContainer
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


func _ready() -> void:
	layer = 10
	var names := PackedStringArray(["Georgia", "Garamond", "Palatino Linotype", "Times New Roman", "serif"])
	serif = SystemFont.new()
	serif.font_names = names
	serif_italic = SystemFont.new()
	serif_italic.font_names = names
	serif_italic.font_italic = true
	serif_bold = SystemFont.new()
	serif_bold.font_names = names
	serif_bold.font_weight = 700

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_title(root)
	_build_prompt(root)
	_build_mouse_hint(root)
	_build_panel(root)
	panel_body.meta_clicked.connect(_on_meta)
	_build_guestbook(root)
	chime = AudioStreamPlayer.new()
	chime.stream = _make_chime()
	chime.volume_db = -6.0
	add_child(chime)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
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


func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 10)


func _build_title(root: Control) -> void:
	title_card = VBoxContainer.new()
	title_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	title_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	title_card.offset_left = 60
	title_card.offset_top = -70
	title_card.offset_bottom = -70
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.add_theme_constant_override("separation", 2)
	var sub := _label("Picayune, Mississippi", 26, Color(0.95, 0.9, 0.8, 0.9), serif_italic)
	var main := _label("The Jekyll Island Club", 68, PARCHMENT, serif)
	var help := _label("W A S D to walk.  Shift to run.  Mouse to look.  E to use what's in front of you.  R if you get stuck.", 18, Color(0.95, 0.9, 0.8, 0.85), serif)
	for l in [sub, main, help]:
		_shadow(l)
		title_card.add_child(l)
	title_card.modulate.a = 0.0
	root.add_child(title_card)


func show_title() -> void:
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(title_card, "modulate:a", 1.0, 1.4)
	tw.tween_interval(6.5)
	tw.tween_property(title_card, "modulate:a", 0.0, 2.0)


func _build_prompt(root: Control) -> void:
	prompt_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	sb.border_color = BRASS
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 10
	sb.content_margin_right = 20
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	prompt_box.add_theme_stylebox_override("panel", sb)
	prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_box.offset_top = -70
	prompt_box.offset_bottom = -70
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := PanelContainer.new()
	var ks := StyleBoxFlat.new()
	ks.bg_color = BRASS
	ks.set_corner_radius_all(6)
	ks.content_margin_left = 10
	ks.content_margin_right = 10
	ks.content_margin_top = 1
	ks.content_margin_bottom = 2
	key.add_theme_stylebox_override("panel", ks)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(_label("E", 20, INK, serif_bold))
	h.add_child(key)
	prompt_label = _label("", 22, PARCHMENT, serif_italic)
	h.add_child(prompt_label)
	prompt_box.add_child(h)
	prompt_box.visible = false
	root.add_child(prompt_box)


func set_prompt(text: String) -> void:
	if text == "":
		prompt_box.visible = false
		return
	if prompt_label.text != text:
		prompt_label.text = text
		prompt_box.reset_size()
	prompt_box.visible = true


func _build_mouse_hint(root: Control) -> void:
	mouse_hint = _label("Click to look around", 18, PARCHMENT, serif_italic)
	_shadow(mouse_hint)
	mouse_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mouse_hint.offset_top = 24
	mouse_hint.visible = false
	root.add_child(mouse_hint)


func _build_panel(root: Control) -> void:
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = BRASS
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 30
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	panel_title = _label("", 38, GREEN, serif)
	v.add_child(panel_title)
	panel_body = RichTextLabel.new()
	panel_body.bbcode_enabled = true
	panel_body.fit_content = true
	panel_body.scroll_active = false
	panel_body.custom_minimum_size = Vector2(660, 0)
	panel_body.add_theme_font_override("normal_font", serif)
	panel_body.add_theme_font_override("italics_font", serif_italic)
	panel_body.add_theme_font_override("bold_font", serif_bold)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size"]:
		panel_body.add_theme_font_size_override(k, 21)
	panel_body.add_theme_color_override("default_color", INK)
	panel_body.add_theme_constant_override("line_separation", 5)
	v.add_child(panel_body)

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	var btn := Button.new()
	btn.text = "Close   Esc"
	btn.add_theme_font_override("font", serif)
	btn.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = GREEN if state != "hover" else GREEN.lightened(0.15)
		bs.set_corner_radius_all(4)
		bs.content_margin_left = 18
		bs.content_margin_right = 18
		bs.content_margin_top = 8
		bs.content_margin_bottom = 9
		btn.add_theme_stylebox_override(state, bs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, PARCHMENT)
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


func _paper_box(radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = BRASS
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 30
	return sb


func _field_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.7)
	sb.border_color = Color(0, 0, 0, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _style_field(c: Control) -> void:
	c.add_theme_font_override("font", serif)
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", INK)
	c.add_theme_stylebox_override("normal", _field_box())
	c.add_theme_stylebox_override("focus", _field_box())


func _green_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", serif)
	btn.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = GREEN if state != "hover" else GREEN.lightened(0.15)
		bs.set_corner_radius_all(4)
		bs.content_margin_left = 18
		bs.content_margin_right = 18
		bs.content_margin_top = 8
		bs.content_margin_bottom = 9
		btn.add_theme_stylebox_override(state, bs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, PARCHMENT)
	return btn


func _build_guestbook(root: Control) -> void:
	gb_panel = PanelContainer.new()
	gb_panel.add_theme_stylebox_override("panel", _paper_box())
	gb_panel.set_anchors_preset(Control.PRESET_CENTER)
	gb_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gb_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(660, 0)
	gb_panel.add_child(v)
	v.add_child(_label("The guest book", 38, GREEN, serif))
	var intro := _label("Everybody who comes through signs the book. Put your name down and say what brought you in.", 20, INK, serif)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	gb_name = LineEdit.new()
	gb_name.placeholder_text = "Your name"
	gb_name.max_length = 40
	_style_field(gb_name)
	gb_name.text_submitted.connect(func(_t: String) -> void: gb_note.grab_focus())
	v.add_child(gb_name)
	gb_note = LineEdit.new()
	gb_note.placeholder_text = "A short note, then press Enter"
	gb_note.max_length = 280
	_style_field(gb_note)
	gb_note.text_submitted.connect(func(_t: String) -> void: _on_sign_pressed())
	v.add_child(gb_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	gb_status = _label("", 19, GREEN, serif_italic)
	gb_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gb_status)
	var sign_btn := _green_button("Sign the book")
	sign_btn.pressed.connect(_on_sign_pressed)
	var close_btn := _green_button("Close   Esc")
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
		gb_entries.add_child(_label("Fresh page. Be the first name in the book.", 19, INK, serif_italic))
		return
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var head := _label("%s     %s" % [String(e.get("name", "")), String(e.get("date", ""))], 20, GREEN, serif_bold)
		var body := _label(String(e.get("note", "")), 19, INK, serif)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(600, 0)
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
		_toast = _label("", 22, PARCHMENT, serif_italic)
		_shadow(_toast)
		_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast.offset_top = 70
		get_child(0).add_child(_toast)
	_toast.text = text
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
		panel_body.custom_minimum_size = Vector2(700, 0)
		c.reset_size()
		await get_tree().process_frame
		var max_h := c.get_parent_area_size().y * 0.88
		if c.size.y > max_h:
			var extra := c.size.y - panel_body.size.y
			panel_body.fit_content = false
			panel_body.scroll_active = true
			panel_body.custom_minimum_size = Vector2(700, max_h - extra)
	c.reset_size()
	c.position = (c.get_parent_area_size() - c.size) / 2.0
