"""Build every character into blender/JekyllClubGame.blend and export them for Godot.

    python tools/blender/build_characters.py            # all of them
    python tools/blender/build_characters.py player     # just one (scene name without NPC_ prefix)

Runs with the bpy module (pip install bpy) or inside Blender:
    blender -b blender/JekyllClubGame.blend -P tools/blender/build_characters.py -- player
"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anims  # noqa: E402
import charlib as C  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
BLEND = os.path.join(ROOT, "blender", "JekyllClubGame.blend")
EXPORTS = os.path.join(ROOT, "exports")
MODELS = os.path.join(ROOT, "godot", "models")


def M():
    """The shared wardrobe. Names: CH_<texture>__<what it is>."""
    return {
        "skin_fair": C.cmat("CH_skin__fair", "#d9ae8e", 0.55),
        "skin_ruddy": C.cmat("CH_skin__ruddy", "#cf9a7c", 0.55),
        "skin_olive": C.cmat("CH_skin__olive", "#b88a68", 0.55),
        "skin_player": C.cmat("CH_skin__player", "#c79a74", 0.55),
        "skin_brown": C.cmat("CH_skin__brown", "#7a5238", 0.5),
        "skin_pale": C.cmat("CH_skin__pale", "#e0bca4", 0.55),
        "eye": C.cmat("CHX_eye", "#1a1410", 0.15),
        "hair_dark": C.cmat("CH_velvet__hair_dark", "#241a14", 0.7),
        "hair_brown": C.cmat("CH_velvet__hair_brown", "#3a2416", 0.7),
        "hair_gray": C.cmat("CH_velvet__hair_gray", "#8a8680", 0.7),
        "hair_white": C.cmat("CH_velvet__hair_white", "#d8d4cc", 0.7),
        "hair_black": C.cmat("CH_velvet__hair_black", "#141210", 0.65),
        "hair_sandy": C.cmat("CH_velvet__hair_sandy", "#7a5a38", 0.7),
        "wool_black": C.cmat("CH_wool__black", "#16161a", 0.85),
        "wool_charcoal": C.cmat("CH_wool__charcoal", "#2a2a2e", 0.85),
        "wool_navy": C.cmat("CH_wool__navy", "#1a2030", 0.85),
        "wool_brown": C.cmat("CH_wool__brown", "#3a2c22", 0.85),
        "wool_gray": C.cmat("CH_wool__gray", "#55524c", 0.85),
        "tweed_brown": C.cmat("CH_tweed__brown", "#5a4a38", 0.9),
        "tweed_gray": C.cmat("CH_tweed__gray", "#6a6660", 0.9),
        "tweed_green": C.cmat("CH_tweed__green", "#3a4232", 0.9),
        "club_green": C.cmat("CH_wool__club_green", "#1c3a2a", 0.8),
        "cream": C.cmat("CH_linen__cream", "#d8ceb1", 0.8),
        "shirt": C.cmat("CH_linen__shirt", "#eee8da", 0.8),
        "white_jacket": C.cmat("CH_linen__steward_white", "#f2eee4", 0.75),
        "vest_gray": C.cmat("CH_wool__vest_gray", "#4a4a4e", 0.8),
        "vest_buff": C.cmat("CH_wool__vest_buff", "#8a7a5a", 0.8),
        "tie_red": C.cmat("CH_velvet__tie_red", "#8c2a1b", 0.6),
        "tie_black": C.cmat("CH_velvet__tie_black", "#101012", 0.55),
        "tie_navy": C.cmat("CH_velvet__tie_navy", "#1c2440", 0.6),
        "tie_green": C.cmat("CH_velvet__tie_green", "#1f3a2a", 0.6),
        "pocket_blue": C.cmat("CH_linen__pocket_blue", "#4982c2", 0.6),
        "shoe_black": C.cmat("CH_leather__shoe_black", "#141212", 0.4),
        "shoe_brown": C.cmat("CH_leather__shoe_brown", "#2d1b0c", 0.45),
        "sole": C.cmat("CH_leather__sole", "#0c0a08", 0.8),
        "leather_brown": C.cmat("CH_leather__brown", "#4a2e1a", 0.55),
        "leather_black": C.cmat("CH_leather__black", "#16120f", 0.5),
        "glove": C.cmat("CH_leather__glove", "#2a2420", 0.6),
        "felt_black": C.cmat("CH_velvet__felt_black", "#121214", 0.7),
        "felt_brown": C.cmat("CH_velvet__felt_brown", "#3a2a1e", 0.75),
        "felt_gray": C.cmat("CH_velvet__felt_gray", "#4a4846", 0.75),
        "silk_black": C.cmat("CH_velvet__silk_black", "#0a0a0c", 0.35),
        "straw": C.cmat("CH_straw__boater", "#dbc48c", 0.8),
        "band_red": C.cmat("CH_velvet__band_red", "#6a1e18", 0.6),
        "band_black": C.cmat("CH_velvet__band_black", "#0e0e10", 0.6),
        "brass": C.cmat("CH_brass__buttons", "#b79049", 0.35, 0.9),
        "horn": C.cmat("CH_leather__horn", "#1c140e", 0.4),
        "steel": C.cmat("CH_iron_clean__steel", "#8a8a8e", 0.3, 0.9),
        "iron": C.cmat("CH_iron__iron", "#2a2826", 0.5, 0.6),
        "wood": C.cmat("CH_wood_dark__wood", "#3a2415", 0.5),
        "paper": C.cmat("CH_paper__paper", "#e8dcc0", 0.9),
        "lamp": C.cmat("CHX_lamp", "#ffc070", 0.3, 0.0, "#ffb060", 6.0),
        "denim": C.cmat("CH_wool__denim", "#2e3a52", 0.9),
        "cloak": C.cmat("CH_wool__cloak", "#111216", 0.95),
        "cloak_sheen": C.cmat("CH_velvet__cloak_sheen", "#1b1c22", 0.8),
        "face_shadow": C.cmat("CHX_shadow", "#020202", 1.0),
        "cord": C.cmat("CH_velvet__cord", "#2a2a2d", 0.8),
        "scarf_gray": C.cmat("CH_wool__scarf_gray", "#6a6864", 0.95),
        "scarf_wine": C.cmat("CH_wool__scarf_wine", "#4a1a1c", 0.95),
        "scarf_cream": C.cmat("CH_wool__scarf_cream", "#c8bca4", 0.95),
    }


# ------------------------------------------------------------------ the cast
# coat: overcoat (to the knee), frock (to mid-thigh), sack (suit jacket to the hip),
#       steward (waist-length white mess jacket), work (short work coat), cloak (the hooded figure)
CAST = {
    "player": dict(file="player", height=1.80, build=1.0, skin="skin_player", hair="hair_brown", hair_style="parted",
                   face=dict(jaw=1.05, nose=1.0, brow=1.0, chin=1.05, age=0.2), coat="sack", coat_mat="club_green",
                   trousers="cream", shoes="shoe_brown", tie="tie_red", vest=None, pocket="pocket_blue",
                   hat="boater", hat_mat="straw", band="band_red", anims=("base", "run", "sneak", "carry")),
    "player_waiter": dict(file="player_waiter", height=1.80, build=1.0, skin="skin_player", hair="hair_brown", hair_style="parted",
                          face=dict(jaw=1.05, nose=1.0, brow=1.0, chin=1.05, age=0.2), coat="steward", coat_mat="white_jacket",
                          trousers="wool_black", shoes="shoe_black", bowtie="tie_black", vest=None, hat=None,
                          anims=("base", "run", "sneak", "carry")),
    # The Senator: sixty-nine, heavy white mustache, silk hat, cane
    "aldrich": dict(file="npc_aldrich", height=1.78, build=1.12, belly=0.6, skin="skin_ruddy", hair="hair_white", hair_style="short", bald=0.7,
                    face=dict(jaw=1.1, nose=1.15, nose_len=1.1, brow=1.3, chin=0.9, age=0.9, width=1.04), mustache=("walrus", 1.25),
                    mustache_mat="hair_white", brows="hair_white",
                    coat="overcoat", coat_mat="wool_black", trousers="wool_charcoal", shoes="shoe_black", tie="tie_black",
                    vest="vest_gray", hat="top", hat_mat="silk_black", band="band_black", scarf="scarf_wine", anims=("base", "sit", "talk")),
    # His private secretary: young, quick, carries the valise
    "shelton": dict(file="npc_shelton", height=1.76, build=0.92, skin="skin_pale", hair="hair_sandy", hair_style="parted",
                    face=dict(jaw=0.95, nose=0.95, brow=0.9, chin=1.0, age=0.05, width=0.97), coat="sack", coat_mat="wool_gray",
                    trousers="wool_gray", shoes="shoe_black", tie="tie_navy", vest=None, hat="bowler", hat_mat="felt_black",
                    band="band_black", prop="valise", anims=("base", "sit", "talk")),
    # Assistant Secretary of the Treasury, economist, thirty-seven
    "andrew": dict(file="npc_andrew", height=1.75, build=1.02, skin="skin_fair", hair="hair_dark", hair_style="parted",
                   face=dict(jaw=1.0, nose=0.95, brow=1.0, chin=1.05, age=0.15, width=1.03), coat="overcoat", coat_mat="wool_navy",
                   trousers="wool_charcoal", shoes="shoe_black", tie="tie_green", vest="vest_gray", hat="homburg", hat_mat="felt_gray",
                   band="band_black", scarf="scarf_cream", anims=("base", "sit", "talk")),
    # Morgan partner; the one who talks to the newspapermen at Brunswick
    "davison": dict(file="npc_davison", height=1.80, build=1.05, skin="skin_ruddy", hair="hair_brown", hair_style="short", bald=0.35,
                    face=dict(jaw=1.15, nose=1.0, brow=1.05, chin=1.1, age=0.35), coat="overcoat", coat_mat="tweed_brown",
                    trousers="wool_brown", shoes="shoe_brown", tie="tie_red", vest="vest_buff", hat="bowler", hat_mat="felt_brown",
                    band="band_black", prop="gun_case", anims=("base", "sit", "talk")),
    # National City Bank; pince-nez and a neat mustache
    "vanderlip": dict(file="npc_vanderlip", height=1.83, build=0.98, skin="skin_fair", hair="hair_gray", hair_style="parted",
                      face=dict(jaw=1.0, nose=1.1, nose_len=1.1, brow=1.1, chin=1.0, age=0.45, width=0.98), mustache=("plain", 1.0),
                      mustache_mat="hair_gray", glasses=True, coat="overcoat", coat_mat="wool_charcoal", trousers="wool_charcoal",
                      shoes="shoe_black", tie="tie_black", vest="vest_gray", hat="homburg", hat_mat="felt_black", band="band_black",
                      prop="gun_case", anims=("base", "sit", "talk")),
    # Kuhn, Loeb partner, born in Hamburg; dark mustache, slight
    "warburg": dict(file="npc_warburg", height=1.72, build=0.95, skin="skin_olive", hair="hair_black", hair_style="parted", bald=0.2,
                    face=dict(jaw=0.95, nose=1.12, nose_len=1.05, brow=1.1, chin=0.95, age=0.35, width=0.98), mustache=("plain", 1.1),
                    mustache_mat="hair_black", coat="overcoat", coat_mat="wool_black", trousers="wool_black", shoes="shoe_black",
                    tie="tie_navy", vest="vest_gray", hat="homburg", hat_mat="felt_black", band="band_black", scarf="scarf_gray", anims=("base", "sit", "talk")),
    # Bankers Trust; thirty-eight, clean shaven, dark hair
    "strong": dict(file="npc_strong", height=1.79, build=1.0, skin="skin_fair", hair="hair_dark", hair_style="parted",
                   face=dict(jaw=1.1, nose=1.0, brow=1.05, chin=1.1, age=0.15), coat="overcoat", coat_mat="wool_gray",
                   trousers="wool_gray", shoes="shoe_black", tie="tie_black", vest="vest_gray", hat="bowler", hat_mat="felt_black",
                   band="band_black", prop="gun_case", anims=("base", "sit", "talk")),
    # the railroad's yard detective, walking the platform with a lantern
    "yardman": dict(file="npc_yardman", height=1.84, build=1.15, belly=0.5, skin="skin_ruddy", hair="hair_dark", hair_style="short",
                    face=dict(jaw=1.2, nose=1.1, brow=1.25, chin=1.15, age=0.5), mustache=("walrus", 1.0), mustache_mat="hair_dark",
                    coat="overcoat", coat_mat="wool_brown", trousers="wool_brown", shoes="shoe_brown", tie=None, vest=None,
                    hat="bowler", hat_mat="felt_brown", band="band_black", prop="lantern", gloves=True, anims=("base", "lantern")),
    # a brakeman in a work coat and cap, also carrying a lamp
    "brakeman": dict(file="npc_brakeman", height=1.76, build=1.05, skin="skin_fair", hair="hair_sandy", hair_style="short",
                     face=dict(jaw=1.1, nose=1.05, brow=1.1, chin=1.05, age=0.3), mustache=("plain", 0.9), mustache_mat="hair_sandy",
                     coat="work", coat_mat="denim", trousers="denim", shoes="shoe_brown", tie=None, vest=None, hat="cap", hat_mat="wool_charcoal",
                     prop="lantern", gloves=True, anims=("base", "lantern")),
    # the car's porter, in the company's dark uniform and cap
    "porter": dict(file="npc_porter", height=1.78, build=1.0, skin="skin_brown", hair="hair_black", hair_style="short",
                   face=dict(jaw=1.05, nose=1.05, brow=1.05, chin=1.0, age=0.4), mustache=("plain", 0.9), mustache_mat="hair_black",
                   coat="sack", coat_mat="wool_navy", trousers="wool_navy", shoes="shoe_black", tie="tie_black", vest=None,
                   hat="porter", hat_mat="wool_navy", band="leather_black", buttons_mat="brass", anims=("base", "carry", "talk")),
    # the hooded figure who walks the club's lawn today
    "hooded": dict(file="hooded_figure", height=1.86, build=1.05, skin="skin_pale", hair=None, face=dict(age=0.5), coat="cloak",
                   coat_mat="cloak", trousers="cloak", shoes="shoe_black", tie=None, vest=None, hat="hood", hat_mat="cloak",
                   gloves=True, anims=("base",)),
}


def clean_scene(name):
    old = bpy.data.scenes.get(name)
    if old:
        for ob in list(old.objects):
            data = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if data is not None and getattr(data, "users", 1) == 0:
                if isinstance(data, bpy.types.Mesh):
                    bpy.data.meshes.remove(data)
                elif isinstance(data, bpy.types.Armature):
                    bpy.data.armatures.remove(data)
        bpy.data.scenes.remove(old)
    sc = bpy.data.scenes.new(name)
    return sc


def build(key):
    spec = CAST[key]
    scene_name = {"player": "Player_Character", "player_waiter": "Player_Waiter", "hooded": "NPC_Hooded"}.get(key, "NPC_" + key.capitalize())
    sc = clean_scene(scene_name)
    bpy.context.window.scene = sc if bpy.context.window else None
    try:
        bpy.context.window.scene = sc
    except Exception:
        pass
    coll = sc.collection
    mats = M()
    body = C.Body(spec.get("height", 1.8), spec.get("build", 1.0), spec.get("belly", 0.0), spec.get("shoulders", 1.0))
    # armature ops need the scene active
    for w in bpy.context.window_manager.windows:
        w.scene = sc
    rig = C.make_armature(key.capitalize(), body, coll)

    part = C.Part()
    face = C.Face(**spec.get("face", {}))
    skin = mats[spec["skin"]]
    coat = spec["coat"]
    cm = mats[spec["coat_mat"]]
    shirt = mats["shirt"]
    tie = mats.get(spec.get("tie") or "", None)
    vest = mats.get(spec.get("vest") or "", None)
    gloves = spec.get("gloves", False)

    C.add_legs(part, body, mats[spec["trousers"]], hem=0.1)
    C.add_shoes(part, body, mats[spec["shoes"]], mats["sole"], boot_top=0.16 if key in ("yardman", "brakeman") else 0.0)

    if coat == "cloak":
        C.add_torso(part, body, cm, {"v_depth": 1.6, "lapel": 0.0})
        C.add_skirt(part, body, cm, bottom=0.1, flare=1.45, split=True)
        C.add_arms(part, body, cm, None, mats["glove"], sleeve_r=1.25, gloves=True)
    else:
        opts = {"shirt": shirt, "tie": tie, "vest": vest, "button_mat": mats.get(spec.get("buttons_mat", ""), mats["horn"]),
                "pocket_mat": mats.get(spec.get("pocket") or "", None)}
        if coat == "overcoat":
            opts.update({"v_depth": 1.25, "lapel": 0.016, "buttons": 3})
            C.add_torso(part, body, cm, opts)
            C.add_skirt(part, body, cm, bottom=0.5, flare=1.22)
            C.add_arms(part, body, cm, shirt, mats["glove"] if gloves else skin, sleeve_r=1.12, gloves=gloves)
        elif coat == "frock":
            opts.update({"v_depth": 1.22, "lapel": 0.014, "buttons": 2})
            C.add_torso(part, body, cm, opts)
            C.add_skirt(part, body, cm, bottom=0.62, flare=1.15)
            C.add_arms(part, body, cm, shirt, skin, sleeve_r=1.05)
        elif coat == "sack":
            opts.update({"v_depth": 1.17, "lapel": 0.012, "buttons": 3})
            C.add_torso(part, body, cm, opts)
            C.add_skirt(part, body, cm, bottom=0.78, flare=1.06)
            C.add_arms(part, body, cm, shirt, skin, sleeve_r=1.0)
        elif coat == "steward":
            opts.update({"v_depth": 1.2, "lapel": 0.008, "buttons": 4, "button_mat": mats["brass"], "tie": None})
            C.add_torso(part, body, cm, opts)
            C.add_arms(part, body, cm, shirt, skin, sleeve_r=0.98)
        elif coat == "work":
            opts.update({"v_depth": 1.36, "lapel": 0.01, "buttons": 4, "shirt": mats["wool_gray"]})
            C.add_torso(part, body, cm, opts)
            C.add_skirt(part, body, cm, bottom=0.8, flare=1.05)
            C.add_arms(part, body, cm, None, mats["glove"] if gloves else skin, sleeve_r=1.05, gloves=gloves)
        C.add_collar(part, body, shirt)
    C.add_neck(part, body, skin)
    if spec.get("bowtie"):
        C.add_bowtie(part, body, mats[spec["bowtie"]])
    if spec.get("scarf"):
        C.add_scarf(part, body, mats[spec["scarf"]])
    if coat == "cloak":
        C.add_mantle(part, body, mats["cloak_sheen"])

    brows = mats[spec.get("brows") or spec.get("hair") or "hair_dark"]
    if coat == "cloak":
        C.add_head(part, body, face, mats["face_shadow"], mats["face_shadow"], mats["face_shadow"])
    else:
        C.add_head(part, body, face, skin, mats["eye"], brows)
    if spec.get("hair") and spec.get("hat") in (None, "boater", "bowler", "homburg", "top", "cap", "porter"):
        C.add_hair(part, body, face, mats[spec["hair"]], style=spec.get("hair_style", "short"), bald=spec.get("bald", 0.0))
    if spec.get("mustache"):
        kind, size = spec["mustache"]
        C.add_mustache(part, body, mats[spec.get("mustache_mat", spec.get("hair"))], kind, size)
    if spec.get("glasses"):
        C.add_glasses(part, body, mats["steel"])
    if spec.get("hat"):
        C.add_hat(part, body, face, spec["hat"], mats[spec["hat_mat"]], mats.get(spec.get("band") or "", None))
    if spec.get("prop"):
        pm = {"leather": mats["leather_brown"], "brass": mats["brass"], "wood": mats["wood"], "iron": mats["iron"],
              "lamp": mats["lamp"], "paper": mats["paper"]}
        C.add_prop(part, body, spec["prop"], pm, "R")

    ob = part.build(key.capitalize() + "Body", coll, rig, smooth=True)
    anims.build_all(rig, body.k, set(spec.get("anims", ("base",))))
    sc.frame_start = 1
    sc.frame_end = 100
    sc.render.fps = anims.FPS
    return sc, spec["file"]


def export(sc, fname):
    for w in bpy.context.window_manager.windows:
        w.scene = sc
    for d in (EXPORTS, MODELS):
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, fname + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_active_scene=True, export_apply=False,
                                  export_lights=False, export_cameras=False, export_animations=True,
                                  export_animation_mode="NLA_TRACKS", export_image_format="AUTO",
                                  export_skins=True, export_def_bones=False, export_optimize_animation_size=True)


def main(keys):
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    for key in keys:
        sc, fname = build(key)
        export(sc, fname)
        print("built", key, "->", fname)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    keys = [a for a in argv if a in CAST] or list(CAST.keys())
    main(keys)
