extends Node
class_name StatsManager

signal stats_changed(heat, discontent, hope, survivors)

var heat: int = 50
var discontent: int = 50
var hope: int = 50
var survivors: int = 50

func apply_effects(effect: Dictionary) -> void:
	heat += int(effect.get("Heat", 0))
	discontent += int(effect.get("Discontent", 0))
	hope += int(effect.get("Hope", 0))
	survivors += int(effect.get("Survivors", 0))
	_emit()

func _emit() -> void:
	emit_signal("stats_changed", heat, discontent, hope, survivors)
