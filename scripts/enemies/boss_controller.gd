extends CharacterBody2D
class_name BossController

signal health_changed(current: int, maximum: int)
signal defeated(exp_reward: int, gold_reward: int)
signal death_finished

enum State { WATCH, CHASE, WINDUP, STRIKE, HURT, DEATH }

const STRIKE_VFX := preload("res://assets/vfx/slash_2.png")

var state := State.WATCH
var target: Hero
var _health: HealthComponent
var _hitbox: Hitbox
var _state_time := 0.0
var _attack_cooldown := 0.0
var _attack_direction := -1.0
var _rig: CharacterMotionRig2D
var _body_collision: CollisionShape2D

func configure(hero_target: Hero) -> void:
	target = hero_target

func _ready() -> void:
	_add_body_shape()
	_add_combat_nodes()
	_add_visual_rig()

func _physics_process(delta: float) -> void:
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
	if is_instance_valid(_rig):
		_rig.set_facing(_attack_direction)
	_apply_animation()

func get_attack_power() -> int:
	return 25

func get_defense() -> int:
	return 13

func receive_canonical_hit(amount: int, knockback: Vector2) -> bool:
	return _health.apply_canonical_damage(amount, knockback * 0.35)

func get_health_snapshot() -> Vector2i:
	return Vector2i(_health.current, _health.maximum)

func _update_chase() -> void:
	if not is_instance_valid(target):
		state = State.WATCH
		return
	_attack_direction = signf(target.global_position.x - global_position.x)
	var distance := _horizontal_distance_to_target()
	if distance <= 114.0 and _vertical_distance_to_target() <= 76.0 and _attack_cooldown <= 0.0:
		state = State.WINDUP
		_state_time = 0.46
		velocity.x = 0.0
		return
	velocity.x = _attack_direction * 105.0

func _start_strike() -> void:
	state = State.STRIKE
	_state_time = 0.38
	_attack_cooldown = 1.35
	velocity.x = _attack_direction * 275.0
	_hitbox.activate(&"boss_basic", 0.28, Vector2(_attack_direction * 58.0, -3.0))
	_spawn_strike_vfx()

func _distance_to_target() -> float:
	return global_position.distance_to(target.global_position) if is_instance_valid(target) else INF

func _horizontal_distance_to_target() -> float:
	return absf(target.global_position.x - global_position.x) if is_instance_valid(target) else INF

func _vertical_distance_to_target() -> float:
	return absf(target.global_position.y - global_position.y) if is_instance_valid(target) else INF

func _on_health_changed(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)

func _on_damaged(_amount: int, knockback: Vector2) -> void:
	if state in [State.WATCH, State.CHASE]:
		state = State.HURT
		_state_time = 0.25
		velocity = knockback

func _on_depleted() -> void:
	if state == State.DEATH:
		return
	state = State.DEATH
	velocity = Vector2.ZERO
	_hitbox.monitoring = false
	if is_instance_valid(_body_collision):
		_body_collision.set_deferred("disabled", true)
	_apply_animation()
	defeated.emit(120, 60)
	var death_duration := _animation_duration(&"death")
	var tween := create_tween()
	tween.tween_interval(death_duration)
	tween.tween_property(self, "modulate", Color(0.32, 0.06, 0.12, 0.0), 0.22)
	tween.tween_callback(func() -> void: death_finished.emit())
	tween.tween_callback(queue_free)

func _add_body_shape() -> void:
	_body_collision = CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 23.0
	shape.height = 76.0
	_body_collision.shape = shape
	_body_collision.position = Vector2(0.0, -13.0)
	add_child(_body_collision)

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
	_hitbox.configure(self, Vector2(84.0, 64.0))
	add_child(_hitbox)

func _add_visual_rig() -> void:
	_rig = CharacterMotionRig2D.new()
	_rig.configure(&"boss")
	add_child(_rig)

func _apply_animation() -> void:
	var anim := &"watch"
	match state:
		State.WATCH:
			anim = &"watch"
		State.CHASE:
			anim = &"chase"
		State.WINDUP:
			anim = &"windup"
		State.STRIKE:
			anim = &"strike"
		State.HURT:
			anim = &"hurt"
		State.DEATH:
			anim = &"death"
	if is_instance_valid(_rig):
		var speed := clampf(absf(velocity.x) / 105.0, 0.72, 1.28) if state == State.CHASE else 1.0
		_rig.play(anim, speed)

func _animation_duration(animation: StringName) -> float:
	return _rig.get_animation_duration(animation) if is_instance_valid(_rig) else 1.0

func _spawn_strike_vfx() -> void:
	var vfx := Sprite2D.new()
	vfx.texture = STRIKE_VFX
	vfx.position = Vector2(_attack_direction * 40.0, -6.0)
	vfx.flip_h = _attack_direction < 0.0
	vfx.z_index = 1
	add_child(vfx)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(vfx, "modulate:a", 0.0, 0.3)
	tween.tween_property(vfx, "scale", Vector2(1.5, 1.5), 0.3)
	tween.chain().tween_callback(vfx.queue_free)
