class_name EnemyLibrary
extends RefCounted
## Code-defined enemy templates. Move to .tres resources when content grows.

const GREEN_SLIME_MODEL := preload("res://assets/enemies/green_slime.glb")

static func green_slime() -> EnemyData:
	var d := EnemyData.new()
	d.id = &"green_slime"
	d.display_name = "Green Slime"
	d.max_hp = 6.0
	d.gold = 20
	d.color = Color(0x5A / 255.0, 0x8B / 255.0, 0x2F / 255.0)   # also the puddle/slime-ball tint
	d.model = GREEN_SLIME_MODEL
	d.model_height = 1.1
	# Clip names baked into green_slime.glb: Idle, Moving, Death, leap_ready, leap, shoot.
	d.anim_idle = &"Idle"
	d.anim_move = &"Moving"
	d.anim_death = &"Death"

	d.leap_min_cooldown = 3.0
	d.leap_max_cooldown = 5.5
	d.leap_ready_time = 1.0
	d.leap_travel_time = 0.6
	d.leap_height = 3.0
	d.leap_damage = 14.0
	d.leap_radius = 2.0
	d.anim_leap_ready = &"leap_ready"
	d.anim_leap = &"leap"

	d.shoot_min_cooldown = 2.5
	d.shoot_max_cooldown = 4.5
	d.shoot_count_min = 1
	d.shoot_count_max = 10
	d.shoot_interval = 0.12
	d.shoot_speed = 10.0
	d.shoot_damage = 5.0
	d.anim_shoot = &"shoot"

	d.leaves_puddle_trail = true
	d.puddle_interval = 0.5
	d.puddle_radius = 1.3
	d.puddle_lifetime = 5.0
	d.puddle_damage = 4.0
	d.puddle_tick_interval = 0.9
	d.puddle_landing_radius_mult = 1.6
	return d

static func spinner() -> EnemyData:
	var d := EnemyData.new()
	d.id = &"spinner"
	d.display_name = "Spinner"
	d.max_hp = 90.0
	d.gold = 35
	d.move_speed = 2.0
	d.color = Color(0.7, 0.3, 0.9)
	var s := SpiralPattern.new()
	s.interval = 0.25
	s.arms = 3
	s.bullet_speed = 6.0
	d.patterns.assign([s])
	return d

static func piercer() -> EnemyData:
	var d := EnemyData.new()
	d.id = &"piercer"
	d.display_name = "Piercer"
	d.max_hp = 80.0
	d.gold = 45
	d.move_speed = 5.0
	d.color = Color(1.0, 0.2, 0.7)
	var p := AimedPattern.new()
	p.interval = 2.2
	p.count = 5
	p.spread = 12.0
	p.damage = 12.0
	p.bullet_speed = 10.0
	p.pierces_shield = true   # ignores the shield bar
	d.patterns.assign([p])
	return d
