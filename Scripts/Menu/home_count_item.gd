extends Panel
class_name HomeCountItem
@onready var title: Label = %ItemTitle
@onready var description : Label = %ItemDescription
@onready var progress_bar: TextureProgressBar = %ProgressBar

signal clicked # Tıklanma sinyali

	# Panel'in input alabilmesi için mouse filter'ı ayarla
	# (Editörden Mouse -> Filter -> Stop veya Pass yapılmış olmalı)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
