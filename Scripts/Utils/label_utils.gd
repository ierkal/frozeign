class_name LabelUtils
extends RefCounted

## Utility functions for Label color management that work with LabelSettings.


## Sets the font color on a label, handling both LabelSettings and theme overrides.
## If the label has LabelSettings, it makes the settings unique and changes font_color.
## Otherwise, it uses theme color override.
static func set_font_color(label: Label, color: Color) -> void:
	if not label:
		return

	if label.label_settings:
		# Make settings unique if shared, then set color
		if not label.label_settings.resource_local_to_scene:
			label.label_settings = label.label_settings.duplicate()
		label.label_settings.font_color = color
	else:
		label.add_theme_color_override("font_color", color)


## Removes the font color override, restoring to default.
## For LabelSettings, sets color to white. For theme override, removes it.
static func remove_font_color(label: Label, default_color: Color = Color.WHITE) -> void:
	if not label:
		return

	if label.label_settings:
		label.label_settings.font_color = default_color
	else:
		label.remove_theme_color_override("font_color")
