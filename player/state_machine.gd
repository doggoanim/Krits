class_name StateMachine
extends Node

var current: PlayerState
var current_name: StringName = &""

## `states` maps state id -> instance. The id becomes the node name.
func setup(p: Player, states: Dictionary) -> void:
	for id in states:
		var s: PlayerState = states[id]
		s.name = id
		s.player = p
		s.machine = self
		add_child(s)

func start(state: StringName) -> void:
	transition_to(state)

func transition_to(state: StringName, msg: Dictionary = {}) -> void:
	var next := get_node_or_null(NodePath(str(state))) as PlayerState
	assert(next != null, "Unknown state: %s" % state)
	var prev := current_name
	if current:
		current.exit(state)
	current = next
	current_name = state
	current.enter(prev, msg)

func physics_update(delta: float) -> void:
	if current:
		current.physics_update(delta)
