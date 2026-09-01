extends Resource
class_name LevelConfig

## Data-driven level definition. Adapted architecture from crystal-trails (reference only) and SummerEngine template room concept.
## Each stage in v1 maps 1:1 to a LevelConfig. Adding a 4th stage requires only a new resource, no core logic edit.

@export var id: StringName = &"rift_approach"
@export var display_name: String = "RIFT APPROACH"
@export var width: float = 2400.0
@export var spawn: Vector2 = Vector2(180.0, 406.0)
@export var platforms: Array = []
@export var hazards: Array[Vector2] = []
@export var enemies: Array = []
@export var moving_platforms: Array = []
@export var checkpoints: Array[Vector2] = []
@export var death_plane_y: float = 620.0
@export var has_boss: bool = false
@export var boss_position: Vector2 = Vector2(1900.0, 398.0)
@export var next_level_id: StringName = &""

func to_stage_dict() -> Dictionary:
    return {
        "name": display_name,
        "width": width,
        "spawn": spawn,
        "platforms": platforms,
        "hazards": hazards,
        "enemies": enemies,
        "boss": has_boss,
        "boss_position": boss_position,
        "moving_platforms": moving_platforms,
        "checkpoints": checkpoints,
        "death_plane_y": death_plane_y,
        "next": String(next_level_id),
    }

static func from_stage_dict(index: int, data: Dictionary) -> LevelConfig:
    var cfg := LevelConfig.new()
    var ids := [&"rift_approach", &"broken_keep", &"rift_throne"]
    cfg.id = ids[clampi(index, 0, ids.size() - 1)]
    cfg.spawn = data.get("spawn", Vector2(180, 406)) as Vector2
    cfg.width = float(data.get("width", 2400.0))
    cfg.display_name = String(data.get("name", "STAGE %d" % (index + 1)))
    var plats = data.get("platforms", [])
    cfg.platforms = plats.duplicate(true) if plats is Array else []
    cfg.hazards = data.get("hazards", []) as Array[Vector2]
    cfg.enemies = data.get("enemies", []).duplicate(true) if data.get("enemies", []) is Array else []
    cfg.has_boss = bool(data.get("boss", false))
    cfg.boss_position = data.get("boss_position", Vector2(1900, 398)) as Vector2
    cfg.checkpoints = data.get("checkpoints", []) as Array[Vector2]
    if cfg.checkpoints.is_empty():
        cfg.checkpoints = [cfg.spawn + Vector2(cfg.width * 0.52, 0.0)]
    cfg.death_plane_y = float(data.get("death_plane_y", 620.0))
    if index + 1 < 3:
        cfg.next_level_id = ids[index + 1]
    return cfg
