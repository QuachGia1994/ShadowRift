extends Node2D
class_name ZoneBuilder

const TILE_SIZE := 32
const ZONE_COLUMNS := 75
const GROUND_ROW := 13
const ZONE_TILE_SET := preload("res://assets/environment/rift_zone_tileset.tres")
const PLATFORM_TEXTURE := preload("res://assets/environment/platform_rune.png")

var _foreground: TileMapLayer

func build() -> void:
	_create_tile_layers(ZONE_TILE_SET)
	_create_ground_collision()
	_create_one_way_platform(Vector2(660.0, 330.0), Vector2(224.0, 18.0))
	_create_one_way_platform(Vector2(1260.0, 280.0), Vector2(192.0, 18.0))
	_create_hazard(Vector2(930.0, 419.0))

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
	for x in range(ZONE_COLUMNS):
		background.set_cell(Vector2i(x, 7 + int(sin(float(x) * 0.42) * 2.0)), 0, Vector2i(0, 0))
		midground.set_cell(Vector2i(x, 11 + int(sin(float(x) * 0.28))), 0, Vector2i(1, 0))
		_foreground.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(2, 0))
		_foreground.set_cell(Vector2i(x, GROUND_ROW + 1), 0, Vector2i(1, 0))
	for x in range(18, 25):
		_foreground.set_cell(Vector2i(x, 10), 0, Vector2i(2, 0))
	for x in range(37, 43):
		_foreground.set_cell(Vector2i(x, 8), 0, Vector2i(2, 0))

func _create_ground_collision() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.position = Vector2(ZONE_COLUMNS * TILE_SIZE * 0.5, (GROUND_ROW + 1) * TILE_SIZE)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ZONE_COLUMNS * TILE_SIZE, TILE_SIZE * 2.0)
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
	collision.one_way_collision_margin = 10.0
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
