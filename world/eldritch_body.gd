@tool
class_name EldritchBody
extends Node3D
## The look of the KillerFish: something that was a fish a long time ago. A
## swollen violet body with a lumpy second lobe, one huge slit-pupilled eye and
## a scatter of small ones, a toothed maw ringed by writhing tentacles, two
## flailing side arms, long tentacles trailing behind and a ridge of dorsal
## spikes. Pure visuals: KillerFish builds one and calls set_agitation().
##
##   agitation 0  drifting: slow, lazy writhing, a sickly yellow eye
##   agitation 1  hunting:  tentacles streamed back, thrashing fast, eye burning red
##
## Faces -Z (its swim direction), `length` metres from nose to rear. Built in
## _ready() and animated in _process(), so it also runs in the editor viewport.

const SEGMENTS := 7
const MOUTH_TENTACLES := 8
const TRAIL_TENTACLES := 4
const TEETH := 10
const OUTLINE := 0.03

const TENTACLE_TIP := Color(1.0, 0.25, 0.75)
const EYE_CALM := Color(0.85, 1.0, 0.2)
const EYE_ANGRY := Color(1.0, 0.12, 0.08)
const BONE := Color(0.92, 0.9, 0.78)

var length := 1.8
var flesh := Color(0.26, 0.1, 0.32)

var _agitation := 0.0          ## target, set by the owner
var _agit := 0.0               ## eased toward it
var _t := 0.0
var _core: Node3D              ## everything but the tentacles' roots sway with this
var _eye_mat: StandardMaterial3D
var _big_eye: Node3D
var _tentacles: Array[Dictionary] = []   ## {segments, phase, calm_dir, hunt_dir, root, long}

static func create(body_length: float, flesh_color: Color) -> EldritchBody:
	var b := EldritchBody.new()
	b.length = body_length
	b.flesh = flesh_color
	return b

func set_agitation(value: float) -> void:
	_agitation = clampf(value, 0.0, 1.0)

func _ready() -> void:
	_t = randf() * 10.0
	_core = Node3D.new()
	add_child(_core)
	_build_body()
	_build_eyes()
	_build_maw()
	_build_spikes()
	_build_tentacles()

# ---------------------------------------------------------------- materials

func _toon(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

# ---------------------------------------------------------------- the pieces

func _build_body() -> void:
	var L := length
	var skin := _toon(flesh)
	var main := _mesh(_core, _sphere(0.5), skin, Vector3.ZERO, Vector3(0.55, 0.5, 0.95) * L)
	CelOutline.apply(main, OUTLINE)
	# The swollen second lobe at the back, paler and bruised.
	var lobe := _mesh(_core, _sphere(0.5), _toon(flesh.lerp(Color(0.5, 0.35, 0.55), 0.45)),
			Vector3(0.0, 0.05, 0.3) * L, Vector3(0.42, 0.44, 0.5) * L)
	CelOutline.apply(lobe, OUTLINE)
	# A sickly belly lump.
	_mesh(_core, _sphere(0.5), _toon(flesh.lerp(Color(0.5, 0.65, 0.45), 0.5)),
			Vector3(0.0, -0.18, -0.05) * L, Vector3(0.36, 0.2, 0.55) * L)

func _build_eyes() -> void:
	var L := length
	_eye_mat = _glow(EYE_CALM)
	_big_eye = Node3D.new()
	_big_eye.position = Vector3(0.0, 0.1, -0.4) * L
	_core.add_child(_big_eye)
	_mesh(_big_eye, _sphere(0.13 * L), _eye_mat, Vector3.ZERO)
	# The slit pupil, sitting on the eye's front.
	_mesh(_big_eye, _sphere(0.5), _glow(Color(0.02, 0.0, 0.05)),
			Vector3(0.0, 0.0, -0.125 * L), Vector3(0.035, 0.2, 0.025) * L)
	# A scatter of small ones, off-kilter on purpose.
	var spots := [Vector3(0.26, 0.12, -0.1), Vector3(-0.26, 0.1, -0.12), Vector3(0.2, 0.2, 0.15),
			Vector3(-0.22, 0.19, 0.2), Vector3(0.05, 0.27, 0.02), Vector3(-0.29, -0.02, 0.3)]
	for p: Vector3 in spots:
		_mesh(_core, _sphere(0.04 * L), _eye_mat, p * L)

func _build_maw() -> void:
	var L := length
	var centre := Vector3(0.0, -0.08, -0.46) * L
	_mesh(_core, _sphere(0.5), _glow(Color(0.35, 0.0, 0.08)), centre, Vector3(0.3, 0.2, 0.1) * L)
	var tooth := CylinderMesh.new()
	tooth.top_radius = 0.0
	tooth.bottom_radius = 0.025 * L
	tooth.height = 0.13 * L
	tooth.radial_segments = 5
	var bone := _toon(BONE)
	for i in TEETH:
		var a := TAU * float(i) / TEETH
		var mi := _mesh(_core, tooth, bone, centre + Vector3(cos(a) * 0.14, sin(a) * 0.09, -0.04) * L)
		mi.rotation_degrees.x = -90.0   # points forward (-Z)

func _build_spikes() -> void:
	var L := length
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.03 * L
	spike.height = 0.2 * L
	spike.radial_segments = 5
	var mat := _toon(flesh.darkened(0.25))
	for i in 6:
		var z := lerpf(-0.2, 0.55, float(i) / 5.0)
		var h := 0.24 + 0.05 * sin(float(i) * 2.3)
		var mi := _mesh(_core, spike, mat, Vector3(0.0, h, z) * L)
		mi.rotation_degrees.x = 25.0   # raked back

func _build_tentacles() -> void:
	var L := length
	# Around the maw, reaching forward and out.
	for i in MOUTH_TENTACLES:
		var a := TAU * (float(i) + 0.5) / MOUTH_TENTACLES
		var root_pos := Vector3(cos(a) * 0.2, -0.08 + sin(a) * 0.13, -0.44) * L
		var calm := Vector3(cos(a) * 0.7, sin(a) * 0.6 - 0.1, -1.0).normalized()
		var hunt := Vector3(cos(a) * 0.5, sin(a) * 0.4, 0.9).normalized()
		_add_tentacle(root_pos, calm, hunt, 0.11 * L, 0.045 * L, float(i) * 0.9, false)
	# Long ones trailing behind.
	for i in TRAIL_TENTACLES:
		var a := TAU * float(i) / TRAIL_TENTACLES + 0.4
		var root_pos := Vector3(cos(a) * 0.14, sin(a) * 0.12, 0.5) * L
		var calm := Vector3(cos(a) * 0.5, sin(a) * 0.4 - 0.15, 1.0).normalized()
		_add_tentacle(root_pos, calm, calm, 0.17 * L, 0.05 * L, float(i) * 1.7 + 3.0, true)
	# Two flailing arms from the flanks.
	for side in [-1.0, 1.0]:
		var calm := Vector3(side * 1.0, -0.5, -0.3).normalized()
		var hunt := Vector3(side * 0.6, -0.1, 0.8).normalized()
		_add_tentacle(Vector3(side * 0.26, -0.1, -0.15) * L, calm, hunt, 0.13 * L, 0.05 * L, side * 2.0 + 5.0, false)

## One tentacle: a chain of tapering capsules, each a child of the last so a
## single rotation per joint bends the whole rest of it. It points along its
## local -Z; the last joint carries a glowing tip.
func _add_tentacle(root_pos: Vector3, calm: Vector3, hunt: Vector3, seg_len: float, radius: float,
		phase: float, long: bool) -> void:
	var root := Node3D.new()
	root.position = root_pos
	root.basis = Basis.looking_at(calm)
	_core.add_child(root)
	var skin := _toon(flesh.lerp(Color(0.6, 0.2, 0.5), 0.35))
	var segs: Array[Node3D] = []
	var parent: Node3D = root
	for i in SEGMENTS:
		var joint := Node3D.new()
		if i > 0:
			joint.position = Vector3(0.0, 0.0, -seg_len)
		parent.add_child(joint)
		var taper := 1.0 - float(i) / float(SEGMENTS)
		var cap := CapsuleMesh.new()
		cap.radius = radius * (0.25 + 0.75 * taper)
		cap.height = seg_len * 1.25
		cap.radial_segments = 8
		cap.rings = 2
		var mi := _mesh(joint, cap, skin, Vector3(0.0, 0.0, -seg_len * 0.5))
		mi.rotation_degrees.x = 90.0
		if i == SEGMENTS - 1:
			_mesh(joint, _sphere(radius * 0.4), _glow(TENTACLE_TIP), Vector3(0.0, 0.0, -seg_len))
		segs.append(joint)
		parent = joint
	_tentacles.append({"root": root, "segments": segs, "phase": phase, "calm": calm, "hunt": hunt, "long": long})

# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	if _core == null:
		return
	_agit = move_toward(_agit, _agitation, delta * 3.0)
	var rate := lerpf(1.6, 7.0, _agit)
	_t += delta * rate
	var amp := lerpf(0.2, 0.36, _agit)

	# The whole body breathes and slithers.
	var breath := sin(_t * 0.7) * 0.03
	_core.scale = Vector3(1.0 + breath, 1.0 - breath, 1.0)
	_core.rotation.y = sin(_t * 0.5) * lerpf(0.06, 0.14, _agit)

	# The eye pulses, and burns red when it hunts.
	_big_eye.scale = Vector3.ONE * (1.0 + 0.07 * sin(_t * 1.3))
	_eye_mat.albedo_color = EYE_CALM.lerp(EYE_ANGRY, _agit)

	for tn in _tentacles:
		var root: Node3D = tn["root"]
		var dir: Vector3 = (tn["calm"] as Vector3).lerp(tn["hunt"], _agit * 0.9).normalized()
		root.basis = Basis.looking_at(dir)
		var segs: Array = tn["segments"]
		var phase: float = tn["phase"]
		var speed := 1.0 if not tn["long"] else 0.7
		for i in segs.size():
			var reach := 0.35 + 0.9 * float(i) / float(SEGMENTS)
			var joint: Node3D = segs[i]
			joint.rotation.x = sin(_t * speed - float(i) * 0.8 + phase) * amp * reach
			joint.rotation.y = cos(_t * speed * 0.8 - float(i) * 0.7 + phase * 1.3) * amp * reach
