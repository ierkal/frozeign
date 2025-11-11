extends Node
class_name CardDecision

signal decision_changed(side: String)
signal decision_cleared
signal committed(side: String)

var _is_deciding := false
var _decided_side := ""
var _original_pos_x := 0.0

func set_origin_x(x: float) -> void:
	_original_pos_x = x

func on_drag_updated(current_x: float, _rot: float, threshold_ok: bool, side_now: String) -> void:
	if threshold_ok:
		if not _is_deciding or _decided_side != side_now:
			_is_deciding = true
			_decided_side = side_now
			decision_changed.emit(side_now)
	else:
		if _is_deciding:
			_is_deciding = false
			_decided_side = ""
			decision_cleared.emit()

func commit_if_threshold(threshold_ok: bool, fallback_side: String) -> bool:
	if not threshold_ok:
		return false
	if _decided_side == "":
		_decided_side = fallback_side
	committed.emit(_decided_side)
	return true

func last_side() -> String:
	return _decided_side
