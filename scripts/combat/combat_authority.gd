extends Node
class_name CombatAuthority

signal damage_resolved(position: Vector2, amount: int)

const MAX_MELEE_DISTANCE := 144.0
const DAMAGE_CAP := 9999
const ATTACK_MULTIPLIERS := {&"basic_one": 1.0, &"basic_two": 1.28, &"skill_one": 1.65, &"skill_two": 2.1, &"enemy_basic": 1.0, &"wraith_bolt": 1.10, &"boss_basic": 1.35}

func resolve_hit(source: Node2D, target: Node2D, attack_kind: StringName) -> bool:
	if not _valid_combatants(source, target) or not ATTACK_MULTIPLIERS.has(attack_kind):
		return false
	if source.global_position.distance_to(target.global_position) > MAX_MELEE_DISTANCE:
		return false
	if not source.has_method("get_attack_power") or not target.has_method("get_defense") or not target.has_method("receive_canonical_hit"):
		return false
	var attack_power := _canonical_attack(source)
	var defense := clampi(int(target.call("get_defense")), 0, DAMAGE_CAP)
	var raw_damage := int(round(float(attack_power) * float(ATTACK_MULTIPLIERS[attack_kind])))
	var resolved_damage := clampi(raw_damage - int(defense * 0.55), 1, DAMAGE_CAP)
	var direction := signf(target.global_position.x - source.global_position.x)
	var knockback := Vector2(220.0 * direction, -145.0)
	if attack_kind == &"enemy_basic":
		knockback = Vector2(285.0 * direction, -175.0)
	elif attack_kind == &"boss_basic":
		knockback = Vector2(320.0 * direction, -195.0)
	var applied := bool(target.call("receive_canonical_hit", resolved_damage, knockback))
	if applied:
		damage_resolved.emit(target.global_position + Vector2(0.0, -46.0), resolved_damage)
	return applied

func resolve_projectile_hit(source: Node2D, target: Node2D, attack_kind: StringName) -> bool:
	if not _valid_combatants(source, target) or not ATTACK_MULTIPLIERS.has(attack_kind):
		return false
	if source.global_position.distance_to(target.global_position) > 760.0:
		return false
	if not target.has_method("get_defense") or not target.has_method("receive_canonical_hit"):
		return false
	var raw_damage := int(round(float(_canonical_attack(source)) * float(ATTACK_MULTIPLIERS[attack_kind])))
	var defense := clampi(int(target.call("get_defense")), 0, DAMAGE_CAP)
	var resolved_damage := clampi(raw_damage - int(defense * 0.55), 1, DAMAGE_CAP)
	var direction := signf(target.global_position.x - source.global_position.x)
	var applied := bool(target.call("receive_canonical_hit", resolved_damage, Vector2(170.0 * direction, -90.0)))
	if applied:
		damage_resolved.emit(target.global_position + Vector2(0.0, -46.0), resolved_damage)
	return applied

func resolve_environment_hit(target: Node2D, raw_damage: int, knockback: Vector2) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.has_method("receive_canonical_hit"):
		return false
	var resolved_damage := clampi(raw_damage, 1, DAMAGE_CAP)
	var applied := bool(target.call("receive_canonical_hit", resolved_damage, knockback.limit_length(500.0)))
	if applied:
		damage_resolved.emit(target.global_position + Vector2(0.0, -46.0), resolved_damage)
	return applied

func _valid_combatants(source: Node2D, target: Node2D) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target or not source.is_inside_tree() or not target.is_inside_tree():
		return false
	var source_faction := _faction(source)
	var target_faction := _faction(target)
	# Unknown test/utility actors remain compatible; known gameplay actors may
	# only damage the opposing faction. This prevents enemy melee/projectiles
	# from hitting other enemies while preserving the existing test harness.
	if source_faction != 0 or target_faction != 0:
		return source_faction != 0 and target_faction != 0 and source_faction != target_faction
	return true

func _faction(actor: Node2D) -> int:
	if actor is Hero:
		return 1
	if actor is EnemyController or actor is BossController:
		return 2
	return 0

func _canonical_attack(source: Node2D) -> int:
	if source.has_method("get_canonical_attack_power"):
		return clampi(int(source.call("get_canonical_attack_power")), 1, DAMAGE_CAP)
	return clampi(int(source.call("get_attack_power")), 1, DAMAGE_CAP)
