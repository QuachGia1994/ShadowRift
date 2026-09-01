extends Control
class_name GameHud

const GOLD := Color(0.92, 0.73, 0.34)
const TEXT := Color(0.92, 0.94, 0.97)
const MUTED := Color(0.64, 0.70, 0.78)
const SAFE_EDGE_FALLBACK := 18.0

const HUD_FRAME := preload("res://assets/ui/hud_frame.png")
const BAR_UNDER := preload("res://assets/ui/bar_under.png")
const HP_FILL := preload("res://assets/ui/hp_fill.png")
const MP_FILL := preload("res://assets/ui/mp_fill.png")
const EXP_FILL := preload("res://assets/ui/exp_fill.png")
const BOSS_FILL := preload("res://assets/ui/boss_fill.png")
const ICON_RUST_BLADE := preload("res://assets/ui/icon_rust_blade.png")
const ICON_RIFT_SABER := preload("res://assets/ui/icon_rift_saber.png")
const ICON_ASH_VEST := preload("res://assets/ui/icon_ash_vest.png")
const ICON_WARDEN_MAIL := preload("res://assets/ui/icon_warden_mail.png")
const ITEM_ICONS := {"Rust Blade": ICON_RUST_BLADE, "Rift Saber": ICON_RIFT_SABER, "Ash Vest": ICON_ASH_VEST, "Warden Mail": ICON_WARDEN_MAIL}

var _hero: Hero
var _boss: BossController
var _hero_snapshot: Dictionary = {}
var _boss_current := 0
var _boss_maximum := 1
var _paused := false

var _panel: NinePatchRect
var _level_label: Label
var _level_caption: Label
var _hp_bar: TextureProgressBar
var _mp_bar: TextureProgressBar
var _exp_bar: TextureProgressBar
var _gold_chip: Label
var _atk_chip: Label
var _def_chip: Label
var _weapon_slot: NinePatchRect
var _weapon_icon: TextureRect
var _weapon_slot_label: Label
var _weapon_name_label: Label
var _armor_slot: NinePatchRect
var _armor_icon: TextureRect
var _armor_slot_label: Label
var _armor_name_label: Label
var _stage_label: Label
var _boss_bar: TextureProgressBar
var _boss_name_label: Label
var _fps_label: Label
var _pause_overlay: Control
var _pause_title: Label
var _pause_hint: Label
var _banner_panel: NinePatchRect
var _banner_title: Label
var _banner_hint: Label
var _banner_tween: Tween
var _last_safe := Rect2()
var _text_cache := {}

func configure(hero: Hero, boss: BossController = null) -> void:
	_hero = hero
	_hero.resources_changed.connect(_on_hero_resources_changed)
	_hero_snapshot = _hero.get_resource_snapshot()
	bind_boss(boss)

func bind_boss(boss: BossController) -> void:
	if is_instance_valid(_boss) and _boss.health_changed.is_connected(_on_boss_health_changed):
		_boss.health_changed.disconnect(_on_boss_health_changed)
	_boss = boss
	_boss_current = 0
	_boss_maximum = 1
	if is_instance_valid(_boss):
		_boss.health_changed.connect(_on_boss_health_changed)
		var boss_health := _boss.get_health_snapshot()
		_boss_current = boss_health.x
		_boss_maximum = boss_health.y

func set_stage(stage_number: int, total_stages: int, stage_name: String) -> void:
	if is_instance_valid(_stage_label):
		_stage_label.text = "%d/%d · %s" % [stage_number, total_stages, stage_name]

func show_banner(title: String, hint: String, duration: float = 0.9) -> void:
	if not is_instance_valid(_banner_panel):
		return
	if is_instance_valid(_banner_tween):
		_banner_tween.kill()
	_banner_title.text = title
	_banner_hint.text = hint
	_banner_panel.visible = true
	_banner_panel.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(maxf(0.15, duration))
	_banner_tween.tween_property(_banner_panel, "modulate:a", 0.0, 0.2)
	_banner_tween.tween_callback(func() -> void:
		_banner_panel.visible = false
		_banner_panel.modulate.a = 1.0
	)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_build_controls()
	_refresh_values()

func _input(event: InputEvent) -> void:
	if _paused or not event is InputEventScreenTouch or not event.pressed or not is_instance_valid(_hero):
		return
	if _weapon_rect().has_point(event.position):
		_hero.cycle_equipment(&"weapon")
	elif _armor_rect().has_point(event.position):
		_hero.cycle_equipment(&"armor")

func _process(_delta: float) -> void:
	var safe := _safe_area_rect()
	if safe != _last_safe:
		_last_safe = safe
		_layout(safe)
	_refresh_values()

func _on_hero_resources_changed(snapshot: Dictionary) -> void:
	_hero_snapshot = snapshot

func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_current = current
	_boss_maximum = maximum

func set_pause_state(paused: bool) -> void:
	_paused = paused
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = paused

func _weapon_rect() -> Rect2:
	var safe := _safe_area_rect()
	return Rect2(safe.position + Vector2(2.0, 114.0), Vector2(146.0, 29.0))

func _armor_rect() -> Rect2:
	var safe := _safe_area_rect()
	return Rect2(safe.position + Vector2(154.0, 114.0), Vector2(146.0, 29.0))

func _safe_area_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = size
	var fallback := Rect2(Vector2(SAFE_EDGE_FALLBACK, SAFE_EDGE_FALLBACK), Vector2(maxf(1.0, viewport_size.x - SAFE_EDGE_FALLBACK * 2.0), maxf(1.0, viewport_size.y - SAFE_EDGE_FALLBACK * 2.0)))
	var display_size := DisplayServer.screen_get_size()
	var display_safe := DisplayServer.get_display_safe_area()
	if display_size.x <= 0 or display_size.y <= 0 or display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return fallback
	return MobileControls.scale_safe_area(viewport_size, display_size, display_safe)

func _build_controls() -> void:
	_panel = NinePatchRect.new()
	_panel.texture = HUD_FRAME
	_panel.patch_margin_left = 12
	_panel.patch_margin_right = 12
	_panel.patch_margin_top = 12
	_panel.patch_margin_bottom = 12
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_level_label = _make_label("1", 20, Color(1.0, 0.87, 0.55))
	_level_caption = _make_label("LEVEL", 9, MUTED)
	_hp_bar = _make_bar(HP_FILL, 18)
	_mp_bar = _make_bar(MP_FILL, 15)
	_exp_bar = _make_bar(EXP_FILL, 11)
	_gold_chip = _make_chip(GOLD)
	_atk_chip = _make_chip(Color(0.90, 0.48, 0.32))
	_def_chip = _make_chip(Color(0.36, 0.69, 0.83))
	_weapon_slot = _make_slot()
	_weapon_icon = _make_icon()
	_weapon_slot.add_child(_weapon_icon)
	_weapon_slot_label = _make_label("BLADE", 8, GOLD)
	_weapon_slot.add_child(_weapon_slot_label)
	_weapon_name_label = _make_label("", 10, Color(0.88, 0.90, 0.94))
	_weapon_slot.add_child(_weapon_name_label)
	_armor_slot = _make_slot()
	_armor_icon = _make_icon()
	_armor_slot.add_child(_armor_icon)
	_armor_slot_label = _make_label("ARMOR", 8, GOLD)
	_armor_slot.add_child(_armor_slot_label)
	_armor_name_label = _make_label("", 10, Color(0.88, 0.90, 0.94))
	_armor_slot.add_child(_armor_name_label)
	_stage_label = _make_label("1/3 · RIFT APPROACH", 13, MUTED)
	_boss_name_label = _make_label("RIFT WARDEN", 10, Color(0.88, 0.67, 0.70))
	_boss_bar = _make_bar(BOSS_FILL, 17)
	_fps_label = _make_label("", 10, Color(0.45, 0.86, 0.70))
	_banner_panel = NinePatchRect.new()
	_banner_panel.texture = HUD_FRAME
	_banner_panel.patch_margin_left = 12
	_banner_panel.patch_margin_right = 12
	_banner_panel.patch_margin_top = 12
	_banner_panel.patch_margin_bottom = 12
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.visible = false
	add_child(_banner_panel)
	_banner_title = _make_label("", 18, Color.WHITE)
	_banner_hint = _make_label("", 10, MUTED)
	_banner_panel.add_child(_banner_title)
	_banner_panel.add_child(_banner_hint)
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	add_child(_pause_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.006, 0.010, 0.022, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dim)
	var pause_panel := NinePatchRect.new()
	pause_panel.texture = HUD_FRAME
	pause_panel.patch_margin_left = 12
	pause_panel.patch_margin_right = 12
	pause_panel.patch_margin_top = 12
	pause_panel.patch_margin_bottom = 12
	pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(pause_panel)
	pause_panel.name = "PausePanel"
	_pause_title = _make_label("PAUSED", 27, Color.WHITE)
	_pause_overlay.add_child(_pause_title)
	_pause_hint = _make_label("Tap || to resume", 13, Color(0.74, 0.79, 0.87))
	_pause_overlay.add_child(_pause_hint)
	_pause_overlay.set_meta("panel", pause_panel)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_bar(fill: Texture2D, height: int) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.texture_under = BAR_UNDER
	bar.texture_progress = fill
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 4
	bar.stretch_margin_right = 4
	bar.stretch_margin_top = 4
	bar.stretch_margin_bottom = 4
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.custom_minimum_size = Vector2(219.0, float(height))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar

func _make_chip(accent: Color) -> Label:
	var label := _make_label("", 10, accent)
	add_child(label)
	return label

func _make_slot() -> NinePatchRect:
	var slot := NinePatchRect.new()
	slot.texture = HUD_FRAME
	slot.patch_margin_left = 12
	slot.patch_margin_right = 12
	slot.patch_margin_top = 12
	slot.patch_margin_bottom = 12
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	return slot

func _make_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	return icon

func _layout(safe: Rect2) -> void:
	if _hero_snapshot.is_empty():
		return
	var origin := safe.position
	_panel.position = origin
	_panel.size = Vector2(302.0, 108.0)
	_level_label.position = origin + Vector2(22.0, 20.0)
	_level_caption.position = origin + Vector2(17.0, 56.0)
	_hp_bar.position = origin + Vector2(65.0, 11.0)
	_hp_bar.size = Vector2(219.0, 18.0)
	_mp_bar.position = origin + Vector2(65.0, 35.0)
	_mp_bar.size = Vector2(219.0, 15.0)
	_exp_bar.position = origin + Vector2(65.0, 57.0)
	_exp_bar.size = Vector2(219.0, 11.0)
	_gold_chip.position = origin + Vector2(70.0, 79.0)
	_atk_chip.position = origin + Vector2(162.0, 79.0)
	_def_chip.position = origin + Vector2(228.0, 79.0)
	var weapon_rect := _weapon_rect()
	_weapon_slot.position = weapon_rect.position
	_weapon_slot.size = weapon_rect.size
	_weapon_icon.position = weapon_rect.position + Vector2(6.0, 3.0)
	_weapon_icon.size = Vector2(22.0, 22.0)
	_weapon_slot_label.position = weapon_rect.position + Vector2(32.0, 1.0)
	_weapon_name_label.position = weapon_rect.position + Vector2(32.0, 12.0)
	var armor_rect := _armor_rect()
	_armor_slot.position = armor_rect.position
	_armor_slot.size = armor_rect.size
	_armor_icon.position = armor_rect.position + Vector2(6.0, 3.0)
	_armor_icon.size = Vector2(22.0, 22.0)
	_armor_slot_label.position = armor_rect.position + Vector2(32.0, 1.0)
	_armor_name_label.position = armor_rect.position + Vector2(32.0, 12.0)
	var center_x := safe.position.x + safe.size.x * 0.5
	_stage_label.position = Vector2(center_x - 92.0, safe.position.y - 6.0)
	var boss_width := minf(430.0, safe.size.x * 0.38)
	_boss_bar.position = Vector2(center_x - boss_width * 0.5, safe.position.y + 28.0)
	_boss_bar.size = Vector2(boss_width, 17.0)
	_boss_name_label.position = Vector2(center_x - boss_width * 0.5, safe.position.y + 2.0)
	_fps_label.position = Vector2(safe.end.x - 58.0, safe.position.y + 2.0)
	_banner_panel.position = Vector2(center_x - 150.0, safe.position.y + 62.0)
	_banner_panel.size = Vector2(300.0, 64.0)
	_banner_title.position = Vector2(18.0, 9.0)
	_banner_hint.position = Vector2(18.0, 34.0)
	var pause_panel: NinePatchRect = _pause_overlay.get_meta("panel")
	var pause_center := safe.get_center()
	pause_panel.position = pause_center - Vector2(155.0, 61.0)
	pause_panel.size = Vector2(310.0, 122.0)
	_pause_title.position = pause_center - Vector2(54.0, 32.0)
	_pause_hint.position = pause_center + Vector2(-62.0, 8.0)

func _set_cached(label: Label, key: String, value: String) -> void:
	if _text_cache.get(key) != value:
		_text_cache[key] = value
		label.text = value

func _refresh_values() -> void:
	if _hero_snapshot.is_empty():
		return
	_set_cached(_level_label, "level", "%d" % int(_hero_snapshot.level))
	_hp_bar.max_value = maxi(1, int(_hero_snapshot.max_health))
	_hp_bar.value = int(_hero_snapshot.health)
	_mp_bar.max_value = maxi(1, int(_hero_snapshot.max_mana))
	_mp_bar.value = int(_hero_snapshot.mana)
	_exp_bar.max_value = maxi(1, int(_hero_snapshot.exp_to_next))
	_exp_bar.value = int(_hero_snapshot.exp)
	_set_cached(_gold_chip, "gold", "G %d" % int(_hero_snapshot.gold))
	_set_cached(_atk_chip, "atk", "ATK %d" % int(_hero_snapshot.attack))
	_set_cached(_def_chip, "def", "DEF %d" % int(_hero_snapshot.defense))
	var weapon_icon: Texture2D = ITEM_ICONS.get(str(_hero_snapshot.weapon_name))
	var armor_icon: Texture2D = ITEM_ICONS.get(str(_hero_snapshot.armor_name))
	if weapon_icon != null:
		_weapon_icon.texture = weapon_icon
	if armor_icon != null:
		_armor_icon.texture = armor_icon
	_set_cached(_weapon_name_label, "weapon", str(_hero_snapshot.weapon_name))
	_set_cached(_armor_name_label, "armor", str(_hero_snapshot.armor_name))
	var fps := Engine.get_frames_per_second()
	_set_cached(_fps_label, "fps", "%d FPS" % fps)
	var fps_healthy := fps >= 55
	if _text_cache.get("fps_healthy") != fps_healthy:
		_text_cache["fps_healthy"] = fps_healthy
		_fps_label.add_theme_color_override("font_color", Color(0.45, 0.86, 0.70) if fps_healthy else Color(0.95, 0.70, 0.27))
	var boss_visible := is_instance_valid(_boss) and _boss_current > 0
	_boss_bar.visible = boss_visible
	_boss_name_label.visible = boss_visible
	if boss_visible:
		_boss_bar.max_value = maxi(1, _boss_maximum)
		_boss_bar.value = _boss_current
