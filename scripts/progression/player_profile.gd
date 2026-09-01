extends RefCounted
class_name PlayerProfile

signal stats_changed(stats: Dictionary)

const BASE_HEALTH := 122
const BASE_MANA := 100
const BASE_ATTACK := 18
const BASE_DEFENSE := 4

var level := 1
var weapon_id := &"rust_blade"
var armor_id := &"ash_vest"
var _stats: Dictionary = {}

func _init() -> void:
	_stats = _recompute()

func set_level(next_level: int) -> void:
	level = clampi(next_level, 1, 99)
	_commit_recompute()

func equip(slot: StringName, item_id: StringName) -> bool:
	if ItemCatalog.get_item(slot, item_id).is_empty():
		return false
	if slot == &"weapon":
		weapon_id = item_id
	elif slot == &"armor":
		armor_id = item_id
	else:
		return false
	_commit_recompute()
	return true

func get_stats() -> Dictionary:
	return _stats.duplicate(true)

func get_equipment_payload() -> Dictionary:
	return {"weapon": String(weapon_id), "armor": String(armor_id)}

func restore_equipment(payload: Dictionary) -> bool:
	var weapon := StringName(str(payload.get("weapon", "")))
	var armor := StringName(str(payload.get("armor", "")))
	if ItemCatalog.get_item(&"weapon", weapon).is_empty() or ItemCatalog.get_item(&"armor", armor).is_empty():
		return false
	weapon_id = weapon
	armor_id = armor
	_commit_recompute()
	return true

func is_canonical(candidate: Dictionary) -> bool:
	return candidate == _recompute()

func _commit_recompute() -> void:
	_stats = _recompute()
	stats_changed.emit(get_stats())

func _recompute() -> Dictionary:
	var weapon := ItemCatalog.get_item(&"weapon", weapon_id)
	var armor := ItemCatalog.get_item(&"armor", armor_id)
	return {
		"max_health": BASE_HEALTH + (level - 1) * 9 + int(armor.get("health", 0)),
		"max_mana": BASE_MANA + (level - 1) * 3,
		"attack": BASE_ATTACK + (level - 1) * 2 + int(weapon.get("attack", 0)),
		"defense": BASE_DEFENSE + int(level / 3) + int(armor.get("defense", 0)),
		"weapon_name": str(weapon.get("name", "Unknown")),
		"armor_name": str(armor.get("name", "Unknown"))
	}

