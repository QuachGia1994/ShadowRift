extends Node2D

const WORLD_WIDTH := 2400.0
const GROUND_Y := 440.0
const SKY_TEXTURE := preload("res://assets/environment/bg_sky.png")
const RUINS_TEXTURE := preload("res://assets/environment/bg_ruins.png")
const MIST_TEXTURE := preload("res://assets/environment/bg_foreground_mist.png")
const HIT_SPARK := preload("res://assets/vfx/hit_spark.png")

var _hero: Hero
var _boss: BossController
var _save_repository := SaveRepository.new()
var _projectile_pool: ReusablePool
var _damage_number_pool: ReusablePool
var _hud: GameHud
var _controls: MobileControls
var _paused_by_user := false

func _ready() -> void:
	_create_background()
	_create_zone()
	_create_combat_authority()
	_create_pools()
	_create_controls()
	_create_hero()
	_load_progress()
	_create_enemies()
	_create_boss()
	_create_hud()

func _create_background() -> void:
	_add_parallax_layer(SKY_TEXTURE, Vector2(0.0, 0.0), -30)
	_add_parallax_layer(RUINS_TEXTURE, Vector2(0.28, 0.0), -25)
	_add_parallax_layer(MIST_TEXTURE, Vector2(0.55, 0.0), -20)

func _add_parallax_layer(texture: Texture2D, scroll: Vector2, z: int) -> void:
	var parallax := Parallax2D.new()
	parallax.scroll_scale = scroll
	parallax.repeat_size = Vector2(texture.get_width(), 0.0)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	parallax.add_child(sprite)
	parallax.z_index = z
	add_child(parallax)

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
	_spawn_hit_spark(position)

func _spawn_hit_spark(position: Vector2) -> void:
	var spark := Sprite2D.new()
	spark.texture = HIT_SPARK
	spark.global_position = position + Vector2(0.0, -6.0)
	spark.rotation = randf_range(-0.35, 0.35)
	spark.z_index = 2
	add_child(spark)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "modulate:a", 0.0, 0.22)
	tween.tween_property(spark, "scale", Vector2(1.25, 1.25), 0.22)
	tween.chain().tween_callback(spark.queue_free)

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
