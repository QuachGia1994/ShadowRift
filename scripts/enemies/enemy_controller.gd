extends CharacterBody2D
class_name EnemyController

signal defeated(exp_reward: int, gold_reward: int)
signal death_finished

enum Kind { WARDEN, WRAITH }
enum State { PATROL, AGGRO, ATTACK, HURT, DEATH }

const WARDEN_FRAMES := preload("res://assets/sprites/enemies/warden_frames.tres")
const WRAITH_FRAMES := preload("res://assets/sprites/enemies/wraith_frames.tres")

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
var _sprite: AnimatedSprite2D
var _body_collision: CollisionShape2D
var _facing := 1.0
var _motion_clock := 0.0

func configure(enemy_kind: Kind, hero_target: Hero) -> void:
	kind = enemy_kind
	target = hero_target

func _ready() -> void:
	_anchor_x = global_position.x
	_add_body_shape()
	_add_combat_nodes()
	_add_sprite()

func _physics_process(delta: float) -> void:
	_health.tick(delta)
	_hitbox.tick(delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_motion_clock += delta
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
	_sprite.flip_h = _facing < 0.0
	_apply_animation()
	_apply_visual_motion()

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
	if distance > 430.0 or _target_vertical_distance() > 170.0:
		state = State.PATROL
		return
	var direction := signf(target.global_position.x - global_position.x)
	if direction != 0.0:
		_facing = direction
	if distance <= _attack_range() and _target_vertical_distance() <= _attack_vertical_tolerance() and _attack_cooldown <= 0.0:
		_start_attack(direction)
		return
	velocity.x = direction * _move_speed()
	if kind == Kind.WRAITH and is_on_floor() and distance > 125.0 and distance < 235.0:
		velocity.y = -330.0

func _start_attack(direction: float) -> void:
	state = State.ATTACK
	_facing = direction if direction != 0.0 else _facing
	_attack_time = 0.34 if kind == Kind.WARDEN else 0.25
	_attack_cooldown = 1.0 if kind == Kind.WARDEN else 0.72
	velocity.x = direction * (90.0 if kind == Kind.WARDEN else 175.0)
	var hitbox_offset := 38.0 if kind == Kind.WARDEN else 43.0
	_hitbox.activate(&"enemy_basic", _attack_time * 0.66, Vector2(direction * hitbox_offset, -5.0))

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

func _target_horizontal_distance() -> float:
	return absf(target.global_position.x - global_position.x) if is_instance_valid(target) else INF

func _target_vertical_distance() -> float:
	return absf(target.global_position.y - global_position.y) if is_instance_valid(target) else INF

func _move_speed() -> float:
	return 95.0 if kind == Kind.WARDEN else 150.0

func _attack_range() -> float:
	return 80.0 if kind == Kind.WARDEN else 88.0

func _attack_vertical_tolerance() -> float:
	return 58.0 if kind == Kind.WARDEN else 86.0

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

func _add_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = WARDEN_FRAMES if kind == Kind.WARDEN else WRAITH_FRAMES
	_sprite.centered = false
	# 192px HD cells scaled to the original 64px visual footprint and pivot.
	_sprite.offset = Vector2(-96.0, -126.0)
	_sprite.scale = Vector2(64.0 / 192.0, 64.0 / 192.0)
	add_child(_sprite)
	_sprite.play(&"patrol" if kind == Kind.WARDEN else &"hover")

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
				anim = &"dash_attack"
			State.HURT:
				anim = &"hurt"
			State.DEATH:
				anim = &"death"
	if _sprite.animation != anim:
		_sprite.play(anim)

func _animation_duration(animation: StringName) -> float:
	var fps := maxf(0.01, _sprite.sprite_frames.get_animation_speed(animation))
	return float(_sprite.sprite_frames.get_frame_count(animation)) / fps

func _apply_visual_motion() -> void:
	if not is_instance_valid(_sprite):
		return
	var base_scale := 64.0 / 192.0
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(base_scale, base_scale)
	match state:
		State.PATROL:
			_sprite.position.y = sin(_motion_clock * 8.0) * 1.2
		State.AGGRO:
			_sprite.position.y = sin(_motion_clock * 11.0) * 1.6
			_sprite.rotation = deg_to_rad(1.2 * _facing)
		State.ATTACK:
			_sprite.position.x = 4.0 * _facing
			_sprite.rotation = deg_to_rad(4.5 * _facing)
			_sprite.scale = Vector2(base_scale * 1.04, base_scale * 0.97)
		State.HURT:
			_sprite.position.x = -3.0 * _facing
			_sprite.rotation = deg_to_rad(-3.0 * _facing)
		State.DEATH:
			_sprite.position.y = 2.0
