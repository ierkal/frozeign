extends Control
class_name SurvivedDaysUI

@onready var days_value: Label = $Panel/DaysValue

var survived_days : int = 0
func on_day_survive():
	survived_days+=1
	days_value.text=  "%d DAYS SURVIVED." %survived_days
