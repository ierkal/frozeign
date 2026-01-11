extends Control
class_name SurvivedDaysUI

@onready var day_label: Label = %DaysValue
@onready var total_day_label: Label = %TotalDaysValue # Asla resetlenmez
@onready var chief_name_label: Label = %ChiefName # Yeni Label
@onready var active_buffs_ui : ActiveBuffsUI = %ActiveBuffsUI
var total_days: int = 0
var current_days: int = 0


func _ready() -> void:
	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	# Get screen size and safe area
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()

	# Calculate bottom inset (for home indicator/bottom notch)
	var bottom_inset := screen_size.y - (safe_area.position.y + safe_area.size.y)

	# Get viewport size for proper scaling
	var viewport_size := get_viewport_rect().size

	# Scale inset to viewport coordinates
	var scale_y := viewport_size.y / float(screen_size.y) if screen_size.y > 0 else 1.0
	var scaled_bottom := bottom_inset * scale_y

	# Push up from bottom to avoid home indicator
	#offset_bottom = -scaled_bottom


func update_ui(chief_name: String) -> void:
	chief_name_label.text = str(chief_name)
	_update_labels()

func on_day_survive() -> void:
	current_days += 1
	total_days += 1
	_update_labels()

func reset_days() -> void:
	current_days = 0
	_update_labels()

func _update_labels() -> void:
	day_label.text = str(current_days) + " days being chief" 
	if total_day_label:
		total_day_label.text = "TOTAL: " + str(total_days)
