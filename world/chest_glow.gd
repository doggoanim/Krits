class_name ChestGlow
extends Node3D
## "There's still something inside": warm light rays leaking out of the seam
## between a chest's lid and body, plus a faint glow on the ground around it.
## Pure decoration — Chest owns when it shows (an unlooted, closed chest) and
## just calls fade_to().
##
## Place the node at the seam's height at the chest's centre; three tilted
## streaky sheets (front and both sides, see chest_glow.gdshader) rise from the gap
## and an OmniLight3D adds the spill.

const SHADER: Shader = preload("res://world/chest_glow.gdshader")

@export var half_extents := Vector2(0.52, 0.33)   ## half width (x) and depth (z) of the chest at the seam
@export var ray_height := 0.6                     ## how far the rays reach above the gap
@export var tilt_deg := 14.0                      ## how far the rays lean outward
@export var glow_color := Color(1.0, 0.85, 0.5)
@export var light_energy := 0.9
@export var light_range := 3.5

var amount := 0.0:
	set(v):
		amount = v
		_apply()

var _material: ShaderMaterial
var _light: OmniLight3D
var _age := 0.0
var _tween: Tween

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"glow_color", glow_color)
	# +Z = front. Sheets face out of the front and both sides; nothing leaks at the
	# back, where the hinges are.
	_add_sheet(Vector3(0.0, 0.0, half_extents.y), 0.0, half_extents.x * 2.0)
	_add_sheet(Vector3(half_extents.x, 0.0, 0.0), PI * 0.5, half_extents.y * 2.0)
	_add_sheet(Vector3(-half_extents.x, 0.0, 0.0), -PI * 0.5, half_extents.y * 2.0)
	_light = OmniLight3D.new()
	_light.light_color = glow_color
	_light.omni_range = light_range
	_light.shadow_enabled = false
	_light.light_specular = 0.0
	add_child(_light)
	_apply()

func _process(delta: float) -> void:
	if amount <= 0.0 or _light == null:
		return
	_age += delta
	_light.light_energy = light_energy * amount * (0.9 + 0.1 * sin(_age * 2.1))

## Fades the rays to `target` (0 = off, 1 = full) over `duration` seconds.
func fade_to(target: float, duration := 0.4) -> void:
	if _tween != null:
		_tween.kill()
	if duration <= 0.0:
		amount = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "amount", target, duration)

func _add_sheet(offset: Vector3, yaw: float, width: float) -> void:
	var pivot := Node3D.new()
	pivot.position = offset
	pivot.rotation.y = yaw
	add_child(pivot)
	var quad := QuadMesh.new()
	quad.size = Vector2(width, ray_height)
	quad.center_offset = Vector3(0.0, ray_height * 0.5, 0.0)   # sits on the gap, rises from it
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _material
	mi.rotation.x = deg_to_rad(tilt_deg)   # lean the top outward
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)

func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"amount", amount)
	visible = amount > 0.001
	if _light != null:
		_light.visible = visible
