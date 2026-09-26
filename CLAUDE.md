# The Jekyll Island Club: the game

A personal 3D game: walk the clubhouse of The Jekyll Island Club (Picayune, Mississippi) at dusk,
go room to room, and use what's in each room. Built in Blender, played in Godot 4.7.
Owner: founder of The Jekyll Island Club. Club email jekyllsclub@gmail.com. Site jekyllsclub.com.

The look is Skyrim / Dark Souls 1 art style (the setting stays 1880s-1910 Mississippi and Georgia):
worn, textured surfaces, heavy air, warm lamplight against cool shadow, drained color.

## Folder layout
- `blender/JekyllClubGame.blend`: every model. Scenes: Clubhouse_Exterior, Lobby, Library,
  Player_Character, Player_Waiter, NPC_Hooded, NPC_Aldrich / Shelton / Andrew / Davison / Vanderlip /
  Warburg / Strong / Yardman / Brakeman / Porter / Conductor / Watchman / Steward, Hoboken_Yard, Hoboken_Train, Hoboken_Boxcars,
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
    shutter, shot). `python tools/sounds.py door shot` makes just those.
  - `fonts/`: .woff copies of the OFL fonts for painting text.
  - `blender/kit.py`: the modeling kit (MB mesh builder, mat, img_mat, text_mesh, new_scene, export).
  - `blender/charlib.py`, `anims.py`, `build_characters.py`: the characters and their animations.
  - `blender/build_1910.py`: Hoboken yard, train, motor cab, the private car, the Jekyll meeting room.
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
  - `scripts/chapter1910.gd`: the 1910 chapter (Hoboken, the private car, Jekyll Island, the meeting room),
    the pocket Kodak, the caught resets, the evidence panel at the end.
  - `scripts/look.gd`: textured materials by Blender material name (MATS, EMIT, IMG tables),
    lighting presets, color grading, graphics quality.
  - `scripts/foliage.gd`: leaf, needle, palmetto, moss and grass cards scattered over canopies and lawns.
  - `scripts/markers.gd`: Blender LIGHT_ and MARK_ empties become lights and named positions.
  - `scripts/actor.gd`, `scripts/guard.gd`: scripted people; watchmen with sight, hearing, lanterns.
    A guard's `watching = false` keeps him walking his round without noticing anyone; `pauses` sets where
    he stops and for how long; `arm(..., with_lantern)`.
  - `scripts/player.gd`: third-person controller (WASD, mouse orbit, Shift run, C sneak, Space jump,
    R unstuck, step-up), outfits (club, waiter), carrying a tray, the pocket Kodak (set_kodak), noise level
    for guards. The tray and the Kodak follow the left hand but stay level.
  - `scripts/hud.gd`: title, prompt bar, reading panel with [url] links, guest book, toast, chime,
    location banners, subtitles (say), letterbox, chapter cards, objective line, a second line under it
    for countdowns and photo tallies (set_timer), sneak eye (sneak_eye.gd).
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
- The chapter, as played: watch the seven arrive by cab, each at his own pace (MEN speed), climb the real
  steps of the observation platform and go in at the rear door. Then sneak past four watchmen (yard detective,
  brakeman, night watchman in the crate lane, conductor south of the car) to the car's dark front steps
  (a faint diamond marks them) within 3:30, or the train leaves without you. In the car: listen at the pantry,
  put on the steward's jacket, pour for Frank and Nelson, then photograph four papers in Arthur's valise with
  the pocket Kodak (hold E) while the real steward makes his rounds (3:00; he only minds you in the lounge).
  On Jekyll: pour Nelson's coffee, hear the plan, the men go out "duck hunting", photograph the chalkboard and
  Paul's and Abe's notes only while Arthur's head is down, take the clean copy when a shot on the marsh draws
  him to the window, and get out the door before he's back. Caught anywhere: that part starts over.
  The end is the evidence panel with the real history.

## Testing without playing
- `godot --path godot -- --shot level=lobby pos=x,y,z look=x,y,z out=/path.png [player=x,y,z] [hud=1] [debug=1]`
  saves a screenshot of any level (the 1910 levels and the three rooms too).
- `godot --headless --path godot -- --autotest` plays the whole 1910 chapter with every scene skipped.
- `godot --headless --path godot -- --stealthtest` sends a careful and a careless sneak through the yard.
- `godot --headless --path godot -- --roomtest` uses everything in the three rooms.
- `--shot` extras: `swing=Door_Library` opens a door first; `setup=rear|front|valise|room` stages a chapter
  moment (chapter1910 shot_setup).
- After adding textures or models, run `godot --headless --path godot --import` once.

## Status
Done: exterior (Queen Anne clubhouse, live oaks with leaf cards and hanging moss, grass, gas lamps,
fireflies, crickets), Grand Lobby, Library (unchanged content), the three rooms (Honey House, Drafting Room,
Trading Floor), the 1910 chapter, all characters, the Skyrim / Dark Souls look and interface.
Ways into 1910: take the railroad ticket from the hooded figure after he's talked a while, or pick up the
ticket on the lobby desk.
Stealth difficulty: the owner has said to leave it as it is for now (lanterns 2.5x brighter, sight 14 m,
four watchmen). The stealthtest's careful sneak can still get caught waiting at the last crossing.

## Open questions for the owner
- Wholesale honey: the cottage food law generally limits sales to direct-to-consumer, so the shelf
  doesn't offer wholesale until the owner confirms.
- The town is spelled "Carriere" on the Honey House shelf (ZV Automotive's site spells it that way; the
  brief and the 40 Acre Farm site say "Carrier"). Change it in rooms.gd if the owner prefers.
- Discord and journal links for the Trading Floor's members-only doors aren't known yet.

## Ideas on the list
- Optional: Higgsfield image-to-3D for more detailed people or props (uses the owner's credits; ask first).
  Not used so far: the owner asked for no Higgsfield.
- A web export of the game to feature on jekyllsclub.com (would want graphics quality low or medium).
- Let the hooded figure wander into the lobby, or give him a faint rim light.
