extends Control
class_name QuestUI

signal need_quest_data

@export var quest_item_scene: PackedScene
@onready var list_node: VBoxContainer = %QuestListVbox
@onready var close_btn: Button = $CloseBtn

func _ready() -> void:
	#EventBus.quest_menu_requested.connect(_on_request_received)
	hide()
	close_btn.pressed.connect(_on_close_button_pressed)

func _on_request_received() -> void:
	need_quest_data.emit()

func show_quests(quest_data: Array) -> void:
	ContainerUtils.clear_children(list_node)

	for data in quest_data:
		var item = quest_item_scene.instantiate()
		list_node.add_child(item)

		var title_label = item.get_node("QuestTitle")
		var desc_label = item.get_node("QuestDescription")

		# Determine item state
		var state: ItemStateStyler.ItemState
		if data.is_completed:
			state = ItemStateStyler.ItemState.COMPLETED
			title_label.text = "[Completed] " + data.title
			desc_label.text = data.description
		elif data.is_unlocked:
			state = ItemStateStyler.ItemState.ACTIVE
			title_label.text = data.title
			desc_label.text = data.description
		else:
			state = ItemStateStyler.ItemState.LOCKED
			title_label.text = data.title
			desc_label.text = "???"

		# Apply colors using ItemStateStyler
		title_label.modulate = ItemStateStyler.get_color_for_state(state)
		desc_label.modulate = ItemStateStyler.get_description_color_for_state(state)
	
func _on_close_button_pressed() -> void:
	hide()
