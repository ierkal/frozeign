extends Button


func _ready() -> void:
	self.pressed.connect(_on_quest_menu_button_pressed)
func _on_quest_menu_button_pressed() -> void:
	print("quest menu requested")
	EventBus.quest_menu_requested.emit()
