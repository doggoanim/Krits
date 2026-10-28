# Orb Odyssey RPG (Godot 4.7+)

Open `project.godot` in Godot 4.7+ and press F5 — this boots `ui/main_menu.tscn`
(splash -> title -> save slots -> name prompt, see "Main menu" below), which hands
off to `main.tscn` for actual gameplay.
To iterate on gameplay without going through the menu every time, open
`main.tscn` directly and press F6 (run current scene) instead. Everything is
built in code from small modules, so there are no hand-edited .tscn files
besides `main.tscn` and `ui/main_menu.tscn` (both are just a bare root node with
a script attached — all their content is built in `_ready()`) — but that's just
how this project started, not a rule: see "Building your own map" below for
hand-building levels visually in the editor, which works fine.

## Main menu
`ui/main_menu.tscn` (script `ui/main_menu.gd`) is a controller over a persistent 3D
backdrop plus a stack of full-screen pages, shown one at a time with fades:

1. **Splash** (`ui/menu/splash_screen.tscn`) — opaque black card; any key skips. Assign the
   studio image to the `Image` node's texture in that scene (a dim placeholder label shows
   until you do).
2. **Stage** (`ui/menu/menu_stage.tscn`) — pitch-black world, a `StarField` of random white
   dots, and `MenuHero`: the real `krits.glb`, forced to flat white, tumbling freely on all
   three axes (`tumble_speed`) in a looping pose. After the splash it floats centred for a beat, then slides to the right.
   Its pose is a clip named like "main menu" (case/spaces/underscores ignored), else `idle` —
   export that clip from Blender and it's used automatically; if none is found a warning
   lists every clip the model has.
3. **Title** — big "Krits" on the left, blinking "Press any key to continue", then Play /
   Settings / Quit (the hand-drawn `assets/ui/button_1/2/3.png` as normal/hover/pressed,
   styled in `ui/menu/menu_theme.tres`).
4. **Save slots** — three tall rectangles (left/middle/right) + a small Return button. A
   used slot loads straight into the game; an empty one goes to the name prompt.
5. **Name prompt** — "What's my name?"; the first character typed snaps the box to "Krits"
   and the shared `DialogueBox` says "oh yeah I remember it now". Dismissing that line
   creates the save and starts the game.

Every page extends `MenuScreen` and only ever emits `navigate(target, payload)`; `MainMenu`
does the fading and choreography. To add a page: new `MenuScreen` scene, instance it in
`main_menu.tscn`, register it in `MainMenu._screens`.

Saves are three files (`user://save_slot_1..3.json`) managed by `Game` (`current_slot`,
`slot_summary()`, `start_new_game()`); an old single-file `user://save.json` is adopted as
slot 1 on first launch. `Game.player_name` is stored per save.

## Controls
WASD move · Mouse camera · Space jump · Shift roll (ground) / air dive (air) ·
Ctrl crouch (ground) / ground pound (air) · F1-F11 debug tools (see DebugTools) · Tab stats · M fast travel · Esc free mouse

Tricks: roll+jump = long jump · jump right after a pound = high jump ·
dive, long-jump, or roll into a wall = wall bounce (pops you into the air;
dive/long-jump can chain another dive, rolling into one launches you off the
ground) · ground pound works out of a dive · stopping or sharply reversing
direction on the ground skids into a brief slide — no steering until it ends ·
jumping out of a skid caused by reversing direction (not just stopping) does
a Mario 64-style side flip instead of a plain jump — higher arc, launches
toward the new direction.

## Layout
- shading/   toon.gdshader + toon_material.tres — the project-wide cel-shading look. ModelUtil
			 (core/) uses this automatically for every rigged character (see below): one dedicated
			 ShaderMaterial duplicated per mesh surface, same as the old DIFFUSE_TOON setup it
			 replaced, so flash-on-hit/slime-tint keep working via ModelUtil.get_tint()/set_tint()
			 rather than touching the shader directly. For a world prop instead, assign
			 toon_material.tres (or a copy of it) to a mesh surface/material override by hand. The
			 shadow edge is the main reason this exists over just using `diffuse_toon`: it overrides
			 light() so the shadow's own edge gets quantized by `shadow_threshold`/`shadow_softness`
			 exactly like the lit/dark band does, instead of a hard-banded diffuse term sitting next
			 to the engine's default soft PCF shadow blur. `rim_strength`/`specular_strength` default
			 to 0 (both effects off) — raise either to add a rim light or a toon specular highlight
			 band per-material. outline_overlay.gdshader is OutlineSystem's (core/) screen-space
			 edge-detect pass — see there for why outlines are a global compositor pass and not a
			 per-mesh effect.
- core/      Events (signal bus), Game (stats, flags, spawns, save), InputSetup,
			 OutlineSystem (one shared screen-space black outline around every character that opts
			 in via ModelUtil.apply_cel_shading()'s outline_hook — a single outer silhouette per
			 character rather than one inverted-hull outline per body-part mesh, which could leak a
			 stray line at seams between touching parts; see its own header comment for the full
			 technique),
			 VFX (one-shot particle effects usable from any Node3D, e.g. WorldEnemy's pop-in puff)
- player/    Player + PlayerConfig (all tunables), StateMachine, states/ (one file per move), camera,
			 PlayerVisual (loads assets/player/krits.glb, plays its baked animations by name),
			 PlayerEffects (particles), PlayerAudio (movement SFX, sounds/SFX/ — jump, long jump,
			 air dive, wall/roll bounce, skid, side flip, orb attack, footsteps, and the ground
			 pound's three phases (ready/jump/land); every one-shot gets a slight random
			 pitch_scale nudge except air dive and long jump, which stay fixed). Footsteps
			 are timed to the running clip's own loop (PlayerVisual.run_phase()), not a
			 fixed timer — see GroundState._update_footsteps().
- assets/    player/krits.glb — rigged character + animations (idle, run, jump_start1/2/3, falling,
			 air_dive, roll_loop, long_jump, ground_pound, ground_pound_land, crouch_idle,
			 crouch_walk, roll_collision, slide, side_jump, attack1/2/3). jump_start and attack
			 each have 3 interchangeable variants, picked at random per jump / per orb hit
			 (PlayerVisual).
			 Re-export over this file to update the model/animations.
- combat/    EncounterManager (a circular barrier dissolves into place right where the fight starts,
			 nobody teleports anywhere) -> Arena (orbs, combo, the circular wall, stage_root for its
			 dissolving geometry), Enemy/EnemyData, Bullet + patterns/ (Radial, Aimed, Spiral; `pierces_shield`
			 flag), SlimePuddle (damage/slow/no-jump ground hazard). EnemyData also supports an optional
			 telegraphed leap attack and a randomized burst-shoot volley (see EnemyLibrary.green_slime for
			 an enemy using both, plus a puddle trail) on top of the plain generic bullet patterns.
			 What touching an Orb does depends on the equipped WeaponData.kind (Arena._on_orb_hit()):
			 Sword is the plain combo hit above; Bow spawns ARROW/SHOOT orbs (arrows bank damage,
			 a shoot orb releases the whole bank, a shoot with nothing banked whiffs); Staff spawns
			 FIRE/ICE/EARTH rune orbs (touching one just queues it into a 3-slot buffer, no damage,
			 no bounce — a pickup, not a hit) plus one CAST orb per fight — touching CAST looks up
			 whatever's queued against a named spell table (Arena._build_spell_table()/
			 _lookup_spell(), Magicka-style), applying a damage multiplier plus each queued
			 element's own status effect via Enemy.apply_burn()/apply_slow()/apply_stun(); an
			 unlisted combination still falls back to a sensible default (_fallback_spell()) so no
			 cast is ever wasted. Queuing a 4th rune instead overloads the staff
			 (Arena._overload_staff()): self-damage that pierces the shield, a tri-color burst, and
			 a small outward/upward fling. ARROW/FIRE/ICE/EARTH orbs also render differently from
			 the rest (Orb._refresh()): a hollow, semi-transparent core with a billboard icon at the
			 center (Orb.ICON_TEXTURE_PATHS — drop an image in at that path and it shows
			 automatically) instead of the plain solid orb every other kind uses.
- stats/     PlayerStats (HP/Shield/Damage, entirely equipment-driven — see equipment/ — plus
			 gold and shield recharge; no levels)
- equipment/ EquipmentData (base: id/display_name/price) + ArmorData (HP), ShieldData (Shield),
			 WeaponData (Damage, plus a `kind` of Sword/Bow/Staff — each with its own orb
			 behavior in Arena, see combat/ above), EquipmentLibrary (the catalog, same
			 static-builder pattern as EnemyLibrary). ShopMenu (ui/) lists/buys/equips from it;
			 ShopKeeper (world/) is the in-world trigger that opens it.
- world/     Interactable (shared range/prompt/trigger base — floats a prompt while the player's in
			 range and able to use it, calls _interact() on press), NPC and ShopKeeper both extend it
			 (talk vs. open ShopMenu). Door also extends it: walking up and pressing interact swaps the
			 active level for its `target_level`, landing the player on whichever Spawnpoint/DoorSpawn
			 in it has `target_spawn_id` (see Main._on_level_travel_requested()/LoadingScreen (ui/) for
			 the cartoon iris wipe it happens behind). DoorSpawn is a lightweight interior-only arrival
			 marker (no fast-travel unlock/heal, unlike Spawnpoint). interior_room.tscn is a building-
			 interior blockout in the same per-box spirit as TestLevel, but as real scene nodes instead
			 of code: six separate thin StaticBody3D panels (Floor, Ceiling, WallNorth/South/East/West),
			 each with its own CollisionShape3D — a true hollow shell, not one solid block covering the
			 whole room (an earlier, code-generated version of this scene made exactly that mistake: one
			 BoxShape3D sized to the whole room is solid collision filling the ENTIRE volume, not a
			 hollow one, so anything spawned inside it got shoved out unpredictably — it read as falling
			 through/off the floor). The ceiling and walls use a cull_mode-FRONT material so what
			 renders is each panel's INNER face rather than its outer one; the floor uses the ordinary
			 cull-back material since its top face already faces the right way. Carries a ReturnDoor +
			 ReturnSpawn back out. Open it (or any interior duplicated from it) directly in the editor
			 to see/resize the room — nothing about its layout is generated at runtime anymore.
			 Duplicate the whole scene per distinct building, resize/reposition its panels to the new
			 room's shape, and swap in real wall/furniture assets later. house_1_interior.tscn is a
			 worked example of that duplication, for house_chesburg_1 — wired to a Door + DoorSpawn
			 (both children of that house node in chesburg.tscn, spawn_id `house_1_entrance`) placed
			 just outside its front wall; nudge their position in the editor if they don't line up with
			 the model's actual doorway, since the placement here is an estimate — the house's door
			 isn't a separate node in its .glb. Door.target_level and ReturnDoor's own target_level are
			 a .tscn PATH (@export_file), not a PackedScene export, and deliberately so: an interior's
			 return door normally points right back at the very level that placed the entrance Door
			 leading to it, so the two scenes reference each other, and a PackedScene export bakes that
			 into a real circular ext_resource dependency Godot's loader can deadlock on ("Parse Error:
			 Busy"). A path string carries no such edge — Door._interact() loads it lazily, only once
			 actually used. WorldEnemy (pops in
			 when near, wanders, touch = fight), Spawnpoint, WorldChunk (distance-based
			 visibility culling for a region), WorldGate (blocks a path until a story flag is set),
			 EnvironmentConfig (sun/sky/tonemap/glow/color-grading tunables), chesburg.tscn (the default
			 first area — a small plaza built from plain Godot nodes: boxes, cylinders, prisms, no
			 Blender or terrain plugin needed; open it in the editor and drag things around like any
			 other scene), TestLevel (a code-built mechanics-testing blockout, not a designed place —
			 still there if you want it, see main.gd's `level_scene` default),
			 WorldDissolver + world_dissolve.gdshader (world-space noise dissolve used by encounters),
			 water/ (water.tscn — a plain PlaneMesh/MeshInstance3D with water.gdshader already
			 assigned: toon-stepped shallow/deep color blend, layered sine-wave vertex motion, and
			 a fresnel rim; resize/instance it like any other prop, no script or extra setup needed.
			 No shoreline foam or real depth-based shading yet — the color banding is driven by the
			 wave height itself as a stand-in)
- ui/        Hud, menus (stats / travel), ScreenTransition + dissolve.gdshader (screen-space
			 fade utility, not currently wired up — kept in case a UI-level transition is wanted
			 later), LoadingScreen (a real cartoon iris wipe — iris_mask.gdshader draws solid black
			 outside a circular hole and fully transparent inside it, and the script just animates that
			 hole's radius down to a point and back out, rather than a decorative shape floating on an
			 already-opaque screen — built by UiRoot and driven entirely by Main's Door-swap handler, see
			 world/door.gd). Static layout for all
			 of these lives in their matching .tscn (hud.tscn,
			 main_menu.tscn, menu_base.tscn + stats_menu.tscn/travel_menu.tscn inheriting it,
			 screen_transition.tscn, loading_screen.tscn) — open any of them in the editor to move/resize things;
			 the .gd scripts just hold behavior now (refresh logic, tweens, signals). The two
			 exceptions are deliberate: PortraitSlot is a single custom-drawn Control with
			 nothing to lay out, and PortraitViewport builds its private mini 3D scene (lights,
			 camera, the live player model) in code because that camera rig is positioned from
			 runtime constants (Player.STAND_HEIGHT), not fixed numbers a scene could hold.

## Extending
- New move: add a `states/xxx_state.gd` extending PlayerState, register it in Player._ready.
- New/changed character animation: re-export assets/player/krits.glb from Blender (one glTF with every
  action as a separate Action/NLA strip — see PlayerVisual's ANIM_* constants for the clip names each
  state expects), then call `player.visual.play(&"clip_name")` from whichever state should use it.
- New bullet pattern: extend BulletPattern, implement fire().
- New enemy: add a static builder in EnemyLibrary (or save an EnemyData .tres).
- Story: use Game.set_flag / Game.flag; WorldEnemy ids save as `cleared_<id>` flags.
- Encounters: place a WorldEnemy (enemy_id + EnemyData). Enemies within 14m of the touched one join the fight and enlarge the stage.
- Large map performance: wrap a region's geometry in a WorldChunk (see "Building your own map" below).
- Progression blockers: a WorldGate with `required_flag` set opens itself once that story flag is set.
- Lighting / color grading: duplicate world/environment_config.gd's defaults as a `.tres`, tweak it, and
  assign it to Main's `env_config` in main.tscn — see "Lighting and color grading" below.

Not tested in-engine (no Godot binary was available while writing): expect to tune
PlayerConfig values and fix any small typing errors on first run.

## Building your own map
`world/test_level.gd` is just a blockout for trying the mechanics — it's not special,
and nothing requires levels to be built in code. To build a real level visually:

1. Create a new scene (`Scene > New Scene`), root node type `Node3D`. Save it
   somewhere under `world/` (or wherever you like), e.g. `world/chesburg.tscn`.
2. Build your geometry normally — meshes, `CSGShape3D`, imported models, whatever
   you like. Godot has no built-in sculptable terrain tool (unlike Unity); for
   basic-shapes environments, `CSGShape3D` primitives, a `GridMap` (tile-based,
   paint a `MeshLibrary` in the editor), or plain `StaticBody3D`+`MeshInstance3D`
   nodes (what `world/chesburg.tscn` uses) all cover this without Blender — see
   `chesburg.tscn` for a whole zone built from nothing but boxes, cylinders
   and prisms, editable like any other scene. For organic rolling terrain, add
   a heightmap plugin (Terrain3D,
   HTerrain, both free via AssetLib) or sculpt a mesh externally and import it.
   Anything that should be solid ground/walls needs a collision shape on
   **collision layer 1** (the "World" layer; `StaticBody3D` with its
   `collision_layer` set to just bit 1 checked). `_box()` in `test_level.gd` shows
   the minimal version of this if you want a code reference. Also check bit 8
   (`CameraRig.GROUND_LAYER`) on anything flat enough to walk on — floors,
   platforms, stairs — so the camera's own collision (it ignores ordinary
   walls/props on purpose, see CameraRig) treats it as ground instead of
   clipping straight through it.
3. Add fast-travel points: add child nodes of type `Spawnpoint` (it has a
   `class_name`, so it's searchable in the "Create New Node" dialog like any
   built-in node) and set `spawn_id` / `display_name` in the Inspector.
   `Game.last_spawn` (or `&"start"` on a fresh save) is where the player
   appears, so make sure one Spawnpoint has `spawn_id = "start"`.
4. Add overworld enemies: add child nodes of type `WorldEnemy`, and in the
   Inspector set `enemy_id` (unique per enemy, used for the `cleared_<id>` save
   flag) and `data` to an `EnemyData` resource — either one of `EnemyLibrary`'s
   builders saved as a `.tres`, or a new one you make.
5. Open `main.tscn`, select the "Main" node, and in the Inspector set its new
   **Level Scene** field to your new scene. That's the only code-side wiring
   needed — `main.gd` instantiates whatever you put there instead of TestLevel.

### One big interconnected map, with culling and progression gates

If most of the game is meant to be one continuous map rather than separate
zones you travel between, build it all as one scene (step 1 above still
applies — one `.tscn`) and use these two to keep it fast and gated:

- **WorldChunk** — wrap each region's geometry/props (a town, a cave, a hill)
  in a `WorldChunk` node (reparent that region's content underneath it) and
  position the WorldChunk itself near the region's center. It shows/hides
  that whole subtree based on distance to the player (`view_distance`,
  default 80m) so distant parts of the map simply aren't rendered. It
  doesn't touch collision or enemy logic — `WorldEnemy` already does its own
  closer-range spawn/despawn, which is the right granularity for actors;
  WorldChunk is for the geometry and set-dressing around them.
- **WorldGate** — a `StaticBody3D` you build like any solid obstacle (give it
  a `CollisionShape3D` and a visual — rubble, a sealed door, a magic wall),
  set its `required_flag` in the Inspector to a story flag name, and it
  blocks the path until `Game.set_flag(that_flag)` is called somewhere
  (a quest trigger, an NPC conversation, a boss defeat), at which point it
  opens itself live — no reload needed. Hook its `opened` signal if you want
  a custom animation or sound when it falls away instead of just vanishing.

Spawnpoints work the same as before for fast travel within this single map —
`M` just teleports the player to whichever unlocked Spawnpoint you pick, no
scene loading involved. A separate scene-per-zone setup (loading a new scene
when the player crosses a boundary) is a different, heavier approach for
when a single scene gets too large to keep open at once — not needed yet,
and we can build it later if the map grows to that scale.

## Lighting and color grading
All of this lived as a handful of hardcoded lines in `main.gd` before (one flat
sun, default sky colors, no tonemapping or color correction) — it's now a single
tunable resource, `world/environment_config.gd` (`EnvironmentConfig`), covering:

- **Sun**: color, brightness, angle, shadows on/off.
- **Sky**: top/horizon/ground colors (a `ProceduralSkyMaterial` under the hood —
  swap in an HDRI `PanoramaSkyMaterial` yourself later if you want a photo sky
  instead), ambient light strength.
- **Tonemap/exposure**: `tonemap_mode` defaults to Filmic (rolls off highlights
  instead of clipping them white) — ACES is the other common pick if Filmic
  looks too flat; exposure and white point adjust overall brightness/contrast
  of that curve.
- **Glow**: a soft bloom on bright areas — intensity/bloom/threshold.
- **Ambient occlusion (SSAO)**: contact shadows in corners/crevices, mostly
  what makes geometry stop looking flat.
- **Color grading**: brightness/contrast/saturation sliders for a quick grade,
  or drop in a LUT texture (`color_correction_lut`) for anyone using a real
  color-grading tool (e.g. exported from DaVinci Resolve/Photoshop as a
  256x16 PNG) for a fully custom look.

To use it: duplicate an `EnvironmentConfig` resource (`Resource > New Resource`
in the editor, search "EnvironmentConfig", save as a `.tres`), tweak its fields
in the Inspector, then open `main.tscn`, select "Main", and set its `env_config`
field to that `.tres`. Leaving it unset uses the defaults in the script, which
are reasonable but generic — the whole point of pulling this into a resource is
so you can iterate on the look without touching code, and keep a few different
presets (day/night, a moodier dungeon area, etc.) as separate `.tres` files if
you want per-region lighting later.

This only covers the one global `WorldEnvironment` — EncounterManager swaps a
couple of its fields (background/ambient) temporarily during a fight and
restores them after, so whatever look you set here carries into combat too.
