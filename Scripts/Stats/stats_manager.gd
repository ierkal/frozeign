extends Node
class_name StatsManager

signal stats_changed(morale, dissent, authority, devotion)
signal stat_threshold_reached(stat_name: String, value: int)

var morale: int = GameConstants.DEFAULT_STAT_VALUE
var dissent: int = GameConstants.DEFAULT_STAT_VALUE
var authority: int = GameConstants.DEFAULT_STAT_VALUE
var devotion: int = GameConstants.DEFAULT_STAT_VALUE

func apply_effects(effect: Dictionary) -> void:
	# apply deltas
	morale += int(effect.get("Morale", 0))
	dissent += int(effect.get("Dissent", 0))
	authority += int(effect.get("Authority", 0))
	devotion += int(effect.get("Devotion", 0))

	# check death BEFORE clamping (so we can detect <0 or >100)
	_check_out_of_bounds()

	# now clamp for UI display
	_clamp_stats()
	_emit()

func _check_out_of_bounds() -> void:
	# Emit only one, fixed priority
	if morale < GameConstants.STAT_MIN or morale > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("morale", morale)
		return
	if dissent < GameConstants.STAT_MIN or dissent > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("dissent", dissent)
		return
	if authority < GameConstants.STAT_MIN or authority > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("authority", authority)
		return
	if devotion < GameConstants.STAT_MIN or devotion > GameConstants.STAT_MAX:
		stat_threshold_reached.emit("devotion", devotion)
		return

func _clamp_stats() -> void:
	morale = clamp(morale, GameConstants.STAT_MIN, GameConstants.STAT_MAX)
	dissent = clamp(dissent, GameConstants.STAT_MIN, GameConstants.STAT_MAX)
	authority = clamp(authority, GameConstants.STAT_MIN, GameConstants.STAT_MAX)
	devotion = clamp(devotion, GameConstants.STAT_MIN, GameConstants.STAT_MAX)

func _emit() -> void:
	stats_changed.emit(morale, dissent, authority, devotion)

func reset_stats() -> void:
	morale = GameConstants.DEFAULT_STAT_VALUE
	dissent = GameConstants.DEFAULT_STAT_VALUE
	authority = GameConstants.DEFAULT_STAT_VALUE
	devotion = GameConstants.DEFAULT_STAT_VALUE
	stats_changed.emit(morale, dissent, authority, devotion)
