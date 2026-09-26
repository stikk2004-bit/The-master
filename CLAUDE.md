# The Jekyll Island Club: the game

A personal 3D game: walk the clubhouse of The Jekyll Island Club (Picayune, Mississippi) at dusk,
go room to room, and use what's in each room. Built in Blender, played in Godot 4.7.
Owner: founder of The Jekyll Island Club. Club email jekyllsclub@gmail.com. Site jekyllsclub.com.

## Folder layout
- `blender/JekyllClubGame.blend`: every model. Scenes: Clubhouse_Exterior, Lobby, Library,
  Player_Character, NPC_Hooded (and "Scene", an unrelated Picayune town test; leave it alone).
  Text block `club_lib.py` inside the .blend has the modeling helpers (MB mesh builder, mat,
  picture, framed, img_mat, text_obj). Load it with `exec(bpy.data.texts["club_lib.py"].as_string())`.
- `exports/`: .glb copies of every model.
- `art/source/`: the owner's original artwork (from the website zip, plus the club seal).
  `art/textures/`: game-ready versions (seal_main.jpg is the seal over the front desk).
- `godot/`: the Godot project. Open project.godot. F5 to play.
  - `models/*.glb`: what the game loads (copy exports here).
  - `scripts/main.gd`: rooms, lighting, interactables, lessons UI, bank ledger, guest book, NPC hookup.
  - `scripts/player.gd`: third-person controller (WASD, mouse orbit, Shift run, Space jump, R unstuck, step-up).
  - `scripts/hud.gd`: title card, E prompt, reading panel with [url] links, guest book, toast, chime.
  - `scripts/lessons.gd`: the four studies as data: 13 chapters, grown and kid text, one quiz each.
  - `scripts/money_sim.gd`: the Money Machine (gold, bank loans, spending and taxes, the Fed, run 40 years).
  - `scripts/npc.gd`: the hooded figure who walks the lawn.
  - Saves: user://guestbook.json and user://progress.json
    (%APPDATA%/Godot/app_userdata/The Jekyll Island Club/). Logs are there too, in logs/.

## Hard rules (learned the hard way)
- GDScript files use TABS. The owner edits in Godot, which saves tabs. Never mix.
- When rewriting a file with Python: build the full new text in memory FIRST, then open for write.
  `open(p, "w").write(f(open(p).read()))` truncates before reading and wipes the file.
- Beware substring replaces: replacing "panel.x" also hits "gb_panel.x".
- Avoid multi-line lambdas as function arguments in GDScript. Use named functions or Callable.bind().
- No em dashes in any in-game text. Write like a real person from south Mississippi, plain and warm.
- No trading signals, setups, indicator logic, or strategy anywhere (Trading Floor rule: "NO COURSE").
- Money content must stay accurate: banks create deposits by lending, repayment destroys them,
  government deficits add deposits and taxes remove them, the Fed creates reserves when it buys bonds,
  cash withdrawal changes form not amount. Label toy models as toy models.

## Blender to Godot
- Real-world meters. Blender (x, y, z) becomes Godot (x, z, -y). Rooms face the player walking in along Blender +Y.
- Collision by name: `-col` (mesh + trimesh), `-colonly` (invisible hull). main.gd also forces
  backface_collision on every trimesh, so flipped faces can't become holes.
- Export per scene with use_active_scene=True (otherwise every scene in the file gets exported):
  `bpy.ops.export_scene.gltf(filepath=..., export_format='GLB', use_active_scene=True, export_apply=True,
   export_lights=False, export_cameras=False, export_animations=False, export_image_format='AUTO')`
- Characters share one 14-bone skeleton (Root, Hips, Spine, Head, UpperArm/LowerArm/UpperLeg/LowerLeg/Foot .L/.R).
  Rigid skinning: each body part weighted 1.0 to one bone, then joined. Player animations export with
  export_animation_mode='ACTIONS' (Idle, Walk, Run). The NPC uses NLA tracks named Idle/Walk with
  export_animation_mode='NLA_TRACKS'.
- Keep glow gentle: GlassLit emission 1.3, LampGlass 2.0, bulbs 2.2, door transoms about 1.1.
  Game uses AgX tonemapping, ambient ~1.1, omni lights 0.25 to 1.3 energy with attenuation 0.9.

## How rooms work in main.gd
- `_build_level(name)` frees the old room, then calls `_build_<name>()`, which instances the .glb,
  adds omni lights, and registers interactables with `add_interactable(pos, radius, prompt, callable)`.
- Doors call `go_to(level, spawn_pos, facing_yaw)` (fade out, swap, fade in).
  Yaw 0 looks toward Godot -Z (into a room). Keep spawn points outside the door prompt radius.
- Panels: `open_panel(title, bbcode)` or `_show(kind, title, bbcode)`. Clickable links use
  `[url=meta]` and land in `_on_link(meta)`.

## Status
Done: exterior (Queen Anne clubhouse, live oaks, moss, gas lamps, fireflies, ribbon banner, club sign),
Grand Lobby (club seal above the desk, framed art, guest book, bell, notice board, marks),
Library (four volumes with chapters and quizzes, kids mode switch, bank ledger, sealed envelope,
the Money Machine), the player, the hooded figure.

## Next rooms (from the owner's brief)
Build each as its own Blender scene, export, add `_build_<room>()` in main.gd, and replace the
lobby door's `_room_door(...)` call with `go_to(...)`. Lobby doors (Godot): Trading (-9, -10), Studio (9, -4), Honey (9, -10).

1. The Honey House (Jekyll's 40 Acre Farm). Amber, gold, warm wood, Georgia type like the honey label
   (art/textures/honey_label.jpg). A hive you open to pull a frame (bees, comb, capped honey, colony facts).
   A shelf of jars: Raw Honey, $15, 16 oz, harvested in Carrier, Mississippi, raw, unfiltered, never heated.
   Order by call or text 601-569-3719 or stikk2004@gmail.com. Wholesale for local businesses.
   Bee removal, including commercial jobs (gas stations, storefronts). Label disclaimer: Mississippi Cottage
   Food Law, not inspected by MSDH, do not feed honey to children under one year.
   Open question for the owner: the cottage food law generally limits sales to direct-to-consumer, so confirm wholesale is allowed.
2. The Drafting Room (Jekyll Studio). Framed screens of live sites (art/textures/work_*.jpg):
   rootsbehavioralhealth.org, go-git-er.com, tinytidesplayroom.netlify.app, zvautomotive.com, prscms.org,
   40acrefarm.netlify.app. Pricing chalkboard: $50 one-time setup (domain, hosting, going live, basic upkeep)
   plus a build fee that scales with the work (simple site about $200 build, about $250 total).
   Optional monthly plan $30 to $300+ by workload. Client owns the site outright.
   Contact stikk2004@gmail.com, (601) 569-3719. A drafting table to "commission a draft".
   A hidden drawer marked 1997 with a Geocities-style gag.
3. The Trading Floor (Jekyll Island Trading, Discord community; owner trades MNQ/NQ intraday).
   Dark room, green and amber screens, scrolling ticker. Big "NO COURSE" plaque: journaling, psychology,
   and accountability are shared, never strategy. Pre-market check-in (sleep, focus, mood gives
   ready / take it easy / sit out). Leaderboard and journal as members-only doors (Discord and journal links
   not known yet). Never any signals, setups, or strategy.

## Ideas on the list
- Optional: Higgsfield image-to-3D for a more detailed player or props (uses the owner's Higgsfield credits; ask first).
- A web export of the game to feature on jekyllsclub.com.
- Let the hooded figure wander into the lobby, or give him a faint rim light.
