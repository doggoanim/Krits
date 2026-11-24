class_name NpcBarks
extends Node
## Gives a character something to say as you walk past: a short line floats above their
## head for a few seconds when you come near (not while you talk to them, fight, or have
## just heard them). Add as a CHILD of an NPC or ShopKeeper; the lines come from
## data/barks.cfg, in a section named after the parent node:
##
##   [Yule]
##   morning=Line one | Line two          ("|" separates alternatives; one is picked at random)
##   day=...   evening=...   night=...    (WorldClock.period())
##   flag_cat_found=...                   (used instead while that story flag is set)
##
## Flag lines win over time-of-day lines most of the time, so the town reacts to what you've
## done without repeating itself.

const PATH := "res://data/barks.cfg"
const FLAG_PREFIX := "flag_"

@export var radius := 5.5                   ## how close the player must come to trigger a line
@export var cooldown := 28.0                ## seconds before this character barks again
@export var chance := 0.7                   ## chance to speak when you walk into range (not every pass)
@export var height := 2.3                   ## label height above the parent's origin

static var _cfg: ConfigFile
static var _last_bark_msec := -100000   ## across everyone: two bubbles never talk over each other
const GLOBAL_GAP_MSEC := 2500
const FLAG_PRIORITY := 0.65   ## chance a set flag's line is used over the time-of-day line

var _owner_node: Node3D
var _label: Label3D
var _tween: Tween
var _cool := 0.0
var _inside := false

func _ready() -> void:
	_owner_node = get_parent() as Node3D
	if Engine.is_editor_hint() or _owner_node == null:
		set_process(false)
		return
	_cool = randf_range(2.0, 8.0)   # not everyone speaks on the very first frame
	_label = Label3D.new()
	_label.name = "BarkLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.0048
	_label.font_size = 34
	_label.outline_size = 12
	_label.outline_modulate = Color(0.08, 0.06, 0.05, 0.9)
	_label.modulate = Color(1, 0.97, 0.88, 0.0)
	_label.width = 520.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.top_level = true   # keeps its own orientation: the NPC turning must not flip the text
	_label.visible = false
	add_child(_label)

func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if _label.visible:
		_label.global_position = _owner_node.global_position + Vector3.UP * height
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var close := player.global_position.distance_to(_owner_node.global_position) < radius
	if close and not _inside and _cool <= 0.0 and _can_speak():
		if randf() < chance:
			_speak()
		_cool = cooldown
	_inside = close

func _can_speak() -> bool:
	if not _owner_node.visible or Game.in_combat or Game.input_locked:
		return false
	if DialogueBox.instance != null and DialogueBox.instance.is_active():
		return false
	return Time.get_ticks_msec() - _last_bark_msec > GLOBAL_GAP_MSEC

func _speak() -> void:
	var line := pick_line(String(_owner_node.name))
	if line.is_empty():
		return
	say(line)

## Shows `line` above the character for a few seconds (also used by NpcChat for its conversations).
## Returns how long the line stays up.
func say(line: String) -> float:
	_last_bark_msec = Time.get_ticks_msec()
	_label.text = line
	_label.global_position = _owner_node.global_position + Vector3.UP * height
	_label.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var stay := 2.2 + line.length() * 0.045
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(stay)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(func() -> void: _label.visible = false)
	return stay + 0.75

## A line for `who` right now (flags and time of day), or "" when the file has nothing.
static func pick_line(who: String) -> String:
	var cfg := _load()
	if not cfg.has_section(who):
		return ""
	var flagged: Array[String] = []
	for key in cfg.get_section_keys(who):
		if key.begins_with(FLAG_PREFIX) and Game.flag(StringName(key.substr(FLAG_PREFIX.length()))):
			flagged.append(String(cfg.get_value(who, key)))
	var timed := String(cfg.get_value(who, String(WorldClock.period()), ""))
	var source := ""
	if not flagged.is_empty() and (timed.is_empty() or randf() < FLAG_PRIORITY):
		source = flagged[randi() % flagged.size()]
	else:
		source = timed
	if source.is_empty():
		return ""
	var options := source.split("|", false)
	return options[randi() % options.size()].strip_edges()

## A line for being stomped on: the character's own `stomp` key, else the shared [Stomp] section.
static func pick_stomp_line(who: String) -> String:
	var cfg := _load()
	for section in [who, "Stomp"]:
		if cfg.has_section(section) and cfg.has_section_key(section, "stomp"):
			var options := String(cfg.get_value(section, "stomp")).split("|", false)
			if not options.is_empty():
				return options[randi() % options.size()].strip_edges()
	return ""

static func _load() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		var err := _cfg.load(PATH)
		if err != OK:
			push_error("NpcBarks: could not load %s (error %d) — is data/*.cfg in the export filter?" % [PATH, err])
	return _cfg
