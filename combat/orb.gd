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
	Kind.PLAIN: [Color(1.0, 0.2, 0.2), Color(1.0, 0.8, 0.8)],   # sword: red
	Kind.ARROW: [Color(0.3, 0.9, 0.3), Color(0.85, 1.0, 0.85)],   # bow: green
	Kind.SHOOT: [Color(0.3, 0.9, 0.3), Color(0.85, 1.0, 0.85)],
	Kind.FIRE: [Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.6)],
	Kind.ICE: [Color(0.4, 0.8, 1.0), Color(0.85, 0.97, 1.0)],
	Kind.EARTH: [Color(0.55, 0.35, 0.15), Color(0.85, 0.75, 0.6)],
	Kind.CAST: [Color(0.65, 0.3, 1.0), Color(0.9, 0.8, 1.0)],   # magic: purple
}

## Kinds drawn as a hollow glass shell (the collectibles: arrows and the
## element runes); every other kind is a solid core. See _refresh().
const HOLLOW_KINDS: Array[Kind] = [Kind.ARROW, Kind.FIRE, Kind.ICE, Kind.EARTH]

## Every orb has a billboard icon in its center, tinted with the orb's own
## color (see orb_icon.gdshader). The
## value is the icon's texture path; a missing file just leaves the center
## empty (see _ready()'s ResourceLoader.exists() guard) — the element runes'
## art isn't made yet.
const ICON_TEXTURE_PATHS := {
	Kind.PLAIN: "res://assets/ui/sword_icon.png",
	Kind.ARROW: "res://assets/ui/arrow_icon.png",
	Kind.SHOOT: "res://assets/ui/bow_icon.png",
	Kind.CAST: "res://assets/ui/staff_icon.png",
	Kind.FIRE: "res://assets/sprites/icons/orb_fire.png",
	Kind.ICE: "res://assets/sprites/icons/orb_ice.png",
	Kind.EARTH: "res://assets/sprites/icons/orb_earth.png",
}
const OUTLINE_SHADER := preload("res://combat/orb_outline.gdshader")
const ICON_SHADER := preload("res://combat/orb_icon.gdshader")
const ICON_SIZE := 0.62   ## world-space width/height of the icon quad
const CORE_HOLLOW_ALPHA := 0.35   ## how see-through the glass-shell core is

var kind: Kind = Kind.PLAIN
var _icon: MeshInstance3D   ## billboard icon quad — see _ready()
var _icon_mat: ShaderMaterial

const CORE_RADIUS := 0.4
const RING_INNER_RADIUS := 0.5
const RING_OUTER_RADIUS := 0.62
const RING_TILT := 55.0   ## degrees off horizontal
const OUTLINE_THICKNESS := 0.055   ## bold, cartoony black outline
const SHADOW_RADIUS := 0.55         ## ground blob shadow under the orb
const SHADOW_ALPHA := 0.3
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
var _hollow := false
var _outline_mat: Material   ## hollow kinds: rim-only ShaderMaterial (orb_outline.gdshader); solid kinds: CelOutline's plain black material
var _base_scale := 1.0   ## target scale from _refresh() (1.0 active, 0.5 inactive); the
                          ## per-frame breathing pulse multiplies on top of this
var _t := randf() * TAU
var _pop := 1.0            ## squash-and-stretch multiplier on the visuals, tweened by _punch()
var _shadow: MeshInstance3D   ## flat blob on the ground below, so you can judge where the orb is

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
	_hollow = kind in HOLLOW_KINDS
	if _hollow:
		# A plain inverted hull would show its far wall through the glass as a
		# dark fill, so hollow cores get the rim-only outline shader instead.
		var rim := ShaderMaterial.new()
		rim.shader = OUTLINE_SHADER
		rim.set_shader_parameter(&"grow", OUTLINE_THICKNESS)
		rim.set_shader_parameter(&"core_radius", CORE_RADIUS)
		_mesh_outline.material_override = rim
	# CelOutline's own material is plain opaque black — left alone it would
	# stay solid once the core fades to the inactive color, so _refresh()
	# fades it along with the core.
	_outline_mat = _mesh_outline.material_override

	var tm := TorusMesh.new()
	tm.inner_radius = RING_INNER_RADIUS
	tm.outer_radius = RING_OUTER_RADIUS
	_ring = MeshInstance3D.new()
	_ring.mesh = tm
	_ring.rotation.x = deg_to_rad(RING_TILT)
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _ring_mat
	add_child(_ring)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ICON_SIZE
	_icon_mat = ShaderMaterial.new()
	_icon_mat.shader = ICON_SHADER
	_icon_mat.render_priority = 1   # over the core, ring and outline
	var path: String = ICON_TEXTURE_PATHS.get(kind, "")
	if path != "" and ResourceLoader.exists(path):
		_icon_mat.set_shader_parameter(&"icon", load(path))
	else:
		_icon_mat.set_shader_parameter(&"fade", 0.0)   # no art yet — draw nothing
	_icon = MeshInstance3D.new()
	_icon.mesh = quad
	_icon.material_override = _icon_mat
	_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_icon)

	_build_shadow()
	_refresh()

func _build_shadow() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = SHADOW_RADIUS
	disc.bottom_radius = SHADOW_RADIUS
	disc.height = 0.01
	disc.radial_segments = 20
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, SHADOW_ALPHA)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.material_override = mat
	_shadow.top_level = true   # stays on the ground while the orb floats/bobs above
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)

func _update_shadow() -> void:
	var arena := get_parent() as Arena
	if arena == null or _shadow == null:
		return
	var ground := arena.ground_height(global_position)
	_shadow.global_position = Vector3(global_position.x, ground + 0.05, global_position.z)
	var height := maxf(global_position.y - ground, 0.0)
	_shadow.scale = Vector3.ONE * clampf(1.0 - height * 0.1, 0.4, 1.0) * _base_scale
	_shadow.visible = active

## Squash-and-stretch pop (drop landing, respawn).
func _punch(from: float) -> void:
	_pop = from
	create_tween().tween_property(self, "_pop", 1.0, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

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
	_mesh.scale = Vector3.ONE * (_base_scale * pulse * _pop)
	if _mesh_outline:
		_mesh_outline.scale = _mesh.scale
	_ring.scale = Vector3.ONE * (_base_scale * _pop)
	_ring.rotate_y(delta * (RING_SPIN_SPEED if active else RING_SPIN_SPEED_IDLE))

	if Engine.get_physics_frames() % 3 == 0:
		_update_shadow()
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
	tw.tween_callback(_punch.bind(0.6))   # lands with a squash

func relocate(pos: Vector3) -> void:
	global_position = pos
	active = true
	_refresh()
	_punch(0.01)   # pops back in

func _refresh() -> void:
	var colors: Array = KIND_COLORS[kind]
	# Hollow kinds: CULL_FRONT on a closed sphere hides the near-side faces,
	# leaving the far-side inside wall visible through it, which reads as
	# hollow rather than solid. The outline and the ring stay solid.
	if active:
		_core_mat.albedo_color = colors[0]
		_core_mat.albedo_color.a = CORE_HOLLOW_ALPHA if _hollow else 1.0
		_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _hollow else BaseMaterial3D.TRANSPARENCY_DISABLED
		_core_mat.cull_mode = BaseMaterial3D.CULL_FRONT if _hollow else BaseMaterial3D.CULL_BACK
	else:
		_core_mat.albedo_color = INACTIVE_COLOR
		_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_core_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_ring_mat.albedo_color = colors[1] if active else INACTIVE_COLOR
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	var outline_alpha := 1.0 if active else INACTIVE_COLOR.a
	if _outline_mat is ShaderMaterial:
		(_outline_mat as ShaderMaterial).set_shader_parameter(&"alpha", outline_alpha)
	elif _outline_mat is StandardMaterial3D:
		var m := _outline_mat as StandardMaterial3D
		m.albedo_color.a = outline_alpha
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	if _icon:
		_icon.visible = active
		# Hollow: the icon sits on glass, so it takes the orb's color. Solid:
		# the same color would vanish into the core, so use its pale shade.
		_icon_mat.set_shader_parameter(&"tint", colors[0] if _hollow else colors[1])
	_base_scale = 1.0 if active else 0.5
