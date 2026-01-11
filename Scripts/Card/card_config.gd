extends Resource
class_name CardConfig

@export_category("Thresholds/Speeds")
@export var rotate_threshold: int = 180
@export var rotate_speed: float = 0.002
@export var position_threshold: int = 200
@export var input_position_threshold: int = 140

@export_category("Animations")
@export var throw_duration: float = 0.5
@export var throw_distance: float = 400
@export var throw_fall_distance: float = 1200
@export var flip_duration: float = 0.2
@export var reset_duration: float = 0.15

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"

func side_from_positions(original_x: float, current_x: float) -> String:
	if current_x > original_x:
		return SIDE_RIGHT
	return SIDE_LEFT
