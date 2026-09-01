extends SceneTree

class TestActor:
	extends Node2D
	var attack := 30
	var defense := 5
	var received := 0

	func get_attack_power() -> int:
		return attack

	func get_canonical_attack_power() -> int:
		return attack

	func get_defense() -> int:
		return defense

	func receive_authoritative_hit(amount: int, _knockback: Vector2) -> bool:
		received = amount
		return true

var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_profile_recomputes_stats()
	_test_save_rejects_tampering()
	_test_combat_uses_canonical_damage()
	_test_pool_reuses_items()
	await process_frame
	if _failures == 0:
		print("PASS: 4 behavior tests")
	quit(_failures)

func _test_profile_recomputes_stats() -> void:
	var profile := PlayerProfile.new()
	var base_attack := int(profile.get_canonical_stats().attack)
	_expect(profile.equip(&"weapon", &"rift_saber"), "valid weapon equips")
	_expect(int(profile.get_canonical_stats().attack) > base_attack, "weapon changes canonical attack")
	_expect(not profile.equip(&"armor", &"unknown"), "unknown armor is rejected")
	_expect(profile.is_canonical(profile.get_stats()), "display stats match canonical stats")

func _test_save_rejects_tampering() -> void:
	var repository := SaveRepository.new()
	repository.save_path = "user://shadow_rift_test_save.json"
	var payload := {"level": 1, "experience": 12, "experience_to_next": 100, "gold": 7, "mana": 70, "health": 90, "equipment": {"weapon": "rust_blade", "armor": "ash_vest"}}
	_expect(repository.save_game(payload).ok, "valid save writes")
	_expect(repository.load_game().ok, "valid save loads")
	var file := FileAccess.open(repository.save_path, FileAccess.READ)
	var wrapper := JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	wrapper.payload.gold = 999999
	file = FileAccess.open(repository.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(wrapper))
	file.close()
	var tampered := repository.load_game()
	_expect(not tampered.ok and tampered.error == "save_checksum_mismatch", "edited payload fails checksum")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repository.save_path))

func _test_combat_uses_canonical_damage() -> void:
	var authority := CombatAuthority.new()
	var source := TestActor.new()
	var target := TestActor.new()
	root.add_child(authority)
	root.add_child(source)
	root.add_child(target)
	source.position = Vector2.ZERO
	target.position = Vector2(40.0, 0.0)
	_expect(authority.resolve_hit(source, target, &"basic_one"), "nearby hit resolves")
	_expect(target.received == 28, "damage formula uses attack minus defense")
	target.position = Vector2(300.0, 0.0)
	_expect(not authority.resolve_hit(source, target, &"basic_one"), "out-of-range hit is rejected")
	authority.queue_free()
	source.queue_free()
	target.queue_free()

func _test_pool_reuses_items() -> void:
	var pool := ReusablePool.new()
	root.add_child(pool)
	pool.configure(_make_pool_item, 1)
	var first := pool.acquire()
	pool.release(first)
	var second := pool.acquire()
	_expect(first == second, "pool returns released instance")
	pool.queue_free()

func _make_pool_item() -> Node2D:
	return Node2D.new()

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + label)

