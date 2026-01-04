extends Button
func _on_quest_menu_button_pressed() -> void:
	EventBus.quest_menu_requested.emit()