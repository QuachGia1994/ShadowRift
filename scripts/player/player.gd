extends CharacterBody2D
class_name Hero

## Upgraded with donor mechanics: asymmetric gravity, variable jump, coyote/buffer, turn boost
## Adapted from SummerEngine template (MIT 66fc71b) + godot-platformer-toolkit (MIT e755d6e)
## Preserves ShadowRift identity: 2-hit combo, Skill1/2, CombatAuthority, Option A anim

signal attack_requested(combo_step: int)
signal state_changed(previous: State, current: State)
signal resources_changed(snapshot: Dictionary)
signal persistence_requested
signal died
signal jumped
signal landed

enum State { IDLE, MOVE, JUMP, ATTACK, HURT, DEATH }

const MOVE_SPEED := 250.0
const MOVE_ACCELERATION := 2600.0
const MOVE_DECELERATION := 3200.0
const JUMP_SPEED := -720.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER_TIME := 0.13
const ATTACK_DURATION := 0.22
const COMBO_GRACE := 0.34

# Donor-adapted game-feel tuning (template 1100/1400 + toolkit derived)
const GRAVITY_RISE := 1800.0
const GRAVITY_FALL := 2650.0
const MAX_FALL_SPEED := 900.0
const JUMP_CUT_FACTOR := 0.42
const TURN_BOOST := 1.55
const AIR_ACCELERATION_FACTOR := 0.88

const SLASH_ONE := preload("res://assets/vfx/slash_1.png")
const SLASH_TWO := preload("res://assets/vfx/slash_2.png")
const SKILL_SLASH := preload("res://assets/vfx/skill_one_slash.png")
const DUST_TEXTURE := preload("res://assets/vfx/dust.png")

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
var _rig: CharacterMotionRig2D
var _attack_anim := &"attack1"
var _keyboard_jump_released := false
var _dust_cooldown := 0.0
var _dust_alternator := false
var _coyote_left := 0.0
var _buffer_left := 0.0
var _was_on_floor: bool = false
var _camera: Camera2D
var _squash: SquashStretch

func _ready() -> void:
    _controls = get_tree().get_first_node_in_group("mobile_controls") as MobileControls
    _profile.stats_changed.connect(_on_stats_changed)
    _add_body_shape()
    _add_combat_nodes()
    _add_visual_rig()
    _add_camera()
    _add_squash()
    resources_changed.emit(get_resource_snapshot())

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or event.echo:
        return
    if event.keycode == KEY_SPACE:
        if event.pressed:
            _key_actions[&"jump"] = true
        else:
            _keyboard_jump_released = true
        return
    if not event.pressed:
        return
    match event.keycode:
        KEY_J:
            _key_actions[&"attack"] = true
        KEY_K:
            _key_actions[&"skill_one"] = true
        KEY_L:
            _key_actions[&"skill_two"] = true

func _physics_process(delta: float) -> void:
    if _dead:
        _health.tick(delta)
        _apply_gravity(delta)
        move_and_slide()
        _update_floor_state(delta)
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
    _update_coyote(delta)
    _update_buffer(delta)
    _apply_gravity(delta)
    if state == State.HURT:
        _update_hurt(delta)
        move_and_slide()
        _update_floor_state(delta)
        return
    if state == State.ATTACK:
        _update_attack(delta)
        move_and_slide()
        _update_floor_state(delta)
        return
    var move_axis := _controls.get_move_axis().x if is_instance_valid(_controls) else 0.0
    # keyboard fallback for donor parity
    var kb := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    if absf(kb) > 0.05:
        move_axis = kb
    # turn boost + air control (adapted template turn_boost 1.6, toolkit air_acceleration)
    var braking := is_zero_approx(move_axis) or move_axis * velocity.x < 0.0
    var accel := MOVE_ACCELERATION
    if not is_on_floor():
        accel *= AIR_ACCELERATION_FACTOR
    if braking and absf(move_axis) > 0.05 and is_on_floor():
        accel *= TURN_BOOST
    var target_speed := move_axis * MOVE_SPEED
    if absf(move_axis) <= 0.05:
        velocity.x = move_toward(velocity.x, 0.0, MOVE_DECELERATION * delta)
    else:
        velocity.x = move_toward(velocity.x, target_speed, accel * delta)
    if absf(move_axis) > 0.05:
        facing = signf(move_axis)
    if is_instance_valid(_rig):
        _rig.set_facing(facing)
    # jump with coyote + buffer (toolkit pattern _coyote_left/_buffer_left)
    if _buffer_left > 0.0 and _coyote_left > 0.0:
        _buffer_left = 0.0
        _coyote_left = 0.0
        velocity.y = JUMP_SPEED
        _set_state(State.JUMP)
        jumped.emit()
        if _squash:
            _squash.trigger_jump()
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
    # Variable jump cut uses the actual keyboard/touch release edge.
    if velocity.y < 0.0 and _jump_released():
        velocity.y *= JUMP_CUT_FACTOR
    _sync_motion_animation()
    if state == State.MOVE and is_on_floor():
        _dust_cooldown -= delta
        if _dust_cooldown <= 0.0:
            _dust_cooldown = 0.16
            _spawn_dust()
    move_and_slide()
    # AnimatableBody2D with sync_to_physics carries CharacterBody2D natively.
    _update_floor_state(delta)

func _update_coyote(delta: float) -> void:
    if is_on_floor():
        _coyote_left = COYOTE_TIME
    else:
        _coyote_left = maxf(0.0, _coyote_left - delta)

func _update_buffer(delta: float) -> void:
    if _jump_pressed():
        _buffer_left = JUMP_BUFFER_TIME
    else:
        _buffer_left = maxf(0.0, _buffer_left - delta)

func _jump_released() -> bool:
    if _keyboard_jump_released:
        _keyboard_jump_released = false
        return true
    return is_instance_valid(_controls) and _controls.consume_action_released(&"jump")

func _update_floor_state(delta: float) -> void:
    var now_on_floor := is_on_floor()
    if now_on_floor and not _was_on_floor:
        landed.emit()
        if _squash:
            _squash.trigger_land()
        if is_instance_valid(_rig):
            _rig.play_land()
    _was_on_floor = now_on_floor

func _apply_gravity(delta: float) -> void:
    if is_on_floor():
        return
    var g := GRAVITY_RISE if velocity.y < 0.0 else GRAVITY_FALL
    velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)

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
    velocity = Vector2.ZERO
    _set_state(State.DEATH)
    died.emit()

func is_dead() -> bool:
    return _dead

func respawn_at(spawn_position: Vector2) -> void:
    _dead = false
    global_position = spawn_position
    velocity = Vector2.ZERO
    _coyote_left = 0.0
    _buffer_left = 0.0
    _health.set_current(_health.maximum)
    _health.grant_invulnerability(1.0)
    _mana = _maximum_mana
    visible = true
    modulate = Color.WHITE
    _set_state(State.IDLE)
    resources_changed.emit(get_resource_snapshot())

func place_at(spawn_position: Vector2) -> void:
    global_position = spawn_position
    velocity = Vector2.ZERO
    if not _dead:
        _set_state(State.IDLE)

func prepare_for_stage(spawn_position: Vector2) -> void:
    if _dead:
        respawn_at(spawn_position)
        return
    place_at(spawn_position)
    var health_recovery := maxi(1, int(round(float(_health.maximum) * 0.18)))
    var mana_recovery := maxi(1, int(round(float(_maximum_mana) * 0.20)))
    _health.set_current(mini(_health.maximum, _health.current + health_recovery))
    _mana = mini(_maximum_mana, _mana + mana_recovery)
    _set_state(State.IDLE)
    resources_changed.emit(get_resource_snapshot())

func set_camera_world_width(world_width: float) -> void:
    if is_instance_valid(_camera):
        _camera.limit_right = maxi(960, int(ceil(world_width)))

func get_facing() -> float:
    return facing

func get_attack_power() -> int:
    return get_canonical_attack_power()

func get_canonical_attack_power() -> int:
    return int(_profile.get_canonical_stats().attack)

func get_defense() -> int:
    return int(_profile.get_canonical_stats().defense)

func receive_canonical_hit(amount: int, knockback: Vector2) -> bool:
    return _health.apply_canonical_damage(amount, knockback)

func grant_rewards(experience: int, gold: int) -> void:
    _experience += maxi(0, experience)
    _gold += maxi(0, gold)
    while _experience >= _experience_to_next:
        _experience -= _experience_to_next
        _level += 1
        _experience_to_next = int(round(_experience_to_next * 1.24))
    _profile.set_level(_level)
    resources_changed.emit(get_resource_snapshot())
    persistence_requested.emit()

func get_resource_snapshot() -> Dictionary:
    var stats := _profile.get_stats()
    return {"health": _health.current, "max_health": _health.maximum, "mana": _mana, "max_mana": _maximum_mana, "level": _level, "exp": _experience, "exp_to_next": _experience_to_next, "gold": _gold, "attack": stats.attack, "defense": stats.defense, "weapon_name": stats.weapon_name, "armor_name": stats.armor_name}

func get_profile() -> PlayerProfile:
    return _profile

func export_save_payload() -> Dictionary:
    return {"level": _level, "experience": _experience, "experience_to_next": _experience_to_next, "gold": _gold, "mana": _mana, "health": _health.current, "equipment": _profile.get_equipment_payload()}

func restore_save_payload(payload: Dictionary) -> bool:
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
    _dead = _health.current <= 0
    _set_state(State.DEATH if _dead else State.IDLE)
    resources_changed.emit(get_resource_snapshot())
    return true

func cycle_equipment(slot: StringName) -> void:
    var ids := ItemCatalog.ids_for_slot(slot)
    if ids.is_empty():
        return
    var current_id := _profile.weapon_id if slot == &"weapon" else _profile.armor_id
    var next_index := (ids.find(current_id) + 1) % ids.size()
    if _profile.equip(slot, ids[next_index]):
        persistence_requested.emit()

func _start_attack() -> void:
    _combo_step = 1 if _combo_grace <= 0.0 else 2
    _attack_time = ATTACK_DURATION
    velocity.x *= 0.25
    _attack_anim = &"attack1" if _combo_step == 1 else &"attack2"
    _set_state(State.ATTACK)
    var attack_kind := &"basic_one" if _combo_step == 1 else &"basic_two"
    _hitbox.activate(attack_kind, ATTACK_DURATION * 0.72, Vector2(34.0 * facing, -5.0))
    _spawn_vfx(SLASH_ONE if _combo_step == 1 else SLASH_TWO, Vector2(26.0 * facing, -8.0), 0.2)
    attack_requested.emit(_combo_step)

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
    _attack_anim = kind
    _set_state(State.ATTACK)
    if kind == &"skill_two":
        var pool := get_tree().get_first_node_in_group("projectile_pool") as ReusablePool
        if is_instance_valid(pool):
            var projectile := pool.acquire() as PooledProjectile
            projectile.activate(self, global_position + Vector2(28.0 * facing, -12.0), facing, kind)
    else:
        _hitbox.activate(kind, duration * 0.78, Vector2(42.0 * facing, -7.0))
        _spawn_vfx(SKILL_SLASH, Vector2(32.0 * facing, -8.0), 0.28)
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
    _apply_animation(next_state)

func _apply_animation(next_state: State) -> void:
    if not is_instance_valid(_rig):
        return
    match next_state:
        State.IDLE:
            _rig.play(&"idle")
        State.MOVE:
            _rig.play(&"move")
        State.JUMP:
            _rig.play(&"jump_rise" if velocity.y <= 0.0 else &"fall")
        State.ATTACK:
            _rig.play(_attack_anim)
        State.HURT:
            _rig.play(&"hurt")
        State.DEATH:
            _rig.play(&"death")

func _sync_motion_animation() -> void:
    if not is_instance_valid(_rig):
        return
    if state == State.JUMP:
        _rig.play(&"jump_rise" if velocity.y < 0.0 else &"fall")
    elif state == State.MOVE:
        _rig.play(&"move", clampf(absf(velocity.x) / MOVE_SPEED, 0.72, 1.35))

func _add_visual_rig() -> void:
    _rig = CharacterMotionRig2D.new()
    _rig.configure(&"hero")
    add_child(_rig)

func _spawn_vfx(texture: Texture2D, local_offset: Vector2, lifetime: float) -> void:
    var vfx := Sprite2D.new()
    vfx.texture = texture
    vfx.position = local_offset
    vfx.flip_h = facing < 0.0
    vfx.z_index = 1
    add_child(vfx)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(vfx, "modulate:a", 0.0, lifetime)
    tween.tween_property(vfx, "scale", Vector2(1.18, 1.18), lifetime)
    tween.chain().tween_callback(vfx.queue_free)

func _spawn_dust() -> void:
    _dust_alternator = not _dust_alternator
    var vfx := Sprite2D.new()
    vfx.texture = DUST_TEXTURE
    vfx.position = Vector2(-8.0 * facing + (4.0 if _dust_alternator else -4.0), 18.0)
    vfx.z_index = -1
    add_child(vfx)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(vfx, "modulate:a", 0.0, 0.32)
    tween.tween_property(vfx, "position:y", vfx.position.y - 5.0, 0.32)
    tween.chain().tween_callback(vfx.queue_free)

func _add_body_shape() -> void:
    var collision := CollisionShape2D.new()
    var shape := CapsuleShape2D.new()
    shape.radius = 12.0
    shape.height = 42.0
    collision.shape = shape
    collision.position = Vector2(0.0, -2.0)
    add_child(collision)

func _add_camera() -> void:
    _camera = Camera2D.new()
    _camera.position = Vector2(120.0, -48.0)
    _camera.position_smoothing_enabled = true
    _camera.position_smoothing_speed = 7.0
    _camera.limit_left = 0
    _camera.limit_right = 2400
    _camera.limit_top = 0
    _camera.limit_bottom = 540
    add_child(_camera)

func _add_squash() -> void:
    _squash = SquashStretch.new()
    _squash.target = _rig
    add_child(_squash)

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
    _maximum_mana = int(stats.max_mana)
    _mana = mini(_mana, _maximum_mana)
    if is_instance_valid(_health):
        _health.set_maximum(int(stats.max_health), true)
    resources_changed.emit(get_resource_snapshot())

# Compatibility shims for old tests expecting _coyote_time/_jump_buffer_time
var _coyote_time: float:
    get: return _coyote_left
    set(value): _coyote_left = value
var _jump_buffer_time: float:
    get: return _buffer_left
    set(value): _buffer_left = value

func _jump_pressed_compat() -> bool:
    return _jump_pressed()
