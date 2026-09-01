extends Node2D

const WORLD_WIDTH := 2400.0
const GROUND_Y := 440.0

var _hero: Hero
var _boss: BossController
var _save_repository := SaveRepository.new()
var _projectile_pool: ReusablePool
var _damage_number_pool: ReusablePool
var _hud: GameHud
var _controls: MobileControls
var _paused_by_user := false

func _ready() -> void:
	_create_zone()
	_create_combat_authority()
	_create_pools()
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
	authority.damage_resolved.connect(_show_damage_number)
	add_child(authority)

func _create_pools() -> void:
	_projectile_pool = ReusablePool.new()
	_projectile_pool.add_to_group("projectile_pool")
	_projectile_pool.configure(_make_projectile, 12)
	add_child(_projectile_pool)
	_damage_number_pool = ReusablePool.new()
	_damage_number_pool.configure(_make_damage_number, 16)
	add_child(_damage_number_pool)
	var performance_budget := PerformanceBudget.new()
	add_child(performance_budget)

func _make_projectile() -> PooledProjectile:
	return PooledProjectile.new()

func _make_damage_number() -> PooledDamageNumber:
	return PooledDamageNumber.new()

func _show_damage_number(position: Vector2, amount: int) -> void:
	if not is_instance_valid(_damage_number_pool):
		return
	var number := _damage_number_pool.acquire() as PooledDamageNumber
	number.activate(amount, position)

func _create_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_controls = MobileControls.new()
	_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls.add_to_group("mobile_controls")
	_controls.pause_requested.connect(_toggle_user_pause)
	layer.add_child(_controls)

func _create_hero() -> void:
	_hero = Hero.new()
	_hero.position = Vector2(180.0, GROUND_Y - 34.0)
	_hero.persistence_requested.connect(_save_progress)
	add_child(_hero)

func _create_enemies() -> void:
	var warden := EnemyController.new()
	warden.configure(EnemyController.Kind.WARDEN, _hero)
	warden.position = Vector2(620.0, GROUND_Y - 28.0)
	warden.defeated.connect(_hero.grant_rewards)
	add_child(warden)
	var wraith := EnemyController.new()
	wraith.configure(EnemyController.Kind.WRAITH, _hero)
	wraith.position = Vector2(1160.0, GROUND_Y - 28.0)
	wraith.defeated.connect(_hero.grant_rewards)
	add_child(wraith)

func _create_boss() -> void:
	_boss = BossController.new()
	_boss.configure(_hero)
	_boss.position = Vector2(1970.0, GROUND_Y - 42.0)
	_boss.defeated.connect(_hero.grant_rewards)
	add_child(_boss)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = GameHud.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.configure(_hero, _boss)
	layer.add_child(_hud)

func _toggle_user_pause() -> void:
	_paused_by_user = not _paused_by_user
	if is_instance_valid(_controls):
		_controls.reset_inputs()
	if is_instance_valid(_hud):
		_hud.set_pause_state(_paused_by_user)
	get_tree().paused = _paused_by_user

func _load_progress() -> void:
	var result := _save_repository.load_game()
	if result.ok:
		_hero.restore_save_payload(result.payload)

func _save_progress() -> void:
	if is_instance_valid(_hero):
		_save_repository.save_game(_hero.export_save_payload())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(_controls):
			_controls.reset_inputs()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_progress()

func _exit_tree() -> void:
	if _paused_by_user and is_instance_valid(get_tree()):
		get_tree().paused = false

func _create_zone() -> void:
	var zone := ZoneBuilder.new()
	zone.build()
	add_child(zone)

func _draw() -> void:
	var sky_top := Color(0.012, 0.020, 0.050)
	var sky_bottom := Color(0.040, 0.055, 0.105)
	draw_rect(Rect2(0.0, 0.0, WORLD_WIDTH, 540.0), sky_top)
	for band in range(6):
		var t := float(band + 1) / 6.0
		var band_color := sky_top.lerp(sky_bottom, t)
		draw_rect(Rect2(0.0, float(band) * 90.0, WORLD_WIDTH, 92.0), Color(band_color.r, band_color.g, band_color.b, 0.90))
	var moon_center := Vector2(790.0, 105.0)
	draw_circle(moon_center, 58.0, Color(0.34, 0.38, 0.52, 0.08))
	draw_circle(moon_center, 42.0, Color(0.68, 0.71, 0.82, 0.10))
	draw_arc(moon_center, 42.0, -1.25, 1.65, 42, Color(0.60, 0.66, 0.86, 0.22), 2.0)
	for x in range(60, int(WORLD_WIDTH), 135):
		var star_y := 48.0 + fmod(float(x * 37), 175.0)
		var star_radius := 1.2 + fmod(float(x), 3.0) * 0.35
		draw_circle(Vector2(float(x), star_y), star_radius, Color(0.54, 0.72, 0.82, 0.34))
	for layer_index in range(4):
		var layer_color := Color(0.055 + layer_index * 0.020, 0.065 + layer_index * 0.018, 0.115 + layer_index * 0.026)
		var base_y := 225.0 + layer_index * 52.0
		var points := PackedVector2Array([Vector2(0.0, 540.0)])
		for x in range(0, int(WORLD_WIDTH) + 160, 160):
			var ridge := sin(float(x) * (0.0065 + layer_index * 0.0007) + float(layer_index)) * (58.0 - layer_index * 5.0)
			var detail := sin(float(x) * 0.014 + float(layer_index) * 1.7) * 18.0
			points.append(Vector2(float(x), base_y + ridge + detail))
		points.append(Vector2(WORLD_WIDTH, 540.0))
		draw_colored_polygon(points, layer_color)
	var horizon_y := 382.0
	draw_rect(Rect2(0.0, horizon_y, WORLD_WIDTH, 2.0), Color(0.18, 0.42, 0.42, 0.12))
	for x in range(70, int(WORLD_WIDTH), 245):
		var mote_y := 335.0 + sin(float(x) * 0.021) * 38.0
		draw_circle(Vector2(float(x), mote_y), 2.6, Color(0.18, 0.72, 0.68, 0.42))
		draw_circle(Vector2(float(x), mote_y), 6.5, Color(0.18, 0.72, 0.68, 0.055))
	var rift_x := 1810.0
	for segment in range(5):
		var y0 := 115.0 + float(segment) * 34.0
		var sway := sin(float(segment) * 1.7) * 9.0
		draw_line(Vector2(rift_x + sway, y0), Vector2(rift_x - sway * 0.6, y0 + 30.0), Color(0.48, 0.20, 0.74, 0.22), 3.0)
		draw_line(Vector2(rift_x + sway, y0), Vector2(rift_x - sway * 0.6, y0 + 30.0), Color(0.36, 0.72, 0.84, 0.10), 8.0)
