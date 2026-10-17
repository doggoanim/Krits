# Orb Odyssey RPG (Godot 4.7+)

Open `project.godot` in Godot 4.7+ and press F5. Everything is built in code from
small modules, so there are no hand-edited .tscn files besides `main.tscn`.

## Controls
WASD move · Mouse camera · Space jump · Shift roll (ground) / air dive (air) ·
Ctrl crouch (ground) / ground pound (air) · F1-F9 debug fight tools · Tab stats · M fast travel · O outfits · Esc free mouse

Tricks: roll+jump = long jump · jump right after a pound = high jump ·
dive or long-jump into a wall = wall bounce (can dive again, chain it).

## Layout
- core/      Events (signal bus), Game (stats, flags, spawns, outfit, save), InputSetup
- player/    Player + PlayerConfig (all tunables), StateMachine, states/ (one file per move), camera, visual
- combat/    EncounterManager (float -> dissolve -> square stage -> return) -> Arena (orbs, combo, walls), Enemy/EnemyData,
             Bullet + patterns/ (Radial, Aimed, Spiral; `pierces_shield` flag)
- stats/     PlayerStats (levels, 3 points per level into hp/shield/damage, shield recharge)
- outfits/   OutfitData + OutfitLibrary (cosmetic only)
- world/     WorldEnemy (pops in when near, wanders, touch = fight), Spawnpoint, TestLevel blockout
- ui/        Hud, menus (stats / travel / outfits), ScreenTransition + dissolve.gdshader

## Extending
- New move: add a `states/xxx_state.gd` extending PlayerState, register it in Player._ready.
- New bullet pattern: extend BulletPattern, implement fire().
- New enemy: add a static builder in EnemyLibrary (or save an EnemyData .tres).
- Story: use Game.set_flag / Game.flag; WorldEnemy ids save as `cleared_<id>` flags.
- Encounters: place a WorldEnemy (enemy_id + EnemyData). Enemies within 14m of the touched one join the fight and enlarge the stage.

Not tested in-engine (no Godot binary was available while writing): expect to tune
PlayerConfig values and fix any small typing errors on first run.
