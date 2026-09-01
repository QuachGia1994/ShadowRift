extends Node
class_name HealthComponent

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, knockback: Vector2)
signal depleted

var maximum := 100
var current := 100
var iframe_duration := 0.48
var _iframe_remaining := 0.0

func configure(maximum_health: int, invulnerability_seconds: float = 0.48) -> void:
	maximum = maxi(1, maximum_health)
	current = maximum
	iframe_duration = maxf(0.0, invulnerability_seconds)
	health_changed.emit(current, maximum)

func tick(delta: float) -> void:
	_iframe_remaining = maxf(0.0, _iframe_remaining - delta)

func apply_canonical_damage(amount: int, knockback: Vector2) -> bool:
	if amount <= 0 or current <= 0 or _iframe_remaining > 0.0:
		return false
	current = maxi(0, current - amount)
	_iframe_remaining = iframe_duration
	health_changed.emit(current, maximum)
	damaged.emit(amount, knockback)
	if current == 0:
		depleted.emit()
	return true

func restore(amount: int) -> void:
	if amount <= 0 or current <= 0:
		return
	current = mini(maximum, current + amount)
	health_changed.emit(current, maximum)

func set_maximum(next_maximum: int, preserve_ratio: bool = true) -> void:
	var ratio := float(current) / float(maxi(1, maximum))
	maximum = maxi(1, next_maximum)
	current = clampi(int(round(maximum * ratio)) if preserve_ratio else mini(current, maximum), 0, maximum)
	health_changed.emit(current, maximum)

func set_current(next_current: int) -> void:
	current = clampi(next_current, 0, maximum)
	health_changed.emit(current, maximum)

func is_invulnerable() -> bool:
	return _iframe_remaining > 0.0
