extends Control
class_name SurvivedDaysUI

@onready var day_label: Label = %DaysValue
@onready var total_day_label: Label = %TotalDaysValue # Asla resetlenmez
@onready var chief_name_label: Label = %ChiefName # Yeni Label
@onready var active_buffs_ui : ActiveBuffsUI = %ActiveBuffsUI
var total_days: int = 0
var current_days: int = 0

func update_ui(chief_name: String) -> void:
	print(chief_name)
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
