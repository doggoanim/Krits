class_name LoadingScreen
extends CanvasLayer
## Cartoon-style loading cover: a full black screen with a hollow ring in the
## middle that pulses — scales up ("zooms in"), then back down ("zooms out"),
## repeating for as long as the screen is covering something being swapped
## out behind it. The pulse is purely decorative, like an old cartoon iris
## wipe's little circle; the black Rect underneath is what actually hides
## the swap, which happens mid-cover where nobody can see it.
##
## One instance, built by UiRoot same as Hud/DialogueBox/etc. Main is the
## only caller: `await LoadingScreen.instance.run(swap_callable)` covers the
## screen, calls `swap_callable` once fully covered, then uncovers again.

const PULSE_SCALE_MIN := 0.7
const PULSE_SCALE_MAX := 1.6
const PULSE_TIME := 0.5    ## one direction of the pulse (in or out)
## Minimum time spent fully covered before/after the swap itself runs, so a
## near-instant swap never reads as a single-frame flicker — there's always
## at least a beat of "yep, that's a loading screen" on either side of it.
const HOLD_TIME := 0.25

static var instance: LoadingScreen

@onready var _ring: TextureRect = %Ring

var _pulse_tween: Tween

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40   # above DialogueBox (20), below nothing — this covers everything
	visible = false
	_ring.texture = SoftCircleTexture.make_ring(128)
	_ring.pivot_offset = _ring.size * 0.5

## Covers the screen, holds, calls `swap` (awaited — it may itself await,
## e.g. a tween or another coroutine), holds again, then uncovers. `swap`
## doing its work while this is fully opaque is the entire point: whatever
## it does (freeing/instancing level nodes, teleporting the player) is never
## actually seen happening.
func run(swap: Callable) -> void:
	visible = true
	_start_pulse()
	await get_tree().create_timer(HOLD_TIME).timeout
	await swap.call()
	await get_tree().create_timer(HOLD_TIME).timeout
	_stop_pulse()
	visible = false

func _start_pulse() -> void:
	_ring.scale = Vector2.ONE * PULSE_SCALE_MIN
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_ring, "scale", Vector2.ONE * PULSE_SCALE_MAX, PULSE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_ring, "scale", Vector2.ONE * PULSE_SCALE_MIN, PULSE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
