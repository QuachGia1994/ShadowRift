extends Node
class_name PerformanceBudget

signal budget_exceeded(draw_calls: int)

const DRAW_CALL_BUDGET := 50

var peak_draw_calls := 0
var _sample_time := 0.0

func _process(delta: float) -> void:
	_sample_time -= delta
	if _sample_time > 0.0:
		return
	_sample_time = 0.5
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	peak_draw_calls = maxi(peak_draw_calls, draw_calls)
	if draw_calls > DRAW_CALL_BUDGET:
		budget_exceeded.emit(draw_calls)

