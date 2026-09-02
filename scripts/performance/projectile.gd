extends Area2D
class_name PooledProjectile

const MAX_LIFETIME := 1.6
const SPEED := 470.0
const WRAITH_LIFETIME := 2.4
const WRAITH_SPEED := 360.0
const HOMING_RESPONSE := 7.0
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
	var launch_direction := Vector2.RIGHT
	if is_instance_valid(_target):
		launch_direction = global_position.direction_to(_target.global_position)
	elif source.has_method("get_facing"):
		launch_direction.x = float(source.call("get_facing"))
	_velocity = launch_direction.normalized() * (WRAITH_SPEED * 0.72)
	_sprite.texture = WRAITH_TEXTURE
	_sprite.flip_h = false
	_sprite.rotation = _velocity.angle()
	monitoring = true

func _physics_process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	if _homing and is_instance_valid(_target) and _target.is_inside_tree():
		# GDQuest donor pattern: desired target velocity plus a damped steering
		# change. The exponential response makes the turn rate frame-rate safe.
		var desired_velocity := global_position.direction_to(_target.global_position) * WRAITH_SPEED
		var steering := 1.0 - exp(-HOMING_RESPONSE * delta)
		_velocity = _velocity.lerp(desired_velocity, steering)
	global_position += _velocity * delta
	if _homing and _velocity.length_squared() > 1.0:
		_sprite.rotation = _velocity.angle()
	_remaining -= delta
	if _remaining <= 0.0:
		deactivate()

func deactivate() -> void:
	monitoring = false
	_target = null
	_homing = false
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
		deactivate()

