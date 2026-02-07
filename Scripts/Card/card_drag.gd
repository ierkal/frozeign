extends Control
class_name CardDrag

signal drag_started
signal drag_updated(current_x: float, rotation: float)
signal drag_ended

@export var cfg: CardConfig

var _dragging := false
var _mouse_offset := 0.0
var _original_pos: Vector2
var _owner_control: Control
var _input_enabled := false
var _vertical_offset := 0.0  # Current accumulated vertical drift
var _mouse_y_start := 0.0  # Y position where drag began

func setup(owner_control: Control, original_pos: Vector2) -> void:
	_owner_control = owner_control
	_original_pos = original_pos
	mouse_filter = Control.MOUSE_FILTER_STOP  # ensure GUI input

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled

func _on_gui_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_offset = get_global_mouse_position().x - _owner_control.position.x
			_mouse_y_start = get_global_mouse_position().y
			_vertical_offset = 0.0
			_dragging = true
			drag_started.emit()
		else:
			_dragging = false
			_vertical_offset = 0.0
			drag_ended.emit()

func _process(delta: float) -> void:
	if not _dragging:
		return

	var gx := get_global_mouse_position().x
	var desired_x := gx - _mouse_offset
	var min_x := _original_pos.x - float(cfg.position_threshold)
	var max_x := _original_pos.x + float(cfg.position_threshold)
	var clamped_x = clamp(desired_x, min_x, max_x)

	_owner_control.position.x = clamped_x

	# Vertical drift: slowly follow vertical mouse delta from grab point
	var mouse_y_delta := get_global_mouse_position().y - _mouse_y_start
	var target_offset := clampf(mouse_y_delta, -cfg.vertical_max_offset, cfg.vertical_max_offset)
	_vertical_offset = lerpf(_vertical_offset, target_offset, cfg.vertical_speed)
	_owner_control.position.y = _original_pos.y + _vertical_offset

	var dx := _original_pos.x - _owner_control.position.x
	var clamped = clamp(-dx, -float(cfg.rotate_threshold), float(cfg.rotate_threshold))
	var rot = clamped * cfg.rotate_speed
	_owner_control.rotation = rot

	drag_updated.emit(_owner_control.position.x, rot)

func over_input_threshold() -> bool:
	return abs(_owner_control.position.x - _original_pos.x) > float(cfg.input_position_threshold)

func current_side() -> String:
	return cfg.side_from_positions(_original_pos.x, _owner_control.position.x)

func swipe_ratio() -> float:
	return clamp(abs(_owner_control.position.x - _original_pos.x) / float(cfg.position_threshold), 0.0, 1.0)
