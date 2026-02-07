extends Control
class_name SkipCircleDrawer

var progress: float = 0.0

@export var radius: float = 16.0
@export var arc_width: float = 3.0
@export var arc_color: Color = Color(1, 1, 1, 0.8)

func _draw() -> void:
	if progress <= 0.0:
		return
	var center := size / 2.0
	var start_angle := -PI / 2.0
	var end_angle := start_angle + TAU * clampf(progress, 0.0, 1.0)
	draw_arc(center, radius, start_angle, end_angle, 32, arc_color, arc_width)
