class_name EnemyLibrary
extends RefCounted
## Code-defined enemy templates. Move to .tres resources when content grows.

static func grunt() -> EnemyData:
	var d := EnemyData.new()
	d.id = &"grunt"
	d.display_name = "Grunt"
	d.max_hp = 60.0
	d.xp = 20
	d.color = Color(0.85, 0.25, 0.25)
	var a := AimedPattern.new()
	a.interval = 1.6
	a.count = 3
	var r := RadialPattern.new()
	r.interval = 3.0
	r.count = 10
	d.patterns.assign([a, r])
	return d

static func spinner() -> EnemyData:
	var d := EnemyData.new()
	d.id = &"spinner"
	d.display_name = "Spinner"
	d.max_hp = 90.0
	d.xp = 35
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
	d.xp = 45
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
