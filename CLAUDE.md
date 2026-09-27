# The Jekyll Island Club: the game

A personal 3D game: walk the clubhouse of The Jekyll Island Club (Picayune, Mississippi) at dusk,
go room to room, and use what's in each room. Built in Blender, played in Godot 4.7.
Owner: founder of The Jekyll Island Club. Club email jekyllsclub@gmail.com. Site jekyllsclub.com.

The look is Skyrim / Dark Souls 1 art style (the setting stays 1880s-1910 Mississippi and Georgia):
worn, textured surfaces, heavy air, warm lamplight against cool shadow, drained color.

## Folder layout
- `blender/JekyllClubGame.blend`: every model. Scenes: Clubhouse_Exterior, Lobby, Library,
  Player_Character, Player_Waiter, NPC_Hooded, NPC_Aldrich / Shelton / Andrew / Davison / Vanderlip /
  Warburg / Strong / Yardman / Brakeman / Porter / Conductor / Watchman / Steward / Jekyll, Hoboken_Yard, Hoboken_Train, Hoboken_Boxcars,
  Motorcar_1910, Private_Car, Jekyll_Meeting, Honey_House, Drafting_Room, Trading_Floor
  (and "Scene", an unrelated Picayune town test; leave it alone).
  Text block `club_lib.py` inside the .blend has the old modeling helpers.
  The owner's file was last saved by Blender 5.2; the build scripts run on the `bpy` 5.0 module and
  save it back. Nothing in it needs 5.2 features. Picture paths inside it are relative to the .blend
  (kit.relink_images), so it opens on the owner's PC and in the cloud alike.
- `tools/`: everything that makes the art. All of it can be re-run.
  - `texgen.py`: paints the tileable PBR textures and foliage cards into godot/textures/ (numpy, no downloads).
  - `paint_1910.py`, `paint_rooms.py`: painted pictures (blinds, skyline, chalkboards, plaque, ticker, screens...).
  - `sounds.py`: synthesized sound into godot/sounds/ (yard, train, fire, marsh, crickets, room, whistle, door,
    shutter, shot, motor, stone). `python tools/sounds.py door shot` makes just those.
  - `fonts/`: .woff copies of the OFL fonts for painting text.
  - `blender/kit.py`: the modeling kit (MB mesh builder, mat, img_mat, text_mesh, new_scene, export).
  - `blender/charlib.py`, `anims.py`, `build_characters.py`: the characters and their animations.
  - `blender/build_1910.py`: Hoboken yard, train, motor cab, the private car, the Jekyll meeting room.
    The yard's `yard_more()` lays the gravel walks (HB_Path) and plank crossings (HB_Planks), post lamps
    along the walks (LIGHT_path), switch stands and a signal mast (LIGHT_sigred / siggreen), the lit yard
    office by the gate, a tool house, lumber, ties, car wheels and a dray in the north end, baggage carts
    and milk cans on the platform, and the signboards.
  - `blender/yard_map.py`: draws a plan of the yard from the models themselves (every upward face, colored
    by material, plus the MARK_ / LIGHT_ empties): godot/textures/yard_map.png (Jekyll's sketch, M in the
    game) and art/maps/hoboken_yard_map.pdf (to print). Re-run after changing the yard. Its frame and scale
    must match mission_ui.gd MAP_X0 / MAP_Y1 / MAP_PX_PER_M / MAP_PAD / MAP_SIZE (it prints them).
  - `blender/build_rooms.py`: the Honey House, the Drafting Room, the Trading Floor.
  - `blender/remaster_exterior.py`: lanterns on the walk's gas lamps, benches, urns by the porch steps.
  - `blender/split_doors.py`: splits the clubhouse's double doors into leaves that swing (see Doors below)
    and re-exports clubhouse_exterior, lobby and library. Safe to run again.
  Run with `python tools/blender/build_characters.py [names]` using the bpy module (pip install bpy)
  or `blender -b blender/JekyllClubGame.blend -P tools/blender/<script>.py -- <names>`.
- `exports/`: .glb copies of every model.
- `art/source/`: the owner's original artwork (from the website zip, plus the club seal).
  `art/textures/`: game-ready versions (seal_main.jpg is the seal over the front desk).
- `godot/`: the Godot project. Open project.godot. F5 to play.
  - `models/*.glb`: what the game loads. `textures/`, `shaders/`, `fonts/`, `sounds/`: the look.
  - `scripts/main.gd`: levels, the present-day rooms (exterior, lobby, library), lessons UI, bank ledger,
    guest book, NPC hookup, dust, ambience, settings, screenshots and test switches.
  - `scripts/rooms.gd`: the Honey House, the Drafting Room and the Trading Floor.
  - `scripts/chapter1910.gd`: the 1910 chapter (River Street and the Hoboken yard, the private car, Jekyll
    Island, the meeting room), the pocket Kodak, the caught resets, the evidence panel at the end.
  - `scripts/mission_ui.gd`: the mission layer of the HUD: big countdown (set_clock), objective box
    (hud.set_objective / hud.set_timer land here), camera item slot, viewfinder, the photo print that
    pops up with who's in it (small, slides in at the left, then flies to its slot), the strip of
    prints still needed, and Jekyll's sketch of the yard (show_map, set_map_player: an arrow where you
    are, the way you're looking; the key is cropped off in the game).
  - `scripts/drive.gd`: Jekyll's motorcar (W/S throttle and brake, A/D steer, E out when stopped).
  - `scripts/look.gd`: textured materials by Blender material name (MATS, EMIT, IMG tables),
    lighting presets, color grading, graphics quality.
  - `scripts/foliage.gd`: leaf, needle, palmetto, moss and grass cards scattered over canopies and lawns.
  - `scripts/markers.gd`: Blender LIGHT_ and MARK_ empties become lights and named positions.
  - `scripts/actor.gd`, `scripts/guard.gd`: scripted people; watchmen with sight, hearing, lanterns.
    The lantern throws a forward SpotLight beam; standing in the beam gets you seen in under a second,
    outside it they see about 6 m in the dark (15 under a lamp), less if you crouch, half as far if you're
    up high. `roam(spots, others, nav_map)` makes them pick random places across the yard, away from the
    other watchmen and their targets, and walk there on the navmesh the chapter bakes at load. They swing
    the beam when they stop, walk over to look when they half see you (`alarmed` calls the nearest other one
    over). `watching = false` keeps a guard walking without noticing anyone; a fixed round still works.
    The roamers share one `seen` dictionary (spot index to the last time anyone was within 6 m of it) and
    favor the spots nobody has looked at in a while, so between them they clear every corner every couple
    of minutes. `perch(yaws)` makes a lookout who stays put up high and turns his lantern to a new facing
    every 6 to 10 s (the switchman in the switch tower, a man on the freight shed roof).
    The tarp wagon has no collision (you crawl under it); a NavigationObstacle3D in chapter _bake_nav keeps
    the watchmen from walking through it and over a hidden player.
  - `scripts/player.gd`: third-person controller (WASD, mouse orbit, Shift run, C sneak, Space jump,
    R unstuck, step-up), outfits (club, waiter), carrying a tray, noise level for guards. The camera is an
    item once `has_camera`: Q raises it (first-person viewfinder, wheel zoom, click emits `shutter`).
    Space against a ledge from knee to chest high climbs onto it (_try_mantle). hide_at()/unhide() tuck
    the player out of sight (guards ignore a hidden player unless right on top of him). F throws a stone
    (`stones`, `throw_stone` signal); the chapter makes it clatter where it lands and guards within 17 m go
    and look (guard.heard_noise). Jekyll gives 3; two more lie hidden in the yard (MARK_stones_0 on a
    climbable crate stack, MARK_stones_1 on the empty boxcar's roof). free_spot(pos) finds the nearest
    place the capsule fits; if the player pushes into something for a second without moving, he's nudged
    there (no more pressing R after getting out of the motorcar or out of a hiding place).
  - `scripts/hud.gd`: title, prompt bar, reading panel with [url] links, guest book, toast, chime,
    location banners, subtitles (say), letterbox, chapter cards, objective line, a second line under it
    for countdowns and photo tallies (set_timer), the signal lamp (signal_lamp.gd: green, amber, red as the
    watchmen notice you; it replaced a Skyrim-style eye). The location banner is a punched ticket slip that
    drops in from the top; the E prompt is a green enamel sign with a brass key token. Keep the interface
    1910 railroad and club, not borrowed from other games.
  - `scripts/lessons.gd`: the four studies as data: 13 chapters, grown and kid text, one quiz each.
  - `scripts/money_sim.gd`: the Money Machine (gold, bank loans, spending and taxes, the Fed, run 40 years).
  - `scripts/npc.gd`: the hooded figure who walks the lawn. `scripts/sound.gd`: ambience loader.
  - Saves: user://guestbook.json, user://progress.json (ch1910 is set when the chapter is finished),
    user://settings.json (graphics quality). (%APPDATA%/Godot/app_userdata/The Jekyll Island Club/).

## Hard rules (learned the hard way)
- GDScript files use TABS. The owner edits in Godot, which saves tabs. Never mix.
- When rewriting a file with Python: build the full new text in memory FIRST, then open for write.
  `open(p, "w").write(f(open(p).read()))` truncates before reading and wipes the file.
- Beware substring replaces: replacing "panel.x" also hits "gb_panel.x".
- Avoid multi-line lambdas as function arguments in GDScript. Use named functions or Callable.bind().
- GDScript treats "inferred from a Variant" as an error here: give dictionary lookups and loop keys a type
  (`var spec: Array = ...`, `String(key)`). Don't name anything `Shader` or `_set` (they clash with Godot).
- No em dashes in any in-game text. Write like a real person from south Mississippi, plain and warm.
- No trading signals, setups, indicator logic, or strategy anywhere (Trading Floor rule: "NO COURSE").
  The Trading Floor screens and ticker show journaling and check-in text, never charts.
- Money content must stay accurate: banks create deposits by lending, repayment destroys them,
  government deficits add deposits and taxes remove them, the Fed creates reserves when it buys bonds,
  cash withdrawal changes form not amount. Label toy models as toy models.
- History stays accurate too. In the 1910 chapter the lines are imagined, the facts are not, and the
  draft panel says so. Men: Nelson Aldrich (host), Arthur Shelton (his secretary), A. Piatt Andrew ("Abe"),
  Henry P. Davison ("Harry", alias Wilbur), Frank Vanderlip (alias Orville), Paul Warburg, Benjamin Strong.
  First names only. Cover story: duck hunting. The plan: the Aldrich Plan (National Reserve Association,
  15 districts), published January 1911, never passed; the Federal Reserve Act (12 Reserve Banks, a Board
  appointed by the President) was signed December 23, 1913; the Reserve Banks opened November 1914.
  Accounts differ on some details (some lists add Charles Norton).

## Blender to Godot
- Real-world meters. Blender (x, y, z) becomes Godot (x, z, -y). Rooms face the player walking in along Blender +Y.
- Collision by name: `-col` (mesh + trimesh), `-colonly` (invisible hull). main.gd also forces
  backface_collision on every trimesh, so flipped faces can't become holes.
- Export per scene with use_active_scene=True (otherwise every scene in the file gets exported). `kit.export`
  does this; `images=False` leaves pictures out when the game lays them on itself (look.gd IMG).
- Materials in Blender are plain colors. The game textures them by NAME: add every new material to
  look.gd `MATS` ([texture set, meters per repeat, options]); the Blender color becomes the surface's
  average color unless `orig: false` or `tint` says otherwise. Glowing ones go in `EMIT`, pictures in `IMG`.
  The world shader projects textures in world meters (triplanar), so models need no UV unwrap.
  Moving things use `"obj": true` so the texture rides along.
- Empties: `LIGHT_<kind>_<n>` become lights (kinds and colors in markers.gd KINDS); `MARK_<name>` become
  named positions and facings the scripts use (an empty faces its local +Y). Blender adds .001 to repeated
  names; markers.gd strips it.
- Objects named HiveLid and HiveFrame are animated in the Honey House; keep those names.
- Characters: one 22-bone skeleton (Root, Hips, Spine, Chest, Neck, Head, and Shoulder, UpperArm,
  LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toe .L/.R), smooth skin weights, built from lofted rings.
  Hair is a shell that lies on the skull (charlib.head_deform) and tucks under the skin at the hairline;
  `bald` clears the top from the forehead back. `spectacles=True` gives round wire glasses (Vanderlip).
  Each man has his own `gait` in build_characters.py CAST (stride a, stance, lean, arm swing, lift, bob,
  sway). Walk cycles are authored for a fixed ground speed (anims.py WALK_V 1.7, RUN_V 3.9, SNEAK_V 1.0 m/s),
  so the game plays them at speed / that speed and feet never slide.
  Cloth materials are named `CH_<texture>__<what>` (look.gd lays that texture on using the mesh UVs, which
  are in meters). `CHX_` materials are left alone (eyes, lamp glass). Hats and carried things are separate
  meshes ending in Hat / Prop so actor.indoors() can take them off. Every character exports its animations
  as NLA tracks: Idle, Walk, Run, SneakIdle, SneakWalk, CarryIdle, CarryWalk, Serve, Sit, SitTalk,
  SitWrite, SitDrink, Talk, LookAround, LanternWalk (each character gets the sets its role needs).
- The look is no longer "gentle glow": AgX tonemapping, SDFGI, volumetric fog, SSAO/SSIL, a color-grading
  LUT, vignette and grain. Presets in look.gd PRESETS: dusk, interior, honey, studio, trading, night1910,
  train, jekyll. Lights get a per-preset gain. F9 cycles graphics quality (high/medium/low) for slower PCs.

## How rooms work
- `_build_level(name)` frees the old room, then builds it: main.gd's `_build_exterior/lobby/library`,
  rooms.gd's `build_honey/studio/trading`, or chapter1910.gd for hoboken, privatecar, jekyll, meeting.
  Each instances the .glb (main._instance applies the look), adds lights and registers interactables
  with `add_interactable(pos, radius, prompt, callable)`.
- Doors call `go_to(level, spawn_pos, facing_yaw)` (fade out, swap, fade in). Pass Vector3.INF when the
  room places the player itself. Yaw 0 looks toward Godot -Z (into a room). Keep spawn points outside the
  door prompt radius.
- Clubhouse doors swing: split_doors.py makes each leaf its own object `<door>_SwingP` / `_SwingN` with its
  origin on the hinge, plus a lit `<door>_Glow` panel behind. `main.swing_door(door)` turns them, and
  `main._through_door(door, level, pos, yaw)` opens the door, then goes through. The Senator's car has two
  doors of its own the chapter swings: `RearDoor` (out onto the observation platform) and `FrontDoor`
  (the west door of the front vestibule, in).
- Panels: `open_panel(title, bbcode)` or `_show(kind, title, bbcode)`. Clickable links use `[url=meta]` and
  land in `_on_link(meta)` (chapter1910 and rooms get first look). `url:<address>` opens a web page.
  `main.after_panel` runs once when the panel closes.
- In the chapter: `begin_scene()` / `end_scene()` wrap cutscenes (letterbox, cinematic camera); `line(who, text)`
  shows a subtitle and waits; E moves a line along (in cutscenes and while pouring coffee), Esc skips the scene.
- The chapter, as played: a letter, then Jekyll (a made-up character; the evidence panel says so) by his
  motorcar at the west end of River Street. He hands over the Kodak (12 exposures), three stones and his sketch of the yard (M).
  Drive to the freight gate, walk in, and the clock starts (7:00). Past the gate the yard reads lighter than
  the street (chapter _yard_air: exposure x1.3, ambient x1.6; the Kodak and motorcar boosts ride on that). The seven arrive while you play, each at his own pace and by one of
  three ways, shuffled every try: by cab up River Street, on foot down the station platform, or across the
  yard from the far side and up the west steps (_arrival_live, MARK_station_walk_*, yard_walk_*, west_step_*).
  They tip their hats to the porter, climb the observation platform steps and go in at the rear door; each
  must be photographed first (the print pops up with his full name and position) or the yard starts over.
  Four travelers who look like some of the men (same models) wander the traveler_* marks; photographing
  one wastes film ("A stranger"). Five watchmen roam with beams and two lookouts watch from up high. Hide under the tarp wagon (it looks onto the platform), in the empty boxcar, or in the shed doorway;
  climb crates or the boxcar ladders. All seven taken, board at the car's dark front steps (a faint diamond
  marks them) before the train leaves. In the car: listen at the pantry,
  put on the steward's jacket, pour for Frank and Nelson, then photograph the four papers by Arthur's valise
  with the Kodak while the real steward makes his rounds (3:00; he only minds you in the lounge).
  On Jekyll: pour Nelson's coffee, hear the plan, the men go out "duck hunting", photograph the chalkboard and
  Paul's and Abe's notes, keeping the camera down whenever Arthur looks up, take the clean copy when a shot on the marsh draws
  him to the window, and get out the door before he's back. Caught anywhere: that part starts over.
  The end is the evidence panel with the real history.

## Testing without playing
- `godot --path godot -- --shot level=lobby pos=x,y,z look=x,y,z out=/path.png [player=x,y,z] [hud=1] [debug=1]`
  saves a screenshot of any level (the 1910 levels and the three rooms too).
- `godot --headless --path godot -- --autotest` plays the whole 1910 chapter with every scene skipped.
- `godot --headless --path godot -- --stealthtest` watches the roaming watchmen for a minute from under the tarp
  (how far they get, how spread out they stay, whether a hidden player stays hidden), then stands in a beam.
- `godot --headless --path godot -- --roomtest` uses everything in the three rooms.
- `--shot` extras: `swing=Door_Library` opens a door first; `setup=rear|front|finder|jekyll|yard|map` stages a
  chapter moment (chapter1910 shot_setup; finder looks through the Kodak from under the tarp; yard is the yard
  as played with its HUD; map holds up Jekyll's sketch).
- After adding textures or models, run `godot --headless --path godot --import` once.

## Status
Done: exterior (Queen Anne clubhouse, live oaks with leaf cards and hanging moss, grass, gas lamps,
fireflies, crickets), Grand Lobby, Library (unchanged content), the three rooms (Honey House, Drafting Room,
Trading Floor), the 1910 chapter, all characters, the Skyrim / Dark Souls look and interface.
Ways into 1910: take the railroad ticket from the hooded figure after he's talked a while, or pick up the
ticket on the lobby desk.
Stealth: five watchmen roam the yard at random with lantern beams, spread out (about 14 m apart on average in
the stealthtest) and sweeping every corner between them, plus two lookouts up high turning their lanterns.
The owner wants it very hard to get the pictures without being seen.
The hooded figure gives one line per E press (no faster than one a second) and offers the ticket with the
third; toasts sit a third of the way down the screen so they never cover the clock or banners.
Animations beyond walking: the player has Throw, Climb (ladders) and Mantle; the seven have TipHat.
Coat skirts follow the thighs in front (charlib.skirt_w) and leg tops are slimmed under coats, arms hang a
little out from the body: that keeps legs and cuffs from showing through coats when walking and sitting.

## Open questions for the owner
- Wholesale honey: the cottage food law generally limits sales to direct-to-consumer, so the shelf
  doesn't offer wholesale until the owner confirms.
- The town is spelled "Carriere" on the Honey House shelf (ZV Automotive's site spells it that way; the
  brief and the 40 Acre Farm site say "Carrier"). Change it in rooms.gd if the owner prefers.
- Discord and journal links for the Trading Floor's members-only doors aren't known yet.

## Ideas on the list
- Higgsfield: the owner OK'd spending their credits to redo the characters. The account had 10 credits
  (free plan): enough for two Tripo text-to-3D models at 5 each, no more. Generated: Aldrich (job
  996d5529-fd2c-47c4-89b5-7e999ad92863) and the player in club clothes (job ab7f1559-bab4-4e72-b27f-2526efc77cd0).
  The cloud session couldn't download them (network policy blocks the CDN host). Plan once they're in the repo
  (e.g. art/higgsfield/*.glb): scale to height, bind to the 22-bone rig with automatic weights so all the
  existing animations play; one shell of a mesh, so no cloth can poke through. A full cast (about 17) would
  need roughly 170 more credits at 5 each plus nothing for rigging (done in Blender).
- A web export of the game to feature on jekyllsclub.com (would want graphics quality low or medium).
- Let the hooded figure wander into the lobby, or give him a faint rim light.
