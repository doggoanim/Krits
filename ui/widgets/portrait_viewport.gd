class_name PortraitViewport
extends Control
## Live 3D headshot for the HUD portrait. Renders a *second*, independent
## copy of the player model into an isolated SubViewport (its own lights,
## camera and World3D — never the gameplay scene) and displays it through a
## TextureRect. Looping the idle clip and listening for outfit changes keeps
## it in sync with the in-game character without ever touching Player or the
## live PlayerVisual, so nothing here can affect — or be affected by —
## gameplay.
##
## Composited between PortraitSlot's grey fill (behind) and its ring outline
## (in front) by Hud._build_meter_cluster(); the viewport's background is
## transparent, so the disc shows through anywhere the model doesn't cover.

const RENDER_SIZE := 256                ## SubViewport resolution, independent of the Control's size
const CAMERA_DISTANCE := 1.6
const CAMERA_HEIGHT_FRAC := 0.62         ## fraction up the model's height the camera frames (a bust shot)
const OUTLINE_THICKNESS_RATIO := 0.011   ## matches PlayerVisual's default

var _viewport: SubViewport
var _model: Node3D
var _anim: AnimationPlayer
var _outfit_materials: Array[BaseMaterial3D] = []

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
	add_child(tex_rect)

	Events.outfit_changed.connect(func(id: StringName): _apply_outfit(OutfitLibrary.get_outfit(id)))

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
	_model.rotation.y = PlayerVisual.MODEL_FACING_OFFSET
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	# fit_height scales _model so it's Player.STAND_HEIGHT tall in world space,
	# but it returns the AABB it measured *before* that scaling — still the
	# right thing to size the outline from (CelOutline's grow_amount is
	# applied inside the model's own pre-scale local space, so it ends up
	# visually correct either way), but the WRONG thing to frame the camera
	# with: the camera sits outside the model in world space, so it needs the
	# model's actual post-scale height, i.e. Player.STAND_HEIGHT itself.
	var fit_box := ModelUtil.fit_height(_model, Player.STAND_HEIGHT)
	var pre_scale_height := fit_box.size.y if fit_box.size.y > 0.001 else Player.STAND_HEIGHT
	var materials: Array[BaseMaterial3D] = []
	ModelUtil.apply_cel_shading(_model, pre_scale_height * OUTLINE_THICKNESS_RATIO, Color.BLACK, materials)
	for m in materials:
		if m.resource_name in PlayerVisual.OUTFIT_SLOTS:
			_outfit_materials.append(m)
	_apply_outfit(OutfitLibrary.get_outfit(Game.outfit))

	if _anim != null and _anim.has_animation(PlayerVisual.ANIM_IDLE):
		_anim.get_animation(PlayerVisual.ANIM_IDLE).loop_mode = Animation.LOOP_LINEAR
		_anim.play(PlayerVisual.ANIM_IDLE)

	var cam := Camera3D.new()
	var look_at_pos := Vector3(0.0, Player.STAND_HEIGHT * CAMERA_HEIGHT_FRAC, 0.0)
	cam.position = look_at_pos + Vector3(0.0, 0.0, CAMERA_DISTANCE)
	world.add_child(cam)
	cam.look_at(look_at_pos, Vector3.UP)
	cam.current = true

func _apply_outfit(o: OutfitData) -> void:
	for m in _outfit_materials:
		m.albedo_color = o.color
