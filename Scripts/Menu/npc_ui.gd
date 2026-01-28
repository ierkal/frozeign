extends Control
class_name NpcUI

signal need_npc_data

enum Tab { ALL_NPCS, COUNCIL }

@export var npc_item_scene: PackedScene
@onready var list_node: GridContainer = %NpcListGrid
@onready var close_btn: Button = $CloseBtn
@onready var tab_all: Button = %TabAll
@onready var tab_council: Button = %TabCouncil
@onready var title_label: Label = %TitleLabel

var _current_tab: Tab = Tab.ALL_NPCS
var _all_npc_data: Array = []

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_on_close_button_pressed)
	tab_all.pressed.connect(_on_tab_all_pressed)
	tab_council.pressed.connect(_on_tab_council_pressed)
	_update_tab_styles()

func show_npcs(npc_data: Array) -> void:
	_all_npc_data = npc_data
	_refresh_display()

func _refresh_display() -> void:
	ContainerUtils.clear_children(list_node)

	var filtered_data = _get_filtered_data()

	# Update title based on tab
	if title_label:
		match _current_tab:
			Tab.ALL_NPCS:
				title_label.text = "NPCs Met"
			Tab.COUNCIL:
				title_label.text = "Council"

	for data in filtered_data:
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

		# Determine item state based on whether NPC has been met
		var is_met = data.has("is_met") and data.is_met
		var state = ItemStateStyler.ItemState.ACTIVE if is_met else ItemStateStyler.ItemState.LOCKED

		if not is_met:
			name_label.text = "???"

		name_label.modulate = ItemStateStyler.get_color_for_state(state)
		image_rect.modulate = GameConstants.Colors.ITEM_ACTIVE if is_met else Color(0.1, 0.1, 0.1, 1.0)

func _get_filtered_data() -> Array:
	match _current_tab:
		Tab.ALL_NPCS:
			return _all_npc_data
		Tab.COUNCIL:
			# Filter to only show NPCs with professions (council + hired)
			var council_data: Array = []
			for data in _all_npc_data:
				if data.has("profession") and data.profession != "":
					council_data.append(data)
			return council_data
	return _all_npc_data

func _on_tab_all_pressed() -> void:
	if _current_tab != Tab.ALL_NPCS:
		_current_tab = Tab.ALL_NPCS
		_update_tab_styles()
		_refresh_display()

func _on_tab_council_pressed() -> void:
	if _current_tab != Tab.COUNCIL:
		_current_tab = Tab.COUNCIL
		_update_tab_styles()
		_refresh_display()

func _update_tab_styles() -> void:
	if not tab_all or not tab_council:
		return

	var active_color = GameConstants.Colors.ITEM_ACTIVE
	var inactive_color = Color(0.5, 0.5, 0.5, 1.0)

	match _current_tab:
		Tab.ALL_NPCS:
			tab_all.modulate = active_color
			tab_council.modulate = inactive_color
		Tab.COUNCIL:
			tab_all.modulate = inactive_color
			tab_council.modulate = active_color

func _on_close_button_pressed() -> void:
	hide()
