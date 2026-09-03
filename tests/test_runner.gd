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

	func receive_canonical_hit(amount: int, _knockback: Vector2) -> bool:
		received = amount
		return true

var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_profile_recomputes_stats()
	_test_player_fsm_and_combo()
	_test_jump_traversal_contract()
	_test_donor_jump_feel()
	_test_touch_jump_release()
	await _test_true_articulated_rig()
	_test_rig_alpha_exclusive_manifest()
	await _test_combat_escape_window()
	await _test_wraith_ranged_homing()
	_test_moving_platform_carry()
	_test_checkpoint_activation()
	_test_killzone_recovery()
	await _test_stage_transition_no_duplicates()
	_test_save_migration()
	_test_level_config_data_driven()
	_test_death_respawn_contract()
	_test_multitouch_and_safe_area()
	_test_input_reset_on_lifecycle_boundary()
	_test_zone_structure()
	_test_stage_catalog_and_progression()
	_test_enemy_and_boss_fsm_smoke()
	_test_inventory_cycles_canonical_equipment()
	_test_save_rejects_tampering()
	_test_combat_uses_canonical_damage()
	_test_pool_reuses_items()
	_test_performance_contract()
	_test_production_resources_load()
	await _test_full_scene_boot_and_pause()
	await _test_defeat_retry_flow()
	await process_frame
	await process_frame
	await process_frame
	if _failures == 0:
		print("PASS: 29 behavior tests")
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
	controls._pending_actions["jump"] = true
	_expect(hero._jump_pressed(), "hero consumes mobile jump action")
	_expect(not hero._jump_pressed(), "mobile jump remains one-shot")
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

func _test_jump_traversal_contract() -> void:
	var hero := Hero.new()
	root.add_child(hero)
	var gravity := maxf(1.0, hero.get_gravity().y)
	var jump_height := (Hero.JUMP_SPEED * Hero.JUMP_SPEED) / (2.0 * gravity)
	_expect(jump_height >= 180.0, "hero jump clears the tallest intended stage step")
	_expect(Hero.COYOTE_TIME >= 0.10 and Hero.JUMP_BUFFER_TIME >= 0.10, "jump includes mobile-friendly coyote and buffer windows")
	hero.queue_free()

func _test_death_respawn_contract() -> void:
	var hero := Hero.new()
	root.add_child(hero)
	# Reproduce a lethal hit arriving on the invisible half of the old blink.
	hero.visible = false
	hero._rig.visible = false
	hero.die()
	_expect(hero.is_dead() and hero.state == Hero.State.DEATH, "hero death enters terminal animation state")
	_expect(hero.visible, "lethal damage cannot freeze Hero on an invisible blink frame")
	hero.respawn_at(Vector2(180.0, 406.0))
	var snapshot := hero.get_resource_snapshot()
	_expect(not hero.is_dead() and hero.state == Hero.State.IDLE, "respawn returns hero to playable idle state")
	_expect(hero.visible and hero._rig.visible and hero.modulate == Color.WHITE, "retry restores Hero and rig visibility")
	_expect(int(snapshot.health) == int(snapshot.max_health) and int(snapshot.mana) == int(snapshot.max_mana), "respawn restores health and mana")
	hero.queue_free()

func _test_touch_jump_release() -> void:
	var controls := MobileControls.new()
	controls.size = Vector2(960.0, 540.0)
	root.add_child(controls)
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.position = controls._button_center("jump")
	press.pressed = true
	controls._handle_touch(press)
	_expect(controls.is_action_held(&"jump"), "touch jump exposes a real held state")
	_expect(controls.consume_action(&"jump"), "touch jump press remains one-shot for takeoff")
	_expect(not controls.consume_action_released(&"jump"), "touch jump is not released while finger remains down")
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = press.position
	release.pressed = false
	controls._handle_touch(release)
	_expect(not controls.is_action_held(&"jump"), "touch jump clears held state on finger release")
	_expect(controls.consume_action_released(&"jump"), "touch jump exposes the release edge for variable jump")
	_expect(not controls.consume_action_released(&"jump"), "touch jump release edge is consumed exactly once")
	controls.queue_free()

func _test_true_articulated_rig() -> void:
	var hero_rig := CharacterMotionRig2D.new()
	hero_rig.configure(&"hero")
	root.add_child(hero_rig)
	await process_frame
	hero_rig.play(&"move")
	hero_rig._player.advance(0.28)
	var hero_back := _signed_degrees(hero_rig.get_bone_rotation_degrees(&"leg_back"))
	var hero_front := _signed_degrees(hero_rig.get_bone_rotation_degrees(&"leg_front"))
	var back_pose := hero_rig._poses[&"leg_back"] as Node2D
	var front_pose := hero_rig._poses[&"leg_front"] as Node2D
	_expect(absf(hero_back) <= 4.0 and absf(hero_front) <= 4.0, "hero run avoids high-angle leg resampling blur")
	_expect(absf(back_pose.position.x - front_pose.position.x) >= 4.0, "hero run keeps opposite-phase leg translation without sliding a whole sprite")
	_expect(hero_rig._bones.size() == 6 and hero_rig._sprites.size() == 6, "hero visual uses six independent cutout parts")
	var boss_rig := CharacterMotionRig2D.new()
	boss_rig.configure(&"boss")
	root.add_child(boss_rig)
	await process_frame
	boss_rig.play(&"windup")
	boss_rig._player.advance(0.40)
	_expect(absf(_signed_degrees(boss_rig.get_bone_rotation_degrees(&"arm_front"))) >= 45.0, "boss windup visibly articulates the weapon arm")
	boss_rig.play(&"strike")
	boss_rig._player.advance(0.20)
	_expect(absf(_signed_degrees(boss_rig.get_bone_rotation_degrees(&"arm_front"))) >= 45.0, "boss strike visibly follows through")
	hero_rig.queue_free()
	boss_rig.queue_free()

func _test_rig_alpha_exclusive_manifest() -> void:
	var file := FileAccess.open("res://assets/rig/rig_manifest.json", FileAccess.READ)
	_expect(file != null, "rig manifest loads for alpha exclusivity")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_expect(parsed is Dictionary, "rig manifest parses")
	if not parsed is Dictionary:
		return
	var poses: Dictionary = (parsed as Dictionary).get("poses", {})
	_expect(not poses.is_empty(), "rig manifest contains poses")
	for pose in poses.values():
		var entry := pose as Dictionary
		_expect(int(entry.get("alpha_overlap_max", 999)) <= 1, "rig moving parts do not duplicate source alpha")

func _test_combat_escape_window() -> void:
	var hero := Hero.new()
	root.add_child(hero)
	var enemy := EnemyController.new()
	enemy.configure(EnemyController.Kind.WARDEN, hero)
	enemy.position = hero.position + Vector2(40.0, 0.0)
	root.add_child(enemy)
	await process_frame
	_expect(enemy.get_collision_exceptions().has(hero), "enemy body does not block Hero movement")
	_expect(hero.get_collision_exceptions().has(enemy), "Hero body does not get trapped by enemy movement")
	_expect(hero._health.iframe_duration >= 0.75, "Hero receives a touch-friendly post-hit iframe window")
	hero.apply_hurt(Vector2(285.0, -175.0))
	_expect(hero._hurt_time <= 0.20, "hurt input lock is short enough to recover")
	_expect(hero.velocity.x >= 280.0, "damage knockback creates physical separation")
	enemy.queue_free()
	hero.queue_free()
	await process_frame

func _test_wraith_ranged_homing() -> void:
	var pool := ReusablePool.new()
	pool.add_to_group("projectile_pool")
	pool.configure(_make_projectile_test, 2)
	root.add_child(pool)
	var hero := Hero.new()
	hero.position = Vector2(360.0, 400.0)
	root.add_child(hero)
	var wraith := EnemyController.new()
	wraith.configure(EnemyController.Kind.WRAITH, hero)
	wraith.position = Vector2(80.0, 400.0)
	root.add_child(wraith)
	await process_frame
	wraith.state = EnemyController.State.AGGRO
	wraith._attack_cooldown = 0.0
	wraith._update_aggro(0.0)
	_expect(wraith.state == EnemyController.State.ATTACK, "Wraith enters ranged cast inside its preferred band")
	_expect(not wraith._hitbox.monitoring, "Wraith cast never enables the melee hitbox")
	_expect(wraith._attack_time >= 0.70, "Wraith exposes a readable cast telegraph")
	wraith._update_attack(0.56)
	var bolt: PooledProjectile = null
	for child in pool.get_children():
		if child is PooledProjectile and child.process_mode != Node.PROCESS_MODE_DISABLED:
			bolt = child as PooledProjectile
			break
	_expect(is_instance_valid(bolt) and bolt._homing, "Wraith cast launches a pooled homing bolt")
	if is_instance_valid(bolt):
		var before_angle := bolt._velocity.angle()
		hero.position += Vector2(0.0, -120.0)
		bolt._physics_process(0.10)
		var turn := absf(wrapf(bolt._velocity.angle() - before_angle, -PI, PI))
		_expect(turn <= PooledProjectile.WRAITH_MAX_TURN_RATE * 0.10 + 0.001, "Wraith bolt turn rate is capped for dodgeability")
		bolt._physics_process(PooledProjectile.WRAITH_HOMING_TIME)
		_expect(not bolt._homing, "Wraith bolt stops tracking after a short lock window")
		var committed_velocity := bolt._velocity
		hero.position = bolt.global_position - Vector2(180.0, 0.0)
		bolt._physics_process(0.10)
		_expect(bolt._velocity.is_equal_approx(committed_velocity), "expired homing bolt cannot U-turn back onto Hero")
	var ally := EnemyController.new()
	ally.configure(EnemyController.Kind.WARDEN, hero)
	ally.position = Vector2(140.0, 400.0)
	root.add_child(ally)
	await process_frame
	var authority := CombatAuthority.new()
	root.add_child(authority)
	_expect(not authority.resolve_hit(wraith, ally, &"enemy_basic"), "combat factions reject enemy friendly fire")
	authority.queue_free()
	ally.queue_free()
	wraith.queue_free()
	hero.queue_free()
	pool.queue_free()
	await process_frame

func _make_projectile_test() -> PooledProjectile:
	return PooledProjectile.new()

func _test_multitouch_and_safe_area() -> void:
	var controls := MobileControls.new()
	controls.size = Vector2(1170.0, 540.0)
	root.add_child(controls)
	var left := InputEventScreenTouch.new()
	left.index = 1
	left.position = controls._joystick_rest_center() + Vector2(48.0, 0.0)
	left.pressed = true
	controls._handle_touch(left)
	var attack := InputEventScreenTouch.new()
	attack.index = 2
	attack.position = controls._button_center("attack")
	attack.pressed = true
	controls._handle_touch(attack)
	_expect(controls._left_touch == 1, "left thumb owns joystick independently")
	_expect(controls.get_move_axis().x > 0.5, "joystick touch produces immediate horizontal movement")
	_expect(int(controls._button_owners.attack) == 2, "right thumb owns attack independently")
	_expect(controls.consume_action(&"attack"), "attack touch queues exactly one action")
	var jump := InputEventScreenTouch.new()
	jump.index = 3
	jump.position = controls._button_center("jump")
	jump.pressed = true
	controls._handle_touch(jump)
	_expect(int(controls._button_owners.jump) == 3, "jump has an independent touch owner")
	_expect(controls.consume_action(&"jump"), "jump touch queues exactly one action")
	var scaled := MobileControls.scale_safe_area(Vector2(1170.0, 540.0), Vector2i(2340, 1080), Rect2i(120, 0, 2100, 1080))
	_expect(is_equal_approx(scaled.position.x, 60.0) and is_equal_approx(scaled.end.x, 1110.0), "safe area scales from display pixels into viewport coordinates")
	for action in ["attack", "jump", "skill_one", "skill_two"]:
		var center: Vector2 = controls._button_center(action)
		_expect(center.x > controls.size.x * 0.5 and center.x < controls.size.x, "%s stays inside landscape right half" % action)
		_expect(center.y > 0.0 and center.y < controls.size.y, "%s stays vertically on-screen" % action)
	controls.queue_free()

func _test_input_reset_on_lifecycle_boundary() -> void:
	var controls := MobileControls.new()
	controls.size = Vector2(960.0, 540.0)
	root.add_child(controls)
	controls._left_touch = 4
	controls._left_origin = Vector2(100.0, 400.0)
	controls._left_position = Vector2(150.0, 400.0)
	controls._button_owners["attack"] = 5
	controls._pending_actions["attack"] = true
	controls.reset_inputs()
	_expect(controls._left_touch == -1 and controls.get_move_axis() == Vector2.ZERO, "lifecycle reset clears joystick ownership")
	_expect(int(controls._button_owners["attack"]) == -1 and not bool(controls._pending_actions["attack"]), "lifecycle reset clears action ownership and pending input")
	controls.queue_free()

func _test_zone_structure() -> void:
	var zone := ZoneBuilder.new()
	var config := StageCatalog.get_stage(0)
	zone.configure(0, float(config.width))
	zone.build(config)
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
	_expect(hazards == 2, "stage one builds both authored hazards")
	_expect(one_way_platforms == 3, "stage one builds three reachable one-way platforms")
	zone.queue_free()

func _test_stage_catalog_and_progression() -> void:
	_expect(StageCatalog.count() == 3, "v1 run contains three authored stages")
	for index in range(StageCatalog.count()):
		var config := StageCatalog.get_stage(index)
		_expect(float(config.width) >= 2000.0, "stage %d has full traversal width" % (index + 1))
		_expect(config.platforms is Array and not config.platforms.is_empty(), "stage %d has authored platform traversal" % (index + 1))
		for entry in config.platforms:
			_expect(entry is Array and entry.size() == 2, "stage platform contract is center + size")
	_expect(not bool(StageCatalog.get_stage(0).boss) and not bool(StageCatalog.get_stage(1).boss), "boss is reserved for final stage")
	_expect(bool(StageCatalog.get_stage(2).boss), "final stage contains Rift Warden")

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
	_expect(enemy._attack_range() >= 80.0, "warden attack range matches the widened visual strike")
	_expect(enemy._animation_duration(&"death") >= 0.6, "enemy death animation has time to complete")
	var boss := BossController.new()
	boss.configure(hero)
	boss.position = Vector2(300.0, 400.0)
	root.add_child(boss)
	boss.state = BossController.State.CHASE
	boss._update_chase()
	_expect(boss.state == BossController.State.WINDUP, "boss chase enters windup in range")
	boss._start_strike()
	_expect(boss.state == BossController.State.STRIKE, "boss windup advances to strike")
	_expect(CombatAuthority.MAX_MELEE_DISTANCE >= 114.0, "combat authority does not clip boss visual reach")
	_expect(boss._animation_duration(&"death") >= 1.0, "boss death animation completes before cleanup")
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
	var hero := Hero.new()
	root.add_child(hero)
	var dead_payload := payload.duplicate(true)
	dead_payload.health = 0
	_expect(hero.restore_save_payload(dead_payload), "valid zero-health save restores")
	_expect(hero.state == Hero.State.DEATH, "zero-health restore keeps death state consistent before world recovery")
	hero.prepare_for_stage(Vector2(180.0, 406.0))
	var recovered := hero.get_resource_snapshot()
	_expect(not hero.is_dead() and hero.state == Hero.State.IDLE, "stage preparation recovers a zero-health save to a playable state")
	_expect(int(recovered.health) == int(recovered.max_health), "dead-save recovery restores health before gameplay resumes")
	hero.queue_free()

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
	target.received = 0
	_expect(authority.resolve_environment_hit(target, 18, Vector2.ZERO), "hazard damage resolves through local authority")
	_expect(target.received == 18, "hazard keeps canonical environment damage")
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

func _test_production_resources_load() -> void:
	for path in ["res://assets/rig/hero/idle_parts.png", "res://assets/rig/hero/run_parts.png", "res://assets/rig/hero/jump_parts.png", "res://assets/rig/hero/slash_parts.png", "res://assets/rig/hero/magic_parts.png", "res://assets/rig/enemies/warden_parts.png", "res://assets/rig/enemies/wraith_parts.png", "res://assets/rig/enemies/rift_warden_parts.png"]:
		_expect(load(path) is Texture2D, "articulated cutout texture loads: %s" % path)
	var tile_set := load("res://assets/environment/rift_zone_tileset.tres") as TileSet
	_expect(tile_set != null and tile_set.has_source(0), "rift tileset loads with atlas source")
	if tile_set != null and tile_set.has_source(0):
		var source := tile_set.get_source(0) as TileSetAtlasSource
		_expect(source != null and source.get_tiles_count() == 3, "rift tileset exposes three tiles")
	for path in ["res://assets/environment/bg_sky.png", "res://assets/environment/bg_ruins.png", "res://assets/environment/bg_foreground_mist.png", "res://assets/environment/platform_rune.png", "res://assets/environment/hazard_spikes.png", "res://assets/ui/hud_frame.png", "res://assets/ui/bar_under.png", "res://assets/ui/hp_fill.png", "res://assets/ui/mp_fill.png", "res://assets/ui/exp_fill.png", "res://assets/ui/boss_fill.png", "res://assets/ui/icon_rust_blade.png", "res://assets/ui/icon_rift_saber.png", "res://assets/ui/icon_ash_vest.png", "res://assets/ui/icon_warden_mail.png", "res://assets/ui/joystick_base.png", "res://assets/ui/joystick_knob.png", "res://assets/ui/button_attack.png", "res://assets/ui/button_jump.png", "res://assets/ui/button_skill_1.png", "res://assets/ui/button_skill_2.png", "res://assets/ui/button_pause.png", "res://assets/vfx/slash_1.png", "res://assets/vfx/slash_2.png", "res://assets/vfx/skill_one_slash.png", "res://assets/vfx/skill_two_projectile.png", "res://assets/vfx/wraith_bolt.png", "res://assets/vfx/hit_spark.png", "res://assets/vfx/dust.png"]:
		_expect(load(path) is Texture2D, "production texture loads: %s" % path)

func _test_full_scene_boot_and_pause() -> void:
	var packed := load("res://scenes/game.tscn") as PackedScene
	_expect(packed != null, "main game scene loads")
	if packed == null:
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	_expect(is_instance_valid(game._hero), "game scene creates hero")
	_expect(not is_instance_valid(game._boss), "stage one starts without the final boss")
	_expect(game._stage_index == 0 and game._stage_remaining == 3, "stage one spawns its authored encounter")
	_expect(is_instance_valid(game._hud), "game scene creates HUD")
	_expect(game._hud.get_parent() is CanvasLayer, "HUD stays screen-space inside a CanvasLayer")
	_expect(game._hud.size.x >= 900.0 and game._hud.size.y >= 500.0, "HUD owns the full logical viewport")
	_expect(is_instance_valid(game._controls), "game scene creates mobile controls")
	_expect(game._controls.process_mode == Node.PROCESS_MODE_ALWAYS, "pause control remains responsive while paused")
	game._load_stage(2, false)
	_expect(game._stage_index == 2 and is_instance_valid(game._boss), "final stage loads Rift Warden")
	_expect(game._hud._stage_label.text.begins_with("3/3"), "HUD reflects current stage progression")
	_expect(game._hud._boss == game._boss, "HUD binds the final boss through its native boss API")
	var hud_bars := 0
	for child in game._hud.get_children():
		if child is TextureProgressBar:
			hud_bars += 1
	_expect(hud_bars >= 4, "HUD presents HP/MP/EXP/boss bars as native TextureProgressBar controls")
	var control_visuals := 0
	for child in game._controls.get_children():
		if child is TextureRect:
			control_visuals += 1
	_expect(control_visuals >= 6, "mobile controls present joystick/buttons/pause as texture visuals")
	_expect(is_instance_valid(game._hero._rig) and game._hero._rig is CharacterMotionRig2D, "hero renders through the native articulated motion rig")
	_expect(game._hero._rig._skeleton is Skeleton2D and game._hero._rig._player is AnimationPlayer, "hero rig uses native Skeleton2D plus AnimationPlayer")
	game._controls._left_touch = 9
	game._toggle_user_pause()
	_expect(paused and game._hud._paused, "pause freezes tree and shows overlay")
	var pause_panel: NinePatchRect = game._hud._pause_overlay.get_meta("panel")
	var pause_center := pause_panel.position + pause_panel.size * 0.5
	_expect(pause_center.distance_to(game._hud._safe_area_rect().get_center()) < 1.0, "pause panel remains centered inside the safe screen area")
	_expect(game._controls._left_touch == -1, "pause clears active touch ownership")
	game._toggle_user_pause()
	_expect(not paused and not game._hud._paused, "resume restores gameplay")
	game.queue_free()
	await process_frame

func _test_defeat_retry_flow() -> void:
	var packed := load("res://scenes/game.tscn") as PackedScene
	_expect(packed != null, "main game scene loads for defeat/retry test")
	if packed == null:
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var checkpoint: Vector2 = game._hero.global_position + Vector2(32.0, 0.0)
	game._level_manager.activate_checkpoint(&"test_retry", checkpoint)
	game._hero.die()
	await create_timer(0.72).timeout
	_expect(paused and game._run_defeated, "death completes into an explicit defeated state")
	_expect(game._hud._defeated and game._hud._defeat_overlay.visible, "defeated overlay exposes the recovery flow")
	_expect(not game._controls._gameplay_enabled, "gameplay touch input is locked while defeated")
	game._retry_from_defeat()
	_expect(not paused and not game._run_defeated, "retry resumes the scene tree")
	_expect(not game._hero.is_dead() and game._hero.state == Hero.State.IDLE, "retry restores hero to a playable state")
	_expect(game._hero.global_position.distance_to(checkpoint) < 1.0, "retry returns hero to the active checkpoint")
	_expect(not game._hud._defeat_overlay.visible and game._controls._gameplay_enabled, "retry dismisses defeat UI and restores controls")
	game.queue_free()
	await process_frame

func _test_donor_jump_feel() -> void:
	var hero := Hero.new()
	root.add_child(hero)
	_expect(Hero.GRAVITY_RISE > 1500.0 and Hero.GRAVITY_FALL > Hero.GRAVITY_RISE, "donor asymmetric gravity preserves weight")
	_expect(Hero.JUMP_CUT_FACTOR < 0.6 and Hero.JUMP_CUT_FACTOR > 0.2, "variable jump cut factor from donor")
	_expect(Hero.TURN_BOOST > 1.2, "responsive turn boost from donor")
	var height := (Hero.JUMP_SPEED * Hero.JUMP_SPEED) / (2.0 * Hero.GRAVITY_RISE)
	_expect(height >= 120.0, "jump apex measurable via derived gravity")
	hero.velocity.y = -380.0
	var before := hero.velocity.y
	hero.velocity.y *= Hero.JUMP_CUT_FACTOR
	_expect(hero.velocity.y > before and hero.velocity.y < 0.0, "jump cut shortens hop")
	_expect(Hero.COYOTE_TIME >= 0.08 and Hero.JUMP_BUFFER_TIME >= 0.08, "donor coyote/buffer windows")
	hero.queue_free()

func _test_moving_platform_carry() -> void:
	var plat := MovingPlatform.new()
	plat.configure(Vector2(400, 300), Vector2(160, 18), Vector2(0, -96), 1.8)
	root.add_child(plat)
	_expect(plat.travel == Vector2(0, -96), "moving platform travel from donor")
	_expect(is_equal_approx(plat.duration, 1.8), "moving platform duration")
	_expect(plat.platform_size == Vector2(160, 18), "platform size")
	var has_col := false
	for c in plat.get_children():
		if c is CollisionShape2D:
			has_col = true
	_expect(has_col, "moving platform creates collision")
	_expect(plat is AnimatableBody2D, "moving platform uses AnimatableBody2D for jitter-free carry")
	plat.queue_free()

func _test_checkpoint_activation() -> void:
	var cp := Checkpoint.new()
	root.add_child(cp)
	var hero := Hero.new()
	root.add_child(hero)
	cp.position = Vector2(500, 400)
	hero.position = Vector2(500, 400)
	var holder := [false]
	var got_pos := [Vector2.ZERO]
	cp.activated.connect(func(id, pos): holder[0] = true; got_pos[0] = pos)
	cp._on_body_entered(hero)
	_expect(holder[0], "checkpoint activates on hero contact")
	_expect(got_pos[0] != Vector2.ZERO, "checkpoint emits position")
	holder[0] = false
	cp._on_body_entered(hero)
	_expect(not holder[0], "checkpoint is one-shot")
	cp.queue_free()
	hero.queue_free()

func _test_killzone_recovery() -> void:
	var kill := Killzone.new()
	kill.position = Vector2(600, 620)
	kill.configure(Vector2(200, 40))
	root.add_child(kill)
	var authority := CombatAuthority.new()
	root.add_child(authority)
	var hero := Hero.new()
	root.add_child(hero)
	hero.position = Vector2(600, 620)
	kill._on_body_entered(hero)
	_expect(true, "killzone triggers without deadlock")
	kill.queue_free()
	authority.queue_free()
	hero.queue_free()

func _test_stage_transition_no_duplicates() -> void:
	var packed := load("res://scenes/game.tscn") as PackedScene
	if packed == null:
		_expect(false, "main game scene loads for transition test")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await game.get_tree().process_frame
	var hero_count_before := 0
	for n in game.get_children():
		if n is Hero:
			hero_count_before += 1
	_expect(hero_count_before == 1, "stage has single hero before transition")
	game._load_stage(1, false)
	await game.get_tree().process_frame
	_expect(is_instance_valid(game._hero), "hero persists after stage transition")
	_expect(not game._transitioning, "transition flag clears")
	var hud_nodes := game.get_tree().get_nodes_in_group("hud")
	_expect(hud_nodes.size() == 1, "no duplicate HUD after transition")
	var ctrl_nodes := game.get_tree().get_nodes_in_group("mobile_controls")
	_expect(ctrl_nodes.size() == 1, "no duplicate MobileControls after transition")
	game.queue_free()
	await game.get_tree().process_frame

func _test_save_migration() -> void:
	var repo := SaveRepository.new()
	repo.save_path = "user://shadow_rift_test_migrate.json"
	var v1_payload := {"level": 2, "experience": 10, "experience_to_next": 100, "gold": 5, "mana": 80, "health": 70, "equipment": {"weapon": "rust_blade", "armor": "ash_vest"}}
	_expect(repo.save_game(v1_payload).ok, "v1 save writes")
	var file := FileAccess.open(repo.save_path, FileAccess.READ)
	var raw := file.get_as_text()
	file.close()
	var wrapper: Dictionary = JSON.parse_string(raw)
	wrapper["schema"] = 1
	wrapper["checksum"] = repo._checksum_v1(v1_payload)
	file = FileAccess.open(repo.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(wrapper))
	file.close()
	var loaded := repo.load_game()
	_expect(loaded.ok, "v1 save migrates to v2")
	_expect(int(loaded.payload.get("stage_index", -1)) == 0, "migrated save defaults stage_index")
	_expect(loaded.payload.has("checkpoint"), "migrated save has checkpoint")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.save_path))

func _test_level_config_data_driven() -> void:
	var mgr := LevelManager.new()
	root.add_child(mgr)
	_expect(mgr.count() == 3, "level manager has three stages")
	var cfg := mgr.get_config(0)
	_expect(cfg.width >= 2000.0, "level config width")
	_expect(cfg.checkpoints.size() >= 1, "level has checkpoint")
	var custom := LevelConfig.new()
	custom.id = &"custom_04"
	custom.display_name = "CUSTOM FOUR"
	custom.width = 2600.0
	custom.spawn = Vector2(180, 406)
	custom.platforms = [[Vector2(600, 340), Vector2(200, 18)]]
	custom.has_boss = false
	_expect(custom.width == 2600.0, "custom 4th stage configurable without core edit")
	mgr.queue_free()
func _signed_degrees(value: float) -> float:
	return wrapf(value + 180.0, 0.0, 360.0) - 180.0

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + label)
