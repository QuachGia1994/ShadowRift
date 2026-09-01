extends Control
class_name MobileControls

const LEFT_ZONE_RATIO := 0.46
const JOYSTICK_RADIUS := 62.0
const BUTTON_RADIUS := 42.0

var _left_touch := -1
var _left_origin := Vector2.ZERO
var _left_position := Vector2.ZERO
var _button_owners := {"attack": -1, "skill_one": -1, "skill_two": -1}
var _pending_actions := {"attack": false, "skill_one": false, "skill_two": false}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _left_touch:
		_left_position = event.position
		queue_redraw()

func get_move_axis() -> Vector2:
	var keyboard_axis := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	if absf(keyboard_axis) > 0.0:
		return Vector2(keyboard_axis, 0.0)
	if _left_touch < 0:
		return Vector2.ZERO
	var offset := (_left_position - _left_origin) / JOYSTICK_RADIUS
	return Vector2(clampf(offset.x, -1.0, 1.0), clampf(offset.y, -1.0, 1.0))

func consume_action(action: StringName) -> bool:
	if not _pending_actions.has(action):
		return false
	var was_pending: bool = _pending_actions[action]
	_pending_actions[action] = false
	return was_pending

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if event.position.x < size.x * LEFT_ZONE_RATIO and _left_touch < 0:
			_left_touch = event.index
			_left_origin = event.position
			_left_position = event.position
		else:
			_claim_button(event.index, event.position)
	else:
		if event.index == _left_touch:
			_left_touch = -1
			_left_origin = Vector2.ZERO
			_left_position = Vector2.ZERO
		for action in _button_owners:
			if _button_owners[action] == event.index:
				_button_owners[action] = -1
	queue_redraw()

func _claim_button(touch_index: int, position: Vector2) -> void:
	for action in _button_owners:
		if _button_owners[action] < 0 and position.distance_to(_button_center(action)) <= BUTTON_RADIUS * 1.35:
			_button_owners[action] = touch_index
			_pending_actions[action] = true
			return

func _button_center(action: String) -> Vector2:
	match action:
		"attack":
			return Vector2(size.x - 88.0, size.y - 88.0)
		"skill_one":
			return Vector2(size.x - 205.0, size.y - 155.0)
		_:
			return Vector2(size.x - 245.0, size.y - 65.0)

func _draw() -> void:
	var joystick_center := _left_origin if _left_touch >= 0 else Vector2(105.0, size.y - 105.0)
	draw_circle(joystick_center, JOYSTICK_RADIUS, Color(0.08, 0.11, 0.18, 0.62))
	draw_arc(joystick_center, JOYSTICK_RADIUS, 0.0, TAU, 40, Color(0.72, 0.62, 0.38, 0.65), 3.0)
	var knob_offset := Vector2.ZERO
	if _left_touch >= 0:
		knob_offset = (_left_position - _left_origin).limit_length(JOYSTICK_RADIUS - 18.0)
	draw_circle(joystick_center + knob_offset, 24.0, Color(0.56, 0.48, 0.34, 0.82))
	_draw_button("attack", Color(0.68, 0.13, 0.16, 0.85), "A")
	_draw_button("skill_one", Color(0.10, 0.42, 0.76, 0.85), "1")
	_draw_button("skill_two", Color(0.39, 0.18, 0.66, 0.85), "2")

func _draw_button(action: String, color: Color, label: String) -> void:
	var center := _button_center(action)
	var pressed: bool = _button_owners[action] >= 0
	draw_circle(center, BUTTON_RADIUS * (0.92 if pressed else 1.0), color.lightened(0.16) if pressed else color)
	draw_arc(center, BUTTON_RADIUS, 0.0, TAU, 36, Color(0.92, 0.78, 0.45, 0.9), 3.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-7.0, 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

