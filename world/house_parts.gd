@tool
class_name HouseParts
extends RefCounted
## Small building pieces made from simple shapes with the project's toon shader: chimneys
## (four styles, with smoke), a dormer window, a weathervane, and door awnings / porches.
## Every builder returns a Node3D positioned by the caller; nothing here knows about
## houses (see HouseDressing, which decides who gets what and where).

const TOON: Shader = preload("res://shading/toon.gdshader")
const SMOKE_TEXTURE: Texture2D = preload("res://assets/sprites/smoke_puff.png")

const CHIMNEY_SFX := "res://sounds/SFX/others/chimney.ogg"
const BRICK := Color(0.62, 0.38, 0.32)
const BRICK_DARK := Color(0.4, 0.26, 0.24)
const PLASTER := Color(0.93, 0.88, 0.78)
const SLATE := Color(0.32, 0.3, 0.36)
const GLASS := Color(0.28, 0.4, 0.55)
const IRON := Color(0.2, 0.2, 0.23)
const WOOD_LIGHT := Color(0.72, 0.52, 0.32)
const WOOD_DARK := Color(0.45, 0.3, 0.2)
const MAT_RED := Color(0.6, 0.25, 0.25)

enum ChimneyStyle { PLAIN, TAPERED, ROUND, POTTED }
const STYLE_COUNT := 4
enum AwningStyle { AWNING, PORCH, STEP }

# ----------------------------------------------------------------- helpers

static func toon(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"albedo_texture", ModelUtil.white_texture())
	m.set_shader_parameter(&"albedo_color", color)
	m.set_shader_parameter(&"rim_strength", 0.0)
	return m

static func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, color, pos, rot_deg)

static func cylinder(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	return _part(parent, mesh, color, pos)

## Runs `start` each time `node` enters the tree (tweens and the like can't be made before).
static func when_in_tree(node: Node, start: Callable) -> void:
	node.tree_entered.connect(start)

## A looping 3D sound on `parent`, quiet beyond `max_distance`. Starts at a random point of
## the loop (so neighbours don't pulse in step) and never plays in the editor, where these
## @tool-built parts also appear.
static func add_loop_sound(parent: Node3D, path: String, volume_db: float, unit_size: float, max_distance: float, pos := Vector3.ZERO) -> void:
	if Engine.is_editor_hint():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	stream = stream.duplicate()   # the loaded resource is shared; don't change its loop flag for everyone
	if "loop" in stream:
		stream.set("loop", true)
	var p := AudioStreamPlayer3D.new()
	p.name = "LoopSound"
	p.stream = stream
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_distance
	p.position = pos
	parent.add_child(p)
	when_in_tree(p, func() -> void: p.play(randf() * maxf(stream.get_length() - 0.1, 0.0)))

static func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = toon(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

# ----------------------------------------------------------------- chimney

## A chimney standing on y = 0 of the returned node (the caller sinks it into the roof).
## `width` is its footprint, `height` the shaft's.
static func chimney(style: int, width: float, height: float, smoke: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Chimney"
	var top := height
	match style:
		ChimneyStyle.TAPERED:
			box(root, Vector3(width, height * 0.6, width), BRICK, Vector3(0, height * 0.3, 0))
			box(root, Vector3(width * 0.75, height * 0.4, width * 0.75), BRICK, Vector3(0, height * 0.8, 0))
			box(root, Vector3(width * 0.95, 0.14, width * 0.95), BRICK_DARK, Vector3(0, height + 0.07, 0))
			top = height + 0.14
		ChimneyStyle.ROUND:
			cylinder(root, width * 0.5, height, BRICK, Vector3(0, height * 0.5, 0))
			cylinder(root, width * 0.62, 0.16, BRICK_DARK, Vector3(0, height + 0.08, 0))
			top = height + 0.16
		ChimneyStyle.POTTED:
			box(root, Vector3(width, height, width), BRICK, Vector3(0, height * 0.5, 0))
			box(root, Vector3(width + 0.2, 0.16, width + 0.2), BRICK_DARK, Vector3(0, height + 0.08, 0))
			cylinder(root, width * 0.3, 0.5, Color(0.7, 0.4, 0.28), Vector3(0, height + 0.41, 0))
			top = height + 0.66
		_:
			box(root, Vector3(width, height, width), BRICK, Vector3(0, height * 0.5, 0))
			box(root, Vector3(width + 0.2, 0.18, width + 0.2), BRICK_DARK, Vector3(0, height + 0.09, 0))
			top = height + 0.18
	if smoke:
		root.add_child(_smoke(Vector3(0, top + 0.1, 0)))
		add_loop_sound(root, CHIMNEY_SFX, -10.0, 5.0, 40.0, Vector3(0, top, 0))
	return root

static func _smoke(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.fixed_fps = Choppy.particle_fps()   # re-simulated in steps, like the hand-made animations
	p.position = at
	p.amount = 8
	p.lifetime = 4.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.25, 0.1, 0.0)   # drifts off with the breeze
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.93, 0.93, 0.95, 0.5), Color(0.9, 0.9, 0.95, 0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = SMOKE_TEXTURE
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	return p

# ------------------------------------------------------------- roof extras

## A small gabled window sticking out of a roof slope. Local +Z is the way it faces.
## Its base is at y = 0 (the caller sinks it into the slope).
static func dormer() -> Node3D:
	var root := Node3D.new()
	root.name = "Dormer"
	box(root, Vector3(1.2, 1.0, 1.1), PLASTER, Vector3(0, 0.5, 0))
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 0.65, 1.4)
	_part(root, prism, SLATE, Vector3(0, 1.0 + 0.325, 0.05))
	box(root, Vector3(0.5, 0.55, 0.04), GLASS, Vector3(0, 0.55, 0.56))
	box(root, Vector3(0.62, 0.07, 0.1), WOOD_DARK, Vector3(0, 0.25, 0.58))   # sill
	return root

## A pole with an arrow that swings gently back and forth in the breeze.
static func weathervane() -> Node3D:
	var root := Node3D.new()
	root.name = "Weathervane"
	cylinder(root, 0.04, 1.2, IRON, Vector3(0, 0.6, 0))
	var arrow := Node3D.new()
	arrow.position.y = 1.15
	root.add_child(arrow)
	box(arrow, Vector3(0.7, 0.05, 0.05), IRON, Vector3.ZERO)
	box(arrow, Vector3(0.16, 0.22, 0.04), IRON, Vector3(-0.32, 0.0, 0.0))   # tail fin
	var head := PrismMesh.new()
	head.size = Vector3(0.22, 0.22, 0.05)
	_part(arrow, head, IRON, Vector3(0.38, 0.0, 0.0), Vector3(0, 0, -90))
	cylinder(root, 0.025, 0.4, IRON, Vector3(0, 1.0, 0))
	arrow.rotation_degrees.y = -35.0
	var swing := SteppedSwing.new()   # turns back and forth in held poses
	swing.name = "SteppedSwing"
	swing.axis = Vector3.UP
	swing.from_degrees = -35.0
	swing.to_degrees = 35.0
	swing.period = 6.4
	arrow.add_child(swing)
	return root

# ------------------------------------------------------------------- sign

## A wooden name plaque hung close to the wall: an iron rod held out from the wall by two
## short brackets, with the board hanging from it on two chains, `text` on both faces.
## The origin is the rod's height on the wall; +Z points out of the house; the board hangs
## below the origin.
static func hanging_sign(text: String, vertical := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Sign"
	var board_w := maxf(1.6, text.length() * 0.2 + 0.5)
	var board_h := 0.75
	var letters := text
	var font := 48
	var spacing := 0.0
	if vertical:   # a tall narrow board with the letters stacked top to bottom
		letters = "\n".join(Array(text.to_upper().split("")))
		font = 36
		spacing = -12.0   # pull the stacked letters closer together
		board_w = 0.8
		board_h = text.length() * 0.23 + 0.3
	var reach := 0.3            ## how far the plaque stands off the wall
	var chain := 0.3
	var rod_w := board_w - 0.1
	box(root, Vector3(rod_w, 0.07, 0.07), IRON, Vector3(0, 0, reach))                       # rod along the wall
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.07, 0.07, reach), IRON, Vector3(sx * (rod_w * 0.5 - 0.05), 0, reach * 0.5))   # brackets into the wall
	# everything below hangs from the rod and swings on it (see SwingingSign)
	var pivot := SwingingSign.new()
	pivot.name = "Swing"
	pivot.position = Vector3(0, 0, reach)
	root.add_child(pivot)
	var cy := -chain - board_h * 0.5
	for sx in [-1.0, 1.0]:
		cylinder(pivot, 0.02, chain, IRON, Vector3(sx * (board_w * 0.5 - 0.25), -chain * 0.5, 0))
	box(pivot, Vector3(board_w + 0.16, board_h + 0.16, 0.1), WOOD_DARK, Vector3(0, cy, 0))   # frame
	box(pivot, Vector3(board_w, board_h, 0.13), WOOD_LIGHT, Vector3(0, cy, 0))               # board
	for side in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = letters
		label.font_size = font
		label.line_spacing = spacing
		label.pixel_size = 0.007
		label.modulate = Color(0.2, 0.1, 0.05)
		label.outline_size = 0
		label.shaded = false
		label.double_sided = false
		label.position = Vector3(0, cy, side * 0.07)
		label.rotation.y = 0.0 if side > 0.0 else PI
		pivot.add_child(label)
	return root

# ------------------------------------------------------- awnings and porches

## A door canopy / porch / step, built for a door whose wall face is at z = 0 of the
## returned node and whose floor is y = 0. +Z points out of the house. `wood` tints it a
## little so the houses' entrances differ.
static func entrance(style: int, wood_shade: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Entrance"
	var wood := WOOD_LIGHT.lerp(WOOD_DARK, clampf(wood_shade, 0.0, 1.0))
	var dark := wood.darkened(0.3)
	match style:
		AwningStyle.PORCH:
			box(root, Vector3(2.8, 0.2, 1.9), wood, Vector3(0, 0.1, 0.95))                       # deck
			for sx in [-1.2, 1.2]:
				box(root, Vector3(0.14, 2.6, 0.14), dark, Vector3(sx, 1.5, 1.75))               # posts
			box(root, Vector3(3.0, 0.14, 2.1), dark, Vector3(0, 2.85, 1.0))                      # flat roof
		AwningStyle.STEP:
			box(root, Vector3(2.2, 0.24, 0.9), Color(0.6, 0.6, 0.62), Vector3(0, 0.12, 0.45))    # stone step
			box(root, Vector3(1.1, 0.04, 0.6), MAT_RED, Vector3(0, 0.26, 0.5))                   # doormat
		_:
			box(root, Vector3(2.4, 0.09, 1.4), wood, Vector3(0, 2.75, 0.62), Vector3(-18, 0, 0)) # slanted canopy
			for sx in [-0.85, 0.85]:
				box(root, Vector3(0.08, 0.08, 1.3), dark, Vector3(sx, 2.58, 0.55), Vector3(-30, 0, 0))   # diagonal struts, steeper than the canopy
	return root
