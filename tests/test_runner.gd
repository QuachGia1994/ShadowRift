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
	_test_player_fsm_and_combo()
	_test_multitouch_isolation_and_landscape_bounds()
	_test_zone_structure()
	_test_enemy_and_boss_fsm_smoke()
	_test_inventory_cycles_canonical_equipment()
	_test_save_rejects_tampering()
	_test_combat_uses_canonical_damage()
	_test_pool_reuses_items()
	_test_performance_contract()
	_test_reconnect_backoff_is_bounded()
	_test_fail_closed_locks_and_clears_intents()
	_test_resume_transitions_are_fail_closed()
	await _test_full_scene_boot_and_pause()
	await process_frame
	if _failures == 0:
		print("PASS: 14 behavior tests")
	quit(_failures)

func _test_profile_recomputes_stats() -> void:
	var profile := PlayerProfile.new()
	var base_attack := int(profile.get_canonical_stats().attack)
	_expect(profile.equip(&"weapon", &"rift_saber"), "valid weapon equips")
	_expect(int(profile.get_canonical_stats().attack) > base_attack, "weapon changes canonical attack")
	_expect(not profile.equip(&"armor", &"unknown"), "unknown armor is rejected")
	_expect(profile.is_canonical(profile.get_stats()), "display stats match canonical stats")

func _test_player_fsm_and_combo() -> void:
	var controls := MobileControls.new()
	controls.size = Vector2(960.0, 540.0)
	controls.add_to_group("mobile_controls")
	root.add_child(controls)
	var hero := Hero.new()
	root.add_child(hero)
	hero._set_state(Hero.State.MOVE)
	_expect(hero.state == Hero.State.MOVE, "hero enters move state")
	hero._combo_grace = 0.0
	hero._start_attack()
	_expect(hero.state == Hero.State.ATTACK and hero._combo_step == 1, "first attack starts combo step one")
	hero._combo_grace = 0.2
	hero._start_attack()
	_expect(hero._combo_step == 2, "second attack is capped at combo step two")
	hero.apply_hurt(Vector2(10.0, -5.0))
	_expect(hero.state == Hero.State.HURT, "hero enters hurt state")
	hero.die()
	_expect(hero.state == Hero.State.DEATH, "hero enters death state")
	controls.remove_from_group("mobile_controls")
	hero.queue_free()
	controls.queue_free()

func _test_multitouch_isolation_and_landscape_bounds() -> void:
	var controls := MobileControls.new()
	controls.size = Vector2(1170.0, 540.0)
	root.add_child(controls)
	var left := InputEventScreenTouch.new()
	left.index = 1
	left.position = Vector2(105.0, 435.0)
	left.pressed = true
	controls._handle_touch(left)
	var attack := InputEventScreenTouch.new()
	attack.index = 2
	attack.position = controls._button_center("attack")
	attack.pressed = true
	controls._handle_touch(attack)
	_expect(controls._left_touch == 1, "left thumb owns joystick independently")
	_expect(int(controls._button_owners.attack) == 2, "right thumb owns attack independently")
	_expect(controls.consume_action(&"attack"), "attack touch queues exactly one action")
	for action in ["attack", "skill_one", "skill_two"]:
		var center: Vector2 = controls._button_center(action)
		_expect(center.x > controls.size.x * 0.5 and center.x < controls.size.x, "%s stays inside landscape right half" % action)
		_expect(center.y > 0.0 and center.y < controls.size.y, "%s stays vertically on-screen" % action)
	var pause_center := controls._pause_center()
	_expect(pause_center.x > controls.size.x * 0.5 and pause_center.y > 0.0, "pause control stays in landscape safe quadrant")
	var left_release := InputEventScreenTouch.new()
	left_release.index = 1
	left_release.position = left.position
	left_release.pressed = false
	controls._handle_touch(left_release)
	var attack_release := InputEventScreenTouch.new()
	attack_release.index = 2
	attack_release.position = attack.position
	attack_release.pressed = false
	controls._handle_touch(attack_release)
	controls.queue_free()

func _test_zone_structure() -> void:
	var zone := ZoneBuilder.new()
	zone.build()
	root.add_child(zone)
	var tile_layers := 0
	var hazards := 0
	var one_way_platforms := 0
	for child in zone.get_children():
		if child is TileMapLayer:
			tile_layers += 1
		elif child is Hazard:
			hazards += 1
		elif child is StaticBody2D:
			for shape_node in child.get_children():
				if shape_node is CollisionShape2D and shape_node.one_way_collision:
					one_way_platforms += 1
	_expect(tile_layers == 3, "zone builds exactly three TileMapLayer nodes")
	_expect(hazards == 1, "zone builds the v1 hazard")
	_expect(one_way_platforms == 2, "zone builds both one-way platforms")
	zone.queue_free()

func _test_enemy_and_boss_fsm_smoke() -> void:
	var hero := Hero.new()
	hero.position = Vector2(350.0, 400.0)
	root.add_child(hero)
	var enemy := EnemyController.new()
	enemy.configure(EnemyController.Kind.WARDEN, hero)
	enemy.position = Vector2(300.0, 400.0)
	root.add_child(enemy)
	enemy._update_patrol(0.0)
	_expect(enemy.state == EnemyController.State.AGGRO, "warden patrol enters aggro near hero")
	enemy._update_aggro(0.0)
	_expect(enemy.state == EnemyController.State.ATTACK, "warden aggro enters attack in range")
	var boss := BossController.new()
	boss.configure(hero)
	boss.position = Vector2(300.0, 400.0)
	root.add_child(boss)
	boss.state = BossController.State.CHASE
	boss._update_chase()
	_expect(boss.state == BossController.State.WINDUP, "boss chase enters windup in range")
	boss._start_strike()
	_expect(boss.state == BossController.State.STRIKE, "boss windup advances to strike")
	boss.queue_free()
	enemy.queue_free()
	hero.queue_free()

func _test_inventory_cycles_canonical_equipment() -> void:
	var hero := Hero.new()
	root.add_child(hero)
	var profile := hero.get_profile()
	var before := profile.weapon_id
	hero.cycle_equipment(&"weapon")
	_expect(profile.weapon_id != before, "touch inventory cycle changes weapon")
	_expect(profile.is_canonical(profile.get_stats()), "cycled equipment keeps canonical stats")
	hero.queue_free()

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

func _test_performance_contract() -> void:
	_expect(Engine.max_fps == 60, "runtime keeps the 60 FPS cap")
	_expect(PerformanceBudget.DRAW_CALL_BUDGET == 50, "draw-call budget remains capped at 50")

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

func _test_full_scene_boot_and_pause() -> void:
	var packed := load("res://scenes/game.tscn") as PackedScene
	_expect(packed != null, "main game scene loads")
	if packed == null:
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	_expect(is_instance_valid(game._hero), "game scene creates hero")
	_expect(is_instance_valid(game._boss), "game scene creates boss")
	_expect(is_instance_valid(game._hud), "game scene creates HUD")
	_expect(is_instance_valid(game._controls), "game scene creates mobile controls")
	_expect(game._controls.process_mode == Node.PROCESS_MODE_ALWAYS, "pause control remains responsive while paused")
	game._toggle_user_pause()
	_expect(paused and game._hud._paused, "pause freezes tree and shows overlay")
	game._toggle_user_pause()
	_expect(not paused and not game._hud._paused, "resume restores gameplay")
	game.queue_free()
	await process_frame

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + label)

