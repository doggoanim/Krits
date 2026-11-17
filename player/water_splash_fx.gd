class_name WaterSplashFx
extends RefCounted
## A cartoon water splash: a crown of pointed water petals that shoots up and
## flares out, a quick white foam flash on the surface, two crisp ripple rings,
## round droplets flung in arcs and, for a big impact, a jet in the middle that
## rises and collapses. Everything is built in code (no assets), unshaded and
## flat-colored with a darker rim so it reads like the rest of the toon look.
##
##   WaterSplashFx.spawn(parent, waterline_position, strength)
##
## `strength` is the size of the impact: about 0.4 for climbing out, 0.8 for
## walking or hopping in, 1.8 for a fall from height or a ground pound.
## Fire and forget: it frees itself.

const WATER := Color(0.55, 0.78, 1.0)
const FOAM := Color(0.96, 0.99, 1.0)
const RIM := Color(0.32, 0.58, 0.9)

const PETALS_OUTER := 12
const PETALS_INNER := 8
const PETAL_SEGMENTS := 6
## Heights as a multiple of the strength (metres at strength 1).
const CROWN_HEIGHT := 0.5
const JET_HEIGHT := 1.2
const DROPLET_SPEED := 4.2
const BIG_STRENGTH := 1.5            ## from here a jet rises in the middle

static var _crown_mesh: ArrayMesh
static var _crown_shader: Shader
static var _drop_texture: Texture2D
static var _ring_texture: Texture2D
static var _disc_texture: Texture2D
static var _drop_quad: QuadMesh

static func spawn(parent: Node, pos: Vector3, strength := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	_prepare()
	var s := maxf(strength, 0.01)
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	_crown(root, s)
	_foam_flash(root, s)
	_ring(root, 4.2 * s, 0.8, 0.0, 0.85)
	_ring(root, 2.8 * s, 0.65, 0.12, 0.6)
	_droplets(root, s, 30, 1.0, 0.16)
	_droplets(root, s, 18, 1.6, 0.09)   # a finer, wider mist of small ones
	if s >= BIG_STRENGTH:
		_jet(root, s)
	root.get_tree().create_timer(1.6).timeout.connect(root.queue_free)

# ------------------------------------------------------------------- crown

## The crown: pointed petals standing in a ring, leaning outward, in two layers.
static func _crown(root: Node3D, s: float) -> void:
	var crown := MeshInstance3D.new()
	crown.mesh = _crown_mesh
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _crown_shader
	crown.material_override = mat
	root.add_child(crown)
	var radius := 0.75 * s
	var height := CROWN_HEIGHT * s
	crown.scale = Vector3(radius * 0.5, height * 0.05, radius * 0.5)
	crown.rotation.y = randf() * TAU
	var tw := crown.create_tween()
	# shoot up and flare out...
	tw.set_parallel(true)
	tw.tween_property(crown, "scale:y", height, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(crown, "scale:x", radius, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(crown, "scale:z", radius, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# ...then slump back down, widening, while fading
	tw.chain().set_parallel(true)
	tw.tween_property(crown, "scale:y", height * 0.25, 0.32).set_delay(0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(crown, "scale:x", radius * 1.3, 0.32).set_delay(0.06)
	tw.tween_property(crown, "scale:z", radius * 1.3, 0.32).set_delay(0.06)
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter(&"alpha", a), 1.0, 0.0, 0.3).set_delay(0.1)

## A bright white splat right at the surface the instant it breaks.
static func _foam_flash(root: Node3D, s: float) -> void:
	var disc := _flat_quad(root, _disc_texture, FOAM, 1.0)
	disc.scale = Vector3.ONE * 0.3 * s
	var mat := disc.material_override as StandardMaterial3D
	var tw := disc.create_tween().set_parallel(true)
	tw.tween_property(disc, "scale", Vector3.ONE * 2.4 * s, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_delay(0.08).set_ease(Tween.EASE_IN)

static func _ring(root: Node3D, max_scale: float, duration: float, delay: float, alpha: float) -> void:
	var ring := _flat_quad(root, _ring_texture, FOAM, alpha)
	ring.scale = Vector3.ONE * 0.4
	ring.visible = delay <= 0.0
	var mat := ring.material_override as StandardMaterial3D
	var tw := ring.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(ring.set_visible.bind(true))
	tw.tween_property(ring, "scale", Vector3.ONE * max_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)

## A flat, camera-independent quad lying on the water, unit size (scale it).
static func _flat_quad(root: Node3D, texture: Texture2D, color: Color, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees.x = -90.0
	mi.position.y = 0.04
	root.add_child(mi)
	return mi

# ----------------------------------------------------------------- droplets

## Round droplets thrown up and out, falling in arcs, shrinking as they go.
static func _droplets(root: Node3D, s: float, amount: int, speed_mult: float, size: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = maxi(int(amount * (0.5 + 0.5 * s)), 6)
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.randomness = 0.5
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 10, 12))
	var quad := _drop_quad.duplicate() as QuadMesh
	quad.size = Vector2.ONE * size
	p.draw_pass_1 = quad
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 48.0
	var v := DROPLET_SPEED * sqrt(s) * speed_mult
	m.initial_velocity_min = v * 0.55
	m.initial_velocity_max = v
	m.gravity = Vector3(0.0, -17.0, 0.0)
	m.scale_min = 0.7
	m.scale_max = 1.5 * (0.6 + 0.4 * s)
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.75, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = shrink
	m.scale_curve = curve_tex
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.25 * s
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.78, 0.9, 1.0, 0.9), Color(0.7, 0.86, 1.0, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	p.emitting = false
	root.add_child(p)
	p.restart()
	p.emitting = true

## For a big impact: a fat column of water in the middle that rises and drops back.
static func _jet(root: Node3D, s: float) -> void:
	var jet := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.32
	cyl.height = 1.0
	cyl.radial_segments = 14
	cyl.rings = 1
	jet.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(WATER.r + 0.15, WATER.g + 0.1, WATER.b, 0.95)
	jet.material_override = mat
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(jet)
	var h := JET_HEIGHT * s
	jet.scale = Vector3(s, 0.01, s)
	jet.position.y = 0.0
	var tw := jet.create_tween().set_parallel(true)
	tw.tween_property(jet, "scale:y", h, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(jet, "position:y", h * 0.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().set_parallel(true)
	tw.tween_property(jet, "scale:y", 0.01, 0.4).set_delay(0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(jet, "position:y", 0.0, 0.4).set_delay(0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(jet, "scale:x", s * 1.5, 0.4).set_delay(0.05)
	tw.tween_property(jet, "scale:z", s * 1.5, 0.4).set_delay(0.05)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_delay(0.1)

# ----------------------------------------------------------- shared resources

static func _prepare() -> void:
	if _crown_mesh != null:
		return
	_crown_shader = Shader.new()
	_crown_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform vec4 base_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform vec4 tip_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.32, 0.58, 0.9, 1.0);
uniform float alpha = 1.0;
void fragment() {
	float h = UV.y;
	vec3 c = mix(base_color.rgb, tip_color.rgb, smoothstep(0.1, 0.9, h));
	c = mix(c, tip_color.rgb, step(0.7, h) * 0.6);                // a lighter band toward the tips
	float edge = smoothstep(0.36, 0.44, abs(UV.x - 0.5));          // darker outline along the sides
	c = mix(c, rim_color.rgb, edge * (1.0 - h * 0.7));
	ALBEDO = c;
	ALPHA = alpha * 0.95;
}
"""
	_crown_mesh = _build_crown()
	_drop_texture = _radial([0.0, 0.7, 0.78, 1.0], [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_ring_texture = _radial([0.0, 0.6, 0.68, 0.82, 0.9, 1.0],
			[Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_disc_texture = _radial([0.0, 0.82, 0.92, 1.0], [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_drop_quad = QuadMesh.new()
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = _drop_texture
	_drop_quad.material = dm

static func _radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t

## Unit crown: petals of height ~1 around radius ~1, lean outward as they rise.
## UV.y runs 0 (base) to 1 (tip) along each petal and UV.x across its width.
static func _build_crown() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	_add_petals(st, rng, PETALS_OUTER, 0.62, 1.0, 0.34, 0.0)
	_add_petals(st, rng, PETALS_INNER, 0.4, 0.72, 0.26, 0.5)
	return st.commit()

static func _add_petals(st: SurfaceTool, rng: RandomNumberGenerator, count: int,
		base_radius: float, height: float, half_width: float, phase: float) -> void:
	for i in count:
		var a := TAU * (float(i) + phase) / count + rng.randf_range(-0.08, 0.08)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		var petal_h := height * rng.randf_range(0.75, 1.0)
		for seg in PETAL_SEGMENTS:
			var t0 := float(seg) / PETAL_SEGMENTS
			var t1 := float(seg + 1) / PETAL_SEGMENTS
			var v := [_petal_vertex(dir, side, base_radius, petal_h, half_width, t0, -1.0),
					_petal_vertex(dir, side, base_radius, petal_h, half_width, t0, 1.0),
					_petal_vertex(dir, side, base_radius, petal_h, half_width, t1, 1.0),
					_petal_vertex(dir, side, base_radius, petal_h, half_width, t1, -1.0)]
			var uv := [Vector2(0, t0), Vector2(1, t0), Vector2(1, t1), Vector2(0, t1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[idx])
				st.add_vertex(v[idx])

static func _petal_vertex(dir: Vector3, side: Vector3, base_radius: float, petal_h: float,
		half_width: float, t: float, side_sign: float) -> Vector3:
	var r := base_radius + 0.5 * pow(t, 1.5)                 # leans outward, more toward the tip
	var w := half_width * pow(1.0 - t, 0.7) * (1.0 + 0.3 * sin(t * PI))   # a bulge, then a point
	return dir * r + Vector3.UP * (t * petal_h) + side * (w * side_sign)
