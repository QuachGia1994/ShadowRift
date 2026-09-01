extends Control
class_name GameHud

var _hero: Hero
var _boss: BossController
var _hero_snapshot: Dictionary = {}
var _boss_current := 0
var _boss_maximum := 1

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _on_hero_resources_changed(snapshot: Dictionary) -> void:
	_hero_snapshot = snapshot

func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_current = current
	_boss_maximum = maximum

func _draw() -> void:
	if _hero_snapshot.is_empty():
		return
	var panel := Rect2(24.0, 18.0, 330.0, 106.0)
	draw_rect(panel, Color(0.025, 0.03, 0.055, 0.88))
	draw_rect(panel, Color(0.57, 0.42, 0.22, 0.85), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(38.0, 40.0), "LV %d" % int(_hero_snapshot.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.96, 0.86, 0.61))
	_draw_bar(Rect2(92.0, 27.0, 245.0, 22.0), int(_hero_snapshot.health), int(_hero_snapshot.max_health), Color(0.72, 0.12, 0.18), "HP")
	_draw_bar(Rect2(92.0, 55.0, 245.0, 18.0), int(_hero_snapshot.mana), int(_hero_snapshot.max_mana), Color(0.08, 0.48, 0.82), "MP")
	_draw_bar(Rect2(92.0, 79.0, 245.0, 14.0), int(_hero_snapshot.exp), int(_hero_snapshot.exp_to_next), Color(0.78, 0.60, 0.18), "EXP")
	draw_string(ThemeDB.fallback_font, Vector2(93.0, 116.0), "Gold %d" % int(_hero_snapshot.gold), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.94, 0.76, 0.26))
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 16.0, 34.0), "1/1", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 88.0, 28.0), "FPS %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.84, 0.88))
	if is_instance_valid(_boss) and _boss_current > 0:
		_draw_bar(Rect2(size.x * 0.5 - 180.0, 54.0, 360.0, 18.0), _boss_current, _boss_maximum, Color(0.58, 0.06, 0.14), "RIFT WARDEN")

func _draw_bar(rect: Rect2, current: int, maximum: int, color: Color, label: String) -> void:
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)
	draw_rect(rect, Color(0.04, 0.045, 0.07, 0.95))
	draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * ratio, rect.size.y - 4.0)), color)
	draw_rect(rect, Color(0.78, 0.66, 0.42, 0.72), false, 1.5)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7.0, rect.size.y - 5.0), "%s %d/%d" % [label, current, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
