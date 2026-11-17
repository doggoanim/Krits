@tool
class_name FireFx
extends RefCounted
## One look for every fire in the game: hand-painted, stylised flames (shading/flame.gdshader)
## that lick and sway, plus the rising spark / ember particles the staff's burn effect has
## (yellow -> orange -> red, shrinking as they climb), drawn as little painted flecks instead
## of plain boxes. Used by the hearth and candles (InteriorParts) and by StatusFx's burn.
##
## flame() and embers() return nodes the caller positions; spark_mesh() is the particle
## mesh for anyone who builds their own particles (StatusFx uses GPU particles).

const SHADER: Shader = preload("res://shading/flame.gdshader")

const PALETTE_FIRE := [Color(0.78, 0.12, 0.06), Color(1.0, 0.42, 0.08), Color(1.0, 0.78, 0.2), Color(1.0, 0.96, 0.7)]
const PALETTE_CANDLE := [Color(0.85, 0.3, 0.06), Color(1.0, 0.6, 0.12), Color(1.0, 0.85, 0.35), Color(1.0, 0.98, 0.8)]
const EMBER_RAMP := [Color(1.0, 0.95, 0.4), Color(1.0, 0.5, 0.1), Color(0.8, 0.1, 0.05, 0.0)]

static var _fleck: Texture2D

## A cluster of flame tongues (a tall one in the middle, shorter ones either side), each
## flickering on its own. `height` and `width` size the biggest tongue; its base is at y 0.
static func flame(height: float, width: float, palette: Array = PALETTE_FIRE, tongues := 3, seed_value := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Flame"
	var layout := [
		[0.0, 1.0, 1.0, 0.0],      # [x offset, height scale, width scale, seed]
		[-0.32, 0.65, 0.75, 1.7],
		[0.3, 0.72, 0.8, 3.1],
		[0.08, 0.45, 0.6, 4.4],
	]
	for i in mini(tongues, layout.size()):
		var spec: Array = layout[i]
		var card := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var h: float = height * spec[1]
		var w: float = width * spec[2]
		quad.size = Vector2(w, h)
		card.mesh = quad
		card.position = Vector3(width * spec[0], h * 0.5, 0.0)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter(&"rim_color", palette[0])
		mat.set_shader_parameter(&"body_color", palette[1])
		mat.set_shader_parameter(&"core_color", palette[2])
		mat.set_shader_parameter(&"heart_color", palette[3])
		mat.set_shader_parameter(&"seed", float(spec[3]) + seed_value)
		mat.set_shader_parameter(&"speed", 1.0 + 0.15 * i)
		mat.render_priority = i   # the biggest at the back, small ones in front
		card.material_override = mat
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(card)
	return root

## Rising sparks like the staff's burn: yellow -> orange -> red, shrinking and fading.
static func embers(amount: int, lifetime: float, rise: float, radius: float, size := 0.1) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Embers"
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise
	p.gravity = Vector3(0.0, rise * 0.5, 0.0)   # they keep accelerating upward, like heat
	p.damping_min = 0.2
	p.damping_max = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.angle_min = -40.0
	p.angle_max = 40.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.color_ramp = ramp(EMBER_RAMP)
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = shrink
	p.mesh = spark_mesh(Vector2.ONE * size)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## A camera-facing quad with the painted fleck texture, tinted by the particle's colour.
static func spark_mesh(size: Vector2) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = fleck_texture()
	quad.material = m
	return quad

static func ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(0.0 if colors.size() <= 1 else float(i) / float(colors.size() - 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g

## A small teardrop with a slightly uneven edge, like a dab of paint (white; tinted per particle).
static func fleck_texture() -> Texture2D:
	if _fleck != null:
		return _fleck
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := 1.0 - (y + 0.5) / n * 2.0      # +1 top, -1 bottom
			var half := (1.0 - absf(v + 0.1) ) * 0.6 if v > -0.1 else sqrt(maxf(0.0, 1.0 - pow((v + 0.1) / 0.9, 2.0))) * 0.6
			var wobble := 0.06 * sin(v * 9.0 + u * 5.0)
			if absf(u) < half + wobble and v > -1.0 and v < 0.9:
				img.set_pixel(x, y, Color.WHITE)
	_fleck = ImageTexture.create_from_image(img)
	return _fleck
