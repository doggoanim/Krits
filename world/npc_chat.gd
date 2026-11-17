class_name NpcChat
extends Node
## Two neighbours stop for a chat. In the chat window of the day, once BOTH their quests are
## done (`require_flags`), the two NPCs walk to either side of a meeting spot, face each other
## and trade lines (floating text above their heads, from data/chats.cfg), then go back to
## their routines. It happens once per window per day, never while you are talking to someone
## or fighting, and only when both are out and about and a straight walk to the spot is clear.
##
## Needs each NPC to have an NpcSchedule (named "Schedule", the way the scene has them) and, to
## show lines, an NpcBarks (named "Barks"). Put the spot (a Marker3D) where both can walk to it
## in a straight line; if a path is blocked the chat just doesn't start, and a warning in the
## output says which NPC to move the spot away from.
##
## data/chats.cfg:
##   [chat_id]
##   c1="A: first line | B: reply | A: ..."     ("A" is the `first` NPC, "B" the `second`)
## One conversation is picked at random each time.

const PATH := "res://data/chats.cfg"

@export var first: NodePath
@export var second: NodePath
@export var spot: NodePath
@export var chat_id := ""                       ## the section of data/chats.cfg
@export var require_flags: PackedStringArray = []
@export var from_hour := 15.0
@export var to_hour := 17.5
@export var gap := 1.6                          ## metres between the two while they talk
@export var gather_timeout := 45.0              ## give up if they can't get there in this many seconds
@export var line_pause := 0.5                   ## extra beat between lines

enum State { WAITING, GATHERING, TALKING, DONE }

static var _cfg: ConfigFile

var _state := State.WAITING
var _a: NPC
var _b: NPC
var _sched_a: NpcSchedule
var _sched_b: NpcSchedule
var _bark_a: NpcBarks
var _bark_b: NpcBarks
var _spot: Node3D
var _check := 0.0
var _clock := 0.0
var _lines: Array[Array] = []   ## [speaker (0 = first, 1 = second), text]
var _line := 0
var _warned := false

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_a = get_node_or_null(first) as NPC
	_b = get_node_or_null(second) as NPC
	_spot = get_node_or_null(spot) as Node3D
	if _a == null or _b == null or _spot == null:
		set_process(false)
		return
	_sched_a = _a.get_node_or_null("Schedule") as NpcSchedule
	_sched_b = _b.get_node_or_null("Schedule") as NpcSchedule
	_bark_a = _a.get_node_or_null("Barks") as NpcBarks
	_bark_b = _b.get_node_or_null("Barks") as NpcBarks
	if _sched_a == null or _sched_b == null:
		set_process(false)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	match _state:
		State.WAITING:
			_check -= delta
			if _check <= 0.0:
				_check = 1.0
				if _can_start():
					_begin()
		State.GATHERING:
			_clock += delta
			if _interrupted() or _clock > gather_timeout:
				_end(State.WAITING)
			elif _sched_a.chat_ready() and _sched_b.chat_ready():
				_start_talking()
		State.TALKING:
			if _interrupted():
				_end(State.WAITING)
				return
			_clock -= delta
			if _clock <= 0.0:
				_next_line()
		State.DONE:
			if not _in_window():
				_state = State.WAITING   # a new day, a new chat

# --- conditions --------------------------------------------------------------------------

func _in_window() -> bool:
	return WorldClock.in_range(from_hour, to_hour)

func _flags_ok() -> bool:
	for f in require_flags:
		if not Game.flag(StringName(f)):
			return false
	return true

func _interrupted() -> bool:
	if Game.in_combat or Game.input_locked:
		return true
	if DialogueBox.instance != null and DialogueBox.instance.is_active():
		return true
	return not _in_window() and WorldClock.hour > to_hour + 0.5

func _can_start() -> bool:
	if not _in_window() or not _flags_ok() or _interrupted():
		return false
	if not (_sched_a.can_chat() and _sched_b.can_chat()):
		return false
	var spots := _spots()
	if not (_sched_a.can_reach(spots[0]) and _sched_b.can_reach(spots[1])):
		if not _warned:
			_warned = true
			push_warning("NpcChat '%s': a straight walk to the spot is blocked; move '%s' somewhere both can reach." % [name, _spot.name])
		return false
	return not _conversation().is_empty()

## Where each stands: either side of the spot along its own X axis.
func _spots() -> Array[Vector3]:
	var side := _spot.global_basis.x.normalized() * gap * 0.5
	return [_spot.global_position + side, _spot.global_position - side]

# --- running a chat ------------------------------------------------------------------------

func _begin() -> void:
	var spots := _spots()
	_sched_a.begin_chat(spots[0], spots[1])
	_sched_b.begin_chat(spots[1], spots[0])
	_state = State.GATHERING
	_clock = 0.0

func _start_talking() -> void:
	_lines = _conversation()
	_line = 0
	_state = State.TALKING
	_next_line(true)

func _next_line(first_line := false) -> void:
	if _line >= _lines.size():
		_end(State.DONE)
		return
	var entry: Array = _lines[_line]
	_line += 1
	var bark := _bark_a if int(entry[0]) == 0 else _bark_b
	var shown := 2.4 + String(entry[1]).length() * 0.045
	if bark != null:
		shown = bark.say(String(entry[1]))
	_clock = shown + line_pause

func _end(next_state: State) -> void:
	_sched_a.end_chat()
	_sched_b.end_chat()
	_state = next_state
	_check = 3.0   # not straight away, if it was cut short

# --- the conversation data ---------------------------------------------------------------------

## One random conversation as [[speaker, text], ...]; empty when the file has none for chat_id.
func _conversation() -> Array[Array]:
	var cfg := _load()
	var out: Array[Array] = []
	if chat_id == "" or not cfg.has_section(chat_id):
		return out
	var keys := cfg.get_section_keys(chat_id)
	if keys.is_empty():
		return out
	var raw := String(cfg.get_value(chat_id, keys[randi() % keys.size()]))
	for part in raw.split("|", false):
		var text := part.strip_edges()
		var who := 0
		if text.begins_with("B:"):
			who = 1
			text = text.substr(2).strip_edges()
		elif text.begins_with("A:"):
			text = text.substr(2).strip_edges()
		if not text.is_empty():
			out.append([who, text])
	return out

static func _load() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		var err := _cfg.load(PATH)
		if err != OK and err != ERR_FILE_NOT_FOUND:
			push_warning("NpcChat: could not read %s (error %d)" % [PATH, err])
	return _cfg
