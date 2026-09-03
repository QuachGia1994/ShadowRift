extends Node
class_name LevelManager

## RunManager / LevelManager — data-driven stage orchestration.
## Adapted from SummerEngine RoomManager + GameLab4 GameManager + crystal-trails progression (reference).

signal stage_changed(index: int, config: LevelConfig)
signal checkpoint_activated(id: StringName, position: Vector2)
signal run_completed

const STAGE_COUNT := 3

var current_index: int = 0
var current_config: LevelConfig
var last_checkpoint_position: Vector2
var has_checkpoint: bool = false
var is_transitioning: bool = false

var _configs: Array[LevelConfig] = []

func _ready() -> void:
    _build_configs()
    current_config = _configs[clampi(current_index, 0, _configs.size() - 1)]
    last_checkpoint_position = current_config.spawn

func _build_configs() -> void:
    _configs.clear()
    for i in range(StageCatalog.count()):
        var dict := StageCatalog.get_stage(i)
        var cfg := LevelConfig.from_stage_dict(i, dict)
        _configs.append(cfg)

func get_config(index: int) -> LevelConfig:
    return _configs[clampi(index, 0, _configs.size() - 1)]

func get_current() -> LevelConfig:
    return current_config

func get_spawn() -> Vector2:
    return current_config.spawn if current_config else Vector2(180, 406)

func get_respawn_position() -> Vector2:
    return last_checkpoint_position if has_checkpoint else get_spawn()

func activate_checkpoint(id: StringName, pos: Vector2) -> void:
    last_checkpoint_position = pos
    has_checkpoint = true
    checkpoint_activated.emit(id, pos)

func reset_checkpoint() -> void:
    has_checkpoint = false
    if current_config:
        last_checkpoint_position = current_config.spawn

func advance_stage() -> bool:
    if current_index + 1 >= _configs.size():
        run_completed.emit()
        return false
    current_index += 1
    current_config = _configs[current_index]
    reset_checkpoint()
    stage_changed.emit(current_index, current_config)
    return true

func set_stage(index: int, reset_checkpoint_state: bool = true) -> void:
    current_index = clampi(index, 0, _configs.size() - 1)
    current_config = _configs[current_index]
    if reset_checkpoint_state:
        reset_checkpoint()
    stage_changed.emit(current_index, current_config)

func count() -> int:
    return _configs.size()

func to_save_payload() -> Dictionary:
    # JSON has no native Vector2 type. Persist coordinates explicitly so the
    # checkpoint survives stringify/parse without becoming an opaque String.
    return {
        "stage_index": current_index,
        "checkpoint": {"x": last_checkpoint_position.x, "y": last_checkpoint_position.y},
        "has_checkpoint": has_checkpoint,
    }

func restore_from_payload(payload: Dictionary) -> void:
    if payload.has("stage_index"):
        set_stage(int(payload["stage_index"]))
        if bool(payload.get("has_checkpoint", false)) and payload.has("checkpoint"):
            var cp: Variant = _checkpoint_from_variant(payload["checkpoint"])
            if cp != null:
                last_checkpoint_position = cp as Vector2
                has_checkpoint = true

func _checkpoint_from_variant(value: Variant) -> Variant:
    if value is Vector2:
        return value
    if value is Dictionary and value.has("x") and value.has("y"):
        return Vector2(float(value.x), float(value.y))
    if value is String:
        # Compatibility with schema-2 files written before checkpoint JSON
        # normalization, where JSON.stringify(Vector2) produced a String.
        var parsed: Variant = str_to_var(value)
        if parsed is Vector2:
            return parsed
        var text := String(value).strip_edges()
        if text.begins_with("(") and text.ends_with(")"):
            var components := text.substr(1, text.length() - 2).split(",")
            if components.size() == 2 and components[0].strip_edges().is_valid_float() and components[1].strip_edges().is_valid_float():
                return Vector2(components[0].strip_edges().to_float(), components[1].strip_edges().to_float())
    return null
