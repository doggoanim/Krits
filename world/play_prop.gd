@tool
class_name PlayProp
extends StaticBody3D
## A prop with something to do, picked by `kind`:
##   POT / CRATE / BARREL  smash it: ground-pound onto it, or dive / long-jump / roll into it.
##                         It bursts into pieces and drops what data/drops.cfg lists under
##                         [prop_pot] / [prop_crate] / [prop_barrel] (`gold` is a valid key).
##   MUSHROOM              spongy cap: land on it for a big bounce (StompZone).
## The look comes from PlayProps; place one anywhere and set `kind`. See KickableProp for the
## things you kick, Seat for the things you sit on.

enum Kind { POT, CRATE, BARREL, MUSHROOM }

const BREAK_SOUND := {Kind.POT: [PropSfx.TINK, Vector2(1.5, 1.9)], Kind.CRATE: [PropSfx.WOOD_CHOP, Vector2(0.95, 1.15)], Kind.BARREL: [PropSfx.WOOD_CHOP, Vector2(0.8, 0.95)]}
const RUBBLE := {Kind.POT: Color(0.78, 0.45, 0.3), Kind.CRATE: Color(0.72, 0.52, 0.32), Kind.BARREL: Color(0.6, 0.42, 0.26)}
## Collision half-extents per kind: (radius, height). The mushroom's cap is wider than its stem.
const BODY := {Kind.POT: Vector2(0.3, 0.7), Kind.CRATE: Vector2(0.37, 0.72), Kind.BARREL: Vector2(0.36, 0.82), Kind.MUSHROOM: Vector2(0.62, 0.7)}

@export var kind := Kind.POT:
	set(v):
		kind = v
		_rebuild()
@export var mushroom_bounce := 1.45   ## bounce height of a MUSHROOM, as a fraction of the orb bounce

var _visual: Node3D
var _broken := false

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
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
	if kind == Kind.MUSHROOM and not Engine.is_editor_hint():
		var zone := StompZone.new()
		zone.name = "Stomp"
		zone.squash_target = _visual
		zone.bounce_lift = mushroom_bounce
		zone.pitch_range = Vector2(0.55, 0.85)
		zone.squash = Vector2(1.25, 0.6)
		add_child(zone)

func _build_visual() -> Node3D:
	match kind:
		Kind.CRATE: return PlayProps.crate()
		Kind.BARREL: return PlayProps.barrel()
		Kind.MUSHROOM: return PlayProps.mushroom()
		_: return PlayProps.pot()

func is_breakable() -> bool:
	return kind != Kind.MUSHROOM

## Called by Player.impact_breakables() for every surface a move just hit.
func on_player_impact(move: StringName, p: Player, normal: Vector3, speed: float) -> bool:
	if _broken or not is_breakable():
		return false
	var from_above := move == &"pound" and normal.y > 0.5
	var from_side := (move == &"dive" or move == &"long_jump" or move == &"roll") \
			and absf(normal.y) < 0.5 and speed >= p.config.wall_min_speed
	if not (from_above or from_side):
		return false
	_smash(p)
	return true

func _smash(p: Player) -> void:
	_broken = true
	var center := global_position + Vector3.UP * (BODY[kind] as Vector2).y * 0.5
	var parent := get_parent() as Node3D
	var color: Color = RUBBLE[kind]
	if parent != null:
		VFX.shatter(parent, center, color, 1.1)
		VFX.shatter(parent, center + Vector3.UP * 0.2, color.lightened(0.15), 0.8)
		VFX.smoke_puff(parent, center, 0.8)
	var snd: Array = BREAK_SOUND[kind]
	PropSfx.play_at(self, snd[0], center, snd[1])
	if p.camera_rig:
		p.camera_rig.shake(0.2)
	_give_drops()
	queue_free()

## Rolls this prop's section of data/drops.cfg ("prop_pot"...) straight into the bag.
func _give_drops() -> void:
	var found: PackedStringArray = []
	for drop in Drops.for_enemy(StringName("prop_" + String(Kind.keys()[kind]).to_lower())):
		var n := drop.roll()
		if n <= 0:
			continue
		if drop.item_id == &"gold":
			Game.stats.add_gold(n)
			found.append("%d gold" % n)
			continue
		ItemGet.give(drop.item_id, n)
		var item := ItemLibrary.by_id(drop.item_id)
		found.append("%dx %s" % [n, item.display_name if item != null else String(drop.item_id)])
	if not found.is_empty():
		Events.notice.emit("Found " + ", ".join(found))
