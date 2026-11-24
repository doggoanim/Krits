@tool
class_name CritterVisuals
extends RefCounted
## Small low-poly animals for Pettable: a cat, a hen, a bird and a koi. Each builder returns a
## Node3D standing on y = 0 whose named children (Body, Head, Tail, ...) animate() moves.

const SPECIES := {
	&"cat": {"color": Color(0.9, 0.55, 0.25), "belly": Color(0.98, 0.92, 0.8), "height": 0.45},
	&"hen": {"color": Color(0.96, 0.93, 0.85), "belly": Color(0.9, 0.35, 0.3), "height": 0.5},
	&"bird": {"color": Color(0.4, 0.62, 0.85), "belly": Color(0.95, 0.9, 0.8), "height": 0.3},
	&"koi": {"color": Color(1.0, 0.6, 0.25), "belly": Color(1.0, 0.95, 0.9), "height": 0.2},
}

static func build(species: StringName) -> Node3D:
	var root := Node3D.new()
	var spec: Dictionary = SPECIES.get(species, SPECIES[&"cat"])
	var c: Color = spec["color"]
	var belly: Color = spec["belly"]
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	match species:
		&"hen":
			PlayProps._ball(body, 0.2, c, Vector3(0, 0.26, 0), Vector3(1, 0.95, 1.25))
			PlayProps._ball(body, 0.1, c, Vector3(0, 0.46, 0.16))
			HouseParts.box(body, Vector3(0.04, 0.08, 0.12), belly, Vector3(0, 0.53, 0.2))   # comb
			HouseParts.box(body, Vector3(0.05, 0.04, 0.1), Color(0.95, 0.75, 0.2), Vector3(0, 0.45, 0.27))   # beak
			PlayProps._ball(body, 0.1, c.darkened(0.06), Vector3(0, 0.3, -0.22), Vector3(1, 1, 0.6))   # tail
		&"bird":
			PlayProps._ball(body, 0.1, c, Vector3(0, 0.14, 0), Vector3(1, 0.95, 1.2))
			PlayProps._ball(body, 0.06, c, Vector3(0, 0.24, 0.06))
			HouseParts.box(body, Vector3(0.02, 0.02, 0.05), Color(0.95, 0.7, 0.2), Vector3(0, 0.24, 0.12))
			HouseParts.box(body, Vector3(0.05, 0.02, 0.14), c.darkened(0.15), Vector3(0, 0.14, -0.14))
		&"koi":
			PlayProps._ball(body, 0.12, c, Vector3(0, 0.1, 0), Vector3(1, 0.6, 2.2))
			PlayProps._ball(body, 0.05, belly, Vector3(0.06, 0.13, 0.12), Vector3(1, 1, 1.6))   # patch
			var tail := Node3D.new()
			tail.name = "Tail"
			tail.position = Vector3(0, 0.1, -0.26)
			body.add_child(tail)
			HouseParts.box(tail, Vector3(0.02, 0.12, 0.12), c.lightened(0.1), Vector3(0, 0, -0.05))
		_:   # cat
			PlayProps._ball(body, 0.17, c, Vector3(0, 0.2, 0), Vector3(0.9, 0.95, 1.5))
			PlayProps._ball(body, 0.12, belly, Vector3(0, 0.15, 0.1), Vector3(0.9, 0.7, 1.1))
			var head := Node3D.new()
			head.name = "Head"
			head.position = Vector3(0, 0.34, 0.24)
			body.add_child(head)
			PlayProps._ball(head, 0.11, c, Vector3.ZERO)
			for x in [-0.06, 0.06]:
				HouseParts.box(head, Vector3(0.04, 0.08, 0.03), c, Vector3(x, 0.1, -0.01), Vector3(0, 0, -x * 300.0))
			var tail := Node3D.new()
			tail.name = "Tail"
			tail.position = Vector3(0, 0.26, -0.24)
			body.add_child(tail)
			HouseParts.box(tail, Vector3(0.05, 0.05, 0.3), c.darkened(0.08), Vector3(0, 0.1, -0.1), Vector3(40, 0, 0))
	return root

## Idle motion at time `t`. `excite` (0..1) is how happy it is right now (just petted).
static func animate(root: Node3D, species: StringName, t: float, excite: float) -> void:
	var body := root.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var tail := body.get_node_or_null("Tail") as Node3D
	var head := body.get_node_or_null("Head") as Node3D
	match species:
		&"cat":
			body.scale = Vector3.ONE * (1.0 + 0.02 * sin(t * 2.0))
			if tail: tail.rotation.y = sin(t * (2.0 + excite * 6.0)) * (0.35 + excite * 0.4)
			if head: head.rotation.z = sin(t * 0.7) * 0.08
			body.position.y = excite * absf(sin(t * 14.0)) * 0.05
		&"hen":
			body.rotation.x = maxf(0.0, sin(t * 1.3)) * -0.45 * (1.0 - excite)   # pecking
			body.position.y = excite * absf(sin(t * 16.0)) * 0.06
		&"bird":
			body.position.y = maxf(0.0, sin(t * 3.0)) * 0.015 + excite * absf(sin(t * 18.0)) * 0.08
			body.rotation.y = sin(t * 1.1) * 0.5
		&"koi":
			body.rotation.y = sin(t * 1.4) * 0.35
			body.position = Vector3(sin(t * 0.7) * 0.1, sin(t * 2.0) * 0.01 + excite * 0.12, 0)
			if tail: tail.rotation.y = sin(t * (5.0 + excite * 8.0)) * 0.6
