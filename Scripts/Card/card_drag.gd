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

func setup(owner_control: Control, original_pos: Vector2) -> void:
	_owner_control = owner_control
	_original_pos = original_pos
	mouse_filter = Control.MOUSE_FILTER_STOP  # ensure GUI input

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_offset = get_global_mouse_position().x - _owner_control.position.x
			_dragging = true
			drag_started.emit()
		else:
			_dragging = false
			drag_ended.emit()

func _process(_delta: float) -> void:
	if not _dragging:
		return

	var gx := get_global_mouse_position().x
	var desired_x := gx - _mouse_offset
	var min_x := _original_pos.x - float(cfg.position_threshold)
	var max_x := _original_pos.x + float(cfg.position_threshold)
	var clamped_x = clamp(desired_x, min_x, max_x)

	_owner_control.position.x = clamped_x

	var dx := _original_pos.x - _owner_control.position.x
	var clamped = clamp(-dx, -float(cfg.rotate_threshold), float(cfg.rotate_threshold))
	var rot = clamped * cfg.rotate_speed
	_owner_control.rotation = rot

	drag_updated.emit(_owner_control.position.x, rot)

func over_input_threshold() -> bool:
	return abs(_owner_control.position.x - _original_pos.x) > float(cfg.input_position_threshold)

func current_side() -> String:
	return cfg.side_from_positions(_original_pos.x, _owner_control.position.x)
