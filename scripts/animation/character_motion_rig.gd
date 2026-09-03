extends Node2D
class_name CharacterMotionRig2D

## Native cutout animation rig adapted from Godot's MIT Skeleton2D demo pattern.
## Gameplay owns state/timing; this node owns only articulated visual motion.

const PART_NAMES := [&"body", &"head", &"arm_back", &"arm_front", &"leg_back", &"leg_front"]
const LOCOMOTION_NAMES := [&"idle", &"move", &"jump_rise", &"fall"]

var _profile: StringName = &"hero"
var _cell := 192.0
var _base_offset := Vector2(-96.0, -129.0)
var _base_scale := 64.0 / 192.0
var _skin_paths: Dictionary = {}
var _current_skin := &""

var _flip_root: Node2D
var _skeleton: Skeleton2D
var _player: AnimationPlayer
var _bones: Dictionary = {}
var _poses: Dictionary = {}
var _sprites: Dictionary = {}
var _rest_positions: Dictionary = {}
var _land_locked := false

func configure(profile: StringName) -> void:
	_profile = profile
	match profile:
		&"hero":
			_cell = 192.0
			_base_offset = Vector2(-96.0, -129.0)
			_base_scale = 64.0 / 192.0
			_skin_paths = {
				&"idle": "res://assets/rig/hero/idle_parts.png",
				&"run": "res://assets/rig/hero/run_parts.png",
				&"jump": "res://assets/rig/hero/jump_parts.png",
				&"slash": "res://assets/rig/hero/slash_parts.png",
				&"magic": "res://assets/rig/hero/magic_parts.png",
			}
		&"warden":
			_cell = 192.0
			_base_offset = Vector2(-96.0, -126.0)
			_base_scale = 64.0 / 192.0
			_skin_paths = {&"default": "res://assets/rig/enemies/warden_parts.png"}
		&"wraith":
			_cell = 192.0
			_base_offset = Vector2(-96.0, -126.0)
			_base_scale = 64.0 / 192.0
			_skin_paths = {&"default": "res://assets/rig/enemies/wraith_parts.png"}
		&"boss":
			_cell = 256.0
			_base_offset = Vector2(-128.0, -206.0)
			_base_scale = 128.0 / 256.0
			_skin_paths = {&"default": "res://assets/rig/enemies/rift_warden_parts.png"}

func _ready() -> void:
	_build_nodes()
	_build_animations()
	_player.animation_finished.connect(_on_animation_finished)
	_apply_skin(_skin_for_animation(_initial_animation()))
	play(_initial_animation())

func set_facing(direction: float) -> void:
	if not is_instance_valid(_flip_root) or is_zero_approx(direction):
		return
	_flip_root.scale.x = -1.0 if direction < 0.0 else 1.0

func play(animation: StringName, speed: float = 1.0) -> void:
	if not is_instance_valid(_player) or not _player.has_animation(animation):
		return
	if _land_locked and animation in LOCOMOTION_NAMES:
		return
	if animation not in LOCOMOTION_NAMES and animation != &"land":
		_land_locked = false
	_apply_skin(_skin_for_animation(animation))
	var safe_speed := maxf(0.05, absf(speed))
	if _player.current_animation != animation or not _player.is_playing():
		_player.play(animation, 0.0, safe_speed)
		_player.advance(0.0)
	else:
		_player.speed_scale = safe_speed

func play_land() -> void:
	if _profile != &"hero" or not is_instance_valid(_player) or not _player.has_animation(&"land"):
		return
	_land_locked = true
	_apply_skin(&"jump")
	_player.play(&"land", 0.0, 1.0)
	_player.advance(0.0)

func get_animation_duration(animation: StringName) -> float:
	if not is_instance_valid(_player) or not _player.has_animation(animation):
		return 0.0
	return _player.get_animation(animation).length

func get_current_animation() -> StringName:
	return StringName(_player.current_animation) if is_instance_valid(_player) else &""

func get_bone_rotation_degrees(part: StringName) -> float:
	var pose := _poses.get(part) as Node2D
	return rad_to_deg(pose.rotation) if is_instance_valid(pose) else 0.0

func _initial_animation() -> StringName:
	match _profile:
		&"warden": return &"patrol"
		&"wraith": return &"hover"
		&"boss": return &"watch"
		_: return &"idle"

func _build_nodes() -> void:
	scale = Vector2(_base_scale, _base_scale)
	_flip_root = Node2D.new()
	_flip_root.name = "FlipRoot"
	add_child(_flip_root)
	_skeleton = Skeleton2D.new()
	_skeleton.name = "Skeleton2D"
	_flip_root.add_child(_skeleton)

	var pivots := {
		&"body": Vector2(_cell * 0.50, _cell * 0.57),
		&"head": Vector2(_cell * 0.50, _cell * 0.32),
		&"arm_back": Vector2(_cell * 0.38, _cell * 0.40),
		&"arm_front": Vector2(_cell * 0.62, _cell * 0.40),
		&"leg_back": Vector2(_cell * 0.44, _cell * 0.62),
		&"leg_front": Vector2(_cell * 0.56, _cell * 0.62),
	}
	var z_order := {&"arm_back": -3, &"leg_back": -2, &"body": 0, &"leg_front": 1, &"arm_front": 2, &"head": 3}
	for part in PART_NAMES:
		var bone := Bone2D.new()
		bone.name = String(part)
		bone.auto_calculate_length_and_angle = false
		bone.length = maxf(1.0, _cell * 0.10)
		bone.bone_angle = 0.0
		var pivot: Vector2 = pivots[part]
		bone.position = _base_offset + pivot
		_skeleton.add_child(bone)
		bone.rest = bone.transform
		_bones[part] = bone
		var pose := Node2D.new()
		pose.name = "Pose"
		bone.add_child(pose)
		_poses[part] = pose
		_rest_positions[part] = Vector2.ZERO
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = false
		sprite.position = _base_offset - bone.position
		sprite.z_index = int(z_order[part])
		pose.add_child(sprite)
		_sprites[part] = sprite

	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	_player.root_node = NodePath("..")
	add_child(_player)

func _apply_skin(skin: StringName) -> void:
	if skin == _current_skin or not _skin_paths.has(skin):
		return
	var texture := load(String(_skin_paths[skin])) as Texture2D
	if texture == null:
		push_error("Missing rig skin: %s" % String(_skin_paths[skin]))
		return
	for index in range(PART_NAMES.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(float(index) * _cell, 0.0), Vector2(_cell, _cell))
		var sprite := _sprites[PART_NAMES[index]] as Sprite2D
		sprite.texture = atlas
	_current_skin = skin

func _skin_for_animation(animation: StringName) -> StringName:
	if _profile != &"hero":
		return &"default"
	match animation:
		&"move": return &"run"
		&"jump_rise", &"fall", &"land": return &"jump"
		&"attack1", &"attack2", &"skill_one": return &"slash"
		&"skill_two": return &"magic"
		_: return &"idle"

func _build_animations() -> void:
	var library := AnimationLibrary.new()
	match _profile:
		&"hero": _build_hero_animations(library)
		&"warden": _build_warden_animations(library)
		&"wraith": _build_wraith_animations(library)
		&"boss": _build_boss_animations(library)
	_player.add_animation_library(&"", library)

func _build_hero_animations(library: AnimationLibrary) -> void:
	_add_motion(library, &"idle", 1.20, true, [0.0, 0.6, 1.2], {
		&"body": [-1.0, 1.2, -1.0], &"head": [1.0, -1.5, 1.0],
		&"arm_back": [-3.0, 2.0, -3.0], &"arm_front": [2.0, -2.0, 2.0],
	}, {&"body": [Vector2.ZERO, Vector2(0, -3), Vector2.ZERO]})
	_add_motion(library, &"move", 0.56, true, [0.0, 0.14, 0.28, 0.42, 0.56], {
		&"body": [3.0, -2.0, -3.0, 2.0, 3.0],
		&"head": [-2.0, 1.0, 2.0, -1.0, -2.0],
		&"arm_back": [20.0, 4.0, -20.0, -4.0, 20.0],
		&"arm_front": [-22.0, -5.0, 22.0, 5.0, -22.0],
		# Rotating painted leg cutouts by ~30 degrees resamples their soft alpha
		# into a visible blur. Keep leg rotation nearly neutral and sell the gait
		# with opposite-phase translation instead.
		&"leg_back": [-3.0, -1.0, 3.0, 1.0, -3.0],
		&"leg_front": [3.0, 1.0, -3.0, -1.0, 3.0],
	}, {
		&"body": [Vector2.ZERO, Vector2(0, -3), Vector2.ZERO, Vector2(0, -2), Vector2.ZERO],
		&"leg_back": [Vector2(3, 0), Vector2(1, 2), Vector2(-3, 0), Vector2(-1, -1), Vector2(3, 0)],
		&"leg_front": [Vector2(-3, 0), Vector2(-1, -1), Vector2(3, 0), Vector2(1, 2), Vector2(-3, 0)],
	})
	_add_motion(library, &"jump_rise", 0.28, false, [0.0, 0.28], {
		&"body": [-4.0, -7.0], &"head": [3.0, 7.0], &"arm_back": [10.0, 22.0],
		&"arm_front": [-14.0, -26.0], &"leg_back": [-12.0, -28.0], &"leg_front": [18.0, 34.0],
	}, {&"body": [Vector2.ZERO, Vector2(0, -3)]})
	_add_motion(library, &"fall", 0.42, true, [0.0, 0.21, 0.42], {
		&"body": [5.0, 7.0, 5.0], &"head": [-4.0, -6.0, -4.0],
		&"arm_back": [-10.0, -16.0, -10.0], &"arm_front": [12.0, 18.0, 12.0],
		&"leg_back": [18.0, 26.0, 18.0], &"leg_front": [-10.0, -18.0, -10.0],
	}, {})
	_add_motion(library, &"land", 0.16, false, [0.0, 0.07, 0.16], {
		&"body": [4.0, 10.0, 0.0], &"leg_back": [8.0, 24.0, 0.0], &"leg_front": [-8.0, -24.0, 0.0],
	}, {&"body": [Vector2(0, -2), Vector2(0, 5), Vector2.ZERO]})
	_add_motion(library, &"attack1", 0.22, false, [0.0, 0.07, 0.14, 0.22], {
		&"body": [-10.0, -14.0, 14.0, 2.0], &"head": [5.0, 8.0, -6.0, 0.0],
		&"arm_back": [14.0, 24.0, -10.0, 0.0], &"arm_front": [-58.0, -76.0, 46.0, 10.0],
		&"leg_back": [-8.0, -10.0, 8.0, 0.0], &"leg_front": [10.0, 12.0, -6.0, 0.0],
	}, {&"body": [Vector2(-3, 0), Vector2(-5, 0), Vector2(6, 0), Vector2.ZERO]})
	_add_motion(library, &"attack2", 0.22, false, [0.0, 0.08, 0.15, 0.22], {
		&"body": [9.0, 15.0, -16.0, 0.0], &"head": [-5.0, -7.0, 7.0, 0.0],
		&"arm_back": [-18.0, -30.0, 12.0, 0.0], &"arm_front": [48.0, 70.0, -52.0, 8.0],
		&"leg_back": [8.0, 12.0, -8.0, 0.0], &"leg_front": [-10.0, -14.0, 7.0, 0.0],
	}, {&"body": [Vector2(-2, 0), Vector2(-4, 0), Vector2(7, -1), Vector2.ZERO]})
	_add_motion(library, &"skill_one", 0.28, false, [0.0, 0.10, 0.19, 0.28], {
		&"body": [-15.0, -20.0, 20.0, 0.0], &"head": [8.0, 12.0, -8.0, 0.0],
		&"arm_back": [20.0, 34.0, -16.0, 0.0], &"arm_front": [-70.0, -92.0, 58.0, 8.0],
		&"leg_back": [-12.0, -16.0, 12.0, 0.0], &"leg_front": [14.0, 18.0, -10.0, 0.0],
	}, {&"body": [Vector2(-4, 0), Vector2(-7, -2), Vector2(9, 1), Vector2.ZERO]})
	_add_motion(library, &"skill_two", 0.34, false, [0.0, 0.12, 0.23, 0.34], {
		&"body": [-5.0, -9.0, 8.0, 0.0], &"head": [2.0, 5.0, -4.0, 0.0],
		&"arm_back": [-18.0, -35.0, 24.0, 0.0], &"arm_front": [18.0, 38.0, -26.0, 0.0],
		&"leg_back": [-5.0, -8.0, 4.0, 0.0], &"leg_front": [5.0, 8.0, -4.0, 0.0],
	}, {&"body": [Vector2.ZERO, Vector2(-3, -2), Vector2(4, 0), Vector2.ZERO]})
	_add_motion(library, &"hurt", 0.25, false, [0.0, 0.08, 0.25], {
		&"body": [0.0, -14.0, 0.0], &"head": [0.0, 12.0, 0.0],
		&"arm_back": [0.0, -18.0, 0.0], &"arm_front": [0.0, 22.0, 0.0],
	}, {&"body": [Vector2.ZERO, Vector2(-8, 1), Vector2.ZERO]})
	_add_motion(library, &"death", 0.66, false, [0.0, 0.20, 0.42, 0.66], {
		&"body": [0.0, 18.0, 58.0, 82.0], &"head": [0.0, -10.0, -22.0, -30.0],
		&"arm_back": [0.0, 20.0, 36.0, 42.0], &"arm_front": [0.0, -24.0, -38.0, -42.0],
		&"leg_back": [0.0, -12.0, -34.0, -46.0], &"leg_front": [0.0, 18.0, 40.0, 52.0],
	}, {&"body": [Vector2.ZERO, Vector2(0, 2), Vector2(4, 9), Vector2(8, 18)]})

func _build_warden_animations(library: AnimationLibrary) -> void:
	_add_walk_pair(library, &"patrol", 0.72, 24.0, 16.0)
	_add_walk_pair(library, &"aggro", 0.52, 32.0, 22.0)
	_add_motion(library, &"attack", 0.34, false, [0.0, 0.12, 0.22, 0.34], {
		&"body": [-8.0, -14.0, 15.0, 0.0], &"arm_front": [-48.0, -72.0, 50.0, 6.0],
		&"arm_back": [12.0, 22.0, -14.0, 0.0], &"leg_back": [-6.0, -10.0, 8.0, 0.0], &"leg_front": [8.0, 12.0, -6.0, 0.0],
	}, {&"body": [Vector2(-2, 0), Vector2(-5, 0), Vector2(7, 0), Vector2.ZERO]})
	_add_hurt_death(library, 0.24, 0.72)

func _build_wraith_animations(library: AnimationLibrary) -> void:
	_add_motion(library, &"hover", 0.90, true, [0.0, 0.45, 0.90], {
		&"body": [-3.0, 3.0, -3.0], &"head": [2.0, -3.0, 2.0],
		&"arm_back": [-10.0, 8.0, -10.0], &"arm_front": [12.0, -9.0, 12.0],
		&"leg_back": [-6.0, 7.0, -6.0], &"leg_front": [7.0, -6.0, 7.0],
	}, {&"body": [Vector2(0, 2), Vector2(0, -6), Vector2(0, 2)]})
	_add_motion(library, &"dash_attack", 0.25, false, [0.0, 0.08, 0.17, 0.25], {
		&"body": [-12.0, -20.0, 14.0, 0.0], &"arm_back": [18.0, 32.0, -14.0, 0.0],
		&"arm_front": [-22.0, -38.0, 18.0, 0.0], &"leg_back": [-12.0, -20.0, 10.0, 0.0], &"leg_front": [12.0, 20.0, -10.0, 0.0],
	}, {&"body": [Vector2(-3, 0), Vector2(-8, 0), Vector2(10, 0), Vector2.ZERO]})
	_add_motion(library, &"cast", 0.72, false, [0.0, 0.28, 0.54, 0.72], {
		&"body": [-3.0, -8.0, 5.0, 0.0], &"head": [2.0, 7.0, -4.0, 0.0],
		&"arm_back": [-12.0, -46.0, -18.0, -8.0], &"arm_front": [14.0, 52.0, 24.0, 8.0],
		&"leg_back": [-6.0, -12.0, 4.0, 0.0], &"leg_front": [7.0, 13.0, -4.0, 0.0],
	}, {&"body": [Vector2(0, 1), Vector2(0, -5), Vector2(2, -3), Vector2.ZERO]})
	_add_hurt_death(library, 0.24, 0.68)

func _build_boss_animations(library: AnimationLibrary) -> void:
	_add_motion(library, &"watch", 1.30, true, [0.0, 0.65, 1.30], {
		&"body": [-2.0, 2.0, -2.0], &"head": [2.0, -2.5, 2.0],
		&"arm_back": [-4.0, 4.0, -4.0], &"arm_front": [5.0, -4.0, 5.0],
	}, {&"body": [Vector2.ZERO, Vector2(0, -4), Vector2.ZERO]})
	_add_walk_pair(library, &"chase", 0.68, 28.0, 18.0)
	_add_motion(library, &"windup", 0.46, false, [0.0, 0.20, 0.46], {
		&"body": [0.0, -10.0, -18.0], &"head": [0.0, 6.0, 12.0],
		&"arm_back": [0.0, 18.0, 30.0], &"arm_front": [0.0, -46.0, -78.0],
		&"leg_back": [0.0, -9.0, -14.0], &"leg_front": [0.0, 12.0, 18.0],
	}, {&"body": [Vector2.ZERO, Vector2(-5, -2), Vector2(-10, -3)]})
	_add_motion(library, &"strike", 0.38, false, [0.0, 0.10, 0.22, 0.38], {
		&"body": [-18.0, 16.0, 24.0, 0.0], &"head": [12.0, -8.0, -12.0, 0.0],
		&"arm_back": [30.0, -12.0, -20.0, 0.0], &"arm_front": [-78.0, 62.0, 82.0, 8.0],
		&"leg_back": [-14.0, 12.0, 18.0, 0.0], &"leg_front": [18.0, -14.0, -20.0, 0.0],
	}, {&"body": [Vector2(-10, -3), Vector2(10, 0), Vector2(16, 2), Vector2.ZERO]})
	_add_hurt_death(library, 0.25, 1.00)

func _add_walk_pair(library: AnimationLibrary, name: StringName, length: float, leg_angle: float, arm_angle: float) -> void:
	_add_motion(library, name, length, true, [0.0, length * 0.25, length * 0.5, length * 0.75, length], {
		&"body": [3.0, -2.0, -3.0, 2.0, 3.0],
		&"head": [-2.0, 1.0, 2.0, -1.0, -2.0],
		&"arm_back": [arm_angle, 3.0, -arm_angle, -3.0, arm_angle],
		&"arm_front": [-arm_angle, -3.0, arm_angle, 3.0, -arm_angle],
		&"leg_back": [-leg_angle, -4.0, leg_angle, 5.0, -leg_angle],
		&"leg_front": [leg_angle, 5.0, -leg_angle, -4.0, leg_angle],
	}, {&"body": [Vector2.ZERO, Vector2(0, -3), Vector2.ZERO, Vector2(0, -2), Vector2.ZERO]})

func _add_hurt_death(library: AnimationLibrary, hurt_length: float, death_length: float) -> void:
	_add_motion(library, &"hurt", hurt_length, false, [0.0, hurt_length * 0.35, hurt_length], {
		&"body": [0.0, -13.0, 0.0], &"head": [0.0, 10.0, 0.0],
		&"arm_back": [0.0, -18.0, 0.0], &"arm_front": [0.0, 20.0, 0.0],
	}, {&"body": [Vector2.ZERO, Vector2(-7, 1), Vector2.ZERO]})
	_add_motion(library, &"death", death_length, false, [0.0, death_length * 0.30, death_length * 0.65, death_length], {
		&"body": [0.0, 16.0, 55.0, 82.0], &"head": [0.0, -10.0, -22.0, -30.0],
		&"arm_back": [0.0, 18.0, 34.0, 42.0], &"arm_front": [0.0, -20.0, -36.0, -44.0],
		&"leg_back": [0.0, -12.0, -34.0, -46.0], &"leg_front": [0.0, 16.0, 38.0, 50.0],
	}, {&"body": [Vector2.ZERO, Vector2(0, 3), Vector2(5, 12), Vector2(10, 22)]})

func _add_motion(library: AnimationLibrary, name: StringName, length: float, loop: bool, times: Array, rotations: Dictionary, position_offsets: Dictionary) -> void:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for part in PART_NAMES:
		var rotation_values: Array = rotations.get(part, [])
		if rotation_values.is_empty():
			rotation_values.resize(times.size())
			rotation_values.fill(0.0)
		_add_value_track(animation, NodePath("FlipRoot/Skeleton2D/%s/Pose:rotation" % String(part)), times, rotation_values, true)

		var offsets: Array = position_offsets.get(part, [])
		if offsets.is_empty():
			offsets.resize(times.size())
			offsets.fill(Vector2.ZERO)
		var absolute_positions: Array = []
		var rest: Vector2 = _rest_positions[part]
		for offset in offsets:
			var offset_value: Vector2 = offset
			absolute_positions.append(rest + offset_value)
		_add_value_track(animation, NodePath("FlipRoot/Skeleton2D/%s/Pose:position" % String(part)), times, absolute_positions, false)
	library.add_animation(name, animation)

func _add_value_track(animation: Animation, path: NodePath, times: Array, values: Array, degrees: bool) -> void:
	if times.size() != values.size():
		push_error("Animation track size mismatch: %s" % String(path))
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC_ANGLE if degrees else Animation.INTERPOLATION_CUBIC)
	for index in range(times.size()):
		var value: Variant = deg_to_rad(float(values[index])) if degrees else values[index]
		animation.track_insert_key(track, float(times[index]), value)

func _on_animation_finished(animation: StringName) -> void:
	if animation == &"land":
		_land_locked = false
