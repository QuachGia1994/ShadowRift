extends AnimatableBody2D
class_name MovingPlatform

## Adapted from SummerEngine template-2d-platformer scripts/systems/moving_platform.gd (MIT 66fc71b)
## Uses AnimatableBody2D tween for jitter-free carry on Godot 4.7.2. Syncs player via move_and_slide.

@export var travel: Vector2 = Vector2(0, -128)
@export var duration: float = 2.0
@export var pause_at_ends: float = 0.5
@export var platform_size: Vector2 = Vector2(160, 18)

var _start_pos: Vector2
var _tween: Tween
const PLATFORM_TEXTURE := preload("res://assets/environment/platform_rune.png")

func _ready() -> void:
    _start_pos = global_position
    _create_collision()
    _start_cycle()

func configure(center: Vector2, size: Vector2, travel_vec: Vector2, dur: float) -> void:
    global_position = center
    platform_size = size
    travel = travel_vec
    duration = dur

func _create_collision() -> void:
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = platform_size
    col.shape = shape
    add_child(col)
    var visual := Sprite2D.new()
    visual.texture = PLATFORM_TEXTURE
    visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    visual.region_enabled = true
    visual.region_rect = Rect2(0, 0, platform_size.x, platform_size.y)
    add_child(visual)
    sync_to_physics = true

func _start_cycle() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    _tween = create_tween().set_loops()
    _tween.tween_property(self, "global_position", _start_pos + travel, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    _tween.tween_interval(pause_at_ends)
    _tween.tween_property(self, "global_position", _start_pos, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    _tween.tween_interval(pause_at_ends)
