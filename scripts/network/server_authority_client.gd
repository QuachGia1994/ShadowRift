extends Node
class_name ServerAuthorityClient

signal snapshot_received(snapshot: Dictionary)
signal server_events_received(events: Array)
signal connection_state_changed(state: String, detail: String)

const SESSION_PATH := "user://server_session.cfg"
const MOVE_INTERVAL := 0.10
const SERVER_URL_SETTING := "shadow_rift/server/base_url"

enum Phase { OFFLINE, CONNECTING, ONLINE }

var phase := Phase.OFFLINE
var _http: HTTPRequest
var _base_url := ""
var _session_id := ""
var _token := ""
var _next_sequence := 1
var _request_kind := ""
var _inflight_command: Dictionary = {}
var _command_queue: Array[Dictionary] = []
var _move_direction := 0
var _move_time := 0.0

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)

func connect_to_authority() -> void:
	_base_url = str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).strip_edges().trim_suffix("/")
	if not _base_url.begins_with("https://"):
		_set_phase(Phase.OFFLINE, "invalid_server_url")
		return
	_set_phase(Phase.CONNECTING, "connecting")
	if _load_credentials():
		_request_kind = "resume"
		_send_request("%s/v1/sessions/%s" % [_base_url, _session_id], HTTPClient.METHOD_GET, _auth_headers())
	else:
		_create_session()

func is_online() -> bool:
	return phase == Phase.ONLINE

func set_move_direction(direction: int) -> void:
	_move_direction = clampi(direction, -1, 1)

func submit_action(action: String, fields: Dictionary = {}) -> bool:
	if not is_online() or action not in ["jump", "attack", "skill", "equip", "sync"]:
		return false
	var command := {"action": action}
	for key in fields:
		command[key] = fields[key]
	_enqueue(command)
	return true

func _process(delta: float) -> void:
	if not is_online():
		return
	_move_time -= delta
	if _move_time <= 0.0:
		_move_time = MOVE_INTERVAL
		_enqueue({"action": "move", "direction": _move_direction})

func _create_session() -> void:
	_request_kind = "create"
	_send_request("%s/v1/sessions" % _base_url, HTTPClient.METHOD_POST, [])

func _enqueue(command: Dictionary) -> void:
	if command.action == "move":
		for index in range(_command_queue.size() - 1, -1, -1):
			if _command_queue[index].action == "move":
				_command_queue[index] = command
				return
	_command_queue.append(command)
	_dispatch_next()

func _dispatch_next() -> void:
	if not is_online() or _request_kind != "" or _command_queue.is_empty():
		return
	_inflight_command = _command_queue.pop_front()
	_inflight_command.seq = _next_sequence
	_request_kind = "command"
	_send_request(
		"%s/v1/sessions/%s/commands" % [_base_url, _session_id],
		HTTPClient.METHOD_POST,
		_auth_headers() + PackedStringArray(["Content-Type: application/json"]),
		JSON.stringify(_inflight_command)
	)

func _send_request(url: String, method: HTTPClient.Method, headers: PackedStringArray, body := "") -> void:
	var error := _http.request(url, headers, method, body)
	if error != OK:
		_fail_closed("request_start_failed_%d" % error)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var completed_kind := _request_kind
	_request_kind = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_closed("network_error_%d" % result)
		return
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not decoded is Dictionary:
		_fail_closed("invalid_server_response")
		return
	var payload := decoded as Dictionary
	match completed_kind:
		"create":
			_handle_create(response_code, payload)
		"resume":
			_handle_resume(response_code, payload)
		"command":
			_handle_command(response_code, payload)

func _handle_create(response_code: int, payload: Dictionary) -> void:
	if response_code != 201 or not bool(payload.get("ok", false)):
		_fail_closed("session_create_rejected_%d" % response_code)
		return
	_session_id = str(payload.get("sessionId", ""))
	_token = str(payload.get("token", ""))
	if _session_id.length() != 36 or _token.length() < 32 or not payload.get("state") is Dictionary:
		_fail_closed("invalid_session_credentials")
		return
	_save_credentials()
	_accept_snapshot(payload.state)
	_set_phase(Phase.ONLINE, "connected")
	_dispatch_next()

func _handle_resume(response_code: int, payload: Dictionary) -> void:
	if response_code == 404:
		_clear_credentials()
		_create_session()
		return
	if response_code != 200 or not bool(payload.get("ok", false)) or not payload.get("state") is Dictionary:
		_fail_closed("session_resume_rejected_%d" % response_code)
		return
	_accept_snapshot(payload.state)
	_set_phase(Phase.ONLINE, "resumed")
	_dispatch_next()

func _handle_command(response_code: int, payload: Dictionary) -> void:
	_inflight_command.clear()
	if payload.get("state") is Dictionary:
		_accept_snapshot(payload.state)
	if response_code == 200 and bool(payload.get("ok", false)):
		var events: Variant = payload.get("events", [])
		if events is Array and not events.is_empty():
			server_events_received.emit(events)
	elif response_code != 409:
		_fail_closed("command_rejected_%d" % response_code)
		return
	_dispatch_next()

func _accept_snapshot(snapshot: Dictionary) -> void:
	_next_sequence = maxi(1, int(snapshot.get("lastSeq", 0)) + 1)
	snapshot_received.emit(snapshot)

func _auth_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer %s" % _token, "Accept: application/json"])

func _load_credentials() -> bool:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return false
	_session_id = str(config.get_value("authority", "session_id", ""))
	_token = str(config.get_value("authority", "token", ""))
	return _session_id.length() == 36 and _token.length() >= 32

func _save_credentials() -> void:
	var config := ConfigFile.new()
	config.set_value("authority", "session_id", _session_id)
	config.set_value("authority", "token", _token)
	config.save(SESSION_PATH)

func _clear_credentials() -> void:
	_session_id = ""
	_token = ""
	var absolute_path := ProjectSettings.globalize_path(SESSION_PATH)
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(absolute_path)

func _fail_closed(detail: String) -> void:
	_command_queue.clear()
	_inflight_command.clear()
	_move_direction = 0
	_set_phase(Phase.OFFLINE, detail)

func _set_phase(next_phase: Phase, detail: String) -> void:
	phase = next_phase
	connection_state_changed.emit("ONLINE" if phase == Phase.ONLINE else "CONNECTING" if phase == Phase.CONNECTING else "OFFLINE", detail)
