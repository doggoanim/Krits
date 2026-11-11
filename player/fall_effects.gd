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
@export var wiggle := 0.14             ## how far (m) a streak snakes sideways
@export var wiggle_speed := 11.0       ## how fast the snaking ripples along it

const SEGMENTS := 10

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
	var mat := ShaderMaterial.new()
	mat.shader = _streak_shader()
	mat.set_shader_parameter(&"wiggle", wiggle)
	mat.set_shader_parameter(&"wave_speed", wiggle_speed)
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

## Two thin strips crossed like an X, standing along Y and cut into several
## segments so the streak shader can bend them. Real geometry in the world (not
## camera-facing sprites), so from any angle a streak reads as a line of air.
## UV.y runs 0..1 along the length (the shader fades the tips with it).
static func _cross_mesh(width: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hl := length * 0.5
	for plane in 2:
		var x := Vector3(hw, 0, 0) if plane == 0 else Vector3(0, 0, hw)
		for seg in SEGMENTS:
			var t0 := float(seg) / SEGMENTS
			var t1 := float(seg + 1) / SEGMENTS
			var y0 := lerpf(-hl, hl, t0)
			var y1 := lerpf(-hl, hl, t1)
			var corners := [-x + Vector3(0, y0, 0), x + Vector3(0, y0, 0), x + Vector3(0, y1, 0), -x + Vector3(0, y1, 0)]
			var uvs := [Vector2(0, t0), Vector2(1, t0), Vector2(1, t1), Vector2(0, t1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uvs[idx])
				st.add_vertex(corners[idx])
	return st.commit()

## Unshaded white strip: tips fade out with UV.y, the whole thing fades with the
## particle's own colour alpha, and the body wiggles like a snaking ribbon — each
## streak with its own phase (taken from where it is in the world), tapering to
## nothing at the tips so they stay anchored.
static func _streak_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform float wiggle = 0.14;
uniform float wave_speed = 11.0;
uniform float wave_length = 3.2;
void vertex() {
	float phase = dot(NODE_POSITION_WORLD, vec3(12.9898, 78.233, 37.719));
	float along = VERTEX.y;
	float taper = 1.0 - smoothstep(0.55, 1.1, abs(along));
	float w = sin(along * wave_length + TIME * wave_speed + phase);
	float w2 = cos(along * wave_length * 0.8 + TIME * wave_speed * 0.9 + phase * 1.7);
	VERTEX.x += w * wiggle * taper;
	VERTEX.z += w2 * wiggle * taper;
}
void fragment() {
	float tips = sin(UV.y * 3.14159265);
	ALBEDO = vec3(1.0);
	ALPHA = clamp(tips * COLOR.a, 0.0, 1.0);
}
"""
	return sh

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
