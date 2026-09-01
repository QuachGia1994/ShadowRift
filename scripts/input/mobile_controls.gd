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

var _left_touch := -1
var _left_origin := Vector2.ZERO
var _left_position := Vector2.ZERO
var _button_owners := {"attack": -1, "jump": -1, "skill_one": -1, "skill_two": -1}
var _pending_actions := {"attack": false, "jump": false, "skill_one": false, "skill_two": false}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	queue_redraw()

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
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		pause_requested.emit()
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _left_touch and not get_tree().paused:
		_left_position = event.position
		queue_redraw()

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
	if event.pressed:
		if event.position.distance_to(_pause_center()) <= 36.0:
			pause_requested.emit()
			queue_redraw()
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
	queue_redraw()

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
	queue_redraw()

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

func _draw() -> void:
	_draw_joystick()
	_draw_action_button("attack", Color(0.72, 0.12, 0.19, 0.92), "A", "ATTACK")
	_draw_action_button("jump", Color(0.10, 0.56, 0.72, 0.92), "J", "JUMP")
	_draw_action_button("skill_one", Color(0.10, 0.39, 0.74, 0.92), "1", "SKILL")
	_draw_action_button("skill_two", Color(0.40, 0.16, 0.66, 0.92), "2", "SKILL")
	_draw_pause()

func _draw_joystick() -> void:
	var center := _joystick_rest_center()
	if _left_touch >= 0:
		center = _left_origin
	var active := _left_touch >= 0
	var outer_alpha := 0.78 if active else 0.48
	draw_circle(center, JOYSTICK_RADIUS + 10.0, Color(0.03, 0.045, 0.075, outer_alpha * 0.45))
	draw_circle(center, JOYSTICK_RADIUS, Color(0.045, 0.065, 0.105, outer_alpha))
	draw_arc(center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.78, 0.66, 0.39, 0.86 if active else 0.58), 3.0)
	var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for direction in directions:
		var inner: Vector2 = center + direction * 50.0
		var outer: Vector2 = center + direction * 59.0
		draw_line(inner, outer, Color(0.75, 0.79, 0.86, 0.34), 2.0)
	var knob_offset := Vector2.ZERO
	if active:
		knob_offset = (_left_position - _left_origin).limit_length(JOYSTICK_RADIUS - 16.0)
	var knob_center := center + knob_offset
	draw_circle(knob_center, JOYSTICK_KNOB_RADIUS + 5.0, Color(0.02, 0.03, 0.05, 0.5))
	draw_circle(knob_center, JOYSTICK_KNOB_RADIUS, Color(0.64, 0.53, 0.32, 0.92 if active else 0.72))
	draw_arc(knob_center, JOYSTICK_KNOB_RADIUS, 0.0, TAU, 32, Color(0.95, 0.82, 0.52, 0.72), 2.0)

func _draw_action_button(action: String, color: Color, label: String, caption: String) -> void:
	var center := _button_center(action)
	var pressed := int(_button_owners[action]) >= 0
	var radius := BUTTON_RADIUS * (0.92 if pressed else 1.0)
	draw_circle(center, BUTTON_RADIUS + 8.0, Color(color.r, color.g, color.b, 0.12))
	draw_circle(center, radius, color.lightened(0.18) if pressed else color)
	draw_circle(center + Vector2(0.0, 7.0), radius * 0.82, Color(0.02, 0.025, 0.045, 0.16))
	draw_arc(center, BUTTON_RADIUS, 0.0, TAU, 40, Color(0.94, 0.80, 0.48, 0.95), 3.0)
	var label_size := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25)
	draw_string(ThemeDB.fallback_font, center + Vector2(-label_size.x * 0.5, label_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
	var caption_size := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	draw_string(ThemeDB.fallback_font, center + Vector2(-caption_size.x * 0.5, BUTTON_RADIUS + 16.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.82, 0.85, 0.90, 0.68))

func _draw_pause() -> void:
	var center := _pause_center()
	draw_circle(center, 28.0, Color(0.02, 0.03, 0.055, 0.78))
	draw_arc(center, 27.0, 0.0, TAU, 32, Color(0.78, 0.82, 0.90, 0.80), 2.0)
	draw_rect(Rect2(center + Vector2(-7.0, -9.0), Vector2(4.0, 18.0)), Color.WHITE)
	draw_rect(Rect2(center + Vector2(3.0, -9.0), Vector2(4.0, 18.0)), Color.WHITE)
