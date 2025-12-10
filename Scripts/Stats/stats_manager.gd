extends Node
class_name StatsManager

signal stats_changed(heat, discontent, hope, survivors)
signal stat_threshold_reached(stat_name: String, value: int)

var heat: int = 50
var discontent: int = 50
var hope: int = 50
var survivors: int = 50

func apply_effects(effect: Dictionary) -> void:
	heat += int(effect.get("Heat", 0))
	discontent += int(effect.get("Discontent", 0))
	hope += int(effect.get("Hope", 0))
	survivors += int(effect.get("Survivors", 0))

	_clamp_stats()
	_emit()
	_check_thresholds()

func _clamp_stats() -> void:
	heat = clamp(heat, 0, 100)
	discontent = clamp(discontent, 0, 100)
	hope = clamp(hope, 0, 100)
	survivors = clamp(survivors, 0, 100)

func _emit() -> void:
	emit_signal("stats_changed", heat, discontent, hope, survivors)

func _check_thresholds() -> void:
	# Only emit one threshold per apply, in a fixed priority
	if heat == 0 or heat == 100:
		emit_signal("stat_threshold_reached", "heat", heat)
		return

	if discontent == 0 or discontent == 100:
		emit_signal("stat_threshold_reached", "discontent", discontent)
		return

	if hope == 0 or hope == 100:
		emit_signal("stat_threshold_reached", "hope", hope)
		return

	if survivors == 0 or survivors == 100:
		emit_signal("stat_threshold_reached", "survivors", survivors)
		return
func reset() -> void:
	heat = 50
	discontent = 50
	hope = 50
	survivors = 50
	_emit()
