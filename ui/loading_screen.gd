class_name LoadingScreen
extends CanvasLayer
## Cartoon-style iris wipe: a circular hole in an otherwise fully black
## overlay that closes down to a point — hiding whatever's behind it — then
## reopens, the classic old-cartoon "iris out, iris in" scene transition.
## See iris_mask.gdshader for the actual mask; this script just animates its
## `radius` uniform and times the swap around it. The level swap happens the
## instant the hole is fully shut, where nothing behind it is visible at all.
##
## One instance, registered as the `Iris` autoload (so it survives scene
## changes and is the single loading screen for everything):
##   - level swaps (doors): `await LoadingScreen.instance.run(swap_callable)`
##     closes the iris, calls `swap_callable` once fully shut, then reopens it.
##   - scene changes (menu -> game, game -> menu):
##     `LoadingScreen.instance.go_to_scene(path)` — don't await it from a node
##     that the scene change will free.

## Radius (in the shader's own aspect-corrected units — see
## iris_mask.gdshader) big enough that the circle's edge sits off past every
## screen corner regardless of aspect ratio, i.e. "fully open, nothing
## masked" — bigger than 1.0, since a widescreen window's corners sit
## further from center than its edges once the shader corrects for aspect.
const MAX_RADIUS := 1.3
const IRIS_TIME := 0.45   ## one direction of the wipe (closing or opening)
## Minimum time spent fully closed before/after the swap itself runs, so a
## near-instant swap never reads as a single-frame flicker — there's always
## at least a beat of "yep, that's a transition" on either side of it.
const HOLD_TIME := 0.15

static var instance: LoadingScreen

@onready var _iris: ColorRect = %Iris
var _mat: ShaderMaterial

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40   # above DialogueBox (20), below nothing — this covers everything
	visible = false
	_mat = _iris.material as ShaderMaterial
	_mat.set_shader_parameter(&"radius", MAX_RADIUS)
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)

## Keeps the hole circular (not stretched into an ellipse) regardless of the
## window's own aspect ratio — see iris_mask.gdshader's own comment.
func _update_aspect() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.y > 0.0:
		_mat.set_shader_parameter(&"aspect", Vector2(size.x / size.y, 1.0))

## Closes the iris down to a point, calls `swap` (awaited — it may itself
## await, e.g. a tween or another coroutine) while fully shut, then reopens
## it. `swap` doing its work while this is fully closed is the entire point:
## whatever it does (freeing/instancing level nodes, teleporting the player)
## is never actually seen happening.
func run(swap: Callable) -> void:
	visible = true
	await _animate_radius(MAX_RADIUS, 0.0)
	await get_tree().create_timer(HOLD_TIME).timeout
	await swap.call()
	await get_tree().create_timer(HOLD_TIME).timeout
	await _animate_radius(0.0, MAX_RADIUS)
	visible = false

## Iris out, change the whole scene while nothing is visible, then iris in once
## the new scene has had a couple of frames to build itself. `on_fail` (optional)
## runs if the scene can't be loaded; the iris reopens either way.
func go_to_scene(path: String, on_fail := Callable()) -> void:
	visible = true
	await _animate_radius(MAX_RADIUS, 0.0)
	await get_tree().create_timer(HOLD_TIME).timeout
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("LoadingScreen: could not load %s (error %d)" % [path, err])
		await _animate_radius(0.0, MAX_RADIUS)
		visible = false
		if on_fail.is_valid():
			on_fail.call()
		return
	# The new scene is swapped in at the end of this frame and builds itself in
	# its _ready — give it that long before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(HOLD_TIME).timeout
	await _animate_radius(0.0, MAX_RADIUS)
	visible = false

func _animate_radius(from: float, to: float) -> void:
	_mat.set_shader_parameter(&"radius", from)
	var tween := create_tween()
	tween.tween_method(func(r: float) -> void: _mat.set_shader_parameter(&"radius", r), from, to, IRIS_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
