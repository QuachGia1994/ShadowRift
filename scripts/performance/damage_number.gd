extends Node2D
class_name PooledDamageNumber

var _amount := 0
var _remaining := 0.0

func activate(amount: int, origin: Vector2) -> void:
	_amount = amount
	global_position = origin
	_remaining = 0.72
	modulate = Color.WHITE
	queue_redraw()

func _process(delta: float) -> void:
	position.y -= 38.0 * delta
	_remaining -= delta
	modulate.a = clampf(_remaining / 0.72, 0.0, 1.0)
	if _remaining <= 0.0:
		var pool := get_parent() as ReusablePool
		if is_instance_valid(pool):
			pool.release(self)

func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-12.0, 0.0), str(_amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.78, 0.28))

