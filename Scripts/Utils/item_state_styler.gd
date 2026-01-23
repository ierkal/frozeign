class_name ItemStateStyler

## Utility class for standardizing list item display colors.
## Centralizes the color/style logic for list items (quests, NPCs, etc.)

enum ItemState { LOCKED, ACTIVE, COMPLETED }

static func get_color_for_state(state: ItemState) -> Color:
	match state:
		ItemState.LOCKED:
			return GameConstants.Colors.ITEM_LOCKED
		ItemState.ACTIVE:
			return GameConstants.Colors.ITEM_ACTIVE
		ItemState.COMPLETED:
			return GameConstants.Colors.ITEM_COMPLETED
	return Color.WHITE


static func get_description_color_for_state(state: ItemState) -> Color:
	match state:
		ItemState.LOCKED:
			return Color(0.3, 0.3, 0.3, 0.5)
		ItemState.ACTIVE:
			return Color.WHITE
		ItemState.COMPLETED:
			return Color(0.5, 0.8, 0.5, 0.5)
	return Color.WHITE


static func apply_to_label(label: Label, state: ItemState) -> void:
	label.modulate = get_color_for_state(state)
