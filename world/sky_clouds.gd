class_name SkyClouds
extends Node3D
## Wind Waker-style clouds: what you SEE overhead and the shadows they cast on
## the ground are the SAME objects, so they always move, wrap and fade
## together. (This replaces the old SkyClouds particle layer + the separate,
## unlinked CloudShadows node.)
##
## Each cloud is one Node3D holding
##   - a visible sprite: a single crisp, flat-bottomed, bumpy cartoon cloud
##     texture on a Y-axis billboard (unshaded, casts no shadow itself), and
##   - a few shadow-only primitives laid out along the same row of bumps as the
##     sprite, so the shadow on the ground has the cloud's own outline
##     (SHADOWS_ONLY: rendered into the sun's shadow map, never into the colour
##     pass — the sun needs shadows on, see EnvironmentConfig.sun_shadows).
##
## Usage: add one node anywhere in a level; it manages cloud_count clouds
## drifting along +X across area_size and wrapping round, shrinking/fading near
## the wrap edges so nothing pops. Tune the look from the Inspector.

@export var area_size := Vector2(150.0, 150.0)   ## patch of sky covered, centred on this node
@export var height := 35.0                        ## altitude above this node's own Y
@export var cloud_count := 10
@export var cloud_size := Vector2(16.0, 16.0)     ## base size; a cloud is 1.6x this wide and 0.8x tall
@export var size_variation := 0.3                 ## each cloud is scaled by 1 +/- this
@export var cloud_shade := Color(0.78, 0.86, 0.98) ## underside colour
@export var drift_speed := 0.6                    ## world units/sec along +X (same direction as WindGusts)
@export var react_to_gusts := true                ## clouds visibly speed up while a gust sweeps through
@export var cast_shadows := true                  ## ground shadows that follow each cloud
## Distance (along the drift's X travel) from each end of area_size a cloud
## spends fading, so it never pops in or out.
@export var edge_fade_distance := 30.0

## The cloud's silhouette: (centre x, centre y, radius) in "height units" — the
## sprite is 2.0 wide and 1.0 tall, with a flat base at FLAT_BOTTOM. The shadow
## pieces are placed from these same numbers so shadow and sprite match.
const BUMPS: Array[Vector3] = [
	Vector3(0.38, 0.62, 0.20), Vector3(0.75, 0.46, 0.28), Vector3(1.20, 0.40, 0.31),
	Vector3(1.62, 0.60, 0.21), Vector3(1.00, 0.62, 0.30),
]
const FLAT_BOTTOM := 0.84
const SPRITE_ASPECT := Vector2(1.6, 0.8)   ## quad size multiplier applied to cloud_size

class Cloud:
	var root: Node3D
	var sprite: MeshInstance3D
	var shadow_root: Node3D
	var scale_factor := 1.0

var _clouds: Array[Cloud] = []
var _texture: ImageTexture

func _ready() -> void:
	_texture = _make_texture(256, 128)
	for i in cloud_count:
		_clouds.append(_make_cloud())

func _make_cloud() -> Cloud:
	var c := Cloud.new()
	c.scale_factor = 1.0 + randf_range(-size_variation, size_variation)
	c.root = Node3D.new()
	c.root.position = Vector3(
		randf_range(-area_size.x * 0.5, area_size.x * 0.5),
		height,
		randf_range(-area_size.y * 0.5, area_size.y * 0.5))
	add_child(c.root)

	var quad := QuadMesh.new()
	quad.size = cloud_size * SPRITE_ASPECT * c.scale_factor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y   # stays upright, flat base stays flat
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _texture
	mat.no_depth_test = false
	if randf() < 0.5:   # mirrored: same silhouette reads as a different cloud
		mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
		mat.uv1_offset = Vector3(1.0, 0.0, 0.0)
	quad.material = mat
	c.sprite = MeshInstance3D.new()
	c.sprite.mesh = quad
	c.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.root.add_child(c.sprite)

	if cast_shadows:
		c.shadow_root = Node3D.new()
		c.root.add_child(c.shadow_root)
		var width := cloud_size.x * SPRITE_ASPECT.x * c.scale_factor   # world width of the sprite
		var unit := width * 0.5                                        # one "height unit" in world metres
		for b in BUMPS:
			var cyl := CylinderMesh.new()
			cyl.top_radius = b.z * unit
			cyl.bottom_radius = b.z * unit
			cyl.height = b.z * unit
			cyl.radial_segments = 12
			var mi := MeshInstance3D.new()
			mi.mesh = cyl
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mi.position = Vector3((b.x - 1.0) * unit, 0.0, 0.0)   # sprite centre = cloud centre
			c.shadow_root.add_child(mi)
	return c

func _process(delta: float) -> void:
	var speed := drift_speed
	if react_to_gusts:
		var pos := global_position
		speed *= WindGusts.sample(Vector2(pos.x, pos.z), Time.get_ticks_msec() / 1000.0)
	var half := area_size.x * 0.5
	for c in _clouds:
		c.root.position.x += speed * delta
		if c.root.position.x > half:
			c.root.position.x -= area_size.x
		var edge := minf(c.root.position.x + half, half - c.root.position.x)
		var fade := clampf(edge / maxf(edge_fade_distance, 0.001), 0.0, 1.0)
		c.sprite.transparency = 1.0 - fade           # sprite melts away…
		if c.shadow_root:                             # …and the shadow shrinks away with it
			c.shadow_root.scale = Vector3.ONE * maxf(fade, 0.001)

## One whole cartoon cloud: the union of BUMPS as a single silhouette with a flat
## bottom, sharp anti-aliased edges, white on top fading to `cloud_shade` below.
func _make_texture(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2((x + 0.5) / h, (y + 0.5) / h)
			var sdf := -1.0
			for b in BUMPS:
				sdf = maxf(sdf, b.z - p.distance_to(Vector2(b.x, b.y)))
			sdf = minf(sdf, FLAT_BOTTOM - p.y)
			var a := clampf(sdf * h / 1.5, 0.0, 1.0)
			var shade := smoothstep(0.42, FLAT_BOTTOM, p.y)
			var col := Color.WHITE.lerp(cloud_shade, shade)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)
