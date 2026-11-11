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
const IRIS_TIME := 0.3   ## one direction of the wipe (closing or opening)
## Minimum time spent fully closed before/after the swap itself runs, so a
## near-instant swap never reads as a single-frame flicker — there's always
## at least a beat of "yep, that's a transition" on either side of it.
const HOLD_TIME := 0.08
const COVER_LAYER := 40        ## above everything, DialogueBox (20) included
const HELD_LAYER := 10         ## while hold()ing: still hides the world and HUD, but under the DialogueBox

static var instance: LoadingScreen

@onready var _iris: ColorRect = %Iris
var _mat: ShaderMaterial
var _partial_radius := -1.0   ## >= 0 while close_to() has left the iris part-way shut
var _held := false          ## the screen is being kept black by hold() until release()
var _in_scene_change := false

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = COVER_LAYER   # above DialogueBox (20), below nothing — this covers everything
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
	# If close_to() already shut the iris part-way (the death wipe), carry on from there.
	var from := _partial_radius if _partial_radius >= 0.0 else MAX_RADIUS
	_partial_radius = -1.0
	await _animate_radius(from, 0.0)
	await get_tree().create_timer(HOLD_TIME).timeout
	await swap.call()
	await get_tree().create_timer(HOLD_TIME).timeout
	_mat.set_shader_parameter(&"center", Vector2(0.5, 0.5))   # fully shut: recentre before reopening
	await _animate_radius(0.0, MAX_RADIUS)
	visible = false

## Closes the iris only part-way, onto `center_uv` (screen UV), and stops with a
## gap of `radius` still open — the Mario-style death wipe. The next run()
## carries on from this radius to fully shut.
func close_to(radius: float, center_uv: Vector2, time := IRIS_TIME) -> void:
	_mat.set_shader_parameter(&"center", center_uv)
	visible = true
	_partial_radius = radius
	await _animate_radius(MAX_RADIUS, radius, time)

## Keeps the screen black until release(), even across a go_to_scene() reveal —
## for an opening scene that wants to start in the dark (call it from the new
## scene's _ready, which runs before go_to_scene would open the iris). Covers
## the screen at once if it was not already.
func hold() -> void:
	_held = true
	layer = HELD_LAYER   # so a line spoken in the dark (the opening) shows over the black
	visible = true
	_mat.set_shader_parameter(&"radius", 0.0)

## Lets the held black screen open (the iris wipe in). If a go_to_scene() is
## waiting on the hold it carries on with its own reveal; otherwise this opens it.
func release() -> void:
	_held = false
	layer = COVER_LAYER
	if _in_scene_change:
		return
	await _animate_radius(0.0, MAX_RADIUS)
	visible = false

## Iris out, change the whole scene while nothing is visible, then iris in once
## the new scene has had a couple of frames to build itself. `on_fail` (optional)
## runs if the scene can't be loaded; the iris reopens either way.
func go_to_scene(path: String, on_fail := Callable()) -> void:
	_in_scene_change = true
	visible = true
	await _animate_radius(MAX_RADIUS, 0.0)
	await get_tree().create_timer(HOLD_TIME).timeout
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("LoadingScreen: could not load %s (error %d)" % [path, err])
		_in_scene_change = false
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
	while _held:   # the new scene asked to start in the dark (hold())
		await get_tree().process_frame
	_in_scene_change = false
	await _animate_radius(0.0, MAX_RADIUS)
	visible = false

func _animate_radius(from: float, to: float, time := IRIS_TIME) -> void:
	_mat.set_shader_parameter(&"radius", from)
	var tween := create_tween()
	tween.tween_method(func(r: float) -> void: _mat.set_shader_parameter(&"radius", r), from, to, time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
