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
	await process_frame
	if _failures == 0:
		print("PASS: 16 behavior tests")
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
	hero.die()
	_expect(hero.is_dead() and hero.state == Hero.State.DEATH, "hero death enters terminal animation state")
	hero.respawn_at(Vector2(180.0, 406.0))
	var snapshot := hero.get_resource_snapshot()
	_expect(not hero.is_dead() and hero.state == Hero.State.IDLE, "respawn returns hero to playable idle state")
	_expect(int(snapshot.health) == int(snapshot.max_health) and int(snapshot.mana) == int(snapshot.max_mana), "respawn restores health and mana")
	hero.queue_free()

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
	_expect(hero.state == Hero.State.DEATH, "zero-health restore keeps death state consistent")
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
	var hero_frames := load("res://assets/sprites/hero/hero_frames.tres") as SpriteFrames
	_expect(hero_frames != null, "hero SpriteFrames resource loads")
	for anim in ["idle", "move", "jump", "attack1", "attack2", "skill_one", "skill_two", "hurt", "death"]:
		_expect(hero_frames != null and hero_frames.has_animation(StringName(anim)), "hero animation %s exists" % anim)
	var warden_frames := load("res://assets/sprites/enemies/warden_frames.tres") as SpriteFrames
	_expect(warden_frames != null, "warden SpriteFrames resource loads")
	for anim in ["patrol", "aggro", "attack", "hurt", "death"]:
		_expect(warden_frames != null and warden_frames.has_animation(StringName(anim)), "warden animation %s exists" % anim)
	var wraith_frames := load("res://assets/sprites/enemies/wraith_frames.tres") as SpriteFrames
	_expect(wraith_frames != null, "wraith SpriteFrames resource loads")
	for anim in ["hover", "dash_attack", "hurt", "death"]:
		_expect(wraith_frames != null and wraith_frames.has_animation(StringName(anim)), "wraith animation %s exists" % anim)
	var boss_frames := load("res://assets/sprites/enemies/rift_warden_frames.tres") as SpriteFrames
	_expect(boss_frames != null, "boss SpriteFrames resource loads")
	for anim in ["watch", "chase", "windup", "strike", "hurt", "death"]:
		_expect(boss_frames != null and boss_frames.has_animation(StringName(anim)), "boss animation %s exists" % anim)
	var tile_set := load("res://assets/environment/rift_zone_tileset.tres") as TileSet
	_expect(tile_set != null and tile_set.has_source(0), "rift tileset loads with atlas source")
	if tile_set != null and tile_set.has_source(0):
		var source := tile_set.get_source(0) as TileSetAtlasSource
		_expect(source != null and source.get_tiles_count() == 3, "rift tileset exposes three tiles")
	for path in ["res://assets/environment/bg_sky.png", "res://assets/environment/bg_ruins.png", "res://assets/environment/bg_foreground_mist.png", "res://assets/environment/platform_rune.png", "res://assets/environment/hazard_spikes.png", "res://assets/ui/hud_frame.png", "res://assets/ui/bar_under.png", "res://assets/ui/hp_fill.png", "res://assets/ui/mp_fill.png", "res://assets/ui/exp_fill.png", "res://assets/ui/boss_fill.png", "res://assets/ui/icon_rust_blade.png", "res://assets/ui/icon_rift_saber.png", "res://assets/ui/icon_ash_vest.png", "res://assets/ui/icon_warden_mail.png", "res://assets/ui/joystick_base.png", "res://assets/ui/joystick_knob.png", "res://assets/ui/button_attack.png", "res://assets/ui/button_jump.png", "res://assets/ui/button_skill_1.png", "res://assets/ui/button_skill_2.png", "res://assets/ui/button_pause.png", "res://assets/vfx/slash_1.png", "res://assets/vfx/slash_2.png", "res://assets/vfx/skill_one_slash.png", "res://assets/vfx/skill_two_projectile.png", "res://assets/vfx/hit_spark.png", "res://assets/vfx/dust.png"]:
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
	_expect(is_instance_valid(game._controls), "game scene creates mobile controls")
	_expect(game._controls.process_mode == Node.PROCESS_MODE_ALWAYS, "pause control remains responsive while paused")
	game._load_stage(2, false)
	_expect(game._stage_index == 2 and is_instance_valid(game._boss), "final stage loads Rift Warden")
	_expect(game._hud._stage_label.text.begins_with("3/3"), "HUD reflects current stage progression")
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
	var hero_sprite: AnimatedSprite2D = null
	for child in game._hero.get_children():
		if child is AnimatedSprite2D:
			hero_sprite = child
	_expect(hero_sprite != null and hero_sprite.sprite_frames != null, "hero renders through AnimatedSprite2D sprite frames")
	game._controls._left_touch = 9
	game._toggle_user_pause()
	_expect(paused and game._hud._paused, "pause freezes tree and shows overlay")
	_expect(game._controls._left_touch == -1, "pause clears active touch ownership")
	game._toggle_user_pause()
	_expect(not paused and not game._hud._paused, "resume restores gameplay")
	game.queue_free()
	await process_frame

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + label)
