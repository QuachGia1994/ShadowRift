extends Area2D
class_name Hazard

const DAMAGE := 18

func configure(hazard_size: Vector2) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = hazard_size
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body is Hero:
		return
	var authority := get_tree().get_first_node_in_group("combat_authority") as CombatAuthority
	if is_instance_valid(authority):
		authority.resolve_environment_hit(body, DAMAGE, Vector2(-180.0, -320.0))

func _draw() -> void:
	for index in range(-2, 3):
		var x := float(index) * 18.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 9.0, 12.0), Vector2(x, -16.0), Vector2(x + 9.0, 12.0)]), Color(0.44, 0.51, 0.58))
		draw_line(Vector2(x, -12.0), Vector2(x, 8.0), Color(0.73, 0.90, 0.88), 2.0)

