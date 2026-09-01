extends Area2D
class_name LevelExit

## Adapted from SummerEngine level_end.gd + GameLab4 level_finish_door.gd (MIT)
signal exit_reached

@export var next_level_delay: float = 0.65
var _triggered: bool = false
var _visual: Sprite2D

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    _create_visuals()
    body_entered.connect(_on_body_entered)

func _create_visuals() -> void:
    _visual = Sprite2D.new()
    _visual.texture = preload("res://assets/vfx/skill_two_projectile.png")
    _visual.modulate = Color(0.85, 0.92, 1.0, 0.92)
    _visual.scale = Vector2(2.2, 2.2)
    _visual.position = Vector2(0, -18)
    add_child(_visual)
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(42, 64)
    col.shape = shape
    col.position = Vector2(0, -8)
    add_child(col)
    # subtle pulse
    var tween := create_tween().set_loops()
    tween.tween_property(_visual, "modulate:a", 0.55, 0.7).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(_visual, "modulate:a", 0.92, 0.7).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D) -> void:
    if _triggered:
        return
    if not body is Hero:
        return
    _triggered = true
    exit_reached.emit()
