extends Node2D
class_name LevelRoot

## BaseLevel / LevelRoot — reusable container for one stage.
## Adapted from GameLab4 base_level.gd + template room_loader.gd.

var config: LevelConfig
var zone: ZoneBuilder
var _checkpoints: Array[Checkpoint] = []
var _killzone: Killzone
var _exit: LevelExit

signal checkpoint_reached(id: StringName, pos: Vector2)
signal exit_reached

func configure(level_config: LevelConfig) -> void:
    config = level_config

func build() -> void:
    if config == null:
        return
    zone = ZoneBuilder.new()
    zone.configure(0, config.width)
    var dict := config.to_stage_dict()
    zone.build(dict)
    add_child(zone)
    for entry in config.moving_platforms:
        if entry is Dictionary:
            var mp := MovingPlatform.new()
            mp.configure(entry.get("center", Vector2.ZERO), entry.get("size", Vector2(160, 18)), entry.get("travel", Vector2(0, -96)), entry.get("duration", 2.0))
            add_child(mp)
    for idx in range(config.checkpoints.size()):
        var cp := Checkpoint.new()
        cp.checkpoint_id = StringName("cp_%d" % idx)
        cp.position = config.checkpoints[idx]
        cp.activated.connect(_on_checkpoint_activated)
        add_child(cp)
        _checkpoints.append(cp)
    _killzone = Killzone.new()
    _killzone.position = Vector2(config.width * 0.5, config.death_plane_y)
    _killzone.configure(Vector2(config.width, 48.0))
    add_child(_killzone)
    _exit = LevelExit.new()
    _exit.position = Vector2(config.width - 120.0, 406.0)
    _exit.exit_reached.connect(func(): exit_reached.emit())
    add_child(_exit)

func _on_checkpoint_activated(id: StringName, pos: Vector2) -> void:
    checkpoint_reached.emit(id, pos)

func cleanup() -> void:
    queue_free()
