extends Control
class_name InventoryItem

signal use_pressed(item_id: String)

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var count_label: Label = %CountLabel
@onready var use_button: Button = %UseButton

var _item_id: String = ""

func _ready() -> void:
	if use_button:
		use_button.pressed.connect(_on_use_pressed)

func setup(item_data: Dictionary) -> void:
	_item_id = item_data.get("id", "")

	if icon_texture:
		var icon_path = item_data.get("icon", "")
		if icon_path != "" and FileAccess.file_exists(icon_path):
			icon_texture.texture = load(icon_path)

	if name_label:
		name_label.text = item_data.get("name", "Unknown")

	if description_label:
		description_label.text = item_data.get("description", "")

	if count_label:
		var count = item_data.get("count", 1)
		count_label.text = "x%d" % count
		count_label.visible = count > 1

func get_item_id() -> String:
	return _item_id

func _on_use_pressed() -> void:
	use_pressed.emit(_item_id)
