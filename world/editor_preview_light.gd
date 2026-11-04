@tool
class_name EditorPreviewLight
extends Node
## Makes a dark level readable while you EDIT it, without changing how it looks
## in the game.
##
## The game's real lighting (a level's color grade, ambient, exposure) is applied
## at runtime by Main, so in the editor viewport a dark level like the well has
## no environment at all and looks black. This node adds a bright flat
## WorldEnvironment — but ONLY while you're in the editor. When the game runs
## it removes itself before doing anything, so the level is lit exactly as before.
##
## Turn it off by deleting the node, or set `enabled` to false.

@export var enabled := true:
	set(value):
		enabled = value
		if is_inside_tree():
			_refresh()
@export var ambient_color := Color(0.8, 0.85, 0.95)
@export_range(0.0, 3.0, 0.05) var ambient_energy := 1.0

var _env_node: WorldEnvironment

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()   # in the running game this node does nothing at all
		return
	_refresh()

func _refresh() -> void:
	if _env_node != null:
		_env_node.queue_free()
		_env_node = null
	if not enabled or not Engine.is_editor_hint():
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.1, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	_env_node = WorldEnvironment.new()
	_env_node.environment = env
	add_child(_env_node)   # not owned by the scene, so it is never saved into the .tscn
