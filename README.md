# Orb Odyssey RPG (Godot 4.7+)

Open `project.godot` in Godot 4.7+ and press F5 — this boots `ui/main_menu.tscn`
(New Game / Continue / Quit), which hands off to `main.tscn` for actual gameplay.
To iterate on gameplay without going through the menu every time, open
`main.tscn` directly and press F6 (run current scene) instead. Everything is
built in code from small modules, so there are no hand-edited .tscn files
besides `main.tscn` and `ui/main_menu.tscn` (both are just a bare root node with
a script attached — all their content is built in `_ready()`) — but that's just
how this project started, not a rule: see "Building your own map" below for
hand-building levels visually in the editor, which works fine.

## Controls
WASD move · Mouse camera · Space jump · Shift roll (ground) / air dive (air) ·
Ctrl crouch (ground) / ground pound (air) · F1-F11 debug tools (see DebugTools) · Tab stats · M fast travel · O outfits · Esc free mouse

Tricks: roll+jump = long jump · jump right after a pound = high jump ·
dive, long-jump, or roll into a wall = wall bounce (pops you into the air;
dive/long-jump can chain another dive, rolling into one launches you off the
ground) · ground pound works out of a dive · stopping or sharply reversing
direction on the ground skids into a brief slide — no steering until it ends ·
jumping out of a skid caused by reversing direction (not just stopping) does
a Mario 64-style side flip instead of a plain jump — higher arc, launches
toward the new direction.

## Layout
- core/      Events (signal bus), Game (stats, flags, spawns, outfit, save), InputSetup,
			 VFX (one-shot particle effects usable from any Node3D, e.g. WorldEnemy's pop-in puff)
- player/    Player + PlayerConfig (all tunables), StateMachine, states/ (one file per move), camera,
			 PlayerVisual (loads assets/player/krits.glb, plays its baked animations by name),
			 PlayerEffects (particles), PlayerAudio (movement SFX, sounds/SFX/ — jump, long jump,
			 air dive, wall/roll bounce, skid, side flip, orb attack, footsteps, and the ground
			 pound's three phases (ready/jump/land); every one-shot gets a slight random
			 pitch_scale nudge except air dive and long jump, which stay fixed)
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
- stats/     PlayerStats (levels, 3 points per level into hp/shield/damage, shield recharge)
- outfits/   OutfitData + OutfitLibrary (cosmetic only)
- world/     WorldEnemy (pops in when near, wanders, touch = fight), Spawnpoint, WorldChunk (distance-based
			 visibility culling for a region), WorldGate (blocks a path until a story flag is set),
			 EnvironmentConfig (sun/sky/tonemap/glow/color-grading tunables), TestLevel blockout,
			 WorldDissolver + world_dissolve.gdshader (world-space noise dissolve used by encounters)
- ui/        Hud, menus (stats / travel / outfits), ScreenTransition + dissolve.gdshader (screen-space
			 fade utility, not currently wired up — kept in case a UI-level transition is wanted later)

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
   somewhere under `world/` (or wherever you like), e.g. `world/hometown.tscn`.
2. Build your geometry normally — meshes, `CSGShape3D`, imported models, whatever
   you like. Anything that should be solid ground/walls needs a collision shape on
   **collision layer 1** (the "World" layer; `StaticBody3D` with its
   `collision_layer` set to just bit 1 checked). `_box()` in `test_level.gd` shows
   the minimal version of this if you want a code reference. Also check bit 8
   (`CameraRig.GROUND_LAYER`) on anything flat enough to walk on — floors,
   platforms, stairs — so the camera's own collision (it ignores ordinary
   walls/props on purpose, see CameraRig) treats it as ground instead of
   clipping straight through it.
3. Add fast-travel points: add child nodes of type `Spawnpoint` (it has a
   `class_name`, so it's searchable in the "Create New Node" dialog like any
   built-in node) and set `spawn_id` / `display_name` / `unlocks_outfit` in the
   Inspector. `Game.last_spawn` (or `&"start"` on a fresh save) is where the
   player appears, so make sure one Spawnpoint has `spawn_id = "start"`.
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
