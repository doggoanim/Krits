class_name AbilityRunner
extends RefCounted
## What each AbilityData.Effect does. activate() returns "" on success, or a
## short reason it couldn't be used (shown to the player; cooldown is only
## started on success — see Hotbar.use_slot).

static func activate(ability: AbilityData, player: Player, tree: SceneTree) -> String:
	if player == null or player.dead:
		return ""
	match ability.effect:
		AbilityData.Effect.HEAL:
			var stats := Game.stats
			if stats.hp >= stats.max_hp():
				return "Already at full health."
			stats.heal(ability.amount)
		AbilityData.Effect.GUARD:
			player.invuln = maxf(player.invuln, ability.duration)
			player.visual.flash(ability.duration)
		AbilityData.Effect.SUPER_JUMP:
			var state := player.machine.current_name
			if state != &"Ground" and state != &"Air" and state != &"Crouch":
				return "Can't do that right now."
			player.start_jump(ability.amount)
		AbilityData.Effect.SHOCKWAVE:
			var arena := tree.get_first_node_in_group(&"arena") as Arena
			if arena == null:
				return "Only usable in a fight."
			_shockwave(ability, player, arena)
		AbilityData.Effect.ORB_STACK:
			var arena := tree.get_first_node_in_group(&"arena") as Arena
			if arena == null:
				return "Only usable in a fight."
			var staff := Game.stats.equipped_weapon != null \
				and Game.stats.equipped_weapon.kind == WeaponData.Kind.STAFF
			var count := int(ability.staff_amount if staff and ability.staff_amount > 0.0 else ability.amount)
			if not arena.stack_orbs_on_nearest(player.global_position, count):
				return "No orbs to stack on."
	return ""

static func _shockwave(ability: AbilityData, player: Player, arena: Arena) -> void:
	var dmg := Game.stats.damage() * ability.amount
	for e in arena.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) > ability.radius:
			continue
		HitBurst.spawn(arena, e.center_point(), dmg, 2.0)
		e.punch()
		e.knockback(player.global_position, 8.0)
		e.take_damage(dmg)
	if player.camera_rig:
		player.camera_rig.shake(0.6)
	HitStop.freeze(0.08)
