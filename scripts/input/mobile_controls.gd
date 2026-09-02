extends Control
class_name MobileControls

signal pause_requested

const LEFT_ZONE_RATIO := 0.46
const JOYSTICK_RADIUS := 72.0
const JOYSTICK_KNOB_RADIUS := 28.0
const JOYSTICK_DEAD_ZONE := 0.12
const BUTTON_RADIUS := 38.0
const BUTTON_HIT_RADIUS := 56.0
const SAFE_EDGE_FALLBACK := 18.0
const ACTION_ORDER := ["attack", "jump", "skill_one", "skill_two"]

const JOYSTICK_BASE := preload("res://assets/ui/joystick_base.png")
const JOYSTICK_KNOB := preload("res://assets/ui/joystick_knob.png")
const BUTTON_TEXTURES := {"attack": preload("res://assets/ui/button_attack.png"), "jump": preload("res://assets/ui/button_jump.png"), "skill_one": preload("res://assets/ui/button_skill_1.png"), "skill_two": preload("res://assets/ui/button_skill_2.png")}
const PAUSE_TEXTURE := preload("res://assets/ui/button_pause.png")

var _left_touch := -1
var _left_origin := Vector2.ZERO
var _left_position := Vector2.ZERO
var _button_owners := {"attack": -1, "jump": -1, "skill_one": -1, "skill_two": -1}
var _pending_actions := {"attack": false, "jump": false, "skill_one": false, "skill_two": false}
var _held_actions := {"attack": false, "jump": false, "skill_one": false, "skill_two": false}
var _released_actions := {"attack": false, "jump": false, "skill_one": false, "skill_two": false}
var _gameplay_enabled := true

var _joystick_base: TextureRect
var _joystick_knob: TextureRect
var _button_visuals := {}
var _pause_visual: TextureRect
var _last_safe := Rect2()
var _visuals_dirty := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_build_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_inputs()

func reset_inputs() -> void:
	_left_touch = -1
	_left_origin = Vector2.ZERO
	_left_position = Vector2.ZERO
	for action in ACTION_ORDER:
		_button_owners[action] = -1
		_pending_actions[action] = false
		_held_actions[action] = false
		_released_actions[action] = false
	_visuals_dirty = true
	_update_visuals()

func set_gameplay_enabled(enabled: bool) -> void:
	_gameplay_enabled = enabled
	if not enabled:
		reset_inputs()

func is_action_held(action: StringName) -> bool:
	return bool(_held_actions.get(String(action), false))

func consume_action_released(action: StringName) -> bool:
	var key := String(action)
	if not _released_actions.has(key):
		return false
	var was_released := bool(_released_actions[key])
	_released_actions[key] = false
	return was_released

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		pause_requested.emit()
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _left_touch and not get_tree().paused:
		_left_position = event.position
		_update_visuals()

func get_move_axis() -> Vector2:
	var keyboard_axis := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	if absf(keyboard_axis) > 0.0:
		return Vector2(keyboard_axis, 0.0)
	if _left_touch < 0:
		return Vector2.ZERO
	var offset := (_left_position - _left_origin) / JOYSTICK_RADIUS
	if offset.length() <= JOYSTICK_DEAD_ZONE:
		return Vector2.ZERO
	var limited := offset.limit_length(1.0)
	var scaled_strength := (limited.length() - JOYSTICK_DEAD_ZONE) / (1.0 - JOYSTICK_DEAD_ZONE)
	return limited.normalized() * clampf(scaled_strength, 0.0, 1.0)

func consume_action(action: StringName) -> bool:
	if not _pending_actions.has(action):
		return false
	var was_pending: bool = _pending_actions[action]
	_pending_actions[action] = false
	return was_pending

func _handle_touch(event: InputEventScreenTouch) -> void:
	if not _gameplay_enabled:
		return
	if event.pressed:
		if event.position.distance_to(_pause_center()) <= 36.0:
			pause_requested.emit()
			return
		if get_tree().paused:
			return
		if event.position.x < size.x * LEFT_ZONE_RATIO and _left_touch < 0:
			_left_touch = event.index
			_left_origin = _joystick_rest_center()
			_left_position = event.position
		else:
			_claim_button(event.index, event.position)
	else:
		if event.index == _left_touch:
			_left_touch = -1
			_left_origin = Vector2.ZERO
			_left_position = Vector2.ZERO
		for action in ACTION_ORDER:
			if int(_button_owners[action]) == event.index:
				_button_owners[action] = -1
				_held_actions[action] = false
				_released_actions[action] = true
	_visuals_dirty = true
	_update_visuals()

func _claim_button(touch_index: int, position: Vector2) -> void:
	var nearest_action := ""
	var nearest_distance := INF
	for action in ACTION_ORDER:
		if int(_button_owners[action]) >= 0:
			continue
		var distance := position.distance_to(_button_center(action))
		if distance <= BUTTON_HIT_RADIUS and distance < nearest_distance:
			nearest_action = action
			nearest_distance = distance
	if nearest_action.is_empty():
		return
	_button_owners[nearest_action] = touch_index
	_pending_actions[nearest_action] = true
	_held_actions[nearest_action] = true
	_released_actions[nearest_action] = false
	_visuals_dirty = true
	_update_visuals()

func _joystick_rest_center() -> Vector2:
	var safe := _safe_area_rect()
	return Vector2(safe.position.x + 112.0, safe.end.y - 102.0)

func _button_center(action: String) -> Vector2:
	var safe := _safe_area_rect()
	match action:
		"attack":
			return Vector2(safe.end.x - 86.0, safe.end.y - 88.0)
		"jump":
			return Vector2(safe.end.x - 88.0, safe.end.y - 188.0)
		"skill_one":
			return Vector2(safe.end.x - 190.0, safe.end.y - 156.0)
		_:
			return Vector2(safe.end.x - 198.0, safe.end.y - 58.0)

func _pause_center() -> Vector2:
	var safe := _safe_area_rect()
	return Vector2(safe.end.x - 48.0, safe.position.y + 60.0)

func _safe_area_rect() -> Rect2:
	var fallback := Rect2(Vector2(SAFE_EDGE_FALLBACK, SAFE_EDGE_FALLBACK), Vector2(maxf(1.0, size.x - SAFE_EDGE_FALLBACK * 2.0), maxf(1.0, size.y - SAFE_EDGE_FALLBACK * 2.0)))
	var display_size := DisplayServer.screen_get_size()
	var display_safe := DisplayServer.get_display_safe_area()
	if display_size.x <= 0 or display_size.y <= 0 or display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return fallback
	return scale_safe_area(size, display_size, display_safe)

static func scale_safe_area(viewport_size: Vector2, display_size: Vector2i, safe_area: Rect2i) -> Rect2:
	if display_size.x <= 0 or display_size.y <= 0:
		return Rect2(Vector2.ZERO, viewport_size)
	var scale := Vector2(viewport_size.x / float(display_size.x), viewport_size.y / float(display_size.y))
	return Rect2(Vector2(safe_area.position) * scale, Vector2(safe_area.size) * scale)

func _build_visuals() -> void:
	_joystick_base = _make_visual(JOYSTICK_BASE)
	_joystick_knob = _make_visual(JOYSTICK_KNOB)
	for action in ACTION_ORDER:
		_button_visuals[action] = _make_visual(BUTTON_TEXTURES[action])
	_pause_visual = _make_visual(PAUSE_TEXTURE)
	_update_visuals()

func _make_visual(texture: Texture2D) -> TextureRect:
	var visual := TextureRect.new()
	visual.texture = texture
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	return visual

func _process(_delta: float) -> void:
	var safe := _safe_area_rect()
	if _visuals_dirty or safe != _last_safe:
		_last_safe = safe
		_visuals_dirty = false
		_update_visuals()

func _update_visuals() -> void:
	if not is_instance_valid(_joystick_base):
		return
	var center := _joystick_rest_center()
	if _left_touch >= 0:
		center = _left_origin
	_joystick_base.position = center - Vector2(88.0, 88.0)
	var knob_offset := Vector2.ZERO
	if _left_touch >= 0:
		knob_offset = (_left_position - _left_origin).limit_length(JOYSTICK_RADIUS - 16.0)
	_joystick_knob.position = center + knob_offset - Vector2(36.0, 36.0)
	for action in ACTION_ORDER:
		var visual: TextureRect = _button_visuals[action]
		var pressed := int(_button_owners[action]) >= 0
		visual.position = _button_center(action) - Vector2(48.0, 48.0)
		visual.modulate = Color(1.25, 1.25, 1.25, 1.0) if pressed else Color.WHITE
	_pause_visual.position = _pause_center() - Vector2(32.0, 32.0)
