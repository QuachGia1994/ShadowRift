extends CharacterBody2D
class_name BossController

signal health_changed(current: int, maximum: int)
signal defeated(exp_reward: int, gold_reward: int)

enum State { WATCH, CHASE, WINDUP, STRIKE, HURT, DEATH }

var state := State.WATCH
var target: Hero
var _health: HealthComponent
var _hitbox: Hitbox
var _state_time := 0.0
var _attack_cooldown := 0.0
var _attack_direction := -1.0
var server_entity_id := "boss-1"
var _server_authority_enabled := OS.has_feature("server_authoritative")

func configure(hero_target: Hero) -> void:
	target = hero_target

func _ready() -> void:
	_add_body_shape()
	_add_combat_nodes()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _server_authority_enabled:
		return
	_health.tick(delta)
	_hitbox.tick(delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_state_time = maxf(0.0, _state_time - delta)
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	match state:
		State.WATCH:
			if _distance_to_target() < 520.0:
				state = State.CHASE
		State.CHASE:
			_update_chase()
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
			if _state_time <= 0.0:
				_start_strike()
		State.STRIKE:
			if _state_time <= 0.0:
				state = State.CHASE
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
			if _state_time <= 0.0:
				state = State.CHASE
		State.DEATH:
			velocity.x = 0.0
	move_and_slide()
	visible = not _health.is_invulnerable() or int(Time.get_ticks_msec() / 65) % 2 == 0
	queue_redraw()

func get_attack_power() -> int:
	return 25

func get_defense() -> int:
	return 13

func receive_authoritative_hit(amount: int, knockback: Vector2) -> bool:
	if _server_authority_enabled:
		return false
	return _health.apply_authoritative_damage(amount, knockback * 0.35)

func get_health_snapshot() -> Vector2i:
	return Vector2i(_health.current, _health.maximum)

func apply_server_snapshot(snapshot: Dictionary) -> void:
	if not _server_authority_enabled:
		return
	global_position.x = float(snapshot.get("x", global_position.x))
	_health.set_maximum(int(snapshot.get("maxHp", 1)), false)
	_health.set_current(int(snapshot.get("hp", 0)))
	var alive := bool(snapshot.get("alive", false))
	state = State.WATCH if alive else State.DEATH
	visible = alive
	process_mode = Node.PROCESS_MODE_INHERIT if alive else Node.PROCESS_MODE_DISABLED
	health_changed.emit(_health.current, _health.maximum)
	queue_redraw()

func _update_chase() -> void:
	if not is_instance_valid(target):
		state = State.WATCH
		return
	_attack_direction = signf(target.global_position.x - global_position.x)
	var distance := _distance_to_target()
	if distance <= 92.0 and _attack_cooldown <= 0.0:
		state = State.WINDUP
		_state_time = 0.46
		velocity.x = 0.0
		return
	velocity.x = _attack_direction * 105.0

func _start_strike() -> void:
	state = State.STRIKE
	_state_time = 0.36
	_attack_cooldown = 1.35
	velocity.x = _attack_direction * 265.0
	_hitbox.activate(&"boss_basic", 0.26, Vector2(_attack_direction * 45.0, -3.0))

func _distance_to_target() -> float:
	return global_position.distance_to(target.global_position) if is_instance_valid(target) else INF

func _on_health_changed(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)

func _on_damaged(_amount: int, knockback: Vector2) -> void:
	if state in [State.WATCH, State.CHASE]:
		state = State.HURT
		_state_time = 0.16
		velocity = knockback

func _on_depleted() -> void:
	if state == State.DEATH:
		return
	state = State.DEATH
	_hitbox.monitoring = false
	defeated.emit(120, 60)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.32, 0.06, 0.12, 0.0), 0.75)
	tween.tween_callback(queue_free)

func _add_body_shape() -> void:
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 23.0
	shape.height = 76.0
	collision.shape = shape
	collision.position = Vector2(0.0, -13.0)
	add_child(collision)

func _add_combat_nodes() -> void:
	_health = HealthComponent.new()
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_health.depleted.connect(_on_depleted)
	_health.configure(420, 0.24)
	add_child(_health)
	var hurtbox := Hurtbox.new()
	hurtbox.configure(self, Vector2(54.0, 74.0))
	hurtbox.position = Vector2(0.0, -12.0)
	add_child(hurtbox)
	_hitbox = Hitbox.new()
	_hitbox.configure(self, Vector2(62.0, 58.0))
	add_child(_hitbox)

func _draw() -> void:
	var pulse := (sin(float(Time.get_ticks_msec()) * 0.006) + 1.0) * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(-42.0, 27.0), Vector2(42.0, 27.0), Vector2(30.0, 34.0), Vector2(-30.0, 34.0)]), Color(0.0, 0.0, 0.0, 0.34))
	draw_circle(Vector2.ZERO, 54.0, Color(0.62, 0.08, 0.20, 0.025 + pulse * 0.025))
	draw_colored_polygon(PackedVector2Array([Vector2(-31.0, 23.0), Vector2(-25.0, -39.0), Vector2(0.0, -59.0), Vector2(27.0, -38.0), Vector2(32.0, 23.0)]), Color(0.10, 0.075, 0.14))
	draw_colored_polygon(PackedVector2Array([Vector2(-25.0, 18.0), Vector2(-19.0, -34.0), Vector2(0.0, -49.0), Vector2(20.0, -33.0), Vector2(26.0, 18.0)]), Color(0.20, 0.11, 0.19))
	draw_colored_polygon(PackedVector2Array([Vector2(-24.0, -37.0), Vector2(-47.0, -58.0), Vector2(-21.0, -50.0)]), Color(0.46, 0.09, 0.16))
	draw_colored_polygon(PackedVector2Array([Vector2(24.0, -37.0), Vector2(47.0, -58.0), Vector2(21.0, -50.0)]), Color(0.46, 0.09, 0.16))
	draw_circle(Vector2(-8.0, -30.0), 3.2 + pulse * 0.8, Color(0.98, 0.12, 0.24))
	draw_circle(Vector2(8.0, -30.0), 3.2 + pulse * 0.8, Color(0.98, 0.12, 0.24))
	draw_line(Vector2(-23.0, -4.0), Vector2(-38.0, 17.0), Color(0.52, 0.16, 0.22), 7.0)
	draw_line(Vector2(23.0, -4.0), Vector2(38.0, 17.0), Color(0.52, 0.16, 0.22), 7.0)
	if state == State.WINDUP:
		draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 36, Color(0.90, 0.12, 0.28, 0.82), 5.0)
		draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 36, Color(0.70, 0.18, 0.50, 0.25), 3.0)
	elif state == State.STRIKE:
		draw_arc(Vector2(_attack_direction * 24.0, -4.0), 42.0, -1.1 if _attack_direction > 0.0 else 2.0, 1.15 if _attack_direction > 0.0 else 4.3, 24, Color(1.0, 0.28, 0.34, 0.82), 7.0)
