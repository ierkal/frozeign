extends Node
class_name StatsManager

signal stats_changed(hope, discontent, order, faith)
signal stat_threshold_reached(stat_name: String, value: int)

var hope: int = GameConstants.DEFAULT_STAT_VALUE
var discontent: int = GameConstants.DEFAULT_STAT_VALUE
var order: int = GameConstants.DEFAULT_STAT_VALUE
var faith: int = GameConstants.DEFAULT_STAT_VALUE

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
	if hope < GameConstants.STAT_MIN or hope > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("hope", hope)
		return
	if discontent < GameConstants.STAT_MIN or discontent > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("discontent", discontent)
		return
	if order < GameConstants.STAT_MIN or order > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("order", order)
		return
	if faith < GameConstants.STAT_MIN or faith > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("faith", faith)
		return

func _clamp_stats() -> void:
	hope = clamp(hope, GameConstants.STAT_MIN, GameConstants.STAT_MAX)
	discontent = clamp(discontent, GameConstants.STAT_MIN, GameConstants.STAT_MAX)
	order = clamp(order, GameConstants.STAT_MIN, GameConstants.STAT_MAX)
	faith = clamp(faith, GameConstants.STAT_MIN, GameConstants.STAT_MAX)

func _emit() -> void:
	stats_changed.emit(hope, discontent, order, faith)

func reset_stats() -> void:
	hope = GameConstants.DEFAULT_STAT_VALUE
	discontent = GameConstants.DEFAULT_STAT_VALUE
	order = GameConstants.DEFAULT_STAT_VALUE
	faith = GameConstants.DEFAULT_STAT_VALUE
	stats_changed.emit(hope, discontent, order, faith)
