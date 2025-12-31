extends Node
class_name StatsManager

signal stats_changed(hope, discontent, order, faith)
signal stat_threshold_reached(stat_name: String, value: int)

var hope: int = 50
var discontent: int = 50
var order: int = 50
var faith: int = 50

func apply_effects(effect: Dictionary) -> void:
	# apply deltas
	hope += int(effect.get("Hope", 0))
	discontent += int(effect.get("Discontent", 0))
	order += int(effect.get("Order", 0))
	faith += int(effect.get("Faith", 0))

	# check death BEFORE clamping (so we can detect <0 or >100)
	_check_out_of_bounds()

	# now clamp for UI display
	_clamp_stats()
	_emit()

func _check_out_of_bounds() -> void:
	# Emit only one, fixed priority
	if hope < 0 or hope > 100:
		stat_threshold_reached.emit("hope", hope)
		return
	if discontent < 0 or discontent > 100:
		stat_threshold_reached.emit("discontent", discontent)
		return
	if order < 0 or order > 100:
		stat_threshold_reached.emit("order", order)
		return
	if faith < 0 or faith > 100:
		stat_threshold_reached.emit("faith", faith)
		return

func _clamp_stats() -> void:
	hope = clamp(hope, 0, 100)
	discontent = clamp(discontent, 0, 100)
	order = clamp(order, 0, 100)
	faith = clamp(faith, 0, 100)

func _emit() -> void:
	stats_changed.emit(hope, discontent, order, faith)

func reset() -> void:
	hope = 50
	discontent = 50
	order = 50
	faith = 50
	_emit()
