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
	draw_rect(Rect2(-52.0, 8.0, 104.0, 8.0), Color(0.30, 0.08, 0.10, 0.42))
	draw_rect(Rect2(-52.0, 13.0, 104.0, 4.0), Color(0.92, 0.18, 0.20, 0.16))
	for index in range(-2, 3):
		var x := float(index) * 18.0
		var fill := Color(0.58, 0.25, 0.29) if index % 2 == 0 else Color(0.48, 0.34, 0.39)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 9.0, 12.0), Vector2(x, -16.0), Vector2(x + 9.0, 12.0)]), fill)
		draw_line(Vector2(x, -13.0), Vector2(x, 8.0), Color(0.94, 0.72, 0.67, 0.72), 2.0)
		draw_circle(Vector2(x, -15.0), 2.2, Color(1.0, 0.40, 0.38, 0.46))

