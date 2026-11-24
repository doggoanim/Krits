@tool
class_name PlayProp
extends Smashable
## A prop with something to do, picked by `kind`:
##   POT / CRATE / BARREL  smash it (see Smashable): ground-pound onto it, or dive / long-jump /
##                         roll into it. Drops come from data/drops.cfg under [prop_pot],
##                         [prop_crate] or [prop_barrel].
##   MUSHROOM              spongy cap: land on it for a big bounce (StompZone).
## The look comes from PlayProps; place one anywhere and set `kind`. See KickableProp for the
## things you kick, Seat for the things you sit on.

enum Kind { POT, CRATE, BARREL, MUSHROOM }

const RUBBLE := {Kind.POT: Color(0.78, 0.45, 0.3), Kind.CRATE: Color(0.72, 0.52, 0.32), Kind.BARREL: Color(0.6, 0.42, 0.26)}
const PITCH := {Kind.POT: Vector2(1.5, 1.9), Kind.CRATE: Vector2(0.95, 1.15), Kind.BARREL: Vector2(0.8, 0.95)}
## Collision (radius, height) per kind. The mushroom's cap is wider than its stem.
const BODY := {Kind.POT: Vector2(0.3, 0.7), Kind.CRATE: Vector2(0.37, 0.72), Kind.BARREL: Vector2(0.36, 0.82), Kind.MUSHROOM: Vector2(0.62, 0.7)}

@export var kind := Kind.POT:
	set(v):
		kind = v
		_rebuild()
@export var mushroom_bounce := 1.45   ## bounce height of a MUSHROOM, as a fraction of the orb bounce

var _visual: Node3D

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_sensor = null
	_visual = _build_visual()
	_visual.name = "Visual"
	add_child(_visual)
	var spec: Vector2 = BODY[kind]
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = spec.x
	cyl.height = spec.y
	shape.shape = cyl
	shape.position.y = spec.y * 0.5
	add_child(shape)
	if Engine.is_editor_hint():
		return
	if kind == Kind.MUSHROOM:
		var zone := StompZone.new()
		zone.name = "Stomp"
		zone.squash_target = _visual
		zone.bounce_lift = mushroom_bounce
		zone.pitch_range = Vector2(0.55, 0.85)
		zone.squash = Vector2(1.25, 0.6)
		add_child(zone)
	else:
		drop_section = StringName("prop_" + String(Kind.keys()[kind]).to_lower())
		rubble = RUBBLE[kind]
		wooden = kind != Kind.POT
		break_pitch = PITCH[kind]
		call_deferred(&"_arm")   # the old shape is still queued for deletion this frame

func _build_visual() -> Node3D:
	match kind:
		Kind.CRATE: return PlayProps.crate()
		Kind.BARREL: return PlayProps.barrel()
		Kind.MUSHROOM: return PlayProps.mushroom()
		_: return PlayProps.pot()

func on_player_impact(move: StringName, p: Player, normal: Vector3, speed: float) -> bool:
	if kind == Kind.MUSHROOM:
		return false
	return super(move, p, normal, speed)

func _physics_process(delta: float) -> void:
	if kind != Kind.MUSHROOM:
		super(delta)

func _remove() -> void:
	queue_free()
