extends Container 
class_name ActiveBuffsUI

@export var icon_scene: PackedScene 

var _active_assignments: Dictionary = {}

func _ready() -> void:
	EventBus.buff_started.connect(_on_buff_started)
	EventBus.buff_ended.connect(_on_buff_ended)
	
	for slot in get_children():
		_clear_slot(slot)

func _on_buff_started(buff) -> void:
	if _active_assignments.has(buff.id): return
	
	var available_slot = _find_empty_slot()
	
	if available_slot:
		_fill_slot(available_slot, buff)
		_active_assignments[buff.id] = available_slot
	else:
		print("UI: Buff için boş slot kalmadı! -> " + buff.id)

func _on_buff_ended(buff_id: String) -> void:
	if _active_assignments.has(buff_id):
		var slot = _active_assignments[buff_id]
		
		_clear_slot(slot)
		
		_active_assignments.erase(buff_id)

func _find_empty_slot() -> Node:
	for slot in get_children():
		if not _active_assignments.values().has(slot):
			return slot
	return null

func _fill_slot(slot: Node, buff) -> void:
	slot.visible = true
	
	if icon_scene:
		var icon_instance = icon_scene.instantiate()
		slot.add_child(icon_instance)
		
		if icon_instance is TextureRect:
			icon_instance.texture = load(buff.icon_path)
		elif icon_instance.has_method("set_icon_path"):
			icon_instance.set_icon_path(buff.icon_path)
			
	elif slot is TextureRect:
		slot.texture = load(buff.icon_path)

func _clear_slot(slot: Node) -> void:
	for child in slot.get_children():
		child.queue_free()
	
	if slot is TextureRect:
		slot.texture = null
