extends Node
class_name CombatAuthority

const MAX_MELEE_DISTANCE := 96.0
const DAMAGE_CAP := 9999
const ATTACK_MULTIPLIERS := {&"basic_one": 1.0, &"basic_two": 1.28, &"skill_one": 1.65, &"skill_two": 2.1, &"enemy_basic": 1.0, &"boss_basic": 1.35}

func resolve_hit(source: Node2D, target: Node2D, attack_kind: StringName) -> bool:
	if not _valid_combatants(source, target) or not ATTACK_MULTIPLIERS.has(attack_kind):
		return false
	if source.global_position.distance_to(target.global_position) > MAX_MELEE_DISTANCE:
		return false
	if not source.has_method("get_attack_power") or not target.has_method("get_defense") or not target.has_method("receive_authoritative_hit"):
		return false
	var attack_power := clampi(int(source.call("get_attack_power")), 1, DAMAGE_CAP)
	var defense := clampi(int(target.call("get_defense")), 0, DAMAGE_CAP)
	var raw_damage := int(round(float(attack_power) * float(ATTACK_MULTIPLIERS[attack_kind])))
	var resolved_damage := clampi(raw_damage - int(defense * 0.55), 1, DAMAGE_CAP)
	var direction := signf(target.global_position.x - source.global_position.x)
	var knockback := Vector2(220.0 * direction, -145.0)
	return bool(target.call("receive_authoritative_hit", resolved_damage, knockback))

func resolve_environment_hit(target: Node2D, raw_damage: int, knockback: Vector2) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.has_method("receive_authoritative_hit"):
		return false
	return bool(target.call("receive_authoritative_hit", clampi(raw_damage, 1, DAMAGE_CAP), knockback.limit_length(500.0)))

func _valid_combatants(source: Node2D, target: Node2D) -> bool:
	return is_instance_valid(source) and is_instance_valid(target) and source != target and source.is_inside_tree() and target.is_inside_tree()
