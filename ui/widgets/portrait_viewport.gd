class_name PortraitViewport
extends Control
## Live 3D headshot for the HUD portrait. Renders a *second*, independent
## copy of the player model into an isolated SubViewport (its own lights,
## camera and World3D — never the gameplay scene) and displays it through a
## TextureRect. Looping the idle clip keeps it in sync with the in-game
## character without ever touching Player or the live PlayerVisual, so
## nothing here can affect — or be affected by — gameplay.
##
## Composited on top of the portrait frame art by Hud._build_meter_cluster();
## the viewport's background is transparent, and the render itself is
## clipped to a circle (see CIRCLE_MASK_SHADER_CODE) so the frame's border
## shows through cleanly all the way around instead of a square poking out.

const RENDER_SIZE := 256                ## SubViewport resolution, independent of the Control's size
const CAMERA_DISTANCE := 0.9
const CAMERA_HEIGHT_FRAC := 0.62         ## fraction up the model's height the camera frames (a bust shot)
const OUTLINE_WIDTH_PX := 2.0   ## same screen-space-dilation idea as OutlineSystem, just sized for this render's 256x256, not the main viewport's
const OUTLINE_COLOR := Color.BLACK
const PORTRAIT_TURN := 0.32   ## extra yaw (rad) so the portrait isn't a flat mirror-facing
                               ## shot — turns the character slightly left; flip the sign
                               ## if it reads as turning right instead

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
uniform float outline_width_px : hint_range(0.0, 16.0) = 2.0;

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
	float circle_edge = 1.0 - smoothstep(0.48, 0.5, dist);
	COLOR = vec4(rgb, alpha * circle_edge);
}
"""

var _viewport: SubViewport
var _model: Node3D
var _anim: AnimationPlayer

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	circle_mat.set_shader_parameter(&"outline_width_px", OUTLINE_WIDTH_PX)
	tex_rect.material = circle_mat
	add_child(tex_rect)

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
	_model.rotation.y = PlayerVisual.MODEL_FACING_OFFSET + PORTRAIT_TURN
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	ModelUtil.fit_height(_model, Player.STAND_HEIGHT)
	# No outline_hook here — the outline is drawn entirely by
	# CIRCLE_MASK_SHADER_CODE above, against this render's own alpha, rather
	# than by giving any mesh a hook callback that builds outline geometry.
	ModelUtil.apply_cel_shading(_model)

	if _anim != null and _anim.has_animation(PlayerVisual.ANIM_IDLE):
		_anim.get_animation(PlayerVisual.ANIM_IDLE).loop_mode = Animation.LOOP_LINEAR
		_anim.play(PlayerVisual.ANIM_IDLE)

	var cam := Camera3D.new()
	var look_at_pos := Vector3(0.0, Player.STAND_HEIGHT * CAMERA_HEIGHT_FRAC, 0.0)
	# MODEL_FACING_OFFSET turns the model to face -Z (Godot's forward), so the
	# camera has to sit on the -Z side to see the front of the face rather
	# than the back of the head.
	cam.position = look_at_pos + Vector3(0.0, 0.0, -CAMERA_DISTANCE)
	world.add_child(cam)
	cam.look_at(look_at_pos, Vector3.UP)
	cam.current = true
