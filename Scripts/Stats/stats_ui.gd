extends Control
class_name StatsUI

@onready var heat: TextureProgressBar = %Heat
@onready var discontent: TextureProgressBar = %Discontent
@onready var hope: TextureProgressBar = %Hope
@onready var survivors: TextureProgressBar = %Survivors

@onready var heat_point: TextureRect = %HeatPoint
@onready var discontent_point: TextureRect = %DiscontentPoint
@onready var hope_point: TextureRect = %HopePoint
@onready var survivors_point: TextureRect = %SurvivorsPoint

func _ready() -> void:
	add_to_group("StatsUI")
	clear_preview()

# --------------------------------------------------------
# Called externally by GameDirector (not via singleton)
# --------------------------------------------------------
func update_stats(h: int, d: int, ho: int, s: int) -> void:
	heat.value = h
	discontent.value = d
	hope.value = ho
	survivors.value = s

func show_preview(effect: Dictionary) -> void:
	heat_point.visible = int(effect.get("Heat", 0)) != 0
	discontent_point.visible = int(effect.get("Discontent", 0)) != 0
	hope_point.visible = int(effect.get("Hope", 0)) != 0
	survivors_point.visible = int(effect.get("Survivors", 0)) != 0

func clear_preview() -> void:
	heat_point.visible = false
	discontent_point.visible = false
	hope_point.visible = false
	survivors_point.visible = false
