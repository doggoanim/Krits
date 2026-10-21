class_name PoleGrab
extends Area3D
## Grab trigger + climb axis for Mario 64-style pole climbing — pure
## behavior, no visual or collision of its own, so it can be dropped as a
## child of ANY existing vertical collider (a tree trunk, a lamp post, a
## dedicated decorative pole — see Pole/pole.tscn for that last one) to make
## that object climbable. Player.grab_pole() and
## player/states/pole_climb_state.gd own everything that happens once
## grabbed; this script only builds the trigger shape and fires the grab,
## the same split combat/slime_puddle.gd uses for its own trigger.
##
## Place this node at the base of whatever it's climbing (local Y = 0 at
## ground level, same as a tree's own Trunk) and set `height` to match —
## directly in the Inspector for a hand-placed one, or via configure() if a
## parent script (Pole, say) derives it from its own size.

@export var height := 4.0        ## how tall a climb this is, from this node's own position up
@export var grab_radius := 0.6   ## how far from the centerline (this node's X/Z) the trigger reaches

@onready var _shape: CollisionShape3D = %GrabShape

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # layer 2: player
	monitorable = false
	_rebuild_shape()
	body_entered.connect(_on_body_entered)

## Resizes this grab zone and rebuilds its trigger shape immediately. A
## parent script that derives this node's size from its own (Pole does, for
## instance) should call this instead of setting height/grab_radius
## directly — this node's own _ready() (which builds the shape from
## whatever those were at the time) already ran by the time a parent's
## _ready() gets a chance to touch a child, since children ready first.
func configure(new_height: float, new_grab_radius: float) -> void:
	height = new_height
	grab_radius = new_grab_radius
	if is_node_ready():
		_rebuild_shape()

func _rebuild_shape() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = grab_radius
	shape.height = height
	_shape.shape = shape
	_shape.position.y = height * 0.5

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.grab_pole(self)

## World-space Y the player can't climb above — just under this node's own
## top, so the capsule doesn't poke out above it mid-climb.
func top_y() -> float:
	return global_position.y + height - 0.3
