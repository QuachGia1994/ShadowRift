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
	_test_reconnect_backoff_is_bounded()
	_test_fail_closed_locks_and_clears_intents()
	_test_resume_transitions_are_fail_closed()
	await process_frame
	if _failures == 0:
		print("PASS: 7 behavior tests")
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

func _test_reconnect_backoff_is_bounded() -> void:
	_expect(ServerAuthorityClient.compute_retry_delay(0, 0.0) > 0.0, "first retry delay is positive")
	_expect(ServerAuthorityClient.compute_retry_delay(0, 0.0) < ServerAuthorityClient.compute_retry_delay(1, 0.0), "backoff grows exponentially")
	for attempt in range(0, 12):
		for value in [0.0, 0.5, 0.999]:
			var delay := ServerAuthorityClient.compute_retry_delay(attempt, value)
			_expect(delay > 0.0 and delay <= 30.0, "retry delay never exceeds the 30 second cap")
	_expect(is_equal_approx(ServerAuthorityClient.compute_retry_delay(10, 0.5), 30.0), "backoff caps at 30 seconds")

func _test_fail_closed_locks_and_clears_intents() -> void:
	var client := ServerAuthorityClient.new()
	client._session_id = "00000000-0000-0000-0000-000000000000"
	client._token = "f".repeat(64)
	client._set_phase(ServerAuthorityClient.Phase.ONLINE, "test")
	client._command_queue.append({"action": "attack"})
	client._inflight_command = {"action": "move", "direction": 1, "seq": 4}
	client._fail_closed("test_failure")
	_expect(client._command_queue.is_empty(), "fail-closed clears queued commands")
	_expect(client._inflight_command.is_empty(), "fail-closed clears the in-flight command")
	_expect(client._next_sequence == 1, "fail-closed invalidates the stale sequence")
	_expect(client.phase == ServerAuthorityClient.Phase.RECONNECTING, "saved session reconnects with bounded retries")
	_expect(client._retry_countdown > 0.0, "reconnect retry is scheduled")
	var fresh := ServerAuthorityClient.new()
	fresh._set_phase(ServerAuthorityClient.Phase.ONLINE, "test")
	fresh._fail_closed("test_failure")
	_expect(fresh.phase == ServerAuthorityClient.Phase.OFFLINE, "sessionless client stays offline without retry")
	_expect(fresh._retry_countdown == 0.0, "no retry is scheduled without credentials")
	var locked := ServerAuthorityClient.new()
	locked._set_phase(ServerAuthorityClient.Phase.RECONNECTING, "test")
	_expect(not locked.submit_action("attack"), "commands are rejected while reconnecting")
	locked._set_phase(ServerAuthorityClient.Phase.OFFLINE, "test")
	_expect(not locked.submit_action("jump"), "commands are rejected while offline")

func _test_resume_transitions_are_fail_closed() -> void:
	var labels: Array[String] = []
	var client := ServerAuthorityClient.new()
	client.connection_state_changed.connect(func(state: String, _detail: String) -> void: labels.append(state))
	client._session_id = "00000000-0000-0000-0000-000000000000"
	client._token = "f".repeat(64)
	client._set_phase(ServerAuthorityClient.Phase.RECONNECTING, "test")
	client._handle_resume(404, {})
	_expect(client.phase == ServerAuthorityClient.Phase.RECONNECTING, "unknown session stays locked for authenticated resume retry")
	_expect(client._request_kind != "create", "resume failure never silently creates a new session")
	client._handle_resume(200, {"ok": true, "state": {"lastSeq": 5}})
	_expect(client.phase == ServerAuthorityClient.Phase.ONLINE, "authenticated resume returns online")
	_expect(client._next_sequence == 6, "resume refreshes sequence only from the server snapshot")
	_expect(labels.has("RECONNECTING") and labels.has("ONLINE"), "HUD receives reconnecting and online labels")

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + label)

