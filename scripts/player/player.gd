extends CharacterBody2D
class_name Hero

signal attack_requested(combo_step: int)
signal state_changed(previous: State, current: State)

enum State { IDLE, MOVE, JUMP, ATTACK, HURT, DEATH }

const MOVE_SPEED := 250.0
const JUMP_SPEED := -520.0
const ATTACK_DURATION := 0.22
const COMBO_GRACE := 0.34

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

func _ready() -> void:
	_controls = get_tree().get_first_node_in_group("mobile_controls") as MobileControls
	_add_body_shape()
	_add_combat_nodes()
	_add_camera()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _dead:
		_health.tick(delta)
		velocity.y += get_gravity().y * delta
		move_and_slide()
		return
	_combo_grace = maxf(0.0, _combo_grace - delta)
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
	return 24

func get_defense() -> int:
	return 8

func receive_authoritative_hit(amount: int, knockback: Vector2) -> bool:
	return _health.apply_authoritative_damage(amount, knockback)

func _start_attack() -> void:
	_combo_step = 1 if _combo_grace <= 0.0 else 2
	_attack_time = ATTACK_DURATION
	velocity.x *= 0.25
	_set_state(State.ATTACK)
	var attack_kind := &"basic_one" if _combo_step == 1 else &"basic_two"
	_hitbox.activate(attack_kind, ATTACK_DURATION * 0.72, Vector2(34.0 * facing, -5.0))
	attack_requested.emit(_combo_step)
	queue_redraw()

func _update_attack(delta: float) -> void:
	_attack_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _attack_time <= 0.0:
		_combo_grace = COMBO_GRACE
		_set_state(State.JUMP if not is_on_floor() else State.IDLE)

func _update_hurt(delta: float) -> void:
	_hurt_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 520.0 * delta)
	if _hurt_time <= 0.0:
		_set_state(State.JUMP if not is_on_floor() else State.IDLE)

func _attack_pressed() -> bool:
	return Input.is_key_pressed(KEY_J) or (is_instance_valid(_controls) and _controls.consume_action(&"attack"))

func _jump_pressed() -> bool:
	return Input.is_key_pressed(KEY_SPACE)

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
	_health.configure(140, 0.55)
	_health.damaged.connect(apply_hurt)
	_health.depleted.connect(die)
	add_child(_health)
	var hurtbox := Hurtbox.new()
	hurtbox.configure(self, Vector2(30.0, 46.0))
	hurtbox.position = Vector2(0.0, -3.0)
	add_child(hurtbox)
	_hitbox = Hitbox.new()
	_hitbox.configure(self, Vector2(46.0, 42.0))
	add_child(_hitbox)

func _draw() -> void:
	var body_color := Color(0.18, 0.23, 0.34) if state != State.HURT else Color(0.92, 0.32, 0.34)
	draw_rect(Rect2(-14.0, -23.0, 28.0, 40.0), body_color)
	draw_rect(Rect2(-11.0, -39.0, 22.0, 18.0), Color(0.72, 0.36, 0.20))
	draw_polygon(PackedVector2Array([Vector2(-12.0, -20.0), Vector2(-31.0 * facing, 2.0), Vector2(-9.0, 11.0)]), PackedColorArray([Color(0.42, 0.08, 0.12)]))
	var eye_x := 6.0 * facing
	draw_rect(Rect2(eye_x - 2.0, -33.0, 4.0, 3.0), Color(1.0, 0.76, 0.31))
	if state == State.ATTACK:
		draw_arc(Vector2(18.0 * facing, -5.0), 25.0, -1.2 if facing > 0.0 else 1.9, 1.2 if facing > 0.0 else 4.3, 16, Color(0.95, 0.79, 0.42), 5.0)
