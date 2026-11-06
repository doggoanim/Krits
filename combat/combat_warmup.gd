class_name CombatWarmup
extends Node
## Pre-draws everything a first fight puts on screen, once per run, so the
## fight itself doesn't stall.
##
## Godot compiles a shader / particle pipeline the first time something using
## it is actually drawn. Left alone, that first happens all at once when the
## first encounter starts (arena walls, orbs, the slime's outline, hit bursts,
## particles...) as one big freeze. Instead, shortly after the game starts we
## draw a tiny copy of each combat visual a few metres in front of the camera,
## one group at a time over a few frames, then throw them all away. Nothing is
## visible at that size, and the small compile cost is spread out while the
## player is just walking around.
##
## Adding a new combat effect? Add one `_warm_*` function that spawns it into
## `_stage` and list it in _steps().

static var _done := false

const START_DELAY := 1.5      ## let the level finish loading and the first frames settle
const STEP_FRAMES := 3        ## frames each group stays on screen (a pipeline compiles on its first draw)
const STAGE_SCALE := 0.02     ## so small it can't be seen
const STAGE_DISTANCE := 3.0   ## metres in front of the camera

var _camera: Camera3D
var _stage: Node3D            ## everything warmed lives under here; its processing is off so nothing runs or collides

## Call once from Main after the camera exists. Later calls do nothing.
static func start(host: Node, camera: Camera3D) -> void:
	if _done or camera == null:
		return
	_done = true
	var warmup := CombatWarmup.new()
	warmup._camera = camera
	host.add_child(warmup)
	warmup._run()

func _process(_delta: float) -> void:
	_follow_camera()

## Keeps the stage a few metres in front of the camera so it is always in view.
func _follow_camera() -> void:
	if _stage != null and is_instance_valid(_camera):
		var basis := _camera.global_basis.orthonormalized()
		_stage.global_transform = Transform3D(basis.scaled(Vector3.ONE * STAGE_SCALE),
				_camera.global_position - basis.z * STAGE_DISTANCE)

func _run() -> void:
	await get_tree().create_timer(START_DELAY).timeout
	_stage = Node3D.new()
	_stage.process_mode = Node.PROCESS_MODE_DISABLED   # no physics, no AI, no hits — drawing only
	add_child(_stage)
	for step in _steps():
		if not is_instance_valid(_camera):
			break
		_follow_camera()   # positioned before anything spawns into it
		step.call()
		for i in STEP_FRAMES:
			await get_tree().process_frame
		_clear_stage()
	queue_free()

func _steps() -> Array[Callable]:
	return [_warm_arena, _warm_orbs, _warm_enemies, _warm_telegraphs,
			_warm_particles, _warm_projectiles]

func _clear_stage() -> void:
	for child in _stage.get_children():
		child.queue_free()

# --- Groups ------------------------------------------------------------------

## The barrier's wall and platform shaders.
func _warm_arena() -> void:
	_add_mesh(BoxMesh.new(), Arena.WALL_SHADER)
	_add_mesh(CylinderMesh.new(), Arena.PLATFORM_SHADER)

## One orb of every kind (core, ring, outline, icon shader, shadow).
func _warm_orbs() -> void:
	for kind in Orb.Kind.values():
		var orb := Orb.new()
		orb.kind = kind as Orb.Kind
		_stage.add_child(orb)

## The slime (skinned model, cel shading, outline) with all status effects on,
## plus the plain toon-sphere look the model-less enemies use.
func _warm_enemies() -> void:
	var slime := EnemyLibrary.green_slime()
	if slime.model != null:
		var visual := EnemyVisual.new()
		_stage.add_child(visual)
		visual.setup(slime)
		var fx := StatusFx.new()
		_stage.add_child(fx)
		fx.setup(visual, 0.5, 1.0, 0.5)
		for effect in [&"burn", &"slow", &"stun"]:
			fx.set_active(effect, true)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	ball.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ball.material_override = mat
	_stage.add_child(ball)
	CelOutline.apply(ball, 0.05)

func _warm_telegraphs() -> void:
	Telegraph.circle(_stage, 1.0).set_fill(0.5)
	Telegraph.line(_stage, 0.5)
	Telegraph.exclaim(_stage, 0.0)

## Hit numbers, shard/smoke/splash bursts and the earth pillar.
func _warm_particles() -> void:
	var at := _stage.global_position
	HitBurst.spawn(_stage, at, 12.0)
	HitBurst.spawn(_stage, at, 12.0, 1.0, true)
	SplashFx.spawn(_stage, at, Color(0.35, 0.55, 0.18))
	VFX.shatter(_stage, at, Color.WHITE)
	VFX.smoke_puff(_stage, at)
	EarthPillar.spawn(_stage, at, 1.0, 0.5)

func _warm_projectiles() -> void:
	var plain := Bullet.new()
	_stage.add_child(plain)
	var piercing := Bullet.new()
	piercing.pierces_shield = true
	_stage.add_child(piercing)
	_stage.add_child(SlimePuddle.new())

# --- Helpers -----------------------------------------------------------------

func _add_mesh(mesh: Mesh, shader: Shader) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mi.material_override = mat
	_stage.add_child(mi)
