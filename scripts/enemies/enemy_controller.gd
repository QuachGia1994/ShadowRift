extends CharacterBody2D
class_name EnemyController

signal defeated(exp_reward: int, gold_reward: int)

enum Kind { WARDEN, WRAITH }
enum State { PATROL, AGGRO, ATTACK, HURT, DEATH }

var kind := Kind.WARDEN
var state := State.PATROL
var target: Hero
var _anchor_x := 0.0
var _patrol_direction := 1.0
var _attack_cooldown := 0.0
var _attack_time := 0.0
var _hurt_time := 0.0
var _health: HealthComponent
var _hitbox: Hitbox

func configure(enemy_kind: Kind, hero_target: Hero) -> void:
	kind = enemy_kind
	target = hero_target

func _ready() -> void:
	_anchor_x = global_position.x
	_add_body_shape()
	_add_combat_nodes()
	queue_redraw()

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
	queue_redraw()

func get_attack_power() -> int:
	return 17 if kind == Kind.WARDEN else 13

func get_defense() -> int:
	return 9 if kind == Kind.WARDEN else 3

func receive_canonical_hit(amount: int, knockback: Vector2) -> bool:
	return _health.apply_canonical_damage(amount, knockback)

func _update_patrol(_delta: float) -> void:
	if _target_distance() < 300.0:
		state = State.AGGRO
		return
	if absf(global_position.x - _anchor_x) > 105.0:
		_patrol_direction = -signf(global_position.x - _anchor_x)
	velocity.x = _patrol_direction * _move_speed() * 0.42

func _update_aggro(_delta: float) -> void:
	if not is_instance_valid(target):
		state = State.PATROL
		return
	var distance := _target_distance()
	if distance > 430.0:
		state = State.PATROL
		return
	var direction := signf(target.global_position.x - global_position.x)
	if distance <= _attack_range() and _attack_cooldown <= 0.0:
		_start_attack(direction)
		return
	velocity.x = direction * _move_speed()
	if kind == Kind.WRAITH and is_on_floor() and distance > 125.0 and distance < 235.0:
		velocity.y = -330.0

func _start_attack(direction: float) -> void:
	state = State.ATTACK
	_attack_time = 0.34 if kind == Kind.WARDEN else 0.25
	_attack_cooldown = 1.0 if kind == Kind.WARDEN else 0.72
	velocity.x = direction * (80.0 if kind == Kind.WARDEN else 160.0)
	_hitbox.activate(&"enemy_basic", _attack_time * 0.66, Vector2(direction * 31.0, -5.0))

func _update_attack(delta: float) -> void:
	_attack_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
	if _attack_time <= 0.0:
		state = State.AGGRO

func _update_hurt(delta: float) -> void:
	_hurt_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 430.0 * delta)
	if _hurt_time <= 0.0:
		state = State.AGGRO

func _target_distance() -> float:
	return global_position.distance_to(target.global_position) if is_instance_valid(target) else INF

func _move_speed() -> float:
	return 95.0 if kind == Kind.WARDEN else 150.0

func _attack_range() -> float:
	return 66.0 if kind == Kind.WARDEN else 76.0

func _on_damaged(_amount: int, knockback: Vector2) -> void:
	state = State.HURT
	_hurt_time = 0.24
	velocity = knockback * (0.65 if kind == Kind.WARDEN else 1.0)

func _on_depleted() -> void:
	if state == State.DEATH:
		return
	state = State.DEATH
	_hitbox.monitoring = false
	defeated.emit(24 if kind == Kind.WARDEN else 18, 7 if kind == Kind.WARDEN else 5)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

func _add_body_shape() -> void:
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 13.0
	shape.height = 48.0
	collision.shape = shape
	collision.position = Vector2(0.0, -4.0)
	add_child(collision)

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
	_hitbox.configure(self, Vector2(42.0, 38.0))
	add_child(_hitbox)

func _draw() -> void:
	var pulse := (sin(float(Time.get_ticks_msec()) * 0.008) + 1.0) * 0.5
	if kind == Kind.WARDEN:
		draw_colored_polygon(PackedVector2Array([Vector2(-24.0, 19.0), Vector2(24.0, 19.0), Vector2(17.0, 24.0), Vector2(-17.0, 24.0)]), Color(0.0, 0.0, 0.0, 0.28))
		draw_colored_polygon(PackedVector2Array([Vector2(-17.0, -27.0), Vector2(17.0, -27.0), Vector2(20.0, 14.0), Vector2(-20.0, 14.0)]), Color(0.08, 0.10, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(-13.0, -24.0), Vector2(13.0, -24.0), Vector2(15.0, 12.0), Vector2(-15.0, 12.0)]), Color(0.23, 0.25, 0.31))
		draw_rect(Rect2(-19.0, -38.0, 38.0, 11.0), Color(0.42, 0.08, 0.13))
		draw_colored_polygon(PackedVector2Array([Vector2(-14.0, -39.0), Vector2(0.0, -49.0), Vector2(14.0, -39.0)]), Color(0.16, 0.17, 0.22))
		draw_circle(Vector2(7.0, -32.0), 2.4 + pulse * 0.7, Color(0.98, 0.18, 0.22, 0.95))
		draw_line(Vector2(-25.0, -14.0), Vector2(24.0, 13.0), Color(0.74, 0.78, 0.82), 5.0)
		draw_line(Vector2(-27.0, -16.0), Vector2(-20.0, -20.0), Color(0.93, 0.79, 0.48), 3.0)
	else:
		var float_offset := sin(float(Time.get_ticks_msec()) * 0.006) * 3.0
		draw_circle(Vector2(0.0, 13.0), 25.0, Color(0.23, 0.68, 0.78, 0.035 + pulse * 0.025))
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -42.0 + float_offset), Vector2(19.0, -13.0 + float_offset), Vector2(13.0, 20.0 + float_offset), Vector2(0.0, 14.0 + float_offset), Vector2(-15.0, 21.0 + float_offset), Vector2(-20.0, -13.0 + float_offset)]), Color(0.24, 0.11, 0.35, 0.94))
		draw_arc(Vector2(0.0, -9.0 + float_offset), 20.0, 0.0, TAU, 24, Color(0.30, 0.78, 0.88, 0.45 + pulse * 0.18), 3.0)
		draw_circle(Vector2(5.0, -22.0 + float_offset), 3.0, Color(0.48, 0.94, 1.0))
		draw_circle(Vector2(5.0, -22.0 + float_offset), 7.0, Color(0.36, 0.82, 0.94, 0.10))
