class_name Typewriter
extends Node
## Reveals a RichTextLabel's text one character at a time.
##
## Works on *visible* characters (BBCode like [shake] or [color] never shows
## up half-typed). Adds one tag of its own on top of Godot's BBCode:
##   [pause=0.5]   stops the reveal for 0.5 s at that point in the line
## Punctuation also gets a small automatic beat so sentences breathe.
##
## Usage: add as a child, call play(label, markup); listen for `finished`.
## Call skip() when the player presses interact (stops at the next [pause]),
## finish() to reveal everything at once.

signal finished
## Emitted for every newly revealed visible character (hook sound blips here).
signal character_revealed(character: String)

const BASE_CHARS_PER_SECOND := 42.0
const PAUSE_TAG := "[pause="
const PUNCTUATION_BEATS := {
	".": 0.20, "!": 0.22, "?": 0.22, "…": 0.20, ",": 0.09, ";": 0.12, ":": 0.12, "—": 0.12,
}

var speed := 1.0   ## multiplier on BASE_CHARS_PER_SECOND

var _label: RichTextLabel
var _total := 0
var _pauses := {}        ## visible-char index -> seconds to wait *before* revealing it
var _plain := ""         ## the visible text, for punctuation lookups
var _budget := 0.0       ## seconds of reveal "credit" built up
var _wait := 0.0
var _typing := false

func _ready() -> void:
	set_process(false)

func is_typing() -> bool:
	return _typing

## Starts revealing `markup` in `label`.
func play(label: RichTextLabel, markup: String) -> void:
	_label = label
	var parsed := parse(markup)
	_pauses = parsed["pauses"]
	_plain = parsed["plain"]
	_label.bbcode_enabled = true
	_label.text = parsed["text"]
	_total = _label.get_total_character_count()
	_label.visible_characters = 0
	_budget = 0.0
	_wait = 0.0
	_typing = _total > 0
	set_process(_typing)
	if not _typing:
		_label.visible_characters = -1
		finished.emit.call_deferred()

## Reveals the rest of the line immediately.
func finish() -> void:
	if not _typing:
		return
	_typing = false
	set_process(false)
	_label.visible_characters = -1
	finished.emit()

## The player's skip: fast-forwards to the next [pause] — everything before it
## appears at once and the pause then plays out normally — or straight to the
## end when none is left. A pause already in progress is cut short.
func skip() -> void:
	if not _typing:
		return
	_wait = 0.0
	_budget = 0.0
	var current := _label.visible_characters
	var stop := -1
	for index: int in _pauses.keys():
		if index > current and (stop == -1 or index < stop):
			stop = index
	if stop == -1:
		finish()
	else:
		_label.visible_characters = stop

func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
		delta = -_wait
		_wait = 0.0
	_budget += delta * BASE_CHARS_PER_SECOND * speed
	while _budget >= 1.0 and _typing:
		var index := _label.visible_characters
		if _pauses.has(index):
			_wait = _pauses[index] / speed
			_pauses.erase(index)   # consumed — don't re-trigger on the next frame
			_budget = 0.0
			return
		_label.visible_characters = index + 1
		_budget -= 1.0
		var ch := _plain[index] if index < _plain.length() else ""
		character_revealed.emit(ch)
		if _label.visible_characters >= _total:
			finish()
			return
		var beat: float = PUNCTUATION_BEATS.get(ch, 0.0)
		if beat > 0.0 and index + 1 < _plain.length() and _plain[index + 1] == " ":
			_wait = beat / speed
			_budget = 0.0
			return

## Splits `markup` into {text (BBCode minus [pause] tags), plain (visible
## characters only), pauses (visible index -> seconds)}. Static + pure so
## it's easy to test.
static func parse(markup: String) -> Dictionary:
	var text := ""
	var plain := ""
	var pauses := {}
	var i := 0
	while i < markup.length():
		var c := markup[i]
		if c == "[":
			var close := markup.find("]", i)
			if close == -1:
				text += c
				plain += c
				i += 1
				continue
			var tag := markup.substr(i, close - i + 1)
			if tag.begins_with(PAUSE_TAG):
				var seconds := tag.substr(PAUSE_TAG.length(), tag.length() - PAUSE_TAG.length() - 1).to_float()
				pauses[plain.length()] = pauses.get(plain.length(), 0.0) + seconds
			else:
				text += tag
				if tag == "[lb]":
					plain += "["
				elif tag == "[rb]":
					plain += "]"
			i = close + 1
		else:
			text += c
			plain += c
			i += 1
	return {"text": text, "plain": plain, "pauses": pauses}
