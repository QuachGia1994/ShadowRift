extends Area2D
class_name Hazard

const DAMAGE := 18
const SPIKES_TEXTURE := preload("res://assets/environment/hazard_spikes.png")

func configure(hazard_size: Vector2) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = hazard_size
	collision.shape = shape
	add_child(collision)
	var visual := Sprite2D.new()
	visual.texture = SPIKES_TEXTURE
	visual.position = Vector2(0.0, 2.0)
	add_child(visual)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body is Hero:
		return
	var authority := get_tree().get_first_node_in_group("combat_authority") as CombatAuthority
	if is_instance_valid(authority):
		authority.resolve_environment_hit(body, DAMAGE, Vector2(-180.0, -320.0))

