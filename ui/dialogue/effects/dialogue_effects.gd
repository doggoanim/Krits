class_name DialogueEffects
extends RefCounted
## The dialogue box's own BBCode text effects, on top of Godot's built-ins
## ([shake], [wave], [tornado], [rainbow], [pulse], [fade]):
##   [angry]text[/angry]     hard fast jitter, tinted dark red
##   [whisper]text[/whisper] faint, wavering, drifting a little
##   [shiver]text[/shiver]   small quick tremble (cold, scared)
##   [bounce]text[/bounce]   each letter hops in turn (cheerful)
##   [sad]text[/sad]         sinks slowly, dim blue-grey
## Each one takes optional settings, e.g. [angry level=3 rate=40].
## To add one: write a RichTextEffect subclass below with its `bbcode` name and
## list it in all(). DialogueBox installs everything in all() on its text label.

static func all() -> Array[RichTextEffect]:
	return [AngryFx.new(), WhisperFx.new(), ShiverFx.new(), BounceFx.new(), SadFx.new()]

## Deterministic pseudo-random in -1..1 per (character, time step) — no state needed.
static func noise(index: int, step: int, salt := 0) -> float:
	return fmod(sin(float(index) * 12.9898 + float(step) * 78.233 + float(salt) * 37.719) * 43758.5453, 1.0) * 2.0 - 1.0

class AngryFx extends RichTextEffect:
	var bbcode := "angry"
	func _process_custom_fx(c: CharFXTransform) -> bool:
		var level: float = c.env.get("level", 3.0)
		var rate: float = c.env.get("rate", 30.0)
		var step := int(c.elapsed_time * rate)
		c.offset += Vector2(DialogueEffects.noise(c.relative_index, step, 1), DialogueEffects.noise(c.relative_index, step, 2)) * level
		c.color = c.color.lerp(Color(0.62, 0.05, 0.05), 0.85)
		return true

class WhisperFx extends RichTextEffect:
	var bbcode := "whisper"
	func _process_custom_fx(c: CharFXTransform) -> bool:
		var t := c.elapsed_time
		var i := float(c.relative_index)
		c.color.a *= 0.45 + 0.2 * sin(t * 2.2 + i * 0.7)
		c.offset += Vector2(sin(t * 1.3 + i * 0.5) * 1.5, cos(t * 1.7 + i * 0.4) * 1.5)
		return true

class ShiverFx extends RichTextEffect:
	var bbcode := "shiver"
	func _process_custom_fx(c: CharFXTransform) -> bool:
		var level: float = c.env.get("level", 1.5)
		var step := int(c.elapsed_time * 45.0)
		c.offset += Vector2(DialogueEffects.noise(c.relative_index, step, 3), 0.0) * level
		return true

class BounceFx extends RichTextEffect:
	var bbcode := "bounce"
	func _process_custom_fx(c: CharFXTransform) -> bool:
		var height: float = c.env.get("height", 10.0)
		var speed: float = c.env.get("speed", 6.0)
		var phase := c.elapsed_time * speed - float(c.relative_index) * 0.6
		c.offset.y -= maxf(sin(phase), 0.0) * height   # hops only on the up half of the wave
		return true

class SadFx extends RichTextEffect:
	var bbcode := "sad"
	func _process_custom_fx(c: CharFXTransform) -> bool:
		var t := c.elapsed_time
		c.offset.y += 4.0 + sin(t * 1.2 + float(c.relative_index) * 0.3) * 2.0
		c.color = c.color.lerp(Color(0.3, 0.38, 0.55), 0.75)
		return true
