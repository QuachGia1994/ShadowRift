extends CharacterBody2D
class_name EnemyController

signal defeated(exp_reward: int, gold_reward: int)
signal death_finished

enum Kind { WARDEN, WRAITH }
enum State { PATROL, AGGRO, ATTACK, HURT, DEATH }

var kind := Kind.WARDEN
var state := State.PATROL
var target: Hero
var _anchor_x := 0.0
var _patrol_direction := 1.0
var _attack_cooldown := 0.0
var _attack_time := 0.0
var _attack_fired := false
var _hurt_time := 0.0
var _health: HealthComponent
var _hitbox: Hitbox
var _rig: CharacterMotionRig2D
var _body_collision: CollisionShape2D
var _facing := 1.0

func configure(enemy_kind: Kind, hero_target: Hero) -> void:
	kind = enemy_kind
	target = hero_target

func _ready() -> void:
	_anchor_x = global_position.x
	_add_body_shape()
	_add_combat_nodes()
	_add_visual_rig()
	if is_instance_valid(target):
		add_collision_exception_with(target)
		target.add_collision_exception_with(self)

func _physics_process(delta: float) -> void:
	_health.tick(delta)
	_hitbox.tick(delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	match state:
		State.PATROL:
			_update_patrol(delta)
		State.AGGRO:
			_update_aggro(delta)
		State.ATTACK:
			_update_attack(delta)
		State.HURT:
			_update_hurt(delta)
		State.DEATH:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	move_and_slide()
	visible = not _health.is_invulnerable() or int(Time.get_ticks_msec() / 60) % 2 == 0
	if is_instance_valid(_rig):
		_rig.set_facing(_facing)
	_apply_animation()

func get_attack_power() -> int:
	return 17 if kind == Kind.WARDEN else 13

func get_defense() -> int:
	return 9 if kind == Kind.WARDEN else 3

func receive_canonical_hit(amount: int, knockback: Vector2) -> bool:
	return _health.apply_canonical_damage(amount, knockback)

func _update_patrol(_delta: float) -> void:
	if _target_horizontal_distance() < 300.0 and _target_vertical_distance() < 130.0:
		state = State.AGGRO
		return
	if absf(global_position.x - _anchor_x) > 105.0:
		_patrol_direction = -signf(global_position.x - _anchor_x)
	_facing = _patrol_direction
	velocity.x = _patrol_direction * _move_speed() * 0.42

func _update_aggro(_delta: float) -> void:
	if not is_instance_valid(target):
		state = State.PATROL
		return
	var distance := _target_horizontal_distance()
	if distance > 480.0 or _target_vertical_distance() > 190.0:
		state = State.PATROL
		return
	var direction := signf(target.global_position.x - global_position.x)
	if direction != 0.0:
		_facing = direction
	if kind == Kind.WRAITH:
		_update_wraith_aggro(distance, direction)
		return
	if distance <= _attack_range() and _target_vertical_distance() <= _attack_vertical_tolerance() and _attack_cooldown <= 0.0:
		_start_attack(direction)
		return
	if distance < 70.0 and _attack_cooldown > 0.0:
		velocity.x = -direction * 72.0
	else:
		velocity.x = direction * _move_speed()

func _update_wraith_aggro(distance: float, direction: float) -> void:
	# Ranged caster spacing: retreat if crowded, approach only until a readable
	# casting band, then hold position and telegraph the bolt.
	if distance < 165.0:
		velocity.x = -direction * 145.0
		return
	if distance > 350.0:
		velocity.x = direction * 118.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 520.0 * get_physics_process_delta_time())
	if distance <= 430.0 and _target_vertical_distance() <= 180.0 and _attack_cooldown <= 0.0:
		_start_wraith_cast(direction)

func _start_attack(direction: float) -> void:
	state = State.ATTACK
	_facing = direction if direction != 0.0 else _facing
	_attack_time = 0.34
	_attack_cooldown = 1.15
	_attack_fired = true
	velocity.x = direction * 90.0
	_hitbox.activate(&"enemy_basic", _attack_time * 0.66, Vector2(direction * 38.0, -5.0))

func _start_wraith_cast(direction: float) -> void:
	state = State.ATTACK
	_facing = direction if direction != 0.0 else _facing
	_attack_time = 0.72
	_attack_cooldown = 1.55
	_attack_fired = false
	velocity.x = 0.0

func _fire_wraith_bolt() -> void:
	if _attack_fired or not is_instance_valid(target):
		return
	_attack_fired = true
	var pool := get_tree().get_first_node_in_group("projectile_pool") as ReusablePool
	if not is_instance_valid(pool):
		return
	var projectile := pool.acquire() as PooledProjectile
	projectile.activate_homing(self, global_position + Vector2(_facing * 28.0, -22.0), target, &"wraith_bolt")

func _update_attack(delta: float) -> void:
	_attack_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
	if kind == Kind.WRAITH and not _attack_fired and _attack_time <= 0.18:
		_fire_wraith_bolt()
	if _attack_time <= 0.0:
		state = State.AGGRO

func _update_hurt(delta: float) -> void:
	_hurt_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 430.0 * delta)
	if _hurt_time <= 0.0:
		state = State.AGGRO

func _target_horizontal_distance() -> float:
	return absf(target.global_position.x - global_position.x) if is_instance_valid(target) else INF

func _target_vertical_distance() -> float:
	return absf(target.global_position.y - global_position.y) if is_instance_valid(target) else INF

func _move_speed() -> float:
	return 95.0 if kind == Kind.WARDEN else 150.0

func _attack_range() -> float:
	return 80.0 if kind == Kind.WARDEN else 430.0

func _attack_vertical_tolerance() -> float:
	return 58.0 if kind == Kind.WARDEN else 180.0

func _on_damaged(_amount: int, knockback: Vector2) -> void:
	state = State.HURT
	_hurt_time = 0.24
	velocity = knockback * (0.65 if kind == Kind.WARDEN else 1.0)

func _on_depleted() -> void:
	if state == State.DEATH:
		return
	state = State.DEATH
	velocity = Vector2.ZERO
	_hitbox.monitoring = false
	if is_instance_valid(_body_collision):
		_body_collision.set_deferred("disabled", true)
	_apply_animation()
	defeated.emit(24 if kind == Kind.WARDEN else 18, 7 if kind == Kind.WARDEN else 5)
	var death_duration := _animation_duration(&"death")
	var tween := create_tween()
	tween.tween_interval(death_duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void: death_finished.emit())
	tween.tween_callback(queue_free)

func _add_body_shape() -> void:
	_body_collision = CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 13.0
	shape.height = 48.0
	_body_collision.shape = shape
	_body_collision.position = Vector2(0.0, -4.0)
	add_child(_body_collision)

func _add_combat_nodes() -> void:
	_health = HealthComponent.new()
	_health.configure(105 if kind == Kind.WARDEN else 68, 0.32)
	_health.damaged.connect(_on_damaged)
	_health.depleted.connect(_on_depleted)
	add_child(_health)
	var hurtbox := Hurtbox.new()
	hurtbox.configure(self, Vector2(34.0, 50.0))
	hurtbox.position = Vector2(0.0, -5.0)
	add_child(hurtbox)
	_hitbox = Hitbox.new()
	_hitbox.configure(self, Vector2(52.0, 42.0) if kind == Kind.WARDEN else Vector2(56.0, 42.0))
	add_child(_hitbox)

func _add_visual_rig() -> void:
	_rig = CharacterMotionRig2D.new()
	_rig.configure(&"warden" if kind == Kind.WARDEN else &"wraith")
	add_child(_rig)

func _apply_animation() -> void:
	var anim := &"patrol"
	if kind == Kind.WARDEN:
		match state:
			State.PATROL:
				anim = &"patrol"
			State.AGGRO:
				anim = &"aggro"
			State.ATTACK:
				anim = &"attack"
			State.HURT:
				anim = &"hurt"
			State.DEATH:
				anim = &"death"
	else:
		match state:
			State.PATROL, State.AGGRO:
				anim = &"hover"
			State.ATTACK:
				anim = &"cast"
			State.HURT:
				anim = &"hurt"
			State.DEATH:
				anim = &"death"
	if is_instance_valid(_rig):
		var speed := 1.0
		if state in [State.PATROL, State.AGGRO]:
			speed = clampf(absf(velocity.x) / maxf(1.0, _move_speed()), 0.72, 1.35)
		_rig.play(anim, speed)

func _animation_duration(animation: StringName) -> float:
	return _rig.get_animation_duration(animation) if is_instance_valid(_rig) else 0.7

func get_facing() -> float:
	return _facing
