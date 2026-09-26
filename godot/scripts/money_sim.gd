extends Control
## The Money Machine: a hands-on model of where money comes from.
## Four balance sheets (people, banks, Treasury, Fed) that always stay in balance.

signal closed

const PARCHMENT := Color("f1e7cf")
const INK := Color("1b1510")
const GREEN := Color("1d3a2b")
const BRASS := Color("b8904a")
const UP := "2f7a4a"
const DOWN := "8c2a1c"
const STEPS := ["Gold and goldsmiths", "Banks make money", "Spending and taxes", "The Federal Reserve", "Run the economy"]
const BORROWERS := [["a bakery on Main Street", "a new oven", 200.0], ["a family", "a used truck", 300.0], ["a beekeeper", "twenty new hives", 150.0], ["a lawn service", "a zero-turn mower", 250.0]]

var kids := false
var step := 0
var serif: SystemFont
var serif_b: SystemFont
var serif_i: SystemFont
var tab_buttons: Array = []
var kids_btn: Button
var story: RichTextLabel
var note: RichTextLabel
var action_box: VBoxContainer
var slider_box: VBoxContainer
var money_big: Label
var money_caption: Label
var cards: Dictionary = {}
var chart: MoneyChart
var run_btn: Button
var prev: Dictionary = {}

# gold era
var coins := 100.0
var vault := 0.0
var notes := 0.0

# modern economy (every move below keeps all four balance sheets balanced)
var h_dep := 500.0
var h_cash := 0.0
var h_loans := 0.0
var b_res := 500.0
var b_loans := 0.0
var b_bonds := 0.0
var t_tga := 0.0
var t_debt := 500.0
var f_bonds := 500.0
var loan_list: Array = []

# run the economy
var rate := 4.0
var deficit := 3.0
var fed_buying := false
var running := false
var month := 0
var tick_acc := 0.0
var price := 1.0
var hist: Array = []
var hist_loans: Array = []
var hist_debt: Array = []


class MoneyChart extends Control:
	var series: Array = []
	var font: Font
	var caption := ""

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), true)
		var r := Rect2(Vector2(64, 12), size - Vector2(76, 44))
		var ax := Color(0, 0, 0, 0.35)
		draw_line(Vector2(r.position.x, r.end.y), r.end, ax, 1.0)
		draw_line(r.position, Vector2(r.position.x, r.end.y), ax, 1.0)
		var maxv := 1.0
		var n := 2
		for s in series:
			var d: Array = s["data"]
			n = maxi(n, d.size())
			for v in d:
				maxv = maxf(maxv, float(v))
		maxv *= 1.12
		for s in series:
			var d: Array = s["data"]
			if d.size() < 2:
				continue
			var pts := PackedVector2Array()
			for i in d.size():
				var x := r.position.x + r.size.x * float(i) / float(n - 1)
				var y := r.position.y + r.size.y * (1.0 - float(d[i]) / maxv)
				pts.append(Vector2(x, y))
			draw_polyline(pts, s["color"], 2.5, true)
		if font == null:
			return
		var ink := Color(0.1, 0.08, 0.06, 0.8)
		draw_string(font, Vector2(6, r.position.y + 12), "$" + str(int(maxv)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		draw_string(font, Vector2(6, r.end.y), "$0", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		var lx := r.position.x + 4.0
		for s in series:
			var nm := String(s["name"])
			draw_rect(Rect2(Vector2(lx, size.y - 20), Vector2(16, 5)), s["color"])
			draw_string(font, Vector2(lx + 22, size.y - 13), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
			lx += 40.0 + font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		if caption != "":
			var cw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, Vector2(r.end.x - 4 - cw, size.y - 13), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)


# ---------------- layout ----------------
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var names := PackedStringArray(["Georgia", "Garamond", "Palatino Linotype", "Times New Roman", "serif"])
	serif = SystemFont.new()
	serif.font_names = names
	serif_b = SystemFont.new()
	serif_b.font_names = names
	serif_b.font_weight = 700
	serif_i = SystemFont.new()
	serif_i.font_names = names
	serif_i.font_italic = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 36
	frame.offset_top = 26
	frame.offset_right = -36
	frame.offset_bottom = -26
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = BRASS
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	frame.add_child(outer)
	var head := HBoxContainer.new()
	head.add_child(_lbl("The Money Machine", 36, GREEN, serif))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	kids_btn = _btn("Kids mode", true)
	kids_btn.toggled.connect(_on_kids)
	head.add_child(kids_btn)
	var close_btn := _btn("Close   Esc")
	close_btn.pressed.connect(close_machine)
	head.add_child(close_btn)
	outer.add_child(head)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for i in STEPS.size():
		var b := _btn("%d. %s" % [i + 1, STEPS[i]], true)
		b.pressed.connect(set_step.bind(i, true))
		tabs.add_child(b)
		tab_buttons.append(b)
	outer.add_child(tabs)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 26)
	outer.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	scroll.add_child(left)
	story = _rtl(19)
	left.add_child(story)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 8)
	left.add_child(action_box)
	slider_box = VBoxContainer.new()
	slider_box.add_theme_constant_override("separation", 6)
	left.add_child(slider_box)
	note = _rtl(18)
	left.add_child(note)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	money_caption = _lbl("", 18, INK, serif_i)
	right.add_child(money_caption)
	money_big = _lbl("", 46, Color("2f7a4a"), serif_b)
	right.add_child(money_big)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	right.add_child(grid)
	for key in ["people", "banks", "treasury", "fed"]:
		var card := PanelContainer.new()
		var cb := StyleBoxFlat.new()
		cb.bg_color = Color(1, 1, 1, 0.55)
		cb.border_color = Color(0, 0, 0, 0.18)
		cb.set_border_width_all(1)
		cb.set_corner_radius_all(4)
		cb.content_margin_left = 14
		cb.content_margin_right = 14
		cb.content_margin_top = 10
		cb.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", cb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rt := _rtl(16)
		rt.custom_minimum_size = Vector2(290, 0)
		card.add_child(rt)
		grid.add_child(card)
		cards[key] = rt
	chart = MoneyChart.new()
	chart.font = serif
	chart.custom_minimum_size = Vector2(0, 190)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(chart)
	set_step(step, true)


func _lbl(text: String, fsize: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	return l


func _rtl(fsize: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("normal_font", serif)
	r.add_theme_font_override("bold_font", serif_b)
	r.add_theme_font_override("italics_font", serif_i)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		r.add_theme_font_size_override(k, fsize)
	r.add_theme_color_override("default_color", INK)
	return r


func _btn(text: String, toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.add_theme_font_override("font", serif)
	b.add_theme_font_size_override("font_size", 17)
	var styles := {"normal": Color(1, 1, 1, 0.5), "hover": Color(1, 1, 1, 0.8), "pressed": GREEN, "hover_pressed": GREEN.lightened(0.12), "focus": Color(0, 0, 0, 0)}
	for k in styles:
		var s := StyleBoxFlat.new()
		s.bg_color = styles[k]
		s.border_color = GREEN
		s.set_border_width_all(0 if k == "focus" else 1)
		s.set_corner_radius_all(4)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 7
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(k, s)
	b.add_theme_color_override("font_color", GREEN)
	b.add_theme_color_override("font_hover_color", GREEN)
	b.add_theme_color_override("font_pressed_color", PARCHMENT)
	b.add_theme_color_override("font_hover_pressed_color", PARCHMENT)
	b.add_theme_color_override("font_focus_color", GREEN)
	return b


func _action(text: String, cb: Callable) -> void:
	var b := _btn(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	action_box.add_child(b)


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func close_machine() -> void:
	running = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_machine()
		get_viewport().set_input_as_handled()


func _on_kids(on: bool) -> void:
	kids = on
	set_step(step, false)


func _t(grown: String, kid: String) -> String:
	return kid if kids else grown


# ---------------- numbers ----------------
func _m(v: float) -> String:
	var n := int(round(v))
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if neg else "$") + s + out


func _v(key: String, value: float) -> String:
	var txt := _m(value)
	if prev.has(key):
		var before: float = prev[key]
		if value > before + 0.5:
			return "[color=#%s][b]%s  +%s[/b][/color]" % [UP, txt, _m(value - before).substr(1)]
		if value < before - 0.5:
			return "[color=#%s][b]%s  -%s[/b][/color]" % [DOWN, txt, _m(before - value).substr(1)]
	return txt


func _snapshot() -> void:
	prev = {"coins": coins, "vault": vault, "notes": notes, "h_dep": h_dep, "h_cash": h_cash, "h_loans": h_loans,
		"b_res": b_res, "b_loans": b_loans, "b_bonds": b_bonds, "t_tga": t_tga, "t_debt": t_debt, "f_bonds": f_bonds}


func money() -> float:
	if step == 0:
		return coins + notes
	return h_dep + h_cash


func _do(msg: String, fn: Callable = Callable()) -> void:
	_snapshot()
	if fn.is_valid():
		fn.call()
	note.text = "[i]" + msg + "[/i]"
	_record()
	_refresh()


# ---------------- the moves ----------------
func _lend(x: float) -> void:
	b_loans += x
	h_loans += x
	h_dep += x


func _repay(x: float) -> void:
	x = minf(x, minf(h_loans, h_dep))
	b_loans -= x
	h_loans -= x
	h_dep -= x


func _gov_borrow_and_spend(x: float) -> void:
	# the Treasury sells a bond to a bank for reserves, then spends it into someone's account
	b_bonds += x
	t_debt += x
	h_dep += x


func _tax(x: float) -> void:
	x = minf(x, minf(h_dep, b_res))
	h_dep -= x
	b_res -= x
	t_tga += x


func _gov_spend_from_taxes(x: float) -> void:
	x = minf(x, t_tga)
	t_tga -= x
	b_res += x
	h_dep += x


func _fed_buy(x: float) -> void:
	x = minf(x, b_bonds)
	f_bonds += x
	b_bonds -= x
	b_res += x


func _withdraw_cash(x: float) -> void:
	x = minf(x, minf(h_dep, b_res))
	h_dep -= x
	b_res -= x
	h_cash += x


func _deposit_cash(x: float) -> void:
	x = minf(x, h_cash)
	h_cash -= x
	h_dep += x
	b_res += x


func _dig() -> void:
	coins += 20.0


func _lend_notes() -> void:
	notes += 100.0


func _gold_deposit_apply() -> void:
	coins -= 50.0
	vault += 50.0
	notes += 50.0


func _gold_pay_all() -> void:
	coins += notes
	vault -= notes
	notes = 0.0


func _gold_run_apply() -> void:
	var short := notes - vault
	coins += vault
	vault = 0.0
	notes = short


func _reset_modern() -> void:
	h_dep = 500.0
	h_cash = 0.0
	h_loans = 0.0
	b_res = 500.0
	b_loans = 0.0
	b_bonds = 0.0
	t_tga = 0.0
	t_debt = 500.0
	f_bonds = 500.0
	loan_list.clear()
	month = 0
	price = 1.0
	running = false
	prev = {}


# ---------------- steps ----------------
func set_step(i: int, reset := true) -> void:
	step = i
	for k in tab_buttons.size():
		(tab_buttons[k] as Button).set_pressed_no_signal(k == step)
	kids_btn.set_pressed_no_signal(kids)
	_clear(action_box)
	_clear(slider_box)
	if reset:
		note.text = ""
		prev = {}
		hist.clear()
		hist_loans.clear()
		hist_debt.clear()
		if step == 0:
			coins = 100.0
			vault = 0.0
			notes = 0.0
		else:
			_reset_modern()
			if step == 3:
				_gov_borrow_and_spend(200.0)
	match step:
		0:
			story.text = _t(
				"Before paper money, people paid with gold and silver coins. There was only as much money as metal people could dig up.\n\nCoins are heavy and easy to steal, so folks left their gold with the goldsmith and carried his paper [b]notes[/b] instead. Each note said: bring this back and I'll hand you your gold.\n\nThe goldsmith noticed people almost never came back for their gold all at once. So he started lending out extra notes, more notes than he had gold. Try it, then see what happens when everybody wants their gold back.",
				"A long time ago, money was gold coins. The only way to get more money was to dig up more gold.\n\nGold is heavy, so people left it with the goldsmith and carried a paper note instead. The note said: 'bring this back and get your gold.'\n\nThe goldsmith got sneaky. He wrote extra notes and lent them out, even though he didn't have gold for them. What happens if everybody wants their gold back at once?")
			_action("Dig up 20 more gold coins", _act_dig)
			_action("Leave 50 gold coins with the goldsmith", _gold_deposit)
			_action("The goldsmith lends out 100 in notes", _act_lend_notes)
			_action("Everybody wants their gold back", _gold_run)
		1:
			story.text = _t(
				"This is how most money is made today. You're a bank in a small town. People have $500 on deposit, and you hold $500 of reserves.\n\nWhen you make a loan, you don't hand over anybody's savings. You write two new lines at once: the loan, which the borrower owes you, and a brand new deposit in the borrower's account. That deposit is new money they can spend.\n\nWhen the loan is paid back, both lines come off the books, and that money is gone.",
				"You are the bank! People have $500 saved with you.\n\nWhen you give someone a loan, you don't take anybody's savings. You just type new money into the borrower's account. That's brand new money.\n\nWhen they pay it back, that money disappears.")
			_action("Make a loan", _bank_lend)
			_action("Repay the oldest loan", _bank_repay)
			_action("Start over", set_step.bind(1, true))
		2:
			story.text = _t(
				"The government pays for roads, schools, and the Coast Guard. When it spends more than it collects in taxes, that's a [b]deficit[/b], and it covers the difference by selling [b]bonds[/b], which are IOUs that pay interest.\n\nWatch all four balance sheets. The Treasury sells a bond to a bank, then spends the money. It lands in somebody's account as a brand new deposit.\n\nTaxes run the other way. Deposits go to the Treasury, and that money leaves people's hands.",
				"The government pays for roads and schools. If it spends more than it collects in taxes, it borrows by selling [b]bonds[/b], which are IOUs.\n\nWhen the government spends, the money shows up in people's bank accounts. When people pay taxes, money leaves their accounts.")
			_action("Build a bridge for $200 (borrowed)", _act_bridge)
			_action("Collect $100 in taxes", _act_tax)
			_action("Spend $100 of tax money on the school", _act_school)
		3:
			story.text = _t(
				"The Federal Reserve is the bank for banks. Banks keep accounts there called [b]reserves[/b], and they use them to pay each other. Reserves aren't money you or I can spend. They're the banks' money.\n\nWhen the Fed buys bonds, it pays by typing new reserves into a bank's account. That's the modern version of 'printing money,' and it's one way the Fed pushes interest rates down.\n\nPaper bills come from the Fed too, but only when people ask for them. Taking $50 out of the ATM doesn't create money. It just turns $50 of your deposit into $50 in your pocket.",
				"The Federal Reserve is the bank for banks. Banks keep their own money there, called [b]reserves[/b].\n\nWhen the Fed buys bonds, it types brand new reserves into the banks' accounts.\n\nWhen you get cash from an ATM, you're not making new money. You're just moving it from the bank to your pocket.")
			_action("The Fed buys $100 of bonds", _fed_qe)
			_action("Take $50 out of the ATM", _act_atm)
			_action("Put $50 cash back in the bank", _act_redeposit)
		4:
			story.text = _t(
				"Now let it run for forty years. Every month, people and businesses borrow, pay loans down, and the government spends and taxes. Set the knobs, then press Start.\n\n[b]Interest rate[/b] is set by the Fed. Low rates mean more borrowing, and more new money. High rates slow it down.\n[b]Government deficit[/b] is how much more the government spends than it taxes each year.\n[b]Fed buying bonds[/b] adds reserves to banks.\n\nThe town makes about 2 percent more stuff each year here. When money grows faster than that, prices drift up. This is a toy model with made-up numbers, built to show which way things move, not to predict anything.",
				"Let the town run for forty years! Pick the knobs, then press Start.\n\n[b]Interest rate:[/b] low rates mean lots of borrowing and lots of new money.\n[b]Deficit:[/b] how much extra the government spends.\n\nWatch what happens to prices when money grows fast. This is a pretend town with made-up numbers.")
			_slider("Interest rate", 0.0, 10.0, 0.25, rate, "%.2f%%", _set_rate)
			_slider("Government deficit, per year", -2.0, 8.0, 0.5, deficit, "%.1f%% of money", _set_deficit)
			var cbx := CheckBox.new()
			cbx.text = "The Fed is buying bonds"
			cbx.button_pressed = fed_buying
			cbx.add_theme_font_override("font", serif)
			cbx.add_theme_font_size_override("font_size", 17)
			cbx.add_theme_color_override("font_color", INK)
			cbx.add_theme_color_override("font_hover_color", INK)
			cbx.add_theme_color_override("font_pressed_color", INK)
			cbx.toggled.connect(_set_fed_buying)
			slider_box.add_child(cbx)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			run_btn = _btn("Start")
			run_btn.pressed.connect(_toggle_run)
			row.add_child(run_btn)
			var rb := _btn("Reset")
			rb.pressed.connect(set_step.bind(4, true))
			row.add_child(rb)
			action_box.add_child(row)
	_record()
	_refresh()


# ---------------- button handlers ----------------
func _act_dig() -> void:
	_do(_t("Twenty coins came out of the ground. That's slow, hard work, so money only grew as fast as the digging.", "You dug up 20 new coins. More gold means more money, but digging is hard work."), _dig)


func _act_lend_notes() -> void:
	_do(_t("No new gold came out of the ground. The goldsmith just wrote more notes and lent them. The town has 100 more money to spend, and the goldsmith is promising gold he doesn't have.", "The goldsmith wrote 100 new notes out of thin air and lent them out. Now there are more notes than gold in his vault!"), _lend_notes)


func _gold_deposit() -> void:
	if coins < 50.0:
		_do(_t("Folks don't have 50 coins in their pockets right now. Dig some up first.", "Not enough coins in pockets. Dig some up first!"))
		return
	_do(_t("Fifty coins went into the vault, and the goldsmith handed out 50 in notes. People trade the notes like money. Total money didn't change. It just got lighter to carry.", "50 coins went in the vault, and people got 50 in paper notes instead. Same amount of money, just easier to carry."), _gold_deposit_apply)


func _gold_run() -> void:
	if notes <= vault + 0.5:
		_do(_t("Everybody brought their notes back and every one got paid in gold. The goldsmith kept every promise, because he never lent more than he had.", "Everybody got their gold back. The goldsmith kept his promise!"), _gold_pay_all)
		return
	var short := notes - vault
	var owed := notes
	_do(_t("A RUN ON THE GOLDSMITH. People brought %s in notes, but the vault only held %s in gold. %s worth of notes can't be paid. The last folks in line get nothing. Runs like this are part of why governments later set up central banks, deposit insurance, and finally money that isn't tied to gold at all." % [_m(owed), _m(owed - short), _m(short)], "UH OH! Everybody wanted their gold, but the goldsmith only had gold for some of the notes. %s worth of notes can't be paid. That's called a bank run." % _m(short)), _gold_run_apply)


func _bank_lend() -> void:
	if loan_list.size() >= 5:
		_do(_t("Banks can't lend forever. Capital rules, and whether anybody wants to borrow, put a ceiling on it. Try paying one back.", "That's enough loans for now. Try paying one back."))
		return
	var b: Array = BORROWERS[loan_list.size() % BORROWERS.size()]
	var amt: float = b[2]
	loan_list.append(amt)
	_do(_t("You lent %s to %s for %s. Look at the banks: a new loan and a new deposit, the same size, at the same moment. Nobody's savings went down. The town has %s more money than it did a second ago." % [_m(amt), b[0], b[1], _m(amt)], "You lent %s to %s. You typed brand new money into their account. Nobody's savings went down!" % [_m(amt), b[0]]), _lend.bind(amt))


func _bank_repay() -> void:
	if loan_list.is_empty():
		_do(_t("Nobody owes the bank anything yet. Make a loan first.", "Nobody owes the bank yet. Make a loan first!"))
		return
	var amt: float = loan_list.pop_front()
	_do(_t("A %s loan was paid back. The loan and the deposit that paid it both came off the books, and that money stopped existing. Lending makes money. Paying it back unmakes it." % _m(amt), "A loan got paid back, so that money disappeared. Poof!"), _repay.bind(amt))


func _act_bridge() -> void:
	_do(_t("The Treasury sold a $200 bond to a bank and paid the bridge builders. Their accounts went up by $200. There's $200 more money in town, and the government owes $200 more.", "The government borrowed $200 and paid the bridge builders. Now there's $200 more money in town."), _gov_borrow_and_spend.bind(200.0))


func _act_tax() -> void:
	_do(_t("People paid $100 in taxes. Their deposits dropped, and that money moved to the Treasury's account at the Fed, out of the town's hands.", "People paid $100 in taxes, so there's $100 less money in town."), _tax.bind(100.0))


func _act_school() -> void:
	_do(_t("The Treasury spent tax money it already had. It flowed back into people's accounts. Nothing new was borrowed.", "The government spent tax money on the school, and it went back into people's accounts."), _gov_spend_from_taxes.bind(100.0))


func _fed_qe() -> void:
	if b_bonds < 1.0:
		_do(_t("The banks don't hold any bonds right now, so there's nothing for the Fed to buy. The Fed isn't allowed to buy bonds straight from the Treasury. It buys them from banks and dealers.", "The banks don't have any bonds to sell right now."))
		return
	_do(_t("The Fed bought bonds from the banks and paid with brand new reserves. Look closely: bank reserves went up, but the money people can spend didn't move. It changes what banks hold and pushes interest rates down, which can lead to more lending later.", "The Fed bought bonds and gave the banks new reserves. The banks have more money now, but people's accounts didn't change."), _fed_buy.bind(100.0))


func _act_atm() -> void:
	_do(_t("Your deposit went down $50 and your pocket went up $50. The bank handed over $50 of its reserves as paper bills. Total money didn't change, only its form.", "You took out $50. Your bank account went down and your pocket went up. Same money, different place."), _withdraw_cash.bind(50.0))


func _act_redeposit() -> void:
	_do(_t("The cash went back to the bank and became a deposit again. Still the same amount of money.", "You put the $50 back. Still the same money."), _deposit_cash.bind(50.0))


# ---------------- run the economy ----------------
func _set_rate(v: float) -> void:
	rate = v


func _set_deficit(v: float) -> void:
	deficit = v


func _set_fed_buying(on: bool) -> void:
	fed_buying = on


func _slider(label: String, lo: float, hi: float, stp: float, value: float, fmt: String, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _lbl(label, 17, INK, serif)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = stp
	s.value = value
	s.custom_minimum_size = Vector2(200, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	var out := _lbl(fmt % value, 17, GREEN, serif_b)
	out.custom_minimum_size = Vector2(130, 0)
	row.add_child(out)
	s.value_changed.connect(_on_slider.bind(cb, out, fmt))
	slider_box.add_child(row)


func _on_slider(v: float, cb: Callable, out: Label, fmt: String) -> void:
	cb.call(v)
	out.text = fmt % v


func _toggle_run() -> void:
	if month >= 480:
		set_step(4, true)
	running = not running
	run_btn.text = "Pause" if running else "Start"


func _process(delta: float) -> void:
	if not running or step != 4:
		return
	tick_acc += delta
	while tick_acc > 0.05 and running:
		tick_acc -= 0.05
		_month()


func _month() -> void:
	_snapshot()
	var m0 := money()
	var yearly_new := maxf(0.0, 0.10 - 0.011 * rate)
	_lend(m0 * yearly_new / 12.0)
	_repay(h_loans * 0.09 / 12.0)
	var d := m0 * deficit / 100.0 / 12.0
	if d >= 0.0:
		_gov_borrow_and_spend(d)
	else:
		_tax(-d)
	if fed_buying:
		_fed_buy(b_bonds * 0.2 / 12.0)
	month += 1
	var m1 := money()
	var growth := (m1 - m0) / maxf(m0, 1.0)
	price *= 1.0 + maxf(-0.002, growth - 0.02 / 12.0) * 0.85
	if month % 3 == 0:
		_record()
	if month >= 480:
		running = false
		run_btn.text = "Run it again"
		note.text = "[i]" + _t("Forty years went by. Money in town went from $500 to %s, and prices are about %.1f times what they were. Try a higher interest rate or a smaller deficit and run it again." % [_m(m1), price], "Forty years went by! Prices are about %.1f times higher than when you started. Try different knobs and run it again." % price) + "[/i]"
	_refresh()


func _record() -> void:
	if step == 0:
		hist.append(coins + notes)
	else:
		hist.append(h_dep + h_cash)
		hist_loans.append(h_loans)
		hist_debt.append(t_debt)


# ---------------- drawing the numbers ----------------
func _refresh() -> void:
	money_caption.text = _t("Money people can spend", "Money in town")
	if step == 0:
		money_caption.text = _t("Money in town: coins plus notes", "Money in town: coins and notes")
	money_big.text = _m(money())
	if step == 4:
		money_big.text = "%s     Year %d     Prices x%.2f" % [_m(money()), month / 12, price]
	if step == 0:
		cards["people"].text = "[b]People[/b]\n%s  %s\n%s  %s" % [_t("Gold coins in pockets", "Gold coins"), _v("coins", coins), _t("Goldsmith notes", "Paper notes"), _v("notes", notes)]
		var short := maxf(0.0, notes - vault)
		var warn := ""
		if short > 0.5:
			warn = "\n[color=#%s][b]Short by %s[/b][/color]" % [DOWN, _m(short)]
		cards["banks"].text = "[b]The goldsmith[/b]\n%s  %s\n%s  %s%s" % [_t("Gold in the vault", "Gold in the vault"), _v("vault", vault), _t("Notes he promised to pay", "Notes promised"), _v("notes", notes), warn]
		cards["treasury"].text = "[b]The Treasury[/b]\n[i]%s[/i]" % _t("No paper dollars yet. Gold and silver are the money.", "Not invented yet!")
		cards["fed"].text = "[b]The Federal Reserve[/b]\n[i]%s[/i]" % _t("Not founded until 1913, three years after the meeting at Jekyll Island.", "Not invented yet! It started in 1913.")
		chart.series = [{"data": hist, "color": Color("2f7a4a"), "name": "Money in town"}]
		chart.caption = ""
	else:
		cards["people"].text = "[b]%s[/b]\n%s  %s\n%s  %s\n%s  %s" % [_t("People and businesses", "People"), _t("In the bank", "In the bank"), _v("h_dep", h_dep), _t("Cash in pockets", "Cash in pockets"), _v("h_cash", h_cash), _t("Owe on loans", "Owe the bank"), _v("h_loans", h_loans)]
		cards["banks"].text = "[b]%s[/b]\n[i]%s[/i]  %s %s,  %s %s,  %s %s\n[i]%s[/i]  %s %s" % [_t("Banks", "The bank"), _t("own", "has"), _t("reserves", "vault money"), _v("b_res", b_res), _t("loans", "IOUs"), _v("b_loans", b_loans), _t("bonds", "bonds"), _v("b_bonds", b_bonds), _t("owe", "owes"), _t("deposits", "people's money"), _v("h_dep", h_dep)]
		cards["treasury"].text = "[b]%s[/b]\n%s  %s\n%s  %s" % [_t("The Treasury", "The government"), _t("Tax money on hand", "Tax money"), _v("t_tga", t_tga), _t("Bonds it owes", "IOUs it owes"), _v("t_debt", t_debt)]
		cards["fed"].text = "[b]%s[/b]\n[i]%s[/i]  %s %s\n[i]%s[/i]  %s %s,  %s %s,  %s %s" % [_t("The Federal Reserve", "The Fed"), _t("owns", "has"), _t("bonds", "bonds"), _v("f_bonds", f_bonds), _t("owes", "owes"), _t("bank reserves", "banks"), _v("b_res", b_res), _t("paper cash", "cash"), _v("h_cash", h_cash), _t("Treasury account", "government"), _v("t_tga", t_tga)]
		chart.series = [{"data": hist, "color": Color("2f7a4a"), "name": _t("Money people can spend", "Money")}]
		if step != 3:
			chart.series.append({"data": hist_loans, "color": Color("2d568a"), "name": _t("Bank loans", "Loans")})
		if step >= 2:
			chart.series.append({"data": hist_debt, "color": Color("8c2a1c"), "name": _t("Government bonds", "Government IOUs")})
		chart.caption = ("Year %d" % (month / 12)) if step == 4 else ""
	chart.queue_redraw()
