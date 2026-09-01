extends Area2D
class_name Killzone

## Adapted from SummerEngine killzone.gd (MIT 66fc71b)
## Kills via CombatAuthority hazard path for consistent damage identity.

@export var damage: int = 25
var _shape_size: Vector2 = Vector2(2400, 48)

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    body_entered.connect(_on_body_entered)

func configure(size: Vector2) -> void:
    _shape_size = size
    if not is_inside_tree():
        return
    for child in get_children():
        if child is CollisionShape2D:
            var shape := child.shape as RectangleShape2D
            if shape:
                shape.size = size

func _enter_tree() -> void:
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = _shape_size
    col.shape = shape
    add_child(col)

func _on_body_entered(body: Node2D) -> void:
    if not body is Hero:
        return
    var authority := get_tree().get_first_node_in_group("combat_authority") as CombatAuthority
    if is_instance_valid(authority):
        authority.resolve_environment_hit(body, damage, Vector2.ZERO)
    elif body.has_method("die"):
        body.die()
