class_name FallEffects
extends Node3D
## The longer and faster you fall, the more it shows: white speed streaks rush
## past the player and the model stretches taller and thinner. Both scale with
## downward speed between `start_speed` and the player's terminal velocity, and
## ease back out the moment you stop falling.
##
## Created by Player (add it after `visual`). The stretch scales the visual
## node as a whole, so it layers on top of the squash/stretch pops that act on
## the model inside it.

@export var start_speed := 26.0        ## m/s downward before anything shows
@export var start_drop := 7.0          ## metres fallen before anything shows (a small hop or step never counts)
@export var full_drop := 22.0          ## metres fallen for the full effect
@export var full_stretch_y := 1.35     ## model height multiplier at terminal speed
@export var full_stretch_xz := 0.85
@export var stretch_follow := 10.0     ## how quickly the stretch eases in/out
@export var streak_radius := 3.0       ## how far out from the player streaks appear
@export var streak_max_amount := 60

var _player: Player
var _amount := 0.0          ## 0..1 current intensity (smoothed)
var _streaks: CPUParticles3D

func _ready() -> void:
	_player = get_parent() as Player
	_streaks = CPUParticles3D.new()
	_streaks.emitting = false
	_streaks.local_coords = false   # streaks stay in the world, so the player visibly falls past them
	_streaks.amount = streak_max_amount
	_streaks.lifetime = 0.45
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_streaks.emission_sphere_radius = streak_radius
	_streaks.direction = Vector3.UP
	_streaks.spread = 0.0
	_streaks.gravity = Vector3.ZERO
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A thin quad turned along its travel direction, fading out toward both
	# tips (so a streak has no hard ends) and fading in/out over its life (so
	# it never pops into or out of existence).
	var quad := _cross_mesh(0.07, 2.2)
	var tip := Gradient.new()
	tip.set_color(0, Color(1, 1, 1, 0))
	tip.set_color(1, Color(1, 1, 1, 0))
	tip.add_point(0.5, Color(1, 1, 1, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = tip
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.surface_set_material(0, mat)
	_streaks.particle_flag_align_y = true
	var life := Gradient.new()
	life.set_color(0, Color(1, 1, 1, 0))
	life.set_color(1, Color(1, 1, 1, 0))
	life.add_point(0.2, Color(1, 1, 1, 0.75))
	life.add_point(0.6, Color(1, 1, 1, 0.75))
	_streaks.color_ramp = life
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(1.0, 0.25))
	_streaks.scale_amount_curve = shrink
	_streaks.mesh = quad
	add_child(_streaks)

## Two thin quads crossed like an X, standing along Y. They're real geometry
## in the world (not camera-facing sprites), so from any angle a streak reads
## as a solid line of air rather than a flat card turned toward the lens.
static func _cross_mesh(width: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hl := length * 0.5
	for plane in 2:
		var x := Vector3(hw, 0, 0) if plane == 0 else Vector3(0, 0, hw)
		var corners := [-x + Vector3(0, -hl, 0), x + Vector3(0, -hl, 0), x + Vector3(0, hl, 0), -x + Vector3(0, hl, 0)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])
	return st.commit()

func _physics_process(delta: float) -> void:
	if _player == null or _player.visual == null:
		return
	var target := 0.0
	if _is_falling():
		var top := maxf(_player.config.terminal_velocity - start_speed, 1.0)
		var by_speed := clampf((-_player.velocity.y - start_speed) / top, 0.0, 1.0)
		var by_drop := clampf((_player.fall_drop() - start_drop) / maxf(full_drop - start_drop, 1.0), 0.0, 1.0)
		target = minf(by_speed, by_drop)
	_amount = lerpf(_amount, target, 1.0 - exp(-stretch_follow * delta))
	if _amount < 0.01:
		_amount = 0.0
	_player.visual.scale = Vector3(lerpf(1.0, full_stretch_xz, _amount), lerpf(1.0, full_stretch_y, _amount), lerpf(1.0, full_stretch_xz, _amount))
	_update_streaks()

func _is_falling() -> bool:
	if _player.dead or _player.is_on_floor() or _player.velocity.y >= 0.0:
		return false
	return _player.machine.current_name != &"Swim"

func _update_streaks() -> void:
	_streaks.emitting = _amount > 0.05
	if not _streaks.emitting:
		return
	_streaks.global_position = _player.global_position + Vector3.UP * 1.0
	# Streaks rush upward past the falling player, faster the harder the fall.
	var speed := absf(_player.velocity.y) * 1.1
	_streaks.initial_velocity_min = speed * 0.8
	_streaks.initial_velocity_max = speed * 1.2
	_streaks.scale_amount_min = 0.7 + _amount
	_streaks.scale_amount_max = 1.0 + _amount * 1.5
