extends Area2D
class_name Checkpoint

## Adapted from SummerEngine template checkpoint.gd (MIT 66fc71b)
signal activated(id: StringName, position: Vector2)

@export var checkpoint_id: StringName = &"cp_0"

var _activated: bool = false
var _inactive_color: Color = Color(0.55, 0.55, 0.58, 0.6)
var _active_color: Color = Color(0.2, 0.95, 0.45, 1.0)

var _visual: Polygon2D
var _pole: Polygon2D

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    _create_visuals()
    body_entered.connect(_on_body_entered)

func _create_visuals() -> void:
    _pole = Polygon2D.new()
    _pole.polygon = PackedVector2Array([Vector2(-2, -28), Vector2(2, -28), Vector2(2, 12), Vector2(-2, 12)])
    _pole.color = Color(0.68, 0.62, 0.5)
    add_child(_pole)
    _visual = Polygon2D.new()
    _visual.polygon = PackedVector2Array([Vector2(2, -28), Vector2(18, -22), Vector2(18, -10), Vector2(2, -4)])
    _visual.color = _inactive_color
    add_child(_visual)
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(28, 40)
    col.shape = shape
    col.position = Vector2(8, -8)
    add_child(col)

func _on_body_entered(body: Node2D) -> void:
    if _activated:
        return
    if not body is Hero:
        return
    _activated = true
    _visual.color = _active_color
    # respawn at checkpoint ground + slight offset
    activated.emit(checkpoint_id, global_position + Vector2(0.0, 14.0))
