extends Control
class_name NpcUI

signal need_npc_data

@export var npc_item_scene: PackedScene
@onready var list_node: GridContainer = %NpcListGrid
@onready var close_btn: Button = $CloseBtn

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_on_close_button_pressed)

func show_npcs(npc_data: Array) -> void:
	# Clear existing items
	for child in list_node.get_children():
		child.queue_free()

	for data in npc_data:
		var item = npc_item_scene.instantiate()
		list_node.add_child(item)

		var image_rect = item.get_node("NpcImage")
		var name_label = item.get_node("NpcName")

		# Set the title (profession + name or just name)
		var display_title = ""
		if data.has("profession") and data.profession != "":
			display_title = "%s %s" % [data.profession, data.name]
		else:
			display_title = data.name

		name_label.text = display_title

		# Set the image if available (new: direct Texture2D)
		if data.has("npc_image") and data.npc_image != null:
			image_rect.texture = data.npc_image
		# Fallback to image_path if provided (legacy support)
		elif data.has("image_path") and data.image_path != "":
			var texture = load(data.image_path)
			if texture:
				image_rect.texture = texture

		# Set visual state based on whether NPC has been met
		if data.has("is_met") and data.is_met:
			name_label.modulate = Color.WHITE
			image_rect.modulate = Color.WHITE
		else:
			# Not met yet - show as hidden/locked
			name_label.text = "???"
			name_label.modulate = Color(0.3, 0.3, 0.3, 1.0)
			image_rect.modulate = Color(0.1, 0.1, 0.1, 1.0)

func _on_close_button_pressed() -> void:
	hide()
