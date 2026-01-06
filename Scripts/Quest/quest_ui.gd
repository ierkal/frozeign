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
	for child in list_node.get_children():
		child.queue_free()
	
	for data in quest_data:
		var item = quest_item_scene.instantiate()
		list_node.add_child(item)
		
		var title_label = item.get_node("QuestTitle")
		var desc_label = item.get_node("QuestDescription")
		
		# Mantık katmanları (Ternary kullanmıyoruz)
		if data.is_completed:
			# TAMAMLANANLAR: Yeşilimsi sönük veya üstü çizili gibi
			title_label.text = "[Completed] " + data.title
			desc_label.text = data.description
			title_label.modulate = Color(0.5, 0.8, 0.5, 0.8) 
			desc_label.modulate = Color(0.5, 0.8, 0.5, 0.5)
			
		elif data.is_unlocked:
			# AKTİF/AÇIK OLANLAR: Normal görünüm
			title_label.text = data.title
			desc_label.text = data.description
			title_label.modulate = Color.WHITE
			desc_label.modulate = Color.WHITE
			
		else:
			# KİLİTLİ OLANLAR: Henüz keşfedilmedi
			title_label.text = data.title
			desc_label.text = "???"
			title_label.modulate = Color(0.3, 0.3, 0.3, 1.0)
			desc_label.modulate = Color(0.3, 0.3, 0.3, 0.5)
	
func _on_close_button_pressed() -> void:
	hide()
