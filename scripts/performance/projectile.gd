extends Area2D
class_name PooledProjectile

const MAX_LIFETIME := 1.6
const SPEED := 470.0
const WRAITH_LIFETIME := 1.85
const WRAITH_SPEED := 285.0
const WRAITH_HOMING_TIME := 0.38
const WRAITH_MAX_TURN_RATE := 105.0 * PI / 180.0
const PROJECTILE_TEXTURE := preload("res://assets/vfx/skill_two_projectile.png")
const WRAITH_TEXTURE := preload("res://assets/vfx/wraith_bolt.png")

var actor: Node2D
var attack_kind := &"skill_two"
var _direction := 1.0
var _remaining := 0.0
var _hit_ids: Dictionary = {}
var _sprite: Sprite2D
var _velocity := Vector2.ZERO
var _target: Node2D
var _homing := false
var _homing_remaining := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	add_child(collision)
	_sprite = Sprite2D.new()
	_sprite.texture = PROJECTILE_TEXTURE
	add_child(_sprite)
	area_entered.connect(_on_area_entered)

func activate(source: Node2D, origin: Vector2, direction: float, kind: StringName = &"skill_two") -> void:
	actor = source
	global_position = origin
	_direction = signf(direction) if direction != 0.0 else 1.0
	attack_kind = kind
	_remaining = MAX_LIFETIME
	_hit_ids.clear()
	_target = null
	_homing = false
	_homing_remaining = 0.0
	_velocity = Vector2(SPEED * _direction, 0.0)
	_sprite.texture = PROJECTILE_TEXTURE
	_sprite.flip_h = _direction < 0.0
	_sprite.rotation = 0.0
	monitoring = true

func activate_homing(source: Node2D, origin: Vector2, homing_target: Node2D, kind: StringName = &"wraith_bolt") -> void:
	actor = source
	global_position = origin
	attack_kind = kind
	_remaining = WRAITH_LIFETIME
	_hit_ids.clear()
	_target = homing_target
	_homing = true
	_homing_remaining = WRAITH_HOMING_TIME
	var launch_direction := Vector2.RIGHT
	if is_instance_valid(_target):
		launch_direction = global_position.direction_to(_target.global_position)
	elif source.has_method("get_facing"):
		launch_direction.x = float(source.call("get_facing"))
	_velocity = launch_direction.normalized() * WRAITH_SPEED
	_sprite.texture = WRAITH_TEXTURE
	_sprite.flip_h = false
	_sprite.rotation = _velocity.angle()
	monitoring = true

func _physics_process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	if _homing and _homing_remaining > 0.0 and is_instance_valid(_target) and _target.is_inside_tree():
		# Keep the donor's target-seeking idea, but cap angular velocity and only
		# steer briefly after launch. The bolt then commits to a ballistic line,
		# so a touch player can sidestep/jump it instead of being chased forever.
		var desired_angle := global_position.direction_to(_target.global_position).angle()
		var current_angle := _velocity.angle()
		var angle_delta := wrapf(desired_angle - current_angle, -PI, PI)
		var max_step := WRAITH_MAX_TURN_RATE * delta
		current_angle += clampf(angle_delta, -max_step, max_step)
		_velocity = Vector2.RIGHT.rotated(current_angle) * WRAITH_SPEED
		_homing_remaining = maxf(0.0, _homing_remaining - delta)
		if _homing_remaining <= 0.0:
			_homing = false
			_target = null
	global_position += _velocity * delta
	if _velocity.length_squared() > 1.0:
		_sprite.rotation = _velocity.angle()
	_remaining -= delta
	if _remaining <= 0.0:
		deactivate()

func deactivate() -> void:
	monitoring = false
	_target = null
	_homing = false
	_homing_remaining = 0.0
	_velocity = Vector2.ZERO
	_remaining = 0.0
	var pool := get_parent() as ReusablePool
	if is_instance_valid(pool):
		pool.release(self)

func _on_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var hurtbox := area as Hurtbox
	if not is_instance_valid(hurtbox.actor) or hurtbox.actor == actor:
		return
	var target_id := hurtbox.actor.get_instance_id()
	if _hit_ids.has(target_id):
		return
	_hit_ids[target_id] = true
	var authority := get_tree().get_first_node_in_group("combat_authority") as CombatAuthority
	if is_instance_valid(authority) and authority.resolve_projectile_hit(actor, hurtbox.actor, attack_kind):
		# Area callbacks run while physics queries are being flushed. Stop the
		# projectile immediately, but defer changing monitoring/pool state until
		# the callback has unwound.
		_remaining = 0.0
		set_deferred("monitoring", false)
		call_deferred("deactivate")

