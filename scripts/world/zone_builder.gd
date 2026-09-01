extends Node2D
class_name ZoneBuilder

const TILE_SIZE := 32
const GROUND_ROW := 13
const ZONE_TILE_SET := preload("res://assets/environment/rift_zone_tileset.tres")
const PLATFORM_TEXTURE := preload("res://assets/environment/platform_rune.png")

var _foreground: TileMapLayer
var _columns := 75
var _stage_index := 0

func configure(stage_index: int, world_width: float) -> void:
	_stage_index = maxi(0, stage_index)
	_columns = maxi(1, int(ceil(world_width / float(TILE_SIZE))))

func build(stage_config: Dictionary = {}) -> void:
	var width := float(stage_config.get("width", float(_columns * TILE_SIZE)))
	_columns = maxi(1, int(ceil(width / float(TILE_SIZE))))
	_create_tile_layers(ZONE_TILE_SET)
	_create_ground_collision()
	for entry in stage_config.get("platforms", []):
		if entry is Array and entry.size() == 2:
			_create_one_way_platform(entry[0], entry[1])
	for center in stage_config.get("hazards", []):
		if center is Vector2:
			_create_hazard(center)

func _create_tile_layers(tile_set: TileSet) -> void:
	var background := TileMapLayer.new()
	background.name = "BackgroundTiles"
	background.tile_set = tile_set
	background.z_index = -3
	background.modulate = Color(0.50, 0.58, 0.75, 0.48)
	add_child(background)
	var midground := TileMapLayer.new()
	midground.name = "MidgroundTiles"
	midground.tile_set = tile_set
	midground.z_index = -1
	midground.modulate = Color(0.70, 0.76, 0.82, 0.72)
	add_child(midground)
	_foreground = TileMapLayer.new()
	_foreground.name = "ForegroundTiles"
	_foreground.tile_set = tile_set
	_foreground.z_index = 0
	add_child(_foreground)
	for x in range(_columns):
		var phase := float(_stage_index) * 0.75
		background.set_cell(Vector2i(x, 7 + int(sin(float(x) * 0.42 + phase) * 2.0)), 0, Vector2i(0, 0))
		midground.set_cell(Vector2i(x, 11 + int(sin(float(x) * 0.28 + phase))), 0, Vector2i(1, 0))
		_foreground.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(2, 0))
		_foreground.set_cell(Vector2i(x, GROUND_ROW + 1), 0, Vector2i(1, 0))

func _create_ground_collision() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.position = Vector2(_columns * TILE_SIZE * 0.5, (GROUND_ROW + 1) * TILE_SIZE)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_columns * TILE_SIZE, TILE_SIZE * 2.0)
	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)

func _create_one_way_platform(center: Vector2, platform_size: Vector2) -> void:
	var platform := StaticBody2D.new()
	platform.collision_layer = 1
	platform.position = center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = platform_size
	collision.shape = shape
	collision.one_way_collision = true
	collision.one_way_collision_margin = 12.0
	platform.add_child(collision)
	var visual := Sprite2D.new()
	visual.texture = PLATFORM_TEXTURE
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.region_enabled = true
	visual.region_rect = Rect2(0.0, 0.0, platform_size.x, platform_size.y)
	platform.add_child(visual)
	add_child(platform)

func _create_hazard(center: Vector2) -> void:
	var hazard := Hazard.new()
	hazard.position = center
	hazard.configure(Vector2(90.0, 32.0))
	add_child(hazard)
