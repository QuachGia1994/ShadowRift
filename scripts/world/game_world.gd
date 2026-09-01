extends Node2D

const WORLD_WIDTH := 2400.0
const GROUND_Y := 440.0

var _hero: Hero
var _boss: BossController
var _save_repository := SaveRepository.new()
var _projectile_pool: ReusablePool
var _damage_number_pool: ReusablePool
var _server_authority_enabled := OS.has_feature("server_authoritative")
var _server_client: ServerAuthorityClient
var _server_enemies: Dictionary = {}
var _hud: GameHud
var _controls: MobileControls
var _paused_by_user := false

func _ready() -> void:
	_create_zone()
	_create_combat_authority()
	_create_pools()
	_create_controls()
	_create_hero()
	if not _server_authority_enabled:
		_load_progress()
	_create_enemies()
	_create_boss()
	_create_hud()
	if _server_authority_enabled:
		_create_server_authority()
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
	add_child(_hero)

func _create_enemies() -> void:
	var warden := EnemyController.new()
	warden.configure(EnemyController.Kind.WARDEN, _hero)
	warden.position = Vector2(620.0, GROUND_Y - 28.0)
	warden.server_entity_id = "warden-1"
	warden.defeated.connect(_hero.grant_rewards)
	warden.defeated.connect(_save_progress.unbind(2))
	add_child(warden)
	_server_enemies[warden.server_entity_id] = warden
	var wraith := EnemyController.new()
	wraith.configure(EnemyController.Kind.WRAITH, _hero)
	wraith.position = Vector2(1160.0, GROUND_Y - 28.0)
	wraith.server_entity_id = "wraith-1"
	wraith.defeated.connect(_hero.grant_rewards)
	wraith.defeated.connect(_save_progress.unbind(2))
	add_child(wraith)
	_server_enemies[wraith.server_entity_id] = wraith

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
	_hud = GameHud.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.configure(_hero, _boss)
	layer.add_child(_hud)

func _create_server_authority() -> void:
	_server_client = ServerAuthorityClient.new()
	_server_client.process_mode = Node.PROCESS_MODE_ALWAYS
	_server_client.snapshot_received.connect(_apply_server_snapshot)
	_server_client.server_events_received.connect(_apply_server_events)
	_server_client.connection_state_changed.connect(_on_server_connection_changed)
	add_child(_server_client)
	_hero.bind_server_authority(_server_client)
	_server_client.connect_to_authority()

func _apply_server_snapshot(snapshot: Dictionary) -> void:
	var player: Variant = snapshot.get("player", {})
	if player is Dictionary:
		_hero.apply_server_snapshot(player)
	var enemies: Variant = snapshot.get("enemies", [])
	if not enemies is Array:
		return
	for enemy_snapshot in enemies:
		if not enemy_snapshot is Dictionary:
			continue
		var entity_id := str(enemy_snapshot.get("id", ""))
		if entity_id == _boss.server_entity_id:
			_boss.apply_server_snapshot(enemy_snapshot)
		elif _server_enemies.has(entity_id):
			(_server_enemies[entity_id] as EnemyController).apply_server_snapshot(enemy_snapshot)

func _apply_server_events(events: Array) -> void:
	for event in events:
		if not event is Dictionary or not event.has("amount"):
			continue
		var target_id := str(event.get("targetId", ""))
		var target: Node2D
		if str(event.get("type", "")) == "player_damage":
			target = _hero
		elif target_id == _boss.server_entity_id:
			target = _boss
		else:
			target = _server_enemies.get(target_id) as Node2D
		if is_instance_valid(target):
			_show_damage_number(target.global_position + Vector2(0.0, -46.0), int(event.amount))

func _on_server_connection_changed(state: String, detail: String) -> void:
	var available := state == "ONLINE"
	_hero.set_server_connection_available(available)
	if is_instance_valid(_hud):
		_hud.set_network_status(state, detail)

func _toggle_user_pause() -> void:
	_paused_by_user = not _paused_by_user
	if _server_authority_enabled and is_instance_valid(_server_client):
		_server_client.set_move_direction(0)
	if is_instance_valid(_hud):
		_hud.set_pause_state(_paused_by_user)
	get_tree().paused = _paused_by_user

func _load_progress() -> void:
	var result := _save_repository.load_game()
	if result.ok:
		_hero.restore_save_payload(result.payload)

func _save_progress() -> void:
	if _server_authority_enabled:
		return
	if is_instance_valid(_hero):
		_save_repository.save_game(_hero.export_save_payload())

func _notification(what: int) -> void:
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
