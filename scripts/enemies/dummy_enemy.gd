extends CharacterBody2D
class_name DummyEnemy

var _health: HealthComponent
var _hurtbox: Hurtbox

func _ready() -> void:
	_add_body_shape()
	_health = HealthComponent.new()
	_health.configure(80, 0.32)
	_health.damaged.connect(_on_damaged)
	_health.depleted.connect(_on_depleted)
	add_child(_health)
	_hurtbox = Hurtbox.new()
	_hurtbox.configure(self, Vector2(34.0, 54.0))
	_hurtbox.position = Vector2(0.0, -7.0)
	add_child(_hurtbox)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_health.tick(delta)
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	velocity.x = move_toward(velocity.x, 0.0, 760.0 * delta)
	move_and_slide()
	visible = not _health.is_invulnerable() or int(Time.get_ticks_msec() / 55) % 2 == 0

func get_defense() -> int:
	return 5

func receive_authoritative_hit(amount: int, knockback: Vector2) -> bool:
	return _health.apply_authoritative_damage(amount, knockback)

func _on_damaged(_amount: int, knockback: Vector2) -> void:
	velocity = knockback

func _on_depleted() -> void:
	queue_free()

func _add_body_shape() -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30.0, 52.0)
	collision.shape = shape
	collision.position = Vector2(0.0, -7.0)
	add_child(collision)

func _draw() -> void:
	draw_rect(Rect2(-15.0, -33.0, 30.0, 52.0), Color(0.25, 0.21, 0.29))
	draw_rect(Rect2(-18.0, -38.0, 36.0, 9.0), Color(0.48, 0.14, 0.19))
	draw_circle(Vector2(-6.0, -20.0), 2.5, Color(0.95, 0.34, 0.24))
	draw_circle(Vector2(6.0, -20.0), 2.5, Color(0.95, 0.34, 0.24))

