class_name SaveIndicator
extends Control
## "Saving…" badge in the bottom-right corner. Shown whenever the game writes a
## save (Events.game_saved). The write itself is instant, so the badge is held
## for a minimum time — long enough to actually read — then fades away. A
## second save while it's up just restarts the hold.

const FADE_TIME := 0.2
const HOLD_TIME := 1.1

var _tween: Tween

func _ready() -> void:
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS   # saves also happen while the game is paused
	Events.game_saved.connect(_on_game_saved)

func _on_game_saved() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME * 2.0)
