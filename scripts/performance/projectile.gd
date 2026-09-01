extends Area2D
class_name PooledProjectile

const MAX_LIFETIME := 1.6
const SPEED := 470.0

var actor: Node2D
var attack_kind := &"skill_two"
var _direction := 1.0
var _remaining := 0.0
var _hit_ids: Dictionary = {}

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	add_child(collision)
	area_entered.connect(_on_area_entered)

func activate(source: Node2D, origin: Vector2, direction: float, kind: StringName = &"skill_two") -> void:
	actor = source
	global_position = origin
	_direction = signf(direction) if direction != 0.0 else 1.0
	attack_kind = kind
	_remaining = MAX_LIFETIME
	_hit_ids.clear()
	monitoring = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position.x += SPEED * _direction * delta
	_remaining -= delta
	if _remaining <= 0.0:
		deactivate()

func deactivate() -> void:
	monitoring = false
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

func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(0.20, 0.68, 0.96, 0.84))
	draw_circle(Vector2.ZERO, 6.0, Color(0.72, 0.94, 1.0))
	draw_line(Vector2(-24.0 * _direction, 0.0), Vector2(-8.0 * _direction, 0.0), Color(0.19, 0.44, 0.88, 0.68), 7.0)
