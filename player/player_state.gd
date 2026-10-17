class_name PlayerState
extends Node
## Base class for movement states. Override the hooks you need.

var player: Player
var machine: StateMachine

func enter(_prev: StringName, _msg: Dictionary = {}) -> void: pass
func exit(_next: StringName) -> void: pass
func physics_update(_delta: float) -> void: pass
