extends Area2D
class_name Hitbox

var actor: Node2D
var attack_kind := &"basic_one"
var _active_time := 0.0
var _already_hit: Dictionary = {}

func configure(owner_actor: Node2D, shape_size: Vector2) -> void:
	actor = owner_actor
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	monitorable = false
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = shape_size
	collision.shape = shape
	add_child(collision)
	area_entered.connect(_on_area_entered)

func activate(kind: StringName, duration: float, local_offset: Vector2) -> void:
	attack_kind = kind
	position = local_offset
	_active_time = maxf(0.01, duration)
	_already_hit.clear()
	monitoring = true

func tick(delta: float) -> void:
	_active_time = maxf(0.0, _active_time - delta)
	if _active_time <= 0.0:
		monitoring = false

func _on_area_entered(area: Area2D) -> void:
	if _active_time <= 0.0 or not area is Hurtbox:
		return
	var hurtbox := area as Hurtbox
	if not is_instance_valid(hurtbox.actor) or hurtbox.actor == actor:
		return
	var target_id := hurtbox.actor.get_instance_id()
	if _already_hit.has(target_id):
		return
	_already_hit[target_id] = true
	var authority := get_tree().get_first_node_in_group("combat_authority") as CombatAuthority
	if is_instance_valid(authority):
		authority.resolve_hit(actor, hurtbox.actor, attack_kind)
