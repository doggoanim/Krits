# Orb Odyssey RPG (Godot 4.7+)

Open `project.godot` in Godot 4.7+ and press F5. Everything is built in code from
small modules, so there are no hand-edited .tscn files besides `main.tscn` — but
that's just how this project started, not a rule: see "Building your own map"
below for hand-building levels visually in the editor, which works fine.

## Controls
WASD move · Mouse camera · Space jump · Shift roll (ground) / air dive (air) ·
Ctrl crouch (ground) / ground pound (air) · F1-F9 debug fight tools · Tab stats · M fast travel · O outfits · Esc free mouse

Tricks: roll+jump = long jump · jump right after a pound = high jump ·
dive, long-jump, or roll into a wall = wall bounce (pops you into the air;
dive/long-jump can chain another dive, rolling into one launches you off the
ground) · ground pound works out of a dive · stopping or sharply reversing
direction on the ground skids into a brief slide — no steering until it ends.

## Layout
- core/      Events (signal bus), Game (stats, flags, spawns, outfit, save), InputSetup
- player/    Player + PlayerConfig (all tunables), StateMachine, states/ (one file per move), camera,
             PlayerVisual (loads assets/player/krits.glb, plays its baked animations by name)
- assets/    player/krits.glb — rigged character + animations (idle, run, jump_start, falling, air_dive,
             roll_loop, long_jump, ground_pound, crouch_idle, crouch_walk, roll_collision, slide).
             Re-export over this file to update the model/animations.
- combat/    EncounterManager (float -> world dissolves -> square stage -> return) -> Arena (orbs, combo,
             walls, stage_root for its dissolving geometry), Enemy/EnemyData, Bullet + patterns/ (Radial, Aimed, Spiral; `pierces_shield` flag)
- stats/     PlayerStats (levels, 3 points per level into hp/shield/damage, shield recharge)
- outfits/   OutfitData + OutfitLibrary (cosmetic only)
- world/     WorldEnemy (pops in when near, wanders, touch = fight), Spawnpoint, TestLevel blockout,
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
   the minimal version of this if you want a code reference.
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

Each zone is currently one scene loaded wholesale at startup; multiple
interconnected zones with travel between them (the original "open world" spec)
isn't built yet — flag it if you want that next and we can design how zones
hand off to each other (loading a new scene on an Area3D trigger, keeping
the player's stats/flags via `Game`, etc.).
