class_name Orb
extends Area3D
## Floating bounce target. Emits `hit` once, then waits to be relocated by the arena.
## Visual is a small glowing core (with the game's usual black cel outline) inside a
## tilted halo ring that spins continuously — reads as a distinct "magic" pickup
## rather than a plain sphere, and the spin/pulse alone sell "active" at a glance
## even before the player's close enough to see the color change.

signal hit(orb: Orb)

## What touching this orb does, set by Arena when it's spawned — purely a
## label the orb carries; it has no behavior of its own beyond picking its
## color and visual style (see _refresh()). Arena._on_orb_hit() is what
## actually interprets `kind` differently per equipped weapon:
## - PLAIN: the only kind Sword ever spawns — a normal combo hit, today's
##   behavior, unchanged.
## - ARROW/SHOOT: Bow's pair — touching an arrow orb stacks damage without
##   hitting anything; touching a shoot orb releases the whole stack at once
##   (and does nothing if nothing's stacked).
## - FIRE/ICE/EARTH: Staff's three runes — touching one queues it into
##   Arena's rune buffer without hitting anything (no bounce either, just a
##   collect — see Arena._handle_staff_hit()). CAST releases whatever's
##   queued as a spell looked up from that combination (see
##   Arena._lookup_spell()) — a single rune still does something on its own,
##   a learned combination does something better. Each element's own rune
##   also carries its usual status effect (fire burns, ice slows, earth
##   stuns — see Enemy.apply_burn()/apply_slow()/apply_stun()) when a spell
##   that includes it is cast.
enum Kind { PLAIN, ARROW, SHOOT, FIRE, ICE, EARTH, CAST }

## Core/ring color per kind, active state first in each pair — see _refresh().
## Only PLAIN's pair matches the original fixed ACTIVE_CORE_COLOR/
## ACTIVE_RING_COLOR this replaces. Fire/Ice/Earth's core colors (orange/
## light-blue/brown) are also what Arena's staff-overload burst uses (see
## Arena._overload_staff()) — one source of truth for "what color is this
## element" rather than duplicating them there.
const KIND_COLORS := {
	Kind.PLAIN: [Color(0.2, 0.9, 1.0), Color(0.85, 1.0, 1.0)],
	Kind.ARROW: [Color(0.35, 0.9, 0.35), Color(0.85, 1.0, 0.85)],
	Kind.SHOOT: [Color(1.0, 0.6, 0.15), Color(1.0, 0.9, 0.7)],
	Kind.FIRE: [Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.6)],
	Kind.ICE: [Color(0.4, 0.8, 1.0), Color(0.85, 0.97, 1.0)],
	Kind.EARTH: [Color(0.55, 0.35, 0.15), Color(0.85, 0.75, 0.6)],
	Kind.CAST: [Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0)],
}

## Kinds that are collected rather than fought over (Bow's arrow bank, every
## Staff rune) get the hollow-glass treatment in _refresh() plus a billboard
## icon identifying them, instead of the plain solid core every other kind
## uses. The value is the icon's texture path — drop an image in at that path
## and it'll show automatically; until then the icon node is just blank, no
## error (see _ready()'s ResourceLoader.exists() guard).
const ICON_TEXTURE_PATHS := {
	Kind.ARROW: "res://assets/sprites/icons/orb_arrow.png",
	Kind.FIRE: "res://assets/sprites/icons/orb_fire.png",
	Kind.ICE: "res://assets/sprites/icons/orb_ice.png",
	Kind.EARTH: "res://assets/sprites/icons/orb_earth.png",
}
const CORE_HOLLOW_ALPHA := 0.35   ## how see-through the glass-shell core is for ICON_TEXTURE_PATHS kinds

var kind: Kind = Kind.PLAIN
var _icon: Sprite3D   ## only built for ICON_TEXTURE_PATHS kinds — see _ready()

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

	if ICON_TEXTURE_PATHS.has(kind):
		_icon = Sprite3D.new()
		_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # always faces the player
		_icon.shaded = false
		_icon.double_sided = true
		_icon.no_depth_test = true   # reads clearly through the hollow core either way
		var path: String = ICON_TEXTURE_PATHS[kind]
		if ResourceLoader.exists(path):
			_icon.texture = load(path)
		# else: blank until the art's dropped in at that path — nothing to warn
		# about, this is the expected state until then.
		add_child(_icon)

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
	if _icon:
		_icon.position.y = bob

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
	VFX.shatter(get_parent() as Node3D, global_position, KIND_COLORS[kind][0])

## Starts high above `target` and falls down to it over `duration` — the
## arena's opening reveal (see Arena.play_intro()). `delay` staggers several
## orbs' falls relative to each other so they don't all land in lockstep.
## Purely a position tween; the player is frozen for the whole reveal, so
## there's no need to also gate hits while it's still mid-air.
func drop_in(target: Vector3, from_height: float, duration: float, delay := 0.0) -> void:
	global_position = target + Vector3.UP * from_height
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "global_position", target, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func relocate(pos: Vector3) -> void:
	global_position = pos
	active = true
	_refresh()

func _refresh() -> void:
	var colors: Array = KIND_COLORS[kind]
	# ICON_TEXTURE_PATHS kinds (arrow/fire/ice/earth — everything you collect
	# rather than fight over) get a hollow, semi-transparent "glass" core
	# instead of a solid one: CULL_FRONT on a closed sphere hides the near-
	# side faces, leaving the far-side inside wall visible through it, which
	# reads as hollow rather than solid. The ring (the "outer layer") stays
	# exactly as solid as every other kind — only the core changes.
	var hollow := ICON_TEXTURE_PATHS.has(kind)
	if active:
		_core_mat.albedo_color = colors[0]
		_core_mat.albedo_color.a = CORE_HOLLOW_ALPHA if hollow else 1.0
		_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if hollow else BaseMaterial3D.TRANSPARENCY_DISABLED
		_core_mat.cull_mode = BaseMaterial3D.CULL_FRONT if hollow else BaseMaterial3D.CULL_BACK
	else:
		_core_mat.albedo_color = INACTIVE_COLOR
		_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_core_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_ring_mat.albedo_color = colors[1] if active else INACTIVE_COLOR
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	if _outline_mat:
		_outline_mat.albedo_color.a = 1.0 if active else INACTIVE_COLOR.a
		_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	if _icon:
		_icon.visible = active
	_base_scale = 1.0 if active else 0.5
