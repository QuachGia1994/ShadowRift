extends Node2D

const WORLD_WIDTH := 2400.0
const GROUND_Y := 440.0

var _hero: Hero
var _boss: BossController
var _save_repository := SaveRepository.new()

func _ready() -> void:
	_create_zone()
	_create_combat_authority()
	_create_controls()
	_create_hero()
	_load_progress()
	_create_enemies()
	_create_boss()
	_create_hud()
	queue_redraw()

func _create_combat_authority() -> void:
	var authority := CombatAuthority.new()
	authority.add_to_group("combat_authority")
	add_child(authority)

func _create_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var controls := MobileControls.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.add_to_group("mobile_controls")
	layer.add_child(controls)

func _create_hero() -> void:
	_hero = Hero.new()
	_hero.position = Vector2(180.0, GROUND_Y - 34.0)
	add_child(_hero)

func _create_enemies() -> void:
	var warden := EnemyController.new()
	warden.configure(EnemyController.Kind.WARDEN, _hero)
	warden.position = Vector2(620.0, GROUND_Y - 28.0)
	warden.defeated.connect(_hero.grant_rewards)
	warden.defeated.connect(_save_progress.unbind(2))
	add_child(warden)
	var wraith := EnemyController.new()
	wraith.configure(EnemyController.Kind.WRAITH, _hero)
	wraith.position = Vector2(1160.0, GROUND_Y - 28.0)
	wraith.defeated.connect(_hero.grant_rewards)
	wraith.defeated.connect(_save_progress.unbind(2))
	add_child(wraith)

func _create_boss() -> void:
	_boss = BossController.new()
	_boss.configure(_hero)
	_boss.position = Vector2(1970.0, GROUND_Y - 42.0)
	_boss.defeated.connect(_hero.grant_rewards)
	_boss.defeated.connect(_save_progress.unbind(2))
	add_child(_boss)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hud := GameHud.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.configure(_hero, _boss)
	layer.add_child(hud)

func _load_progress() -> void:
	var result := _save_repository.load_game()
	if result.ok:
		_hero.restore_save_payload(result.payload)

func _save_progress() -> void:
	if is_instance_valid(_hero):
		_save_repository.save_game(_hero.export_save_payload())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_progress()

func _create_zone() -> void:
	var zone := ZoneBuilder.new()
	zone.build()
	add_child(zone)

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, WORLD_WIDTH, 540.0), Color(0.025, 0.035, 0.07))
	for layer_index in range(4):
		var layer_color := Color(0.07 + layer_index * 0.015, 0.08 + layer_index * 0.012, 0.13 + layer_index * 0.018)
		var base_y := 230.0 + layer_index * 48.0
		var points := PackedVector2Array([Vector2(0.0, 540.0)])
		for x in range(0, int(WORLD_WIDTH) + 160, 160):
			points.append(Vector2(x, base_y + sin(float(x) * 0.009 + layer_index) * 65.0))
		points.append(Vector2(WORLD_WIDTH, 540.0))
		draw_colored_polygon(points, layer_color)
	for x in range(70, int(WORLD_WIDTH), 280):
		draw_circle(Vector2(x, 360.0 + sin(float(x)) * 24.0), 3.0, Color(0.22, 0.68, 0.62, 0.55))
