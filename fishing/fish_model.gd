class_name FishModel
extends RefCounted
## A toon fish built from primitives (no model files yet), one design per
## species (SPECS): the project's banded toon shader (shading/toon.gdshader) and
## the shared screen-space outline, like the characters. 1 unit long, nose
## pointing along +X, so scale the returned node by the fish's length in metres.
## Used for the fish that leaps out of the water (FishingSession) and the one
## held up (HeldItem).
##
## Each species is a few numbers (body shape, belly and fin colours), one
## surface pattern and a list of extras; the pieces are generic:
##   patterns  stripe  bands  spots  patches  ear_spot  rainbow
##   extras    whiskers  snout  lantern  spikes  plates  long_fin  big_eyes

const TOON: Shader = preload("res://shading/toon.gdshader")
const INK := Color(0.12, 0.1, 0.14)

## len / h / w: body ellipsoid (length, height, thickness). fin: fin colour
## (default: a darker body). belly: underside colour (default: a paler body).
## accent: the pattern's colour.
const SPECS := {
	&"minnow": {"len": 0.78, "h": 0.26, "w": 0.2, "pattern": "stripe", "accent": Color(0.25, 0.3, 0.4)},
	&"perch": {"len": 0.74, "h": 0.4, "w": 0.24, "pattern": "bands", "accent": Color(0.15, 0.25, 0.12),
			"fin": Color(0.95, 0.5, 0.2), "belly": Color(0.95, 0.9, 0.6), "extras": ["long_fin"]},
	&"silver_trout": {"len": 0.82, "h": 0.32, "w": 0.22, "pattern": "spots", "accent": Color(0.25, 0.28, 0.4)},
	&"golden_koi": {"len": 0.8, "h": 0.36, "w": 0.28, "pattern": "patches", "accent": Color(1.0, 0.97, 0.9),
			"fin": Color(1.0, 0.9, 0.6), "extras": ["whiskers", "long_fin"]},
	&"bluegill": {"len": 0.62, "h": 0.55, "w": 0.2, "pattern": "ear_spot", "accent": Color(0.1, 0.1, 0.2),
			"belly": Color(0.98, 0.65, 0.3), "extras": ["long_fin"]},
	&"carp": {"len": 0.8, "h": 0.42, "w": 0.3, "pattern": "", "belly": Color(0.95, 0.88, 0.6),
			"extras": ["whiskers", "long_fin"]},
	&"catfish": {"len": 0.82, "h": 0.28, "w": 0.34, "pattern": "spots", "accent": Color(0.28, 0.24, 0.22),
			"belly": Color(0.85, 0.8, 0.7), "extras": ["whiskers", "big_eyes"]},
	&"pike": {"len": 0.9, "h": 0.22, "w": 0.18, "pattern": "spots", "accent": Color(0.75, 0.85, 0.5),
			"belly": Color(0.95, 0.95, 0.8), "extras": ["snout"]},
	&"rainbow_trout": {"len": 0.82, "h": 0.32, "w": 0.22, "pattern": "rainbow", "accent": Color(1.0, 0.45, 0.6),
			"belly": Color(0.98, 0.95, 0.9)},
	&"lantern_eel": {"len": 0.95, "h": 0.15, "w": 0.15, "pattern": "stripe", "accent": Color(0.3, 1.0, 0.9),
			"extras": ["lantern"]},
	&"moon_puffer": {"len": 0.6, "h": 0.6, "w": 0.55, "pattern": "spots", "accent": Color(0.55, 0.55, 0.8),
			"belly": Color(1.0, 0.98, 0.9), "extras": ["spikes", "big_eyes"]},
	&"old_sturgeon": {"len": 0.88, "h": 0.28, "w": 0.26, "pattern": "", "belly": Color(0.85, 0.85, 0.75),
			"extras": ["snout", "plates", "whiskers"]},
}
const DEFAULT_SPEC := {"len": 0.8, "h": 0.38, "w": 0.24, "pattern": ""}

static func build(id: StringName, color: Color) -> Node3D:
	var spec: Dictionary = SPECS.get(id, DEFAULT_SPEC)
	var root := Node3D.new()
	var len_b: float = spec["len"]
	var h: float = spec["h"]
	var w: float = spec["w"]
	var belly: Color = spec.get("belly", color.lightened(0.45))
	var fin: Color = spec.get("fin", color.darkened(0.2))
	var accent: Color = spec.get("accent", color.darkened(0.4))
	var extras: Array = spec.get("extras", [])

	# --- body: an ellipsoid with a paler underside
	_ball(root, color, Vector3.ZERO, Vector3(len_b, h, w))
	_ball(root, belly, Vector3(0.0, -h * 0.2, 0.0), Vector3(len_b * 0.92, h * 0.58, w * 0.94))
	_pattern(root, spec["pattern"], accent, len_b, h, w)

	# --- tail: two lobes
	var tail_x := -len_b * 0.5
	for lobe in [-1.0, 1.0]:
		var c := _cone(root, fin, Vector3(tail_x - 0.1, lobe * 0.06, 0.0), 0.075, 0.26, Vector3(1.0, 1.0, 0.3))
		c.rotation_degrees.z = -90.0 + lobe * 26.0
	# --- dorsal fin (a run of them for "long_fin")
	var dorsal := 4 if "long_fin" in extras else 1
	for i in dorsal:
		var x := lerpf(0.0, -0.22, float(i) / maxf(dorsal - 1.0, 1.0)) if dorsal > 1 else -0.04
		var ratio := sqrt(maxf(1.0 - pow(x / (len_b * 0.5), 2.0), 0.05))
		var d := _cone(root, fin, Vector3(x, h * 0.5 * ratio + 0.03, 0.0), 0.05 if dorsal > 1 else 0.09, 0.15 + 0.02 * float(i % 2), Vector3(1.0, 1.0, 0.25))
		d.rotation_degrees.z = 14.0
	# --- pectoral fins
	for side in [-1.0, 1.0]:
		var p := _ball(root, fin, Vector3(len_b * 0.15, -h * 0.2, side * w * 0.52), Vector3(0.15, 0.04, 0.09))
		p.rotation_degrees = Vector3(0.0, side * -20.0, side * 18.0)
	# --- eyes
	var eye_r := 0.085 if "big_eyes" in extras else 0.058
	for side in [-1.0, 1.0]:
		var ex := len_b * 0.3
		var ez := side * w * 0.42
		_ball(root, Color.WHITE, Vector3(ex, h * 0.14, ez), Vector3.ONE * eye_r * 2.0)
		_ball(root, INK, Vector3(ex + eye_r * 0.35, h * 0.14, ez + side * eye_r * 0.5), Vector3.ONE * eye_r * 1.1)

	for extra in extras:
		_extra(root, extra, color, fin, len_b, h, w)
	return root

# ---------------------------------------------------------------- patterns

static func _pattern(root: Node3D, pattern: String, accent: Color, len_b: float, h: float, w: float) -> void:
	match pattern:
		"stripe":   # a lateral line along the flank
			_ball(root, accent, Vector3(0.0, h * 0.04, 0.0), Vector3(len_b * 0.8, h * 0.12, w * 1.03))
		"rainbow":  # a wide coloured band, a thin dark line above it
			_ball(root, accent, Vector3(0.0, h * 0.02, 0.0), Vector3(len_b * 0.78, h * 0.2, w * 1.03))
			_ball(root, accent.lerp(Color(0.4, 0.8, 1.0), 0.6), Vector3(0.0, h * 0.2, 0.0), Vector3(len_b * 0.74, h * 0.07, w * 1.02))
		"bands":    # tall thin dark bands
			for x in [-0.2, -0.03, 0.14]:
				var r := _ratio(x, len_b)
				_ball(root, accent, Vector3(x, 0.0, 0.0), Vector3(0.05, h * r * 1.02, w * r * 1.04))
		"spots":
			var spots := [Vector2(0.24, 0.12), Vector2(0.08, 0.16), Vector2(-0.08, 0.1), Vector2(-0.22, 0.14),
					Vector2(0.15, 0.0), Vector2(-0.02, -0.02), Vector2(-0.16, 0.0)]
			for s: Vector2 in spots:
				var r := _ratio(s.x, len_b)
				for side in [-1.0, 1.0]:
					_ball(root, accent, Vector3(s.x, s.y * h * 2.0, side * w * 0.5 * r), Vector3(0.045, 0.045, 0.02))
		"patches":  # koi: big pale and dark blotches along the back
			var blots := [Vector3(0.18, 0.0, 0.18), Vector3(-0.05, 0.0, 0.22), Vector3(-0.22, 0.0, 0.16)]
			var colors := [accent, Color(0.95, 0.35, 0.15), accent]
			for i in blots.size():
				var b: Vector3 = blots[i]
				var r := _ratio(b.x, len_b)
				_ball(root, colors[i], Vector3(b.x, h * 0.42 * r, 0.0), Vector3(b.z, h * 0.12, w * 0.7 * r))
		"ear_spot": # bluegill's dark gill spot
			for side in [-1.0, 1.0]:
				_ball(root, accent, Vector3(len_b * 0.2, h * 0.02, side * w * 0.48), Vector3(0.09, 0.09, 0.03))

static func _ratio(x: float, len_b: float) -> float:
	return sqrt(maxf(1.0 - pow(x / (len_b * 0.5), 2.0), 0.05))

# ---------------------------------------------------------------- extras

static func _extra(root: Node3D, extra: String, color: Color, fin: Color, len_b: float, h: float, w: float) -> void:
	match extra:
		"whiskers":
			for side in [-1.0, 1.0]:
				for j in 2:
					var wk := _cone(root, INK, Vector3(len_b * 0.5 + 0.05, -h * 0.18 - 0.03 * float(j), side * (w * 0.2 + 0.03 * float(j))), 0.012, 0.16)
					wk.rotation_degrees = Vector3(0.0, side * -35.0, -90.0)   # apex forward along +X, swept sideways
		"snout":     # a long pointed jaw
			var s := _cone(root, color.lerp(Color.WHITE, 0.1), Vector3(len_b * 0.5 + 0.1, -h * 0.04, 0.0), h * 0.4, 0.26, Vector3(1.0, 0.7, 1.0))
			s.rotation_degrees.z = -90.0   # apex forward (+X)
		"lantern":   # an angler's glowing lure on a stalk
			var stalk := _cone(root, INK, Vector3(len_b * 0.45, h * 0.9, 0.0), 0.012, 0.3)
			stalk.rotation_degrees.z = -60.0
			var bulb := _ball(root, Color(0.6, 1.0, 0.95), Vector3(len_b * 0.45 + 0.17, h * 0.9 + 0.13, 0.0), Vector3.ONE * 0.12)
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color(0.6, 1.0, 0.95)
			bulb.material_override = glow
		"spikes":    # a puffer's little spines
			for i in 18:
				var f := (float(i) + 0.5) / 18.0
				var a := TAU * float(i) * 0.618
				var y := 1.0 - 2.0 * f
				var r := sqrt(1.0 - y * y)
				var dir := Vector3(cos(a) * r, y, sin(a) * r)
				if dir.x > 0.65:   # leave the face clear
					continue
				var surface := dir * Vector3(len_b, h, w) * 0.5
				var sp := _cone(root, color.lightened(0.3), surface, 0.02, 0.09)
				# Cones point +Y; rotate that onto the outward direction.
				sp.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), surface)
		"plates":    # a sturgeon's bony ridge
			for i in 6:
				var x := lerpf(0.2, -0.3, float(i) / 5.0)
				var r := _ratio(x, len_b)
				var pl := _cone(root, color.darkened(0.35), Vector3(x, h * 0.5 * r, 0.0), 0.035, 0.07, Vector3(1.4, 1.0, 1.0))
				pl.rotation_degrees.z = 10.0

# ---------------------------------------------------------------- pieces

static func _toon(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"albedo_texture", ModelUtil.white_texture())
	m.set_shader_parameter(&"albedo_color", color)
	m.set_shader_parameter(&"rim_strength", 0.0)
	return m

static func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _toon(color)
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	OutlineSystem.mark(mi)
	return mi

## A unit-diameter ball scaled to `size` (so an ellipsoid).
static func _ball(parent: Node3D, color: Color, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 14
	s.rings = 7
	return _add(parent, s, color, pos, size)

## A cone, apex +Y: base `radius`, `height` long.
static func _cone(parent: Node3D, color: Color, pos: Vector3, radius: float, height: float, scl := Vector3.ONE) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 8
	return _add(parent, c, color, pos, scl)
