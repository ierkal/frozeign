extends Control
class_name SurvivedDaysUI

@onready var days_value: Label = $Panel/DaysValue

var current_days: int = 0

func on_day_survive() -> void:
	current_days += 1
	days_value.text = "%d DAYS SURVIVED" % current_days

func reset_days() -> void:
	current_days = 0
	days_value.text = "%d DAYS SURVIVED" % current_days

