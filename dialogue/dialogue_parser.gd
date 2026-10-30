class_name DialogueParser
extends RefCounted
## Turns a .dlg text file into the DialogueNode / DialogueChoice graph the game
## already runs (DialogueBox is unchanged). One file = one NPC's conversations.
##
##   # a comment
##   @speaker Mayor Arse              default speaker (first one); more @speaker
##   @speaker Desert Mayor            lines declare other names usable below
##   @when quest_done_x -> thanks     if this flag is set, start at `thanks`
##   @when water_quest_accepted -> reminder      (first match in file order wins)
##   @start offer                     entry section (default: the first one)
##
##   == offer ==                      a section — a named stretch of conversation
##   Oh dear you actually came!       a line (spoken by the default speaker)
##   Desert Mayor: Who's there?       a line by another declared speaker
##     and it carries on here         indented = continues the line above
##   Take this.  [give lantern 1]     [set flag]  [give item] / [give item N]
##   > Accept. -> accepted [set water_quest_accepted]    a choice, then where it leads
##   > Show it. -> thanks [item water_spirits] [if met_mayor]   [item x] [if flag]
##   > Never mind.                    no `->` ends the conversation
##
##   == accepted ==
##   Splendid!
##   -> offer                         after the last line, go to another section
##
## Several lines in a section play one after another. Choices must come last in
## a section, after its final line; `-> end` (or no arrow) ends the conversation.
## Directive and tag words (@speaker, [set ...]) ignore case; names (flags, items,
## sections, speakers) do not. Line text keeps the dialogue box's BBCode ([shake], [pause=0.5], ...).
## Mistakes are reported as `file:line: message` and skipped, never fatal.
## Remember: Godot only exports .dlg files if Export > Resources > "Filters to
## export non-resource files" includes `*.dlg`.

class Beat:
	var raw := ""            ## text as written, before the speaker prefix is split off
	var set_flag := ""
	var give_item := ""
	var give_count := 1
	var line := 0

class ChoiceDef:
	var text := ""
	var target := ""
	var if_flag := ""
	var item := ""
	var set_flag := ""
	var line := 0

class Section:
	var id := ""
	var line := 0
	var beats: Array[Beat] = []
	var choices: Array[ChoiceDef] = []
	var tail := ""           ## `-> target` after the last line
	var tail_line := 0
	var first: DialogueNode

class Mods:
	var text := ""
	var set_flag := ""
	var if_flag := ""
	var item := ""
	var give_item := ""
	var give_count := 1

class When:
	var flag := ""
	var target := ""
	var line := 0

static var _cache: Dictionary = {}   ## path -> DialogueScript
static var _mod_regex: RegEx

var _source := ""
var _speakers: Array[String] = []
var _sections: Dictionary = {}       ## id -> Section
var _order: Array[Section] = []
var _whens: Array[When] = []
var _start := ""
var _errors: Array[String] = []

## Parses (and caches) a .dlg file. Returns null if it can't be read.
static func load_file(path: String) -> DialogueScript:
	if _cache.has(path):
		return _cache[path] as DialogueScript
	if not FileAccess.file_exists(path):
		push_error("DialogueParser: no such file: %s" % path)
		return null
	var script := parse(FileAccess.get_file_as_string(path), path)
	_cache[path] = script
	return script

## Parses .dlg source text. `source` is only used in error messages.
static func parse(text: String, source := "<dlg>") -> DialogueScript:
	var parser := DialogueParser.new()
	parser._source = source
	return parser._run(text)

# ------------------------------------------------------------------ reading

func _run(text: String) -> DialogueScript:
	var current: Section = null
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges(false, true)
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("@"):
			_directive(trimmed, n)
		elif trimmed.begins_with("=="):
			current = _begin_section(trimmed, n)
		elif current == null:
			_error(n, "text before the first `== section ==` header")
		elif trimmed.begins_with(">"):
			_choice(current, trimmed.substr(1).strip_edges(), n)
		elif trimmed.begins_with("->"):
			_tail(current, trimmed.substr(2).strip_edges(), n)
		elif not current.choices.is_empty() or current.tail != "":
			_error(n, "lines can't come after choices or a `->` — put them before")
		elif (line.begins_with(" ") or line.begins_with("\t")) and not current.beats.is_empty():
			var last: Beat = current.beats.back()
			var mods := _strip_mods(trimmed)
			last.raw += " " + mods.text
			_apply_beat_mods(last, mods)
		else:
			var beat := Beat.new()
			beat.line = n
			var mods := _strip_mods(trimmed)
			beat.raw = mods.text
			_apply_beat_mods(beat, mods)
			current.beats.append(beat)
	return _build()

func _directive(t: String, n: int) -> void:
	var parts := t.substr(1).split(" ", false, 1)
	var directive := parts[0].to_lower()
	var rest := parts[1].strip_edges() if parts.size() > 1 else ""
	match directive:
		"speaker":
			if rest.is_empty():
				_error(n, "@speaker needs a name")
			else:
				_speakers.append(rest)
		"start":
			_start = rest
		"when":
			var arrow := rest.find("->")
			var flag := rest.substr(0, arrow).strip_edges() if arrow >= 0 else ""
			var target := rest.substr(arrow + 2).strip_edges() if arrow >= 0 else ""
			if flag.is_empty() or target.is_empty():
				_error(n, "expected `@when some_flag -> section`")
			else:
				var w := When.new()
				w.flag = flag
				w.target = target
				w.line = n
				_whens.append(w)
		_:
			_error(n, "unknown directive @%s" % directive)

func _begin_section(t: String, n: int) -> Section:
	var id := t.trim_prefix("==").trim_suffix("==").strip_edges()
	if id.is_empty() or not id.is_valid_identifier():
		_error(n, "section names are letters, digits and underscores: `== name ==`")
		return null
	if _sections.has(id):
		_error(n, "section `%s` is defined twice" % id)
		return null
	var s := Section.new()
	s.id = id
	s.line = n
	_sections[id] = s
	_order.append(s)
	return s

func _choice(section: Section, body: String, n: int) -> void:
	if section.beats.is_empty():
		_error(n, "a choice needs a line before it")
		return
	if section.tail != "":
		_error(n, "a section can't have both choices and a `->`")
		return
	var mods := _strip_mods(body)
	var arrow := mods.text.rfind("->")
	var c := ChoiceDef.new()
	c.line = n
	c.text = (mods.text.substr(0, arrow) if arrow >= 0 else mods.text).strip_edges()
	c.target = mods.text.substr(arrow + 2).strip_edges() if arrow >= 0 else ""
	c.if_flag = mods.if_flag
	c.item = mods.item
	c.set_flag = mods.set_flag
	if c.text.is_empty():
		_error(n, "choice has no text")
		return
	section.choices.append(c)

func _tail(section: Section, target: String, n: int) -> void:
	if not section.choices.is_empty():
		_error(n, "a section can't have both choices and a `->`")
	elif target.is_empty():
		_error(n, "expected `-> section`")
	else:
		section.tail = target
		section.tail_line = n

## Pulls the [set x] [if x] [item x] [give x N] tags out of a line. BBCode
## tags like [shake] or [pause=0.5] don't match and stay in the text.
func _strip_mods(t: String) -> Mods:
	if _mod_regex == null:
		_mod_regex = RegEx.create_from_string("(?i)\\s*\\[(set|if|item|give)\\s+(\\w+)(?:\\s+(\\d+))?\\]")
	var mods := Mods.new()
	for m in _mod_regex.search_all(t):
		var value := m.get_string(2)
		match m.get_string(1).to_lower():
			"set":
				mods.set_flag = value
			"if":
				mods.if_flag = value
			"item":
				mods.item = value
			"give":
				mods.give_item = value
				if m.get_string(3) != "":
					mods.give_count = m.get_string(3).to_int()
	mods.text = _mod_regex.sub(t, "", true).strip_edges()
	return mods

func _apply_beat_mods(beat: Beat, mods: Mods) -> void:
	if mods.set_flag != "":
		beat.set_flag = mods.set_flag
	if mods.give_item != "":
		beat.give_item = mods.give_item
		beat.give_count = mods.give_count

# ------------------------------------------------------------------ building

func _build() -> DialogueScript:
	var result := DialogueScript.new()
	var default_speaker := _speakers[0] if not _speakers.is_empty() else ""
	# Longest names first so "Desert Mayor" wins over a shorter "Desert".
	var names := _speakers.duplicate()
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())

	# Pass 1: a DialogueNode per line, chained in order.
	for s in _order:
		if s.beats.is_empty():
			_error(s.line, "section `%s` has no lines" % s.id)
			continue
		var previous: DialogueNode = null
		for beat in s.beats:
			var node := DialogueNode.new()
			node.speaker = default_speaker
			node.text = beat.raw
			for sp: String in names:
				if beat.raw.begins_with(sp + ":"):
					node.speaker = sp
					node.text = beat.raw.substr(sp.length() + 1).strip_edges()
					break
			node.sets_flag = StringName(beat.set_flag)
			node.gives_item = StringName(beat.give_item)
			node.gives_count = beat.give_count
			if previous == null:
				s.first = node
			else:
				previous.next = node
			previous = node

	# Pass 2: the last line of each section gets its choices / next.
	for s in _order:
		if s.first == null:
			continue
		var last := s.first
		while last.next != null:
			last = last.next
		if not s.choices.is_empty():
			var list: Array[DialogueChoice] = []
			for c in s.choices:
				var choice := DialogueChoice.new()
				choice.text = c.text
				choice.next = _resolve(c.target, c.line)
				choice.required_flag = StringName(c.if_flag)
				choice.required_item = StringName(c.item)
				choice.sets_flag = StringName(c.set_flag)
				list.append(choice)
			last.choices = list
		elif s.tail != "":
			last.next = _resolve(s.tail, s.tail_line)

	# Entry + flag-switched alternatives.
	var entry_id := _start
	if entry_id.is_empty() and not _order.is_empty():
		entry_id = _order[0].id
	result.entry = _resolve(entry_id, 0)
	for w in _whens:
		var variant := DialogueVariant.new()
		variant.required_flag = StringName(w.flag)
		variant.dialogue = _resolve(w.target, w.line)
		if variant.dialogue != null:
			result.variants.append(variant)
	result.errors = _errors
	return result

## Section id -> its first DialogueNode; "" / "end" -> null (conversation over).
func _resolve(target: String, n: int) -> DialogueNode:
	if target.is_empty() or target == "end":
		return null
	var s: Section = _sections.get(target)
	if s == null or s.first == null:
		_error(n, "no section named `%s`" % target)
		return null
	return s.first

func _error(n: int, message: String) -> void:
	var text := "%s:%d: %s" % [_source, n, message]
	_errors.append(text)
	push_error("DialogueParser: " + text)
