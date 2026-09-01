extends RefCounted
class_name ItemCatalog

const WEAPONS := {
	&"rust_blade": {"name": "Rust Blade", "attack": 6},
	&"rift_saber": {"name": "Rift Saber", "attack": 14}
}

const ARMORS := {
	&"ash_vest": {"name": "Ash Vest", "defense": 4, "health": 18},
	&"warden_mail": {"name": "Warden Mail", "defense": 10, "health": 42}
}

static func get_item(slot: StringName, item_id: StringName) -> Dictionary:
	var source: Dictionary = WEAPONS if slot == &"weapon" else ARMORS if slot == &"armor" else {}
	return source.get(item_id, {}).duplicate(true)

static func ids_for_slot(slot: StringName) -> Array[StringName]:
	var source: Dictionary = WEAPONS if slot == &"weapon" else ARMORS if slot == &"armor" else {}
	var result: Array[StringName] = []
	for item_id in source:
		result.append(item_id)
	result.sort()
	return result

