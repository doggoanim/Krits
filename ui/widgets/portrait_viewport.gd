class_name PortraitViewport
extends Control
## Live 3D headshot for the HUD portrait. Renders a *second*, independent
## copy of the player model into an isolated SubViewport (its own lights,
## camera and World3D — never the gameplay scene) and displays it through a
## TextureRect. Looping the idle clip keeps the pose in sync with the in-game
## character without ever touching Player or driving the live PlayerVisual —
## the one exception is the face (see _sync_face): every frame this reads
## (never writes) the real PlayerVisual's current expression() and mirrors
## the same texture onto this copy's own face material, so the portrait
## blinks/winces in lockstep with the actual character instead of running an
## independent blink timer of its own that could drift out of sync. Strictly
## one-way — nothing here can affect gameplay, only observe it.
##
## Composited on top of the portrait frame art by Hud._build_meter_cluster();
## the viewport's background is transparent, and the render itself is
## clipped to a circle (see CIRCLE_MASK_SHADER_CODE) so the frame's border
## shows through cleanly all the way around instead of a square poking out.

const CAMERA_HEIGHT_FRAC := 0.62         ## fraction up the model's height the camera frames (a bust shot)
const OUTLINE_COLOR := Color.BLACK

## The HUD uses the defaults (a 256px circular headshot turned slightly left);
## the pause menu overrides them in pause_menu.tscn for a big, rectangular,
## right-turned, clickable portrait.
@export_group("Render")
@export var render_size := 256         ## SubViewport resolution, independent of the Control's size
@export var camera_distance := 0.9     ## how far the camera sits from the character — larger = smaller in frame (less clipping)
@export var circular := true           ## clip the render to a circle (HUD frame) — off for a free-standing portrait
@export var outline_width_px := 2.0    ## same screen-space-dilation idea as OutlineSystem, sized for this render, not the main viewport's
@export var turn := 0.32               ## extra yaw (rad) so it isn't a flat mirror-facing shot: positive turns the character left, negative right
@export var only_when_visible := false ## don't render while hidden (for a portrait that's only sometimes on screen)
@export var mirror_player_face := true ## copy the live player's expression each frame (HUD). Off = run its own blink timer, for a portrait shown while the game is paused (the player's own face is frozen then)

@export_group("Click squish")
@export var clickable := false
@export var squish_sound: AudioStream
@export var squish_pitch_range := Vector2(0.8, 1.3)   ## random pitch_scale per click
@export_range(0.0, 1.0) var squish_pivot_y := 0.85    ## where on the control the squash anchors (fraction down) — near the character's base
@export var sfx_bus := &"SFX"

## Clips the render to a circle inscribed in the TextureRect's own rect (a
## true circle only when that rect is square, which is how Hud sizes
## PORTRAIT_VIEW_SIZE — without this, a wide pose could reach the render's
## square corners and poke past the frame art's circular border instead of
## being cropped by it) AND draws the character's outline — same technique
## as OutlineSystem (core/outline_system.gd), just folded into this one
## shader instead of a separate camera/viewport/compositor: this render
## already contains nothing but the character on a transparent background
## (see _build_scene — no world geometry, no second camera needed), so its
## own TEXTURE *is* already the clean silhouette to dilate. No per-mesh
## CelOutline hulls here at all anymore, so no seam between body parts to
## worry about either.
const CIRCLE_MASK_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width_px : hint_range(0.0, 32.0) = 2.0;
uniform bool circular = true;

void fragment() {
	vec2 texel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec4 tex = texture(TEXTURE, UV);

	// Approximate circular dilation of TEXTURE's own alpha (see
	// outline_overlay.gdshader for the same technique at full-screen scale) —
	// wherever that's stronger than this pixel's own alpha, an outline ring
	// belongs here.
	float dilated = tex.a;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * (TAU / 8.0);
		vec2 dir = vec2(cos(angle), sin(angle));
		dilated = max(dilated, texture(TEXTURE, UV + dir * outline_width_px * texel_size).a);
		dilated = max(dilated, texture(TEXTURE, UV + dir * outline_width_px * 0.5 * texel_size).a);
	}
	float ring = clamp(dilated - tex.a, 0.0, 1.0);

	vec3 rgb = mix(tex.rgb, outline_color.rgb, ring);
	float alpha = max(tex.a, ring * outline_color.a);

	float dist = length(UV - vec2(0.5));
	float circle_edge = circular ? 1.0 - smoothstep(0.48, 0.5, dist) : 1.0;
	COLOR = vec4(rgb, alpha * circle_edge);
}
"""

var _viewport: SubViewport
var _model: Node3D
var _anim: AnimationPlayer
var _face_material: ShaderMaterial   ## null if the model has no "Face*"-named surface
var _synced_expression: StringName = &""   ## last expression copied from the live player (see _sync_face)

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(render_size, render_size)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if only_when_visible \
			else SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_build_scene()

	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.texture = _viewport.get_texture()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   ## don't force this Control to the render's 256x256
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE       ## ...scale it to the portrait's actual size instead
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle_shader := Shader.new()
	circle_shader.code = CIRCLE_MASK_SHADER_CODE
	var circle_mat := ShaderMaterial.new()
	circle_mat.shader = circle_shader
	circle_mat.set_shader_parameter(&"outline_color", OUTLINE_COLOR)
	circle_mat.set_shader_parameter(&"outline_width_px", outline_width_px)
	circle_mat.set_shader_parameter(&"circular", circular)
	tex_rect.material = circle_mat
	add_child(tex_rect)
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE

func _build_scene() -> void:
	var world := Node3D.new()
	_viewport.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	key_light.light_energy = 1.1
	world.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill_light.light_energy = 0.35
	world.add_child(fill_light)

	_model = PlayerVisual.MODEL_SCENE.instantiate()
	world.add_child(_model)
	_model.rotation.y = PlayerVisual.MODEL_FACING_OFFSET + turn
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	ModelUtil.fit_height(_model, Player.STAND_HEIGHT)
	# No outline_hook here — the outline is drawn entirely by
	# CIRCLE_MASK_SHADER_CODE above, against this render's own alpha, rather
	# than by giving any mesh a hook callback that builds outline geometry.
	var face_materials: Dictionary = {}
	ModelUtil.apply_cel_shading(_model, [], face_materials)
	_face_material = face_materials.values()[0] if not face_materials.is_empty() else null

	if _anim != null and _anim.has_animation(PlayerVisual.ANIM_IDLE):
		_anim.get_animation(PlayerVisual.ANIM_IDLE).loop_mode = Animation.LOOP_LINEAR
		_anim.play(PlayerVisual.ANIM_IDLE)

	var cam := Camera3D.new()
	var look_at_pos := Vector3(0.0, Player.STAND_HEIGHT * CAMERA_HEIGHT_FRAC, 0.0)
	# MODEL_FACING_OFFSET turns the model to face -Z (Godot's forward), so the
	# camera has to sit on the -Z side to see the front of the face rather
	# than the back of the head.
	cam.position = look_at_pos + Vector3(0.0, 0.0, -camera_distance)
	world.add_child(cam)
	cam.look_at(look_at_pos, Vector3.UP)
	cam.current = true

func _process(delta: float) -> void:
	if mirror_player_face:
		_sync_face()
	else:
		_update_own_face(delta)

# --- Own face (when not mirroring the player) -------------------------------------
# Same behaviour as PlayerVisual's: random idle blinks, and a hurt face that
# wins over blinking while it lasts (squish() triggers it).

var _blink_cd := randf_range(PlayerVisual.BLINK_INTERVAL_MIN, PlayerVisual.BLINK_INTERVAL_MAX)
var _blink_hold := 0.0
var _hurt_hold := 0.0

func _update_own_face(delta: float) -> void:
	if _hurt_hold > 0.0:
		_hurt_hold -= delta
		_apply_expression(&"hurt")
		if _hurt_hold <= 0.0:
			_blink_cd = randf_range(PlayerVisual.BLINK_INTERVAL_MIN, PlayerVisual.BLINK_INTERVAL_MAX)
		return
	if _blink_hold > 0.0:
		_blink_hold -= delta
		if _blink_hold <= 0.0:
			_blink_cd = randf_range(PlayerVisual.BLINK_INTERVAL_MIN, PlayerVisual.BLINK_INTERVAL_MAX)
	else:
		_blink_cd -= delta
		if _blink_cd <= 0.0:
			_blink_hold = PlayerVisual.BLINK_DURATION
	_apply_expression(&"blink" if _blink_hold > 0.0 else PlayerVisual.DEFAULT_EXPRESSION)

func _apply_expression(expr: StringName) -> void:
	if _face_material == null or expr == _synced_expression:
		return
	var tex: Texture2D = PlayerVisual.FACE_EXPRESSIONS.get(expr)
	if tex == null:
		return
	_synced_expression = expr
	ModelUtil.set_albedo_texture(_face_material, tex)

# --- Click squish ---------------------------------------------------------------

var _squish_tween: Tween

func _gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and _is_on_character(click.position):
		accept_event()
		squish()

## Squashes and stretches the portrait like a toy being squeezed, with a
## pitch-varied squeak. Snappy: four quick steps, the last one springing back.
func squish() -> void:
	if _squish_tween and _squish_tween.is_valid():
		_squish_tween.kill()
	pivot_offset = Vector2(size.x * 0.5, size.y * squish_pivot_y)
	scale = Vector2.ONE
	_squish_tween = create_tween()
	_squish_tween.tween_property(self, "scale", Vector2(1.3, 0.62), 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squish_tween.tween_property(self, "scale", Vector2(0.86, 1.2), 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squish_tween.tween_property(self, "scale", Vector2(1.07, 0.94), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_squish_tween.tween_property(self, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hurt_hold = PlayerVisual.HURT_EXPRESSION_DURATION   # hurt face for the squeeze (own-face mode)
	_blink_hold = 0.0
	_play_squeak()

func _play_squeak() -> void:
	if squish_sound == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = squish_sound
	player.bus = sfx_bus
	player.pitch_scale = randf_range(squish_pitch_range.x, squish_pitch_range.y)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## Only clicks that land on the character (not the empty transparent area
## around him) count — checked against the render's own alpha.
func _is_on_character(local_pos: Vector2) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var image := _viewport.get_texture().get_image()
	if image == null:
		return false
	var px := Vector2i((local_pos / size * Vector2(image.get_size())).floor())
	px = px.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(px).a > 0.1

## Mirrors the live player's current face expression (blink, hurt, ...) onto
## this copy's own face material — read-only, see this file's header comment.
## Looked up by group each frame rather than cached once, since the actual
## Player node may not exist yet when this HUD element is first ready (e.g.
## shown briefly before the player spawns) and `get_first_node_in_group` is
## cheap. A no-op (same as set_expression()'s own unknown-name handling) if
## there's no player, no face material on either model, or the expression
## hasn't changed since last frame.
func _sync_face() -> void:
	if _face_material == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.visual == null:
		return
	_apply_expression(player.visual.expression())
