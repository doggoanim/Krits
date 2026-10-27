class_name WaterVolume
extends Area3D
## Detects the player entering/exiting a body of water — triggers the splash
## (PlayerEffects.burst_water_splash()) and tells the player itself it's in
## water (Player.enter_water()/exit_water()), which is what drives
## submersion-depth checks (swimming, wet footsteps — see Player._update_water()
## and GroundState._play_footstep()) and the underwater screen tint/audio
## muffle (see core/underwater_overlay.gd, which uses the static at() lookup
## below rather than a Player-specific call, since the CAMERA can be
## underwater independently of whether the player itself currently is).
##
## Drop one of these as a sibling of a water mesh (world/water/water.tscn or
## the hometown.tscn lake), sized to its surface via `size`, and set
## `surface_y` to wherever the water's actual top sits relative to THIS
## node's own origin — not necessarily its center, since the box is usually
## easier to position a bit below the surface so a player walking in is
## already "inside" a little before the splash fires, rather than right at
## the literal edge.

@export var size := Vector3(10.0, 4.0, 10.0)
@export var surface_y := 0.0   ## local Y of the water's top surface, relative to this node's own origin
## >0 swaps the box footprint above for a circular one (a CylinderShape3D of
## this radius instead of a BoxShape3D sized from size.x/size.z) — set this
## for a round/cylindrical water mesh like the hometown lake's: a box sized
## to the same diameter still reaches size.x*sqrt(2)/2 out to its own
## corners, well past the mesh's actual round edge, so the collision read as
## "much bigger than the mesh." size.y still sets the collider's depth
## either way; size.x/size.z are simply unused once this is set.
@export var radius := 0.0
## Tint used by the underwater screen overlay while the camera is below this
## volume's surface (see core/underwater_overlay.gd) — set this to roughly
## match whatever shallow_color/deep_color this body's own water.gdshader
## material is using, so looking up through the surface reads as the same
## water rather than a generic default.
@export var tint_color := Color(0.08, 0.32, 0.42, 0.55)

## Every WaterVolume currently in the tree, for the static at() lookup below
## — nothing else (the camera, mainly) has a direct reference to pick the
## right one from, and giving the camera its own Area3D just to overlap-test
## water would be a second, redundant detection system doing the same job
## this one already does for the player.
static var active: Array[WaterVolume] = []

var _player_inside := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # layer 2: player — see Player.collision_layer
	monitorable = false

	var cs := CollisionShape3D.new()
	if radius > 0.0:
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = size.y
		cs.shape = cyl
	else:
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
	add_child(cs)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	active.append(self)

func _exit_tree() -> void:
	active.erase(self)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).enter_water(self)
		if not _player_inside:
			_player_inside = true
			(body as Player).effects.burst_water_splash(_waterline_pos(body), true)
			(body as Player).audio.play_water_splash()

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		(body as Player).exit_water(self)
		if _player_inside:
			_player_inside = false
			(body as Player).effects.burst_water_splash(_waterline_pos(body), false)
			(body as Player).audio.play_water_splash()

## The splash plays at the player's horizontal position but the water's own
## surface height — not the player's current Y, which on entry is usually
## still above the surface (the body/area overlap a little before the feet
## are actually underwater) and on exit is wherever they climbed out to.
func _waterline_pos(body: Node3D) -> Vector3:
	return Vector3(body.global_position.x, surface_world_y(), body.global_position.z)

## World-space Y of this volume's own surface — surface_y above is local to
## this node's own origin, which isn't necessarily sitting at world Y 0.
func surface_world_y() -> float:
	return global_position.y + surface_y

## True if `pos` falls inside this volume's horizontal footprint, at or below
## its surface — a plain box/cylinder test against `size`/`radius`/
## `surface_y` (matching whichever shape _ready() actually built), independent
## of the Area3D's own physics overlap (which only the player's collider
## triggers). Used by the static at() lookup below.
func contains_point(pos: Vector3) -> bool:
	var local := to_local(pos)
	if radius > 0.0:
		if Vector2(local.x, local.z).length() > radius:
			return false
	elif absf(local.x) > size.x * 0.5 or absf(local.z) > size.z * 0.5:
		return false
	return local.y <= surface_y and local.y >= surface_y - size.y

## How submerged a body of `height`, standing with its feet at world Y
## `feet_y`, is in THIS volume — 0.0 (dry) to 1.0 (fully underwater). See
## Player.water_submersion(), which calls this with its own global_position.y
## and STAND_HEIGHT.
func submersion_ratio(feet_y: float, height: float) -> float:
	return clampf((surface_world_y() - feet_y) / height, 0.0, 1.0)

## The first active WaterVolume (there's rarely more than one anywhere near
## the camera at once) whose footprint contains `pos`, or null. See the
## class doc comment above for why this exists as a static lookup rather
## than yet another Area3D.
static func at(pos: Vector3) -> WaterVolume:
	for w in active:
		if w.contains_point(pos):
			return w
	return null
