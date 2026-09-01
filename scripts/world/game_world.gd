extends Node2D

const GROUND_Y := 440.0
const SKY_TEXTURE := preload("res://assets/environment/bg_sky.png")
const RUINS_TEXTURE := preload("res://assets/environment/bg_ruins.png")
const MIST_TEXTURE := preload("res://assets/environment/bg_foreground_mist.png")
const HIT_SPARK := preload("res://assets/vfx/hit_spark.png")
const GATE_TEXTURE := preload("res://assets/vfx/skill_two_projectile.png")

var _hero: Hero
var _boss: BossController
var _save_repository := SaveRepository.new()
var _projectile_pool: ReusablePool
var _damage_number_pool: ReusablePool
var _hud: GameHud
var _controls: MobileControls
var _paused_by_user := false
var _stage_index := 0
var _stage_root: Node2D
var _stage_gate: Area2D
var _stage_gate_visual: Sprite2D
var _stage_remaining := 0
var _stage_clear := false
var _respawning := false
var _transitioning := false

func _ready() -> void:
	_create_background()
	_create_combat_authority()
	_create_pools()
	_create_controls()
	_create_hero()
	_load_progress()
	_create_hud()
	_load_stage(0, false)

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
	_hero.died.connect(_on_hero_died)
	add_child(_hero)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = GameHud.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.configure(_hero, null)
	layer.add_child(_hud)

func _load_stage(index: int, recover_between_stages: bool = true) -> void:
	_stage_index = clampi(index, 0, StageCatalog.count() - 1)
	var config := StageCatalog.get_stage(_stage_index)
	_clear_stage_root()
	_stage_root = Node2D.new()
	_stage_root.name = "Stage%d" % (_stage_index + 1)
	add_child(_stage_root)
	var zone := ZoneBuilder.new()
	zone.configure(_stage_index, float(config.width))
	zone.build(config)
	_stage_root.add_child(zone)
	_stage_remaining = 0
	_stage_clear = false
	_boss = null
	for spec in config.enemies:
		_spawn_enemy(spec)
	if bool(config.get("boss", false)):
		_spawn_boss(config.get("boss_position", Vector2(1900.0, 398.0)))
	_create_stage_gate(float(config.width))
	if _stage_remaining == 0:
		_unlock_stage_gate()
	_hero.set_camera_world_width(float(config.width))
	if recover_between_stages:
		_hero.prepare_for_stage(config.spawn)
	else:
		_hero.place_at(config.spawn)
	_hud.bind_boss(_boss)
	_hud.set_stage(_stage_index + 1, StageCatalog.count(), str(config.name))

func _clear_stage_root() -> void:
	if is_instance_valid(_stage_root):
		remove_child(_stage_root)
		_stage_root.queue_free()
	_stage_gate = null
	_stage_gate_visual = null
	_boss = null

func _spawn_enemy(spec: Dictionary) -> void:
	var enemy := EnemyController.new()
	var kind_name := str(spec.get("kind", "warden"))
	var kind := EnemyController.Kind.WRAITH if kind_name == "wraith" else EnemyController.Kind.WARDEN
	enemy.configure(kind, _hero)
	enemy.position = spec.get("position", Vector2(700.0, 412.0))
	enemy.defeated.connect(_hero.grant_rewards)
	enemy.death_finished.connect(_on_stage_actor_death_finished)
	_stage_root.add_child(enemy)
	_stage_remaining += 1

func _spawn_boss(position: Vector2) -> void:
	_boss = BossController.new()
	_boss.configure(_hero)
	_boss.position = position
	_boss.defeated.connect(_hero.grant_rewards)
	_boss.death_finished.connect(_on_stage_actor_death_finished)
	_stage_root.add_child(_boss)
	_stage_remaining += 1

func _create_stage_gate(world_width: float) -> void:
	_stage_gate = Area2D.new()
	_stage_gate.collision_layer = 0
	_stage_gate.collision_mask = 1
	_stage_gate.monitoring = false
	_stage_gate.position = Vector2(world_width - 72.0, GROUND_Y - 76.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72.0, 150.0)
	collision.shape = shape
	_stage_gate.add_child(collision)
	_stage_gate_visual = Sprite2D.new()
	_stage_gate_visual.texture = GATE_TEXTURE
	_stage_gate_visual.rotation = PI * 0.5
	_stage_gate_visual.scale = Vector2(2.4, 4.8)
	_stage_gate_visual.modulate = Color(0.35, 0.42, 0.55, 0.28)
	_stage_gate_visual.z_index = 2
	_stage_gate.add_child(_stage_gate_visual)
	_stage_gate.body_entered.connect(_on_stage_gate_body_entered)
	_stage_root.add_child(_stage_gate)

func _on_stage_actor_death_finished() -> void:
	_stage_remaining = maxi(0, _stage_remaining - 1)
	if _stage_remaining == 0:
		_unlock_stage_gate()

func _unlock_stage_gate() -> void:
	_stage_clear = true
	if is_instance_valid(_stage_gate):
		_stage_gate.monitoring = true
	if is_instance_valid(_stage_gate_visual):
		_stage_gate_visual.modulate = Color(0.52, 0.94, 1.0, 0.92)
		var pulse := _stage_gate_visual.create_tween().set_loops()
		pulse.tween_property(_stage_gate_visual, "scale", Vector2(2.55, 5.05), 0.42)
		pulse.tween_property(_stage_gate_visual, "scale", Vector2(2.4, 4.8), 0.42)
	if is_instance_valid(_hud):
		_hud.show_banner("RIFT OPEN", "Reach the gate", 1.0)

func _on_stage_gate_body_entered(body: Node2D) -> void:
	if body != _hero or not _stage_clear or _transitioning or _respawning:
		return
	_transitioning = true
	_controls.reset_inputs()
	var final_stage := _stage_index == StageCatalog.count() - 1
	if final_stage:
		_hud.show_banner("RIFT SEALED", "Run complete", 1.1)
	else:
		_hud.show_banner("STAGE CLEAR", "Entering the next rift", 0.75)
	await get_tree().create_timer(0.75).timeout
	var next_stage := 0 if final_stage else _stage_index + 1
	_load_stage(next_stage, true)
	_save_progress()
	_transitioning = false

func _on_hero_died() -> void:
	if _respawning:
		return
	_respawning = true
	_controls.reset_inputs()
	_hud.show_banner("FALLEN", "Reforming at checkpoint", 1.0)
	await get_tree().create_timer(1.05).timeout
	var config := StageCatalog.get_stage(_stage_index)
	_load_stage(_stage_index, false)
	_hero.respawn_at(config.spawn)
	_respawning = false

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
	if is_instance_valid(_hero) and not _hero.is_dead():
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
