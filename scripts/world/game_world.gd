extends Node2D

## GameWorld — level-orchestrated run with donor architecture
## Adapted from SummerEngine RoomManager/GameManager + GameLab4 base_level + crystal-trails data-driven (reference)
## Keeps pools/HUD/controls, delegates stage to LevelManager/LevelRoot, handles checkpoint/death/respawn without leaks.

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
var _stage_root: LevelRoot
var _stage_gate: Area2D
var _stage_gate_visual: Sprite2D
var _stage_remaining := 0
var _stage_clear := false
var _respawning := false
var _transitioning := false
var _level_manager: LevelManager
# StageCatalog.count() verification shim
var _camera_effects: CameraEffects

func _ready() -> void:
    _create_background()
    _create_combat_authority()
    _create_pools()
    _create_controls()
    _create_level_manager()
    _create_hero()
    _load_progress()
    _create_hud()
    _create_camera_effects()
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

func _create_level_manager() -> void:
    _level_manager = LevelManager.new()
    _level_manager.stage_changed.connect(_on_stage_changed)
    _level_manager.checkpoint_activated.connect(_on_checkpoint_activated)
    _level_manager.run_completed.connect(_on_run_completed)
    add_child(_level_manager)

func _create_camera_effects() -> void:
    _camera_effects = CameraEffects.new()
    add_child(_camera_effects)

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
    if _camera_effects:
        _camera_effects.trigger_shake(3.0 if amount < 10 else 6.0)
        if amount >= 12:
            _camera_effects.trigger_hitstop(0.055)

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
    _hero.position = Vector2(180.0, 406.0)
    _hero.died.connect(_on_hero_died)
    _hero.persistence_requested.connect(_save_progress)
    add_child(_hero)

func _create_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    _hud = GameHud.new()
    _hud.add_to_group("hud")
    layer.add_child(_hud)
    _hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _hud.configure(_hero, null)
    var config := _level_manager.get_config(_stage_index) if _level_manager else null
    var stage_name := config.display_name if config else "RIFT APPROACH"
    _hud.set_stage(_stage_index + 1, _level_manager.count() if _level_manager else 3, stage_name)

func _on_hero_died() -> void:
    if _respawning or _transitioning:
        return
    # ensure death animation completes before respawn (HERO death 0.66s, boss 1.0)
    var death_dur := 0.66
    # check boss death vs hero death: hero death
    get_tree().create_timer(death_dur).timeout.connect(_respawn_hero)

func _respawn_hero() -> void:
    if not is_instance_valid(_hero) or _transitioning:
        return
    _respawning = true
    var respawn_pos := _level_manager.get_respawn_position() if _level_manager else Vector2(180, 406)
    _hero.respawn_at(respawn_pos)
    _respawning = false
    # ensure camera follows
    _hero.set_camera_world_width(_level_manager.get_current().width if _level_manager and _level_manager.get_current() else 2400.0)

func _load_progress() -> void:
    var result := _save_repository.load_game()
    if not result.ok:
        return
    var payload: Dictionary = result.payload
    if is_instance_valid(_hero):
        _hero.restore_save_payload(payload)
    if _level_manager and payload.has("stage_index"):
        _level_manager.restore_from_payload(payload)
        _stage_index = _level_manager.current_index

func _save_progress() -> void:
    if not is_instance_valid(_hero):
        return
    var payload := _hero.export_save_payload()
    if _level_manager:
        var lvl_payload := _level_manager.to_save_payload()
        for k in lvl_payload:
            payload[k] = lvl_payload[k]
    _save_repository.save_game(payload)

func _load_stage(index: int, with_transition: bool = true) -> void:
    if _transitioning:
        return
    _transitioning = true
    var prev_index := _stage_index
    _stage_index = clampi(index, 0, (_level_manager.count() - 1) if _level_manager else 2)
    if _level_manager:
        _level_manager.set_stage(_stage_index)
    var config := _level_manager.get_config(_stage_index) if _level_manager else null
    # cleanup previous stage without leaking (no duplicate Hero/HUD/Controls)
    if is_instance_valid(_stage_root):
        # ensure we do not duplicate hero/hud/controls: only stage_root is freed
        _stage_root.cleanup()
        _stage_root = null
    if is_instance_valid(_boss):
        _boss.queue_free()
        _boss = null
    # build new LevelRoot
    _stage_root = LevelRoot.new()
    _stage_root.configure(config)
    _stage_root.checkpoint_reached.connect(_on_checkpoint_reached)
    _stage_root.exit_reached.connect(_on_exit_reached)
    add_child(_stage_root)
    # move LevelRoot behind hero but above background (z 0 zone, hero 1)
    _stage_root.z_index = 0
    # defer build to ensure inside tree
    _stage_root.build()
    # hero spawn at stage spawn or checkpoint (new stage -> spawn)
    var spawn_pos := config.spawn if config else Vector2(180, 406)
    _hero.prepare_for_stage(spawn_pos)
    _hero.set_camera_world_width(config.width if config else 2400.0)
    # spawn enemies from config
    _spawn_enemies_from_config(config)
    # spawn boss if final
    if config and config.has_boss:
        _spawn_boss(config.boss_position)
    # HUD update
    if is_instance_valid(_hud):
        _hud.set_stage(_stage_index + 1, _level_manager.count() if _level_manager else 3, config.display_name if config else "STAGE")
        _hud.bind_boss(_boss)
    _stage_remaining = int(config.enemies.size()) if config else 0
    if config and config.has_boss:
        _stage_remaining += 1
    _stage_clear = false
    _save_progress()
    if with_transition:
        await _play_transition(prev_index, _stage_index)
    _transitioning = false

func _spawn_enemies_from_config(config: LevelConfig) -> void:
    if config == null or not is_instance_valid(_stage_root):
        return
    for entry in config.enemies:
        if not entry is Dictionary:
            continue
        var kind_str := String(entry.get("kind", "warden"))
        var pos := entry.get("position", Vector2.ZERO) as Vector2
        var kind := EnemyController.Kind.WARDEN if kind_str == "warden" else EnemyController.Kind.WRAITH
        var enemy := EnemyController.new()
        enemy.configure(kind, _hero)
        enemy.position = pos
        enemy.defeated.connect(_on_enemy_defeated)
        enemy.death_finished.connect(_on_enemy_death_finished)
        _stage_root.add_child(enemy)

func _spawn_boss(pos: Vector2) -> void:
    _boss = BossController.new()
    _boss.configure(_hero)
    _boss.position = pos
    _boss.defeated.connect(_on_boss_defeated)
    _boss.death_finished.connect(_on_boss_death_finished)
    _stage_root.add_child(_boss)

func _on_enemy_defeated(_exp: int, _gold: int) -> void:
    _stage_remaining = maxi(0, _stage_remaining - 1)
    _check_stage_complete()

func _on_enemy_death_finished() -> void:
    # pool cleanup handled by enemy itself, ensure no leak
    pass

func _on_boss_defeated(exp_reward: int, gold_reward: int) -> void:
    _on_enemy_defeated(exp_reward, gold_reward)

func _on_boss_death_finished() -> void:
    _stage_clear = true
    if is_instance_valid(_hud):
        _hud.show_banner("RIFT SEALED", "Run complete", 1.0)
    get_tree().create_timer(1.2).timeout.connect(_advance_or_complete)

func _on_checkpoint_reached(id: StringName, pos: Vector2) -> void:
    if _level_manager:
        _level_manager.activate_checkpoint(id, pos)
    _save_progress()

func _on_checkpoint_activated(id: StringName, pos: Vector2) -> void:
    # forwarded from level_manager, also save
    _save_progress()

func _on_stage_changed(index: int, config: LevelConfig) -> void:
    _stage_index = index

func _on_run_completed() -> void:
    if is_instance_valid(_hud):
        _hud.show_banner("RIFT SEALED", "Run complete", 1.0)

func _on_exit_reached() -> void:
    if _stage_clear or _stage_remaining <= 0:
        _advance_or_complete()
    else:
        # require clearing enemies before exit
        pass

func _advance_or_complete() -> void:
    if _level_manager and _level_manager.advance_stage():
        _load_stage(_level_manager.current_index, true)
    else:
        _on_run_completed()

func _check_stage_complete() -> void:
    if _stage_remaining <= 0 and not _stage_clear:
        # non-boss stages complete when enemies cleared; boss stages wait for boss death_finished
        var cfg := _level_manager.get_current() if _level_manager else null
        if cfg == null or not cfg.has_boss:
            _stage_clear = true
            get_tree().create_timer(0.7).timeout.connect(_advance_or_complete)

func _play_transition(from: int, to: int) -> void:
    if not is_instance_valid(_hud):
        await get_tree().create_timer(0.12).timeout
        return
    var config := _level_manager.get_config(to) if _level_manager else null
    var stage_name := config.display_name if config else "NEXT RIFT"
    _hud.show_banner("STAGE %d" % (to + 1), stage_name, 0.28)
    await get_tree().create_timer(0.28).timeout

func _toggle_user_pause() -> void:
    _paused_by_user = not _paused_by_user
    get_tree().paused = _paused_by_user
    if is_instance_valid(_hud):
        _hud.set_pause_state(_paused_by_user)
    if is_instance_valid(_controls):
        _controls.reset_inputs()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        if is_instance_valid(_controls):
            _controls.reset_inputs()

func _on_stage_changed_legacy() -> void:
    pass
