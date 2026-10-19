# Orb Odyssey RPG (Godot 4.7+)

Open `project.godot` in Godot 4.7+ and press F5. Everything is built in code from
small modules, so there are no hand-edited .tscn files besides `main.tscn`.

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
