extends Control
class_name GameHud

const PANEL_BG := Color(0.025, 0.035, 0.065, 0.90)
const PANEL_BG_SOFT := Color(0.035, 0.05, 0.085, 0.82)
const GOLD := Color(0.92, 0.73, 0.34)
const TEXT := Color(0.92, 0.94, 0.97)
const MUTED := Color(0.64, 0.70, 0.78)
const SAFE_EDGE_FALLBACK := 18.0

var _hero: Hero
var _boss: BossController
var _hero_snapshot: Dictionary = {}
var _boss_current := 0
var _boss_maximum := 1
var _paused := false

func configure(hero: Hero, boss: BossController) -> void:
	_hero = hero
	_boss = boss
	_hero.resources_changed.connect(_on_hero_resources_changed)
	_boss.health_changed.connect(_on_boss_health_changed)
	_hero_snapshot = _hero.get_resource_snapshot()
	var boss_health := _boss.get_health_snapshot()
	_boss_current = boss_health.x
	_boss_maximum = boss_health.y

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if _paused or not event is InputEventScreenTouch or not event.pressed or not is_instance_valid(_hero):
		return
	if _weapon_rect().has_point(event.position):
		_hero.cycle_equipment(&"weapon")
	elif _armor_rect().has_point(event.position):
		_hero.cycle_equipment(&"armor")

func _process(_delta: float) -> void:
	queue_redraw()

func _on_hero_resources_changed(snapshot: Dictionary) -> void:
	_hero_snapshot = snapshot

func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_current = current
	_boss_maximum = maximum

func set_pause_state(paused: bool) -> void:
	_paused = paused
	queue_redraw()

func _weapon_rect() -> Rect2:
	var safe := _safe_area_rect()
	return Rect2(safe.position + Vector2(2.0, 114.0), Vector2(146.0, 29.0))

func _armor_rect() -> Rect2:
	var safe := _safe_area_rect()
	return Rect2(safe.position + Vector2(154.0, 114.0), Vector2(146.0, 29.0))

func _draw() -> void:
	if _hero_snapshot.is_empty():
		return
	_draw_player_hud()
	_draw_stage_and_boss()
	_draw_status_cluster()
	if _paused:
		_draw_pause_overlay()

func _draw_player_hud() -> void:
	var safe := _safe_area_rect()
	var origin := safe.position
	var panel := Rect2(origin + Vector2(0.0, 0.0), Vector2(302.0, 108.0))
	_draw_panel(panel, PANEL_BG, Color(0.60, 0.48, 0.26, 0.74))
	draw_circle(origin + Vector2(32.0, 32.0), 23.0, Color(0.08, 0.105, 0.16, 0.96))
	draw_arc(origin + Vector2(32.0, 32.0), 23.0, 0.0, TAU, 32, GOLD, 2.0)
	draw_string(ThemeDB.fallback_font, origin + Vector2(20.0, 39.0), "%d" % int(_hero_snapshot.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.87, 0.55))
	draw_string(ThemeDB.fallback_font, origin + Vector2(17.0, 66.0), "LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
	_draw_bar(Rect2(origin + Vector2(65.0, 11.0), Vector2(219.0, 18.0)), int(_hero_snapshot.health), int(_hero_snapshot.max_health), Color(0.76, 0.10, 0.17), "HP")
	_draw_bar(Rect2(origin + Vector2(65.0, 35.0), Vector2(219.0, 15.0)), int(_hero_snapshot.mana), int(_hero_snapshot.max_mana), Color(0.08, 0.48, 0.82), "MP")
	_draw_bar(Rect2(origin + Vector2(65.0, 57.0), Vector2(219.0, 11.0)), int(_hero_snapshot.exp), int(_hero_snapshot.exp_to_next), Color(0.76, 0.56, 0.17), "EXP")
	_draw_chip(Rect2(origin + Vector2(64.0, 76.0), Vector2(86.0, 23.0)), "G %d" % int(_hero_snapshot.gold), GOLD)
	_draw_chip(Rect2(origin + Vector2(156.0, 76.0), Vector2(60.0, 23.0)), "ATK %d" % int(_hero_snapshot.attack), Color(0.90, 0.48, 0.32))
	_draw_chip(Rect2(origin + Vector2(222.0, 76.0), Vector2(62.0, 23.0)), "DEF %d" % int(_hero_snapshot.defense), Color(0.36, 0.69, 0.83))
	_draw_equipment_slot(_weapon_rect(), "BLADE", str(_hero_snapshot.weapon_name))
	_draw_equipment_slot(_armor_rect(), "ARMOR", str(_hero_snapshot.armor_name))

func _draw_stage_and_boss() -> void:
	var safe := _safe_area_rect()
	var center_x := safe.position.x + safe.size.x * 0.5
	var boss_width := minf(430.0, safe.size.x * 0.38)
	var boss_rect := Rect2(center_x - boss_width * 0.5, safe.position.y + 28.0, boss_width, 17.0)
	draw_string(ThemeDB.fallback_font, Vector2(center_x - 14.0, safe.position.y + 11.0), "1/1", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
	if is_instance_valid(_boss) and _boss_current > 0:
		draw_string(ThemeDB.fallback_font, boss_rect.position + Vector2(0.0, -7.0), "RIFT WARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.88, 0.67, 0.70))
		_draw_bar(boss_rect, _boss_current, _boss_maximum, Color(0.60, 0.04, 0.13), "")

func _draw_status_cluster() -> void:
	var safe := _safe_area_rect()
	var fps := Engine.get_frames_per_second()
	var fps_color := Color(0.45, 0.86, 0.70) if fps >= 55 else Color(0.95, 0.70, 0.27)
	_draw_chip(Rect2(safe.end.x - 62.0, safe.position.y, 62.0, 22.0), "%d FPS" % fps, fps_color)

func _draw_pause_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.006, 0.010, 0.022, 0.78))
	var panel := Rect2(size.x * 0.5 - 155.0, size.y * 0.5 - 61.0, 310.0, 122.0)
	_draw_panel(panel, Color(0.025, 0.035, 0.065, 0.94), Color(0.64, 0.67, 0.74, 0.46))
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 54.0, size.y * 0.5 - 10.0), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 82.0, size.y * 0.5 + 24.0), "Tap || to resume", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.74, 0.79, 0.87))

func _safe_area_rect() -> Rect2:
	var fallback := Rect2(Vector2(SAFE_EDGE_FALLBACK, SAFE_EDGE_FALLBACK), Vector2(maxf(1.0, size.x - SAFE_EDGE_FALLBACK * 2.0), maxf(1.0, size.y - SAFE_EDGE_FALLBACK * 2.0)))
	var display_size := DisplayServer.screen_get_size()
	var display_safe := DisplayServer.get_display_safe_area()
	if display_size.x <= 0 or display_size.y <= 0 or display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return fallback
	var scale := Vector2(size.x / float(display_size.x), size.y / float(display_size.y))
	return Rect2(Vector2(display_safe.position) * scale, Vector2(display_safe.size) * scale)

func _draw_panel(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(0.0, 3.0), rect.size), Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 1.5)
	draw_line(rect.position + Vector2(1.0, 1.0), rect.position + Vector2(rect.size.x - 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.05), 1.0)

func _draw_chip(rect: Rect2, label: String, accent: Color) -> void:
	_draw_panel(rect, PANEL_BG_SOFT, Color(accent.r, accent.g, accent.b, 0.32))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, 10, accent)

func _draw_bar(rect: Rect2, current: int, maximum: int, color: Color, label: String) -> void:
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)
	draw_rect(rect, Color(0.02, 0.027, 0.048, 0.98))
	var fill_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * ratio, rect.size.y - 4.0))
	draw_rect(fill_rect, color)
	draw_line(fill_rect.position + Vector2(1.0, 1.0), fill_rect.position + Vector2(maxf(1.0, fill_rect.size.x - 1.0), 1.0), Color(1.0, 1.0, 1.0, 0.16), 1.0)
	draw_rect(rect, Color(0.74, 0.64, 0.42, 0.54), false, 1.0)
	if not label.is_empty():
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6.0, rect.size.y - 4.0), "%s %d/%d" % [label, current, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)

func _draw_equipment_slot(rect: Rect2, slot_name: String, item_name: String) -> void:
	_draw_panel(rect, Color(0.032, 0.043, 0.070, 0.88), Color(0.48, 0.40, 0.24, 0.48))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7.0, 11.0), slot_name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, 8, GOLD)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7.0, 23.0), item_name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, 10, Color(0.88, 0.90, 0.94))
