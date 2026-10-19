class_name Orb
extends Area3D
## Floating bounce target. Emits `hit` once, then waits to be relocated by the arena.
## Visual is a small glowing core (with the game's usual black cel outline) inside a
## tilted halo ring that spins continuously — reads as a distinct "magic" pickup
## rather than a plain sphere, and the spin/pulse alone sell "active" at a glance
## even before the player's close enough to see the color change.

signal hit(orb: Orb)

const CORE_RADIUS := 0.4
const RING_INNER_RADIUS := 0.5
const RING_OUTER_RADIUS := 0.62
const RING_TILT := 55.0   ## degrees off horizontal
const OUTLINE_THICKNESS := 0.03
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.15
const PULSE_SPEED := 3.1       ## faster than the bob so the two don't lock in sync
const PULSE_AMOUNT := 0.06     ## fraction of scale the core breathes by
const RING_SPIN_SPEED := 1.6   ## rad/s while active
const RING_SPIN_SPEED_IDLE := 0.4   ## slow idle spin while waiting to respawn
const ACTIVE_CORE_COLOR := Color(0.2, 0.9, 1.0)
const ACTIVE_RING_COLOR := Color(0.85, 1.0, 1.0)
const INACTIVE_COLOR := Color(0.25, 0.3, 0.35, 0.3)

var active := true
var _mesh: MeshInstance3D
var _mesh_outline: MeshInstance3D
var _ring: MeshInstance3D
var _core_mat := StandardMaterial3D.new()
var _ring_mat := StandardMaterial3D.new()
var _outline_mat: StandardMaterial3D   ## the duplicate CelOutline.apply() makes — see _ready()
var _base_scale := 1.0   ## target scale from _refresh() (1.0 active, 0.5 inactive); the
                          ## per-frame breathing pulse multiplies on top of this
var _t := randf() * TAU

func _ready() -> void:
	collision_layer = 1 << 4   # layer 5: orb
	collision_mask = 1 << 1    # player
	var s := SphereShape3D.new()
	s.radius = 0.8
	var cs := CollisionShape3D.new()
	cs.shape = s
	add_child(cs)

	var sm := SphereMesh.new()
	sm.radius = CORE_RADIUS
	sm.height = CORE_RADIUS * 2.0
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sm
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = _core_mat
	add_child(_mesh)
	_mesh_outline = CelOutline.apply(_mesh, OUTLINE_THICKNESS)
	# CelOutline's own material is plain opaque black — left alone, it stays
	# fully solid even once the core fades to the translucent inactive color,
	# showing as a stray black ring poking out from behind/around it. Fade it
	# along with the core instead (see _refresh()).
	_outline_mat = _mesh_outline.material_override as StandardMaterial3D

	var tm := TorusMesh.new()
	tm.inner_radius = RING_INNER_RADIUS
	tm.outer_radius = RING_OUTER_RADIUS
	_ring = MeshInstance3D.new()
	_ring.mesh = tm
	_ring.rotation.x = deg_to_rad(RING_TILT)
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _ring_mat
	add_child(_ring)

	_refresh()

func _physics_process(delta: float) -> void:
	_t += delta * BOB_SPEED
	var bob := sin(_t) * BOB_HEIGHT
	_mesh.position.y = bob
	_ring.position.y = bob
	# The outline is a one-off duplicate sibling (see CelOutline), not a child of
	# _mesh, so it needs its own position kept in sync with the bob by hand.
	if _mesh_outline:
		_mesh_outline.position.y = bob

	var pulse := 1.0 + sin(_t * PULSE_SPEED) * PULSE_AMOUNT
	_mesh.scale = Vector3.ONE * (_base_scale * pulse)
	if _mesh_outline:
		_mesh_outline.scale = _mesh.scale
	_ring.scale = Vector3.ONE * _base_scale
	_ring.rotate_y(delta * (RING_SPIN_SPEED if active else RING_SPIN_SPEED_IDLE))

	if active:
		for b in get_overlapping_bodies():
			_try(b)

func _try(body: Node3D) -> void:
	if not active or not (body is Player):
		return
	var p := body as Player
	if p.dead or p.is_on_floor():
		return
	_break()
	hit.emit(self)

## Pops the orb exactly like a real hit (shatter effect, goes inactive) but
## without emitting `hit` — no combo, damage or player bounce. Used when a
## fight ends with orbs still unclaimed (see Arena._end()) so they visibly
## break apart instead of just vanishing along with the rest of the arena.
func break_apart() -> void:
	if active:
		_break()

func _break() -> void:
	active = false
	_refresh()
	VFX.shatter(get_parent() as Node3D, global_position, ACTIVE_CORE_COLOR)

func relocate(pos: Vector3) -> void:
	global_position = pos
	active = true
	_refresh()

func _refresh() -> void:
	_core_mat.albedo_color = ACTIVE_CORE_COLOR if active else INACTIVE_COLOR
	_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = ACTIVE_RING_COLOR if active else INACTIVE_COLOR
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	if _outline_mat:
		_outline_mat.albedo_color.a = 1.0 if active else INACTIVE_COLOR.a
		_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	_base_scale = 1.0 if active else 0.5
