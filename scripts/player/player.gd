extends CharacterBody2D
class_name Hero

signal attack_requested(combo_step: int)
signal state_changed(previous: State, current: State)
signal resources_changed(snapshot: Dictionary)

enum State { IDLE, MOVE, JUMP, ATTACK, HURT, DEATH }

const MOVE_SPEED := 250.0
const JUMP_SPEED := -520.0
const ATTACK_DURATION := 0.22
const COMBO_GRACE := 0.34
const SERVER_GROUND_Y := 406.0

var state := State.IDLE
var facing := 1.0
var _controls: MobileControls
var _attack_time := 0.0
var _combo_grace := 0.0
var _combo_step := 0
var _hurt_time := 0.0
var _dead := false
var _health: HealthComponent
var _hitbox: Hitbox
var _mana := 100
var _maximum_mana := 100
var _level := 1
var _experience := 0
var _experience_to_next := 100
var _gold := 0
var _key_actions := {&"attack": false, &"jump": false, &"skill_one": false, &"skill_two": false}
var _profile := PlayerProfile.new()
var _integrity_check_time := 0.0
var _integrity_violations := 0
var _server_authority_enabled := OS.has_feature("server_authoritative")
var _server_client: ServerAuthorityClient
var _server_snapshot: Dictionary = {}
var _server_animation_time := 0.0
var _visual_time := 0.0

func _ready() -> void:
	_controls = get_tree().get_first_node_in_group("mobile_controls") as MobileControls
	_profile.stats_changed.connect(_on_stats_changed)
	_add_body_shape()
	_add_combat_nodes()
	_add_camera()
	queue_redraw()
	resources_changed.emit(get_resource_snapshot())

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_J:
			_key_actions[&"attack"] = true
		KEY_SPACE:
			_key_actions[&"jump"] = true
		KEY_K:
			_key_actions[&"skill_one"] = true
		KEY_L:
			_key_actions[&"skill_two"] = true

func _physics_process(delta: float) -> void:
	_visual_time += delta
	if _server_authority_enabled:
		_process_server_authority(delta)
		return
	if _dead:
		_health.tick(delta)
		velocity.y += get_gravity().y * delta
		move_and_slide()
		return
	_combo_grace = maxf(0.0, _combo_grace - delta)
	_integrity_check_time -= delta
	if _integrity_check_time <= 0.0:
		_integrity_check_time = 0.5
		if _profile.repair_if_modified():
			_integrity_violations += 1
	_health.tick(delta)
	_hitbox.tick(delta)
	visible = not _health.is_invulnerable() or int(Time.get_ticks_msec() / 55) % 2 == 0
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	if state == State.HURT:
		_update_hurt(delta)
		move_and_slide()
		return
	if state == State.ATTACK:
		_update_attack(delta)
		move_and_slide()
		return
	var move_axis := _controls.get_move_axis().x if is_instance_valid(_controls) else 0.0
	velocity.x = move_toward(velocity.x, move_axis * MOVE_SPEED, 1100.0 * delta)
	if absf(move_axis) > 0.05:
		facing = signf(move_axis)
	if _jump_pressed() and is_on_floor():
		velocity.y = JUMP_SPEED
		_set_state(State.JUMP)
	elif _skill_pressed(&"skill_two"):
		_start_skill(&"skill_two", 34, 0.34)
	elif _skill_pressed(&"skill_one"):
		_start_skill(&"skill_one", 22, 0.28)
	elif _attack_pressed():
		_start_attack()
	elif not is_on_floor():
		_set_state(State.JUMP)
	elif absf(velocity.x) > 8.0:
		_set_state(State.MOVE)
	else:
		_set_state(State.IDLE)
	move_and_slide()
	queue_redraw()

func apply_hurt(knockback: Vector2, duration: float = 0.25) -> void:
	if _dead or state == State.HURT:
		return
	velocity = knockback
	_hurt_time = duration
	_set_state(State.HURT)

func die() -> void:
	if _dead:
		return
	_dead = true
	velocity.x = 0.0
	_set_state(State.DEATH)
	queue_redraw()

func get_facing() -> float:
	return facing

func get_attack_power() -> int:
	return get_canonical_attack_power()

func get_canonical_attack_power() -> int:
	if _server_authority_enabled:
		return int(_server_snapshot.get("attack", 0))
	return int(_profile.get_canonical_stats().attack)

func get_defense() -> int:
	if _server_authority_enabled:
		return int(_server_snapshot.get("defense", 0))
	return int(_profile.get_canonical_stats().defense)

func receive_authoritative_hit(amount: int, knockback: Vector2) -> bool:
	if _server_authority_enabled:
		return false
	return _health.apply_authoritative_damage(amount, knockback)

func grant_rewards(experience: int, gold: int) -> void:
	if _server_authority_enabled:
		return
	_experience += maxi(0, experience)
	_gold += maxi(0, gold)
	while _experience >= _experience_to_next:
		_experience -= _experience_to_next
		_level += 1
		_experience_to_next = int(round(_experience_to_next * 1.24))
	_profile.set_level(_level)
	resources_changed.emit(get_resource_snapshot())

func get_resource_snapshot() -> Dictionary:
	if _server_authority_enabled and not _server_snapshot.is_empty():
		return _server_snapshot.duplicate(true)
	var stats := _profile.get_stats()
	return {"health": _health.current, "max_health": _health.maximum, "mana": _mana, "max_mana": _maximum_mana, "level": _level, "exp": _experience, "exp_to_next": _experience_to_next, "gold": _gold, "attack": stats.attack, "defense": stats.defense, "weapon_name": stats.weapon_name, "armor_name": stats.armor_name}

func get_profile() -> PlayerProfile:
	return _profile

func export_save_payload() -> Dictionary:
	if _server_authority_enabled:
		return {}
	return {"level": _level, "experience": _experience, "experience_to_next": _experience_to_next, "gold": _gold, "mana": _mana, "health": _health.current, "equipment": _profile.get_equipment_payload()}

func restore_save_payload(payload: Dictionary) -> bool:
	if _server_authority_enabled:
		return false
	var repository := SaveRepository.new()
	if not repository.validate_payload(payload).ok:
		return false
	_level = int(payload.level)
	_experience = int(payload.experience)
	_experience_to_next = int(payload.experience_to_next)
	_gold = int(payload.gold)
	_profile.set_level(_level)
	if not _profile.restore_equipment(payload.equipment):
		return false
	var stats := _profile.get_canonical_stats()
	_maximum_mana = int(stats.max_mana)
	_mana = clampi(int(payload.mana), 0, _maximum_mana)
	_health.set_maximum(int(stats.max_health), false)
	_health.set_current(int(payload.health))
	resources_changed.emit(get_resource_snapshot())
	return true

func cycle_equipment(slot: StringName) -> void:
	var ids := ItemCatalog.ids_for_slot(slot)
	if ids.is_empty():
		return
	var current_id := _profile.weapon_id if slot == &"weapon" else _profile.armor_id
	var next_index := (ids.find(current_id) + 1) % ids.size()
	if _server_authority_enabled:
		if is_instance_valid(_server_client) and _server_client.is_online():
			_server_client.submit_action("equip", {"slot": String(slot), "itemId": String(ids[next_index])})
		return
	_profile.equip(slot, ids[next_index])

func bind_server_authority(client: ServerAuthorityClient) -> void:
	_server_client = client

func apply_server_snapshot(player: Dictionary) -> void:
	if not _server_authority_enabled:
		return
	var equipment := {"weapon": str(player.get("weaponId", "")), "armor": str(player.get("armorId", ""))}
	_profile.set_level(int(player.get("level", 1)))
	_profile.restore_equipment(equipment)
	_level = int(player.get("level", 1))
	_experience = int(player.get("exp", 0))
	_experience_to_next = int(player.get("expToNext", 100))
	_gold = int(player.get("gold", 0))
	_maximum_mana = int(player.get("maxMana", 1))
	_mana = clampi(int(player.get("mana", 0)), 0, _maximum_mana)
	_health.set_maximum(int(player.get("maxHp", 1)), false)
	_health.set_current(int(player.get("hp", 0)))
	global_position.x = float(player.get("x", global_position.x))
	global_position.y = float(player.get("y", global_position.y))
	_dead = _health.current <= 0
	if _dead:
		_set_state(State.DEATH)
	elif global_position.y < SERVER_GROUND_Y - 0.5:
		_set_state(State.JUMP)
	var stats := _profile.get_stats()
	_server_snapshot = {
		"health": _health.current,
		"max_health": _health.maximum,
		"mana": _mana,
		"max_mana": _maximum_mana,
		"level": _level,
		"exp": _experience,
		"exp_to_next": _experience_to_next,
		"gold": _gold,
		"attack": int(player.get("attack", 0)),
		"defense": int(player.get("defense", 0)),
		"weapon_name": stats.weapon_name,
		"armor_name": stats.armor_name
	}
	resources_changed.emit(get_resource_snapshot())
	queue_redraw()

func set_server_connection_available(available: bool) -> void:
	if not available and _server_authority_enabled:
		velocity = Vector2.ZERO
		_set_state(State.IDLE if not _dead else State.DEATH)

func _start_attack() -> void:
	_combo_step = 1 if _combo_grace <= 0.0 else 2
	_attack_time = ATTACK_DURATION
	velocity.x *= 0.25
	_set_state(State.ATTACK)
	var attack_kind := &"basic_one" if _combo_step == 1 else &"basic_two"
	_hitbox.activate(attack_kind, ATTACK_DURATION * 0.72, Vector2(34.0 * facing, -5.0))
	attack_requested.emit(_combo_step)
	queue_redraw()

func _process_server_authority(delta: float) -> void:
	_server_animation_time = maxf(0.0, _server_animation_time - delta)
	if not is_instance_valid(_server_client) or not _server_client.is_online() or _dead:
		velocity = Vector2.ZERO
		return
	var move_axis := _controls.get_move_axis().x if is_instance_valid(_controls) else 0.0
	var move_direction := 0 if absf(move_axis) <= 0.05 else int(signf(move_axis))
	_server_client.set_move_direction(move_direction)
	if move_direction != 0:
		facing = float(move_direction)
	if _jump_pressed():
		_server_client.submit_action("jump")
		_set_state(State.JUMP)
		_server_animation_time = 0.22
	elif _skill_pressed(&"skill_two"):
		_server_client.submit_action("skill", {"slot": 2})
		_set_state(State.ATTACK)
		_server_animation_time = 0.34
	elif _skill_pressed(&"skill_one"):
		_server_client.submit_action("skill", {"slot": 1})
		_set_state(State.ATTACK)
		_server_animation_time = 0.28
	elif _attack_pressed():
		_server_client.submit_action("attack")
		_set_state(State.ATTACK)
		_server_animation_time = ATTACK_DURATION
	elif float(_server_snapshot.get("health", 1)) > 0.0 and global_position.y < SERVER_GROUND_Y - 0.5:
		_set_state(State.JUMP)
	elif _server_animation_time <= 0.0:
		_set_state(State.MOVE if move_direction != 0 else State.IDLE)
	queue_redraw()

func _update_attack(delta: float) -> void:
	_attack_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _attack_time <= 0.0:
		_combo_grace = COMBO_GRACE
		_set_state(State.JUMP if not is_on_floor() else State.IDLE)

func _start_skill(kind: StringName, mana_cost: int, duration: float) -> void:
	if _mana < mana_cost:
		return
	_mana -= mana_cost
	_attack_time = duration
	velocity.x *= 0.2
	_set_state(State.ATTACK)
	if kind == &"skill_two":
		var pool := get_tree().get_first_node_in_group("projectile_pool") as ReusablePool
		if is_instance_valid(pool):
			var projectile := pool.acquire() as PooledProjectile
			projectile.activate(self, global_position + Vector2(28.0 * facing, -12.0), facing, kind)
	else:
		_hitbox.activate(kind, duration * 0.78, Vector2(42.0 * facing, -7.0))
	resources_changed.emit(get_resource_snapshot())

func _update_hurt(delta: float) -> void:
	_hurt_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 520.0 * delta)
	if _hurt_time <= 0.0:
		_set_state(State.JUMP if not is_on_floor() else State.IDLE)

func _attack_pressed() -> bool:
	return _consume_key_action(&"attack") or (is_instance_valid(_controls) and _controls.consume_action(&"attack"))

func _jump_pressed() -> bool:
	return _consume_key_action(&"jump") or (is_instance_valid(_controls) and _controls.consume_action(&"jump"))

func _skill_pressed(action: StringName) -> bool:
	return _consume_key_action(action) or (is_instance_valid(_controls) and _controls.consume_action(action))

func _consume_key_action(action: StringName) -> bool:
	var was_pending: bool = _key_actions[action]
	_key_actions[action] = false
	return was_pending

func _set_state(next_state: State) -> void:
	if next_state == state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state)

func _add_body_shape() -> void:
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 12.0
	shape.height = 42.0
	collision.shape = shape
	collision.position = Vector2(0.0, -2.0)
	add_child(collision)

func _add_camera() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(120.0, -48.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_right = 2400
	camera.limit_top = 0
	camera.limit_bottom = 540
	add_child(camera)

func _add_combat_nodes() -> void:
	_health = HealthComponent.new()
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(apply_hurt)
	_health.depleted.connect(die)
	var stats := _profile.get_stats()
	_maximum_mana = int(stats.max_mana)
	_mana = _maximum_mana
	_health.configure(int(stats.max_health), 0.55)
	add_child(_health)
	var hurtbox := Hurtbox.new()
	hurtbox.configure(self, Vector2(30.0, 46.0))
	hurtbox.position = Vector2(0.0, -3.0)
	add_child(hurtbox)
	_hitbox = Hitbox.new()
	_hitbox.configure(self, Vector2(46.0, 42.0))
	add_child(_hitbox)

func _on_health_changed(_current: int, _maximum: int) -> void:
	resources_changed.emit(get_resource_snapshot())

func _on_stats_changed(stats: Dictionary) -> void:
	if _server_authority_enabled:
		return
	_maximum_mana = int(stats.max_mana)
	_mana = mini(_mana, _maximum_mana)
	if is_instance_valid(_health):
		_health.set_maximum(int(stats.max_health), true)
	resources_changed.emit(get_resource_snapshot())

func _draw() -> void:
	var moving := state == State.MOVE
	var airborne := state == State.JUMP
	var bob := sin(_visual_time * 12.0) * 2.0 if moving else 0.0
	var body_color := Color(0.18, 0.26, 0.40) if state != State.HURT else Color(0.92, 0.30, 0.34)
	var outline := Color(0.04, 0.055, 0.09, 0.96)
	var shadow_width := 26.0 if airborne else 34.0
	var shadow_alpha := 0.20 if airborne else 0.34
	draw_colored_polygon(PackedVector2Array([Vector2(-shadow_width, 19.0), Vector2(shadow_width, 19.0), Vector2(shadow_width * 0.65, 24.0), Vector2(-shadow_width * 0.65, 24.0)]), Color(0.0, 0.0, 0.0, shadow_alpha))
	var cape_back := -facing
	draw_colored_polygon(PackedVector2Array([Vector2(-10.0 * facing, -21.0 + bob), Vector2(31.0 * cape_back, -6.0 + bob), Vector2(24.0 * cape_back, 15.0 + bob), Vector2(-8.0 * facing, 9.0 + bob)]), Color(0.48, 0.055, 0.09, 0.92))
	draw_colored_polygon(PackedVector2Array([Vector2(-13.0, -22.0 + bob), Vector2(13.0, -22.0 + bob), Vector2(15.0, 12.0 + bob), Vector2(-15.0, 12.0 + bob)]), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-10.0, -20.0 + bob), Vector2(10.0, -20.0 + bob), Vector2(11.0, 10.0 + bob), Vector2(-11.0, 10.0 + bob)]), body_color)
	draw_rect(Rect2(-12.0, -9.0 + bob, 24.0, 5.0), Color(0.68, 0.48, 0.22, 0.92))
	var leg_phase := sin(_visual_time * 13.0) * 5.0 if moving else 0.0
	draw_line(Vector2(-6.0, 10.0 + bob), Vector2(-7.0 + leg_phase, 22.0), outline, 6.0)
	draw_line(Vector2(6.0, 10.0 + bob), Vector2(7.0 - leg_phase, 22.0), outline, 6.0)
	draw_circle(Vector2(0.0, -31.0 + bob), 11.0, outline)
	draw_circle(Vector2(0.0, -31.0 + bob), 8.5, Color(0.77, 0.38, 0.20))
	draw_rect(Rect2(-10.0, -43.0 + bob, 20.0, 6.0), Color(0.16, 0.19, 0.28))
	var eye_x := 4.0 * facing
	draw_circle(Vector2(eye_x, -32.0 + bob), 2.2, Color(1.0, 0.78, 0.30))
	var sword_hand := Vector2(11.0 * facing, -4.0 + bob)
	var sword_tip := sword_hand + Vector2(30.0 * facing, -12.0)
	draw_line(sword_hand, sword_tip, Color(0.72, 0.78, 0.84), 4.0)
	draw_line(sword_tip, sword_tip + Vector2(7.0 * facing, -3.0), Color(0.92, 0.94, 0.96), 2.0)
	if moving and is_on_floor():
		var dust_side := -facing
		for index in range(3):
			var phase := fmod(_visual_time * 70.0 + float(index) * 9.0, 24.0)
			draw_circle(Vector2(dust_side * (18.0 + phase), 19.0 - float(index) * 3.0), 2.5 - float(index) * 0.45, Color(0.52, 0.48, 0.42, 0.28))
	if state == State.ATTACK:
		var arc_center := Vector2(18.0 * facing, -5.0 + bob)
		draw_arc(arc_center, 30.0, -1.15 if facing > 0.0 else 1.95, 1.15 if facing > 0.0 else 4.35, 20, Color(1.0, 0.77, 0.30, 0.92), 6.0)
		draw_arc(arc_center, 36.0, -1.10 if facing > 0.0 else 2.0, 1.05 if facing > 0.0 else 4.30, 20, Color(0.98, 0.92, 0.66, 0.34), 2.0)
