extends Area2D
class_name Hurtbox

var actor: Node2D

func configure(owner_actor: Node2D, shape_size: Vector2) -> void:
	actor = owner_actor
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = shape_size
	collision.shape = shape
	add_child(collision)

