extends Node
## The three rooms off the Grand Lobby: the Honey House, the Drafting Room and the Trading Floor.
## main.gd builds the level node and calls build_<room>(); everything you can use in the room
## is registered here with main.add_interactable().
##
## Trading Floor rule: journaling, psychology and accountability only. Never signals,
## setups, indicator logic or strategy. Honey: the owner still needs to confirm whether the
## cottage food law allows wholesale, so the shelf doesn't offer it yet.

const Markers := preload("res://scripts/markers.gd")

const LOBBY_FROM_TRADING := Vector3(-7.6, 0.1, -10.0)
const LOBBY_FROM_STUDIO := Vector3(7.6, 0.1, -4.0)
const LOBBY_FROM_HONEY := Vector3(7.6, 0.1, -10.0)

const SITES := {
	"roots": ["rootsbehavioralhealth.org", "Roots Behavioral Health", "Counseling and consulting. \"Helping you heal from the roots up.\""],
	"gogit": ["go-git-er.com", "Go-Git-Er", "Picayune's rideshare and delivery. Rides, groceries, parts and pickups, day or night."],
	"tinytides": ["tinytidesplayroom.netlify.app", "Tiny Tides Playroom", "An indoor play space in Long Beach, Mississippi, for babies, toddlers and young children."],
	"zv": ["zvautomotive.com", "ZV Automotive", "An owner-operated repair shop in Carriere, Mississippi. A straight answer before any work starts."],
	"prscms": ["prscms.org", "Pearl River Soccer Club", "Recreational youth soccer for Pearl River County, coached by volunteers."],
	"farm": ["40acrefarm.netlify.app", "40 Acre Farm", "Raw honey, 100% pure. Small batch, family owned."],
}

var main
var hud
var player
var level: Node3D
var marks := {}
var checkin := {}
var _hive_open := false
var _lid: Node3D
var _frame: Node3D
var _lid_home := Vector3.ZERO
var _frame_home := Vector3.ZERO


func _link(meta: String, text: String) -> String:
	return main._link(meta, text)


func _load(path: String) -> Node3D:
	var n: Node3D = main._instance(path)
	marks = Markers.dress(n, main)
	return n


func mk(name: String) -> Vector3:
	return (marks.get(name, Transform3D.IDENTITY) as Transform3D).origin


# ================================================================== the Honey House
func build_honey() -> void:
	main._air("honey")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	var root := _load("res://models/honey_house.glb")
	main._safety_floor()
	main._ambience("crickets")
	_lid = root.find_child("HiveLid", true, false) as Node3D
	_frame = root.find_child("HiveFrame", true, false) as Node3D
	if _lid:
		_lid_home = _lid.position
	if _frame:
		_frame_home = _frame.position
	_hive_open = false
	level.add_child(_bees(mk("hive") + Vector3(0, 0.9, -0.7)))
	main.add_interactable(mk("hy_spawn") + Vector3(0, 1.0, 0.6), 1.3, "Back to the lobby", main._exit_room.bind(LOBBY_FROM_HONEY, PI / 2.0))
	main.add_interactable(mk("hive") + Vector3(0, 1.0, 0), 1.6, "Open the hive and pull a frame", _open_hive)
	main.add_interactable(mk("jars") + Vector3(0, 1.0, 0), 1.9, "Look at the raw honey", _honey_shelf)
	main.add_interactable(mk("clipboard") + Vector3(0, 1.0, 0), 1.4, "Read the clipboard by the door", _bee_removal)
	main.add_interactable(mk("bench") + Vector3(0, 1.0, 0), 1.5, "Look over the work bench", _bench)


func _bees(p: Vector3) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.amount = 70
	ps.lifetime = 4.0
	ps.preprocess = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.9
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_noise_scale = 1.5
	pm.turbulence_influence_min = 0.3
	pm.turbulence_influence_max = 0.6
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.02)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2a2008")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	ps.draw_pass_1 = q
	ps.position = p
	return ps


func _open_hive() -> void:
	if main.busy:
		return
	main.busy = true
	player.enabled = false
	hud.set_prompt("")
	var cam := Camera3D.new()
	cam.fov = 45.0
	level.add_child(cam)
	cam.global_position = mk("hive_cam")
	cam.look_at(mk("hive_look"))
	cam.current = true
	hud.play_chime()
	if _lid and _frame:
		var tw := create_tween()
		tw.tween_property(_lid, "position", _lid_home + Vector3(0.45, 0.25, 0.0), 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.2)
		tw.tween_property(_frame, "position", _frame_home + Vector3(0.0, 0.42, 0.0), 1.4).set_trans(Tween.TRANS_SINE)
		await tw.finished
	await get_tree().create_timer(0.4).timeout
	main.busy = false
	main.open_panel("A frame of honey",
		"You lift the lid, puff a little smoke across the top bars, and ease one frame up out of the honey super. It's heavy.\n\n"
		+ "[b]What you're holding.[/b]  The pale caps are finished honey. The bees fanned the nectar down until it was thick enough to keep, then sealed each cell with wax. The open, shiny cells are still curing.\n\n"
		+ "[b]Who lives here.[/b]  One queen, tens of thousands of workers in the summer, and a few hundred drones. Every worker is female. The drones are males, and their one job is to mate with a queen from some other hive.\n\n"
		+ "[b]A worker's life.[/b]  In summer a worker lives about six weeks. She cleans cells, feeds the young, builds comb and guards the door, and only then flies out to forage. In her whole life she makes about a twelfth of a teaspoon of honey.\n\n"
		+ "[b]The queen.[/b]  A good queen can lay well over a thousand eggs a day in spring.\n\n"
		+ "[b]Why the smoke.[/b]  It covers up the alarm scent the guard bees give off, so the hive stays calm while you work.\n\n"
		+ "[b]A pound of honey[/b] takes a lot of flying. The colony visits something like two million flowers to make it.")
	main.panel_kind = "hive"
	main.after_panel = _close_hive.bind(cam)


func _close_hive(cam: Camera3D) -> void:
	if _lid and _frame:
		var tw := create_tween()
		tw.tween_property(_frame, "position", _frame_home, 1.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_lid, "position", _lid_home, 0.9).set_trans(Tween.TRANS_SINE)
	player.cam.current = true
	cam.queue_free()


func _honey_shelf() -> void:
	main.open_panel("Raw Honey",
		"[i]Jekyll's 40 Acre Farm[/i]\n\n"
		+ "[b]$15[/b] for a 16 oz jar.\n\n"
		+ "Harvested in Carriere, Mississippi. Raw, unfiltered, and never heated, so it tastes like whatever was blooming when the bees made it.\n\n"
		+ "[b]To order,[/b] call or text [b]601-569-3719[/b], or write [b]stikk2004@gmail.com[/b].\n\n"
		+ "[i]Made under the Mississippi Cottage Food Law. Not inspected by the Mississippi State Department of Health. Do not feed honey to children under one year old.[/i]\n\n"
		+ _link("url:https://40acrefarm.netlify.app", "Visit 40acrefarm.netlify.app"))


func _bee_removal() -> void:
	main.open_panel("Bee Removal",
		"Bees moved into a wall, an eave, a tree or a shed? We'll come get them out, alive when we can, and they'll get a new home out at the farm.\n\n"
		+ "Commercial jobs too: gas stations, storefronts, anywhere they've set up shop.\n\n"
		+ "Call or text [b]601-569-3719[/b].")


func _bench() -> void:
	main.open_panel("The work bench",
		"Frames waiting to be uncapped, the smoker, and a few jars already filled.\n\n"
		+ "The big steel drum is the extractor. You slice the wax caps off a frame, stand it in the basket, and spin it. The honey slings out against the wall of the drum, runs down to the bottom, and comes out the gate into a bucket. The comb goes back in the hive in one piece, so the bees don't have to build it over.\n\n"
		+ "That's all \"raw\" means here: spun out, strained through a coarse screen for the bits of wax, and put in a jar. No heat.")


# ================================================================== the Drafting Room
func build_studio() -> void:
	main._air("studio")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	_load("res://models/drafting_room.glb")
	main._safety_floor()
	main._ambience("room")
	main.add_interactable(mk("dr_spawn") + Vector3(0, 1.0, 0.6), 1.3, "Back to the lobby", main._exit_room.bind(LOBBY_FROM_STUDIO, PI / 2.0))
	for key in SITES.keys():
		var info: Array = SITES[key]
		main.add_interactable(mk("site_" + String(key)) + Vector3(0, 1.0, 0), 1.2, "Look at %s" % String(info[0]), _site.bind(String(key)))
	main.add_interactable(mk("pricing") + Vector3(0, 1.0, 0), 1.7, "Read the pricing board", _pricing)
	main.add_interactable(mk("drafting") + Vector3(0, 1.0, 0), 1.3, "Commission a draft", _commission)
	main.add_interactable(mk("drawer") + Vector3(0, 1.0, 0), 1.0, "Open the drawer marked 1997", _drawer)


func _site(key: String) -> void:
	var info: Array = SITES[key]
	main.open_panel(String(info[1]),
		"[i]%s[/i]\n\n%s\n\nBuilt by Jekyll Studio. The owner owns it outright.\n\n" % [String(info[0]), String(info[2])]
		+ _link("url:https://" + String(info[0]), "Open the live site in your browser"))


func _pricing() -> void:
	main.open_panel("Jekyll Studio: what it costs",
		"[b]$50 one time[/b] to set it up: the domain, the hosting, going live, and basic upkeep.\n\n"
		+ "[b]Plus a build fee[/b] that fits the work. A simple site runs about $200 to build, so about $250 all told.\n\n"
		+ "[b]A monthly plan,[/b] if you want one: $30 to $300 and up, depending on how much work it is each month. You don't have to take one.\n\n"
		+ "[b]You own your site outright.[/b] Nobody holds it hostage.\n\n"
		+ "Write [b]stikk2004@gmail.com[/b] or call [b](601) 569-3719[/b].")


func _commission() -> void:
	main.open_panel("Commission a draft",
		"Every site starts here, on paper, before a line of code.\n\n"
		+ "Tell us who you are, what you do, and what you want folks to do when they land on your page: call you, come by, buy something, sign up. We'll sketch it on this table, send you the draft, and build it once you like it.\n\n"
		+ "Write [b]stikk2004@gmail.com[/b] or call or text [b](601) 569-3719[/b].\n\n"
		+ _link("url:mailto:stikk2004@gmail.com?subject=Commission%20a%20draft", "Start an email"))


func _drawer() -> void:
	hud.play_chime()
	main.open_panel("~*~ Welcome to Jekyll's HomePage ~*~",
		"[center][color=#c0189a][b]!!! UNDER CONSTRUCTION !!![/b][/color]\n\n"
		+ "[color=#1a3aa8][u]Click here[/u][/color] to enter!!!\n\n"
		+ "You are visitor number [b]000417[/b]\n\n"
		+ "[i]Best viewed in Netscape Navigator 3.0 at 800 x 600[/i]\n\n"
		+ "<< Prev  |  [u]Random[/u]  |  Next >>   [i]a proud member of the Magnolia Webring[/i]\n\n"
		+ "[color=#1a3aa8][u]Sign my guestbook!![/u][/color]\n\n"
		+ "[i]Last updated August 1997[/i][/center]\n\n"
		+ "Somebody kept this in a drawer as a reminder. We've come a long way. Commission a draft and we'll build you something that loads before your coffee gets cold.")


# ================================================================== the Trading Floor
func build_trading() -> void:
	main._air("trading")
	RenderingServer.global_shader_parameter_set("ground_y", 0.0)
	_load("res://models/trading_floor.glb")
	main._safety_floor()
	main._ambience("room")
	checkin = {}
	main.add_interactable(mk("tf_spawn") + Vector3(0, 1.0, 0.6), 1.3, "Back to the lobby", main._exit_room.bind(LOBBY_FROM_TRADING, -PI / 2.0))
	main.add_interactable(mk("plaque") + Vector3(0, 1.0, 0), 1.8, "Read the plaque", _plaque)
	main.add_interactable(mk("checkin") + Vector3(0, 1.0, 0), 1.2, "Pre-market check-in", _checkin.bind("", ""))
	main.add_interactable(mk("door_leaderboard") + Vector3(0, 1.0, 0), 1.2, "The leaderboard", _members.bind("leaderboard"))
	main.add_interactable(mk("door_journal") + Vector3(0, 1.0, 0), 1.2, "The journal", _members.bind("journal"))
	main.add_interactable(mk("desks") + Vector3(0, 1.0, 0), 1.8, "Look at the screens", _screens)


func _plaque() -> void:
	main.open_panel("NO COURSE",
		"[i]Jekyll Island Trading[/i]\n\n"
		+ "This room is for the part of trading nobody sells you: keeping a journal, knowing your own head, and having somebody who'll ask whether you did what you said you'd do.\n\n"
		+ "[b]What gets shared here:[/b] journals, how the day felt, what you learned about yourself, and accountability.\n\n"
		+ "[b]What never does:[/b] signals, setups, strategy, or anything for sale. There is no course.\n\n"
		+ "The members meet in the Discord.")


func _checkin(q: String, a: String) -> void:
	if q != "":
		checkin[q] = a
	var body := "Before the open, check in with yourself. Be honest. Nobody else sees this.\n\n"
	var qs := [
		["sleep", "How'd you sleep?", [["good", "Good"], ["ok", "Okay"], ["poor", "Poorly"]]],
		["focus", "How's your focus?", [["sharp", "Sharp"], ["ok", "Okay"], ["scattered", "Scattered"]]],
		["mood", "How are you feeling?", [["calm", "Calm"], ["uneasy", "Uneasy"], ["tilted", "Angry, rushed, or out to win it back"]]],
	]
	for item in qs:
		var key: String = item[0]
		body += "[b]%s[/b]   " % String(item[1])
		for opt in item[2]:
			var label: String = opt[1]
			if checkin.get(key, "") == String(opt[0]):
				body += "[b][color=#2f7a4a]%s[/color][/b]      " % label
			else:
				body += _link("checkin:%s:%s" % [key, String(opt[0])], label) + "      "
		body += "\n\n"
	if checkin.size() >= 3:
		var score := {"good": 2, "ok": 1, "poor": 0, "sharp": 2, "scattered": 0, "calm": 2, "uneasy": 1, "tilted": 0}
		var total: int = int(score[checkin["sleep"]]) + int(score[checkin["focus"]]) + int(score[checkin["mood"]])
		if checkin["mood"] == "tilted" or total <= 2:
			body += "[b]Sit out.[/b]  Today's a day to write in the journal and rest. The market will open again tomorrow, and you'll be in better shape for it.\n\n"
		elif total <= 4:
			body += "[b]Take it easy.[/b]  Write in the journal before the open, go slow, and walk away the minute it gets loud in your head.\n\n"
		else:
			body += "[b]Ready.[/b]  You slept, you're clear, and you're calm. Write down what you mean to do, then hold yourself to it.\n\n"
		body += _link("checkin:reset:", "Start over")
	main._show("checkin", "Pre-market check-in", body)


func on_link(meta: String) -> bool:
	var parts := meta.split(":")
	if parts[0] == "checkin":
		if parts[1] == "reset":
			checkin = {}
			_checkin("", "")
		else:
			_checkin(parts[1], parts[2])
		return true
	if parts[0] == "url":
		OS.shell_open(meta.substr(4))
		return true
	return false


func _members(which: String) -> void:
	main.open_panel("Members only",
		"The %s lives in the Jekyll Island Trading Discord, behind the members' door. Ask a member for an invite.\n\n" % which
		+ "[i]The link goes up here once the club has it set.[/i]")


func _screens() -> void:
	main.open_panel("The journal screens",
		"Each screen shows the same four lines. Members fill them in every day, win or lose:\n\n"
		+ "[b]What I planned.[/b]\n[b]What I actually did.[/b]\n[b]How I felt while I did it.[/b]\n[b]What I learned about myself.[/b]\n\n"
		+ "One line a day, every day. Over a few months it tells you more about how you trade than anything anybody could sell you.")
