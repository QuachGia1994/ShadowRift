extends Node
class_name SquashStretch

## Adapted from godot-platformer-toolkit components/squash_stretch.gd (MIT e755d6e)
## Pure feedback: listens to Hero jumped/landed, never touches physics.

@export var target: Node2D
@export var jump_stretch: Vector2 = Vector2(0.82, 1.18)
@export var land_squash: Vector2 = Vector2(1.28, 0.72)
@export var return_speed: float = 14.0

var _rest_scale: Vector2 = Vector2.ONE
var _current: Vector2 = Vector2.ONE
var _tween_scale: Vector2 = Vector2.ONE

func _ready() -> void:
    if target:
        _rest_scale = target.scale
        _current = _rest_scale
    var hero := get_parent() as Hero
    if hero:
        hero.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
    if not target:
        return
    target.scale = _current
    _current = _current.lerp(_rest_scale, return_speed * delta)

func _on_state_changed(_prev: int, curr: int) -> void:
    if curr == 2: # JUMP
        _current = _rest_scale * jump_stretch
    elif curr == 0 or curr == 1: # IDLE/MOVE after landing
        # small squash on landing handled via is_on_floor check in Hero
        pass

func trigger_land() -> void:
    _current = _rest_scale * land_squash

func trigger_jump() -> void:
    _current = _rest_scale * jump_stretch
