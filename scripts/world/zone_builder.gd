extends Node2D
class_name ZoneBuilder

const TILE_SIZE := 32
const ZONE_COLUMNS := 75
const GROUND_ROW := 13

var _foreground: TileMapLayer

func build() -> void:
	var tile_set := _create_tile_set()
	_create_tile_layers(tile_set)
	_create_ground_collision()
	_create_one_way_platform(Vector2(660.0, 330.0), Vector2(224.0, 18.0))
	_create_one_way_platform(Vector2(1260.0, 280.0), Vector2(192.0, 18.0))
	_create_hazard(Vector2(930.0, 419.0))

func _create_tile_set() -> TileSet:
	var image := Image.create(TILE_SIZE * 3, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for tile_index in range(3):
		var base: Color = [Color(0.055, 0.075, 0.12), Color(0.12, 0.15, 0.18), Color(0.17, 0.20, 0.20)][tile_index]
		for x in range(TILE_SIZE):
			for y in range(TILE_SIZE):
				var checker := 0.025 if (int(x / 4) + int(y / 4)) % 2 == 0 else -0.015
				var color: Color = base.lightened(maxf(0.0, checker)) if checker >= 0.0 else base.darkened(-checker)
				if tile_index == 2 and y < 5:
					color = Color(0.21, 0.37, 0.26)
				image.set_pixel(tile_index * TILE_SIZE + x, y, color)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for tile_index in range(3):
		source.create_tile(Vector2i(tile_index, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)
	return tile_set

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
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-platform_size.x * 0.5, -9.0), Vector2(platform_size.x * 0.5, -9.0), Vector2(platform_size.x * 0.5, 9.0), Vector2(-platform_size.x * 0.5, 9.0)])
	visual.color = Color(0.18, 0.28, 0.22)
	platform.add_child(visual)
	add_child(platform)

func _create_hazard(center: Vector2) -> void:
	var hazard := Hazard.new()
	hazard.position = center
	hazard.configure(Vector2(90.0, 32.0))
	add_child(hazard)
