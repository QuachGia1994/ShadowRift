extends Node
class_name CameraEffects

## Adapted from template camera_controller.gd (shake/hitstop) + toolkit camera_shake.gd (MIT)
## Low-cost juice: hitstop + shake on damage, landing dust hook.

@export var camera: Camera2D
@export var shake_decay: float = 8.0
@export var max_shake_offset: float = 10.0

var _shake_intensity: float = 0.0
var _hitstop_timer: float = 0.0

func _ready() -> void:
    if not camera:
        camera = get_viewport().get_camera_2d()
    var bus := get_tree().get_first_node_in_group("combat_authority") as CombatAuthority
    if bus:
        bus.damage_resolved.connect(_on_damage)

func _process(delta: float) -> void:
    if _hitstop_timer > 0.0:
        _hitstop_timer -= delta
        if _hitstop_timer <= 0.0:
            Engine.time_scale = 1.0
    if _shake_intensity > 0.0:
        _shake_intensity = maxf(0.0, _shake_intensity - shake_decay * delta)
        if camera:
            camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity
            if _shake_intensity <= 0.01:
                camera.offset = Vector2.ZERO

func trigger_shake(intensity: float = 6.0) -> void:
    _shake_intensity = maxf(_shake_intensity, intensity)

func trigger_hitstop(duration: float = 0.06) -> void:
    if duration <= 0.0:
        return
    Engine.time_scale = 0.12
    _hitstop_timer = duration

func _on_damage(_pos: Vector2, amount: int) -> void:
    if amount >= 10:
        trigger_shake(7.0)
        trigger_hitstop(0.05)
    elif amount >= 5:
        trigger_shake(3.5)
