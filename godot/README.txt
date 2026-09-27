THE JEKYLL ISLAND CLUB

Open it
  1. Start Godot 4.7.
  2. Click Import, pick the project.godot file in this folder, then Import & Edit.
     The first open takes a few minutes while Godot imports the models and textures.
  3. Press F5 (or the play arrow, top right) to play.

Controls
  Mouse        look around (click the window if the mouse is loose)
  W A S D      walk (arrow keys work too)
  Shift        run
  C or Ctrl    sneak (stay low and quiet; the eye opens as somebody notices you)
  Space        jump
  E            use whatever you're standing near, or move a conversation along; hide; get out of the motorcar
  Q            once you have the pocket Kodak: hold it up to your eye (again to put it away)
  F            throw a stone where you're looking; a watchman nearby goes to see what landed
  M            in 1910: Jekyll's sketch of the yard, with you on it (the yard doesn't stop while you look)
  Click        through the Kodak: take the picture          Mouse wheel: zoom
  Space        jump, or climb onto a crate or ledge in front of you
  Driving      W go, S brake, A and D steer, E hop out (no need to stop first)
  R            stuck? pops you back to the last good spot
  Mouse wheel  camera closer or farther
  Esc          close a panel, free the mouse, or skip a scene
  F9           graphics: high, medium, low (use low on an older computer)

Where to go
  The Grand Lobby's four doors: the Library, the Trading Floor, the Drafting Room, the Honey House.
  1910: the hooded figure on the lawn has an old railroad ticket for you, and so does the lobby desk.
        Read the letter, meet Jekyll, drive to the freight gate. A printable map of the yard is in
        art/maps/hoboken_yard_map.pdf (in the full project folder). Get a picture of all seven men before
        they go into the Senator's car. They come four ways: a side gate in the back fence, the
        freight gate, the stairs up from the river, or a cab on River Street, and they go in at the
        Senator's car's two doors. A green check over a man's head means you got him; not everybody in a
        good coat is one of the seven. Keep out of the
        lantern beams, mind the lookouts up high, then get aboard at the car's dark
        front steps before the train leaves. Keep out of the steward's sight, and don't be holding the
        camera up when Arthur looks up. Get caught and that part starts over.

Where things live
  models/     exported from blender/JekyllClubGame.blend
  scripts/    the game, all plain GDScript
  textures/   painted by tools/texgen.py and friends
  shaders/    the world, sky, foliage and screen shaders
  sounds/     made by tools/sounds.py
  fonts/      Cinzel, Cormorant Garamond and IM Fell English (SIL Open Font License, see OFL.txt)
