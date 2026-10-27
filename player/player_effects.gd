class_name PlayerEffects
extends Node3D
## Movement particle effects — dust, dirt, smoke. Every ParticleProcessMaterial
## is built in code; every emitter's sprite is the same hand-drawn
## smoke_puff.png (assets/sprites/) regardless of what the effect is meant to
## read as (dust, dirt, smoke, water spray), recolored per effect via each
## one's own color_ramp (vertex_color_use_as_albedo). A separate grainy
## dirt_texture.png used to back the dust-specific effects, but its own
## baked-in brown base didn't take a tint cleanly (see _slime_drip_material_for()'s
## identical reasoning, which is what led here) and read inconsistently next
## to everything else once there were enough differently-tinted dust variants
## (grass/rock/dirt footsteps, water splash) to notice the mismatch — one
## texture, tinted every time, keeps all of it visually consistent.
##
## Two kinds of emitter:
## - Persistent, toggled on/off for as long as a move lasts (running dust,
##   the slime drip). Built once in _ready(). Dive/long-jump used to each
##   have their own continuous smoke/dust trail here too; removed once
##   PlayerSpeedTrail's ghost-afterimage trail covered the same "you're
##   moving fast" read on its own, so there was no need for both.
## - One-shot bursts (jump/land dust, wall-bounce and roll-collision
##   impacts): a fresh GPUParticles3D spawned per call and freed once it's
##   done playing, since these are rare, discrete events, not every frame.
##
## All particles use local_coords = false (world-space simulation), so a
## puff stays where it was emitted instead of sliding along with the player
## afterward — that's what turns continuous emission into a trailing effect.

const DUST_RAMP := [
	Color(0.62, 0.5, 0.33, 0.95),
	Color(0.75, 0.72, 0.62, 0.55),
	Color(0.8, 0.8, 0.8, 0.0),
]
const SMOKE_RAMP := [
	Color(0.95, 0.95, 0.97, 0.85),
	Color(0.8, 0.8, 0.85, 0.4),
	Color(0.8, 0.8, 0.85, 0.0),
]
## Alpha stops for the slime drip's ramp — the color itself is whatever
## SlimePuddle the player is currently standing in uses (see set_slime_drip()),
## not a fixed constant, so it always matches that puddle instead of one
## hardcoded green.
const SLIME_DRIP_ALPHAS := [0.9, 0.6, 0.0]

## Per-surface tints for burst_footstep_dust() — DIRT isn't listed; it reuses
## DUST_RAMP above (the default brown every other dust effect here already
## uses), so there's one fewer ramp to keep in sync whenever that changes.
const GRASS_DUST_RAMP := [
	Color(0.42, 0.55, 0.26, 0.85),
	Color(0.58, 0.64, 0.42, 0.5),
	Color(0.65, 0.68, 0.52, 0.0),
]
const ROCK_DUST_RAMP := [
	Color(0.58, 0.58, 0.6, 0.8),
	Color(0.68, 0.68, 0.7, 0.45),
	Color(0.72, 0.72, 0.74, 0.0),
]
const SPLASH_RAMP := [
	Color(0.85, 0.93, 1.0, 0.95),
	Color(0.8, 0.9, 1.0, 0.6),
	Color(0.8, 0.9, 1.0, 0.0),
]
## Air bubbles while submerged (see set_swim_bubbles()) — unlike every other
## ramp here, this tints toward plain white/fading-alpha rather than a real
## color: bubble.png (see BUBBLE_TEXTURE_PATH) is a hand-drawn bubble with its
## own outline and highlight already painted in, and vertex_color_use_as_albedo
## multiplies that art by this ramp — a blue tint (what every other water
## effect's ramp uses) would just muddy its outline instead of recoloring a
## plain soft blob the way it does for the shared smoke_puff.png sprite.
const BUBBLE_RAMP := [
	Color(1.0, 1.0, 1.0, 0.95),
	Color(1.0, 1.0, 1.0, 0.75),
	Color(1.0, 1.0, 1.0, 0.0),
]

const SMOKE_TEXTURE_PATH := "res://assets/sprites/smoke_puff.png"
const BUBBLE_TEXTURE_PATH := "res://assets/textures/bubble.png"

## Bubbles' own base rise speed/accel before update_bubble_ceiling() scales
## them down near the surface — see that method and _bubble_material().
const BUBBLE_BASE_VELOCITY_MIN := 0.5
const BUBBLE_BASE_VELOCITY_MAX := 1.0
const BUBBLE_BASE_GRAVITY := 1.4
## How far below the water's surface (meters) a bubble needs to be before
## update_bubble_ceiling() stops slowing it down at all — inside this margin
## its speed scales toward (but never quite reaches) zero. See that method.
const BUBBLE_CEILING_REFERENCE := 1.0

var _smoke_quad: QuadMesh
var _bubble_quad: QuadMesh
var _growth_curve: CurveTexture
var _dust_ramp_tex: GradientTexture1D
var _smoke_ramp_tex: GradientTexture1D
var _grass_dust_ramp_tex: GradientTexture1D
var _rock_dust_ramp_tex: GradientTexture1D
var _splash_ramp_tex: GradientTexture1D
var _bubble_ramp_tex: GradientTexture1D
var _ring_texture: GradientTexture2D
var _slime_drip_material: ParticleProcessMaterial   ## kept so set_slime_drip() can swap its color_ramp

var _run_dust: GPUParticles3D
var _slime_drip: GPUParticles3D
var _swim_bubbles: GPUParticles3D

func _ready() -> void:
	_smoke_quad = _make_quad_mesh(load(SMOKE_TEXTURE_PATH))
	_bubble_quad = _make_quad_mesh(load(BUBBLE_TEXTURE_PATH))
	_growth_curve = _make_growth_curve()
	_dust_ramp_tex = _make_ramp(DUST_RAMP)
	_smoke_ramp_tex = _make_ramp(SMOKE_RAMP)
	_grass_dust_ramp_tex = _make_ramp(GRASS_DUST_RAMP)
	_rock_dust_ramp_tex = _make_ramp(ROCK_DUST_RAMP)
	_splash_ramp_tex = _make_ramp(SPLASH_RAMP)
	_bubble_ramp_tex = _make_ramp(BUBBLE_RAMP)
	_ring_texture = SoftCircleTexture.make_ring()

	_run_dust = _build_emitter(_dust_material(3.0, 6.0, 0.35, 0.8), 14, 0.5, false, _smoke_quad)
	add_child(_run_dust)
	_slime_drip_material = _slime_drip_material_for(PlayerVisual.SLIME_TINT_COLOR)
	_slime_drip = _build_emitter(_slime_drip_material, 10, 0.6, false, _smoke_quad)
	_slime_drip.position.y = 1.0   # emit from around the torso, not the feet, so it reads as dripping off the character
	add_child(_slime_drip)
	_swim_bubbles = _build_emitter(_bubble_material(), 8, 1.2, false, _bubble_quad)
	_swim_bubbles.position.y = 1.3   # roughly head height, not the feet — bubbles rise off the face/chest
	add_child(_swim_bubbles)

# ---------------------------------------------------------------- continuous

func set_running_dust(active: bool) -> void:
	_run_dust.emitting = active

## Toggled by SwimState for as long as it's active — see that state's own
## enter()/exit().
func set_swim_bubbles(active: bool) -> void:
	_swim_bubbles.emitting = active

## Keeps bubbles from visibly rising past the water's own surface — unlike
## every other particle effect here, GPUParticles3D knows nothing about the
## world around it, so a bubble emitted underwater would just keep climbing
## along its programmed trajectory straight through the surface and out into
## open air. Called every physics frame while swimming (see
## SwimState.physics_update()), not just once on enter, since how close the
## emitter sits to the surface keeps changing as the player moves vertically
## through the water. `water` null (surfaced, or between WaterVolumes for a
## frame) just resets to the normal full rise speed — SwimState already stops
## emitting entirely in that case anyway, this just leaves nothing stale set
## for whenever it starts again.
##
## The process material's speed/gravity are read live by the GPU sim every
## frame, not just baked in once at spawn, so scaling them down here reaches
## bubbles already mid-flight too: `t` scales both toward (but never quite
## to) zero as the remaining margin below the surface shrinks, so a bubble
## crawls to a near-stop right as it nears the surface instead of sailing
## through it.
func update_bubble_ceiling(water: WaterVolume) -> void:
	var mat := _swim_bubbles.process_material as ParticleProcessMaterial
	if water == null:
		mat.initial_velocity_min = BUBBLE_BASE_VELOCITY_MIN
		mat.initial_velocity_max = BUBBLE_BASE_VELOCITY_MAX
		mat.gravity.y = BUBBLE_BASE_GRAVITY
		return
	var margin := water.surface_world_y() - (global_position.y + _swim_bubbles.position.y)
	var t := clampf(margin / BUBBLE_CEILING_REFERENCE, 0.08, 1.0)
	mat.initial_velocity_min = BUBBLE_BASE_VELOCITY_MIN * t
	mat.initial_velocity_max = BUBBLE_BASE_VELOCITY_MAX * t
	mat.gravity.y = BUBBLE_BASE_GRAVITY * t

## Driven by Player.enter_slime_puddle/exit_slime_puddle, alongside
## PlayerVisual.set_slimed — the green tint and the drip particles always
## turn on and off together. `color` is the specific puddle's own color
## (passed through from SlimePuddle.color, which varies per enemy), so the
## drip is recolored to match it each time — not a fixed green regardless of
## which puddle the player is actually standing in.
func set_slime_drip(active: bool, color := PlayerVisual.SLIME_TINT_COLOR) -> void:
	if active:
		# A fresh GradientTexture1D each time, rather than mutating the
		# existing one's Gradient in place and hoping the running
		# GPUParticles3D notices — assigning a whole new resource to the
		# material's color_ramp is the one change that's guaranteed to show
		# up, including on particles already mid-flight.
		_slime_drip_material.color_ramp = _make_ramp(_slime_drip_colors(color))
	_slime_drip.emitting = active

# ---------------------------------------------------------------- one-shot bursts

func burst_jump_dust() -> void:
	_burst(global_position, Vector3.UP, 35.0, _dust_material(4.0, 7.0, 0.3, 0.75), 8, 0.35, _smoke_quad)

func burst_land_dust() -> void:
	_burst(global_position, Vector3.UP, 60.0, _dust_material(5.5, 9.0, 0.5, 1.2), 16, 0.45, _smoke_quad)

## A small discrete puff synced to each footstep — see GroundState._play_footstep(),
## which already looks up the surface underfoot for PlayerAudio; this reuses
## that same lookup rather than probing again. Separate from
## set_running_dust()'s continuous trail above (a light haze for as long as
## you're sprinting): this adds a punchier per-step accent timed to the exact
## foot-plant, tinted by what's actually underfoot — dirt keeps the same
## brown every other dust effect here uses, grass kicks up less and greener,
## rock kicks up the least (a harder surface) and pale gray. `pos` is passed
## in rather than read from global_position since the caller already has the
## exact foot-level point its own floor probe found.
func burst_footstep_dust(pos: Vector3, surface: FootstepSurfaces.Surface) -> void:
	var ramp := _dust_ramp_tex
	var amount := 9
	var scale_max := 1.0
	match surface:
		FootstepSurfaces.Surface.GRASS:
			ramp = _grass_dust_ramp_tex
			amount = 7
			scale_max = 0.85
		FootstepSurfaces.Surface.ROCK:
			ramp = _rock_dust_ramp_tex
			amount = 6
			scale_max = 0.7
	# Noticeably bigger/more numerous than a first pass at this (originally
	# scale_max 0.4-0.6, amount 3-5): at those sizes it was indistinguishable
	# from set_running_dust()'s own continuous haze already filling the same
	# spot while running, essentially invisible as its own accent. This still
	# reads as a quick accent, not a cloud — one-shot at 0.4s lifetime — just
	# large enough to actually see land and settle each step.
	_burst(pos, Vector3.UP, 55.0, _material(5.0, 5.0, 0.4, scale_max, ramp), amount, 0.4, _smoke_quad)

## Entering/exiting a WaterVolume (see world/water/water_volume.gd): a droplet
## spray plus an expanding ring ripple, both at `pos` (the waterline, not the
## player's own position — see WaterVolume._waterline_pos()). `entering` only
## scales the spray back a bit for the exit case (climbing out kicks up less
## than diving in) — the ripple itself is the same either way, since the
## water's surface doesn't care which direction broke it.
## `big` is for entering fast enough (a fall from height, a ground pound)
## that a normal splash reads as too small for the impact — see
## WaterVolume._on_body_entered()'s own fall-speed check. Only ever true
## together with `entering`; exiting the water never gets the big version.
func burst_water_splash(pos: Vector3, entering: bool, big := false) -> void:
	var amount := 14 if entering else 8
	var speed := 4.5 if entering else 3.0
	var scale_max := 0.7
	var ripple_scale := 5.0
	var ripple_duration := 0.7
	if big:
		amount *= 3
		speed *= 1.8
		scale_max *= 1.6
		ripple_scale *= 1.8
		ripple_duration *= 1.3
	_burst(pos, Vector3.UP, 45.0, _material(speed, 7.0, 0.3, scale_max, _splash_ramp_tex), amount, 0.4, _smoke_quad)
	_spawn_ripple(pos, ripple_scale, ripple_duration)

## A small puddle ring + light spray at each footstep through shallow water
## (see GroundState._play_footstep()) — the same splash idiom as
## burst_water_splash() above, just a lot softer: a footstep barely breaks
## the surface compared to diving fully in. `surface_y` is the water's own
## top (WaterVolume.surface_world_y()), not the player's current Y, same
## reasoning as WaterVolume._waterline_pos().
func burst_water_footstep(pos: Vector3, surface_y: float) -> void:
	var waterline := Vector3(pos.x, surface_y, pos.z)
	_burst(waterline, Vector3.UP, 50.0, _material(3.0, 5.0, 0.25, 0.5, _splash_ramp_tex), 5, 0.3, _smoke_quad)
	_spawn_ripple(waterline, 2.0, 0.4)

## A small wake ripple left periodically while paddling at the surface (see
## SwimState's own timer — this isn't called every frame, just every so
## often, same spirit as a footstep). No particle burst at all, unlike the
## footstep/splash versions above — a continuous swim already reads as
## "disturbing the water" via the stroke sfx and the paddle animation
## itself; this is just a trailing ring, not an impact.
func burst_water_wake(pos: Vector3, surface_y: float) -> void:
	_spawn_ripple(Vector3(pos.x, surface_y, pos.z), 1.3, 0.6)

## A flat ring that grows and fades on the water's surface, independent of the
## player (unlike the particle bursts above, a ripple needs to sit still at
## the splash point while the player keeps swimming/walking away from it —
## see player_speed_trail.gd's identical reasoning for spawning its ghosts
## under the scene root rather than under the player). `max_scale`/`duration`
## default to a full splash's size — burst_water_footstep() above passes
## smaller ones for a puddle-sized ring instead.
func _spawn_ripple(pos: Vector3, max_scale := 5.0, duration := 0.7) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var mesh_inst := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	mesh_inst.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _ring_texture
	mat.albedo_color = Color(0.85, 0.93, 1.0, 0.85)
	mesh_inst.material_override = mat
	mesh_inst.rotation_degrees.x = -90.0   # lie flat, facing up out of the water
	scene_root.add_child(mesh_inst)
	mesh_inst.global_position = pos

	var tw := mesh_inst.create_tween()
	tw.tween_property(mesh_inst, "scale", Vector3.ONE * max_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(mesh_inst.queue_free)

## `normal` points away from the wall — the airborne dive/long-jump bounce,
## a softer puff of air/smoke since nothing solid hit the ground.
func burst_wall_impact(pos: Vector3, normal: Vector3) -> void:
	_burst(pos, normal, 55.0, _smoke_material(4.0, 0.0, 0.5, 1.1), 12, 0.4, _smoke_quad)

## Rolling into a wall on the ground — a punchier, dirtier burst than the
## airborne wall bounce above.
func burst_roll_collision(pos: Vector3, normal: Vector3) -> void:
	_burst(pos, normal, 60.0, _dust_material(6.0, 10.0, 0.55, 1.3), 18, 0.45, _smoke_quad)

# ---------------------------------------------------------------- building blocks

func _burst(pos: Vector3, direction: Vector3, spread_deg: float, mat: ParticleProcessMaterial,
		amount: int, lifetime: float, quad: QuadMesh) -> void:
	mat.direction = direction.normalized() if direction.length() > 0.01 else Vector3.UP
	mat.spread = spread_deg
	var p := _build_emitter(mat, amount, lifetime, true, quad)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.restart()
	get_tree().create_timer(lifetime + 0.3).timeout.connect(p.queue_free)

func _build_emitter(mat: ParticleProcessMaterial, amount: int, lifetime: float, one_shot: bool,
		quad: QuadMesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.randomness = 0.4
	p.local_coords = false
	p.draw_pass_1 = quad
	p.process_material = mat
	p.emitting = false   # continuous emitters wait for set_*(true); bursts are started explicitly below
	return p

func _make_quad_mesh(texture: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true   # lets each particle's process-material color tint this
	m.albedo_texture = texture
	q.material = m
	return q

## Particles grow slightly over their lifetime instead of starting at full
## size — reads as dust/smoke expanding rather than a static sprite.
func _make_growth_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.clear_points()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex

func _make_ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var n := colors.size()
	var offsets := PackedFloat32Array()
	for i in n:
		offsets.append(0.0 if n <= 1 else float(i) / float(n - 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

## `gravity_y` > 0 pulls particles down (dust settling); < 0 lifts them
## (smoke rising). `scale_min`/`scale_max` are multiples of the 0.4m quad.
func _dust_material(speed: float, gravity_y: float, scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	return _material(speed, gravity_y, scale_min, scale_max, _dust_ramp_tex)

func _smoke_material(speed: float, gravity_y: float, scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	return _material(speed, gravity_y, scale_min, scale_max, _smoke_ramp_tex)

func _material(speed: float, gravity_y: float, scale_min: float, scale_max: float,
		ramp: GradientTexture1D) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 35.0
	m.initial_velocity_min = speed * 0.6
	m.initial_velocity_max = speed
	m.gravity = Vector3(0.0, -gravity_y, 0.0)
	m.damping_min = 1.0
	m.damping_max = 2.5
	m.scale_min = scale_min
	m.scale_max = scale_max
	m.scale_curve = _growth_curve
	m.color_ramp = ramp
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.15
	return m

## Builds the drip's 3-stop fade-out ramp (start visible, dim, fully
## transparent — same alpha curve regardless of color) for whichever puddle
## color is currently active. See set_slime_drip().
func _slime_drip_colors(color: Color) -> Array:
	return [
		Color(color.r, color.g, color.b, 0.9),
		Color(color.r, color.g, color.b, 0.6),
		Color(color.r, color.g, color.b, 0.0),
	]

## Small droplets falling straight down off the body — unlike every other
## emitter here (all UP-biased, dust kicked up or smoke rising), this one
## needs its own direction, so it doesn't go through _material() above.
## `color` seeds its initial ramp; set_slime_drip() swaps color_ramp directly
## on the returned material afterward whenever the active puddle changes.
func _slime_drip_material_for(color: Color) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.DOWN
	m.spread = 20.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.8
	m.gravity = Vector3(0.0, -4.0, 0.0)
	m.damping_min = 0.5
	m.damping_max = 1.5
	m.scale_min = 0.25
	m.scale_max = 0.5
	m.scale_curve = _growth_curve
	m.color_ramp = _make_ramp(_slime_drip_colors(color))
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.35
	return m

## Air bubbles for set_swim_bubbles() — the one emitter here that
## accelerates UPWARD (a positive gravity_y, unlike every other effect's
## downward pull or the smoke materials' gentle upward drift) since a real
## bubble speeds up as it rises through water, the opposite of gravity.
##
## Deliberately skips scale_curve (every other emitter here uses
## _growth_curve so dust/smoke reads as expanding outward) — real bubbles
## don't swell from a pinprick over their lifetime, and sharing that curve
## actually hid the size variety scale_min/scale_max already rolls per
## particle: early in their short life every bubble sat near the curve's own
## small starting value regardless of its own random scale, so they all read
## as roughly the same size at a glance. Leaving scale_curve unset makes each
## bubble a constant size for its whole life, picked once at spawn — small
## and large bubbles both stay visibly themselves the entire time instead of
## briefly looking alike while still "growing in."
func _bubble_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 18.0
	m.initial_velocity_min = BUBBLE_BASE_VELOCITY_MIN
	m.initial_velocity_max = BUBBLE_BASE_VELOCITY_MAX
	m.gravity = Vector3(0.0, BUBBLE_BASE_GRAVITY, 0.0)
	m.damping_min = 0.0
	m.damping_max = 0.3
	m.scale_min = 0.04
	m.scale_max = 0.34
	m.color_ramp = _bubble_ramp_tex
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.3
	return m
