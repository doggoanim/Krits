class_name FoliageWind
extends Node
## Drop this in as a CHILD of any world prop you want swaying in the wind —
## a tree, a grass clump, a bush, anything with MeshInstance3Ds underneath
## it (see world/chesburg.tscn's Props/Trees and Props/eyecandies for the
## props this is meant for). On ready, it rewrites every mesh surface under
## its own parent to shading/foliage_wind.gdshader, copying across that
## surface's existing look (albedo texture/color, vertex-color flag,
## roughness, metallic) so nothing changes visually except the sway itself.
##
## Why a sibling-of-the-mesh node instead of a script on the prop: every
## tree/grass asset here is an unmodified imported .glb instance with no
## script of its own (see world/chesburg.tscn) — adding this as a plain
## child node opts a prop into wind sway with zero changes to the asset,
## the same "bolt it on" idiom as OutlineSystem/PixelateEffect elsewhere in
## this project. It's a real scene node (unlike those two), so its tunables
## below are directly editable per-instance in the Inspector — no push-down-
## from-Main indirection needed.
##
## wind_strength is world units of sway per world unit of the mesh's own
## local height — see the shader's header comment for why that scaling needs
## no per-asset calibration. The defaults read as a gentle grass flutter;
## bump wind_strength down for a prop that reads as too wild (a tall tree's
## crown sways further for the same value, being further from its root).
##
## Every frame, this also samples WindGusts.sample() (world/wind_gusts.gd)
## at its own position and pushes the result into each material's `gust`
## uniform — see that file for how the shared gust field works. Set
## `react_to_gusts = false` on a particular instance to opt it out and keep
## a constant idle sway instead (a prop tucked somewhere a sweeping gust
## wouldn't read as sensible, say).

const SHADER := preload("res://shading/foliage_wind.gdshader")

@export var wind_strength := 0.06
@export var wind_speed := 1.5
@export var wind_scale := 0.3
@export var react_to_gusts := true
## Multiplied into this prop's green texels only (leaves/grass — the trunk is
## untouched). White = no change. TreeVariation sets this per tree.
@export var green_tint := Color.WHITE

## Stepping through it (see player/foliage_steps.gd): grass and flowers flatten and lean
## away from the player's feet, bushes shake, and all of them kick up particles. Which
## one a prop is comes from its name or model file (grass / flower / bush / berry), so
## trees and anything else are left alone. `step_bend` < 0 = the default for its kind.
@export var react_to_steps := true
@export var step_bend := -1.0

enum Kind { NONE, GRASS, FLOWER, BUSH }
const GROUP := &"steppable_foliage"
const BEND_BY_KIND := {Kind.GRASS: 1.0, Kind.FLOWER: 0.8, Kind.BUSH: 0.2}
const RUSTLE_DECAY := 3.0

## Bush rustle takes (four recordings; one is picked at random, never the same twice
## in a row): when the player walks into a bush, and a quieter one when a gust of
## breeze sweeps over it.
const RUSTLE_SFX: Array[AudioStream] = [
	preload("res://sounds/SFX/others/bush_rustle_1.wav"),
	preload("res://sounds/SFX/others/bush_rustle_2.wav"),
	preload("res://sounds/SFX/others/bush_rustle_3.wav"),
	preload("res://sounds/SFX/others/bush_rustle_4.wav"),
]
const SFX_BUS := &"SFX"
const STEP_RUSTLE_DB := Vector2(-12.0, -3.0)   ## quietest / loudest walk-in rustle (slow to fast)
const STEP_SOUND_GAP_MSEC := 450               ## one bush won't rustle again this soon
const BREEZE_THRESHOLD := 1.25                 ## the gust level (WindGusts, 0.5 calm to 1.8 peak) that counts as "the breeze arrives"
const BREEZE_RUSTLE_DB := -13.0
const BREEZE_VISUAL_RUSTLE := 0.25             ## how much the bush shakes visually in the breeze
const BREEZE_HEARING := 18.0                   ## only bushes this close to the player make breeze sounds
const BREEZE_GAP_MSEC := Vector2i(1400, 3400)  ## a breeze across many bushes still only rustles every so often
static var _last_variant := -1
static var _breeze_next_msec := 0

var kind := Kind.NONE
var petal_color := Color(0.98, 0.55, 0.7)   ## flowers: what the petals thrown up look like
var reach := 0.6                            ## horizontal radius (m) within which stepping affects it
var _rustle := 0.0
var _step_sound_msec := 0
var _prev_gust := 0.0

var _materials: Array[ShaderMaterial] = []
var _anchor: Node3D   ## whatever _ready() finds itself attached to, for gust position sampling

func _ready() -> void:
	var parent := get_parent()
	if parent:
		_apply_recursive(parent)
	_anchor = parent as Node3D
	if react_to_steps and _anchor != null:
		_detect_kind()
	set_process((react_to_gusts or kind != Kind.NONE) and _anchor != null)

func _process(delta: float) -> void:
	var pos := _anchor.global_position
	if react_to_gusts:
		var gust := WindGusts.sample(Vector2(pos.x, pos.z), Time.get_ticks_msec() / 1000.0)
		for mat in _materials:
			mat.set_shader_parameter(&"gust", gust)
		if kind == Kind.BUSH and _prev_gust < BREEZE_THRESHOLD and gust >= BREEZE_THRESHOLD:
			_on_breeze()
		_prev_gust = gust
	if _rustle > 0.0:
		_rustle = maxf(_rustle - RUSTLE_DECAY * delta, 0.0)
		for mat in _materials:
			mat.set_shader_parameter(&"rustle", _rustle)

## The player is moving through this (called by FoliageSteps): shake it. 0..1.
func step_on(strength: float) -> void:
	if kind != Kind.BUSH:
		return
	var now := Time.get_ticks_msec()
	if _rustle < 0.15 and now - _step_sound_msec >= STEP_SOUND_GAP_MSEC:   # a fresh disturbance, not the same shake continuing
		_step_sound_msec = now
		_play_rustle(lerpf(STEP_RUSTLE_DB.x, STEP_RUSTLE_DB.y, clampf(strength, 0.0, 1.0)))
	_set_rustle(strength)

func _set_rustle(amount: float) -> void:
	_rustle = maxf(_rustle, clampf(amount, 0.0, 1.0))
	for mat in _materials:
		mat.set_shader_parameter(&"rustle", _rustle)

## A gust reaches this bush: it shivers, and (for bushes near the player, and only
## every so often) a soft rustle plays.
func _on_breeze() -> void:
	_set_rustle(BREEZE_VISUAL_RUSTLE)
	var now := Time.get_ticks_msec()
	if now < _breeze_next_msec:
		return
	var listener := get_tree().get_first_node_in_group(&"player") as Node3D
	if listener == null or listener.global_position.distance_to(_anchor.global_position) > BREEZE_HEARING:
		return
	_breeze_next_msec = now + randi_range(BREEZE_GAP_MSEC.x, BREEZE_GAP_MSEC.y)
	_play_rustle(BREEZE_RUSTLE_DB)

func _play_rustle(volume_db: float) -> void:
	var pick := randi() % RUSTLE_SFX.size()
	if pick == _last_variant:
		pick = (pick + 1 + randi() % (RUSTLE_SFX.size() - 1)) % RUSTLE_SFX.size()
	_last_variant = pick
	var p := AudioStreamPlayer3D.new()
	p.stream = RUSTLE_SFX[pick]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.bus = SFX_BUS
	p.unit_size = 5.0
	p.max_distance = 25.0
	_anchor.add_child(p)
	p.position = Vector3(0.0, 0.4, 0.0)
	p.play()
	p.finished.connect(p.queue_free)

func _detect_kind() -> void:
	var label := (_anchor.name + " " + _anchor.scene_file_path.get_file()).to_lower()
	if label.contains("terrain"):
		return   # ground meshes are not foliage you walk through
	if label.contains("flower"):
		kind = Kind.FLOWER
		if label.contains("red"):
			petal_color = Color(0.95, 0.25, 0.3)
		elif label.contains("blue"):
			petal_color = Color(0.4, 0.6, 1.0)
		elif label.contains("green"):
			petal_color = Color(0.55, 0.9, 0.4)
		elif label.contains("yellow"):
			petal_color = Color(1.0, 0.85, 0.3)
	elif label.contains("bush") or label.contains("berry"):
		kind = Kind.BUSH
	elif label.contains("grass"):
		kind = Kind.GRASS
	if kind == Kind.NONE:
		return
	add_to_group(GROUP)
	var bend := step_bend if step_bend >= 0.0 else float(BEND_BY_KIND[kind])
	for mat in _materials:
		mat.set_shader_parameter(&"step_bend", bend)
	var box := _local_box(_anchor)
	var scale := _anchor.global_transform.basis.get_scale()
	reach = clampf(maxf(box.size.x * scale.x, box.size.z * scale.z) * 0.5, 0.4, 1.8)

## Bounding box of every mesh under `n`, in n's own space (approximate: ignores rotation of children).
func _local_box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _apply_recursive(n: Node) -> void:
	if n is MeshInstance3D:
		_wind_ify(n as MeshInstance3D)
	for c in n.get_children():
		if c != self:
			_apply_recursive(c)

func _wind_ify(mi: MeshInstance3D) -> void:
	# Sway height is measured from wherever this mesh's geometry actually
	# starts, not blindly from local Y=0 — most foliage here has its pivot at
	# the base already (so this is just 0), but an asset authored with its
	# pivot somewhere else (a flower card centered on its own bounding box,
	# say) would otherwise see most/all of its vertices read as height 0 and
	# barely sway — see the shader's own comment on base_y.
	var base_y := mi.mesh.get_aabb().position.y if mi.mesh else 0.0
	for i in mi.mesh.get_surface_count() if mi.mesh else 0:
		var src := mi.get_active_material(i)
		var wind_mat := ShaderMaterial.new()
		wind_mat.shader = SHADER

		# Same "copy the look across" approach as ModelUtil._shade_recursive()
		# (core/model_util.gd), just targeting plain imported materials
		# instead of toon-shaded character ones — an untextured/non-
		# BaseMaterial3D surface falls back to white rather than leaving the
		# sampler unbound, which Godot reads back as solid black.
		var tex := ModelUtil.white_texture()
		var tint := Color.WHITE
		var use_vertex_color := false
		var roughness := 1.0
		var metallic := 0.0
		var alpha_scissor := 0.0
		if src is BaseMaterial3D:
			var base := src as BaseMaterial3D
			tex = base.albedo_texture if base.albedo_texture else ModelUtil.white_texture()
			tint = base.albedo_color
			use_vertex_color = base.vertex_color_use_as_albedo
			roughness = base.roughness
			metallic = base.metallic
			if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				alpha_scissor = base.alpha_scissor_threshold

		wind_mat.set_shader_parameter(&"albedo_texture", tex)
		wind_mat.set_shader_parameter(&"albedo_color", tint)
		wind_mat.set_shader_parameter(&"use_vertex_color", use_vertex_color)
		wind_mat.set_shader_parameter(&"roughness", roughness)
		wind_mat.set_shader_parameter(&"metallic", metallic)
		wind_mat.set_shader_parameter(&"alpha_scissor_threshold", alpha_scissor)
		wind_mat.set_shader_parameter(&"wind_strength", wind_strength)
		wind_mat.set_shader_parameter(&"wind_speed", wind_speed)
		wind_mat.set_shader_parameter(&"wind_scale", wind_scale)
		wind_mat.set_shader_parameter(&"base_y", base_y)
		wind_mat.set_shader_parameter(&"green_tint", green_tint)
		mi.set_surface_override_material(i, wind_mat)
		_materials.append(wind_mat)
