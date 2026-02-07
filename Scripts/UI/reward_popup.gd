extends Control
class_name RewardPopup

signal popup_closed

@onready var background: ColorRect = $Background
@onready var popup_panel: Panel = $PopupPanel
@onready var icon_texture: TextureRect = $PopupPanel/VBoxContainer/IconTexture
@onready var name_label: Label = $PopupPanel/VBoxContainer/NameLabel
@onready var description_label: Label = $PopupPanel/VBoxContainer/DescriptionLabel
@onready var close_button: Button = $PopupPanel/CloseButton

var _minigame_id: String = ""

func _ready() -> void:
	hide()
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_on_close_button_pressed)

func show_reward(icon: Texture2D, reward_name: String, description: String, minigame_id: String = "") -> void:
	_minigame_id = minigame_id

	if icon_texture:
		icon_texture.texture = icon
	if name_label:
		name_label.text = reward_name
	if description_label:
		description_label.text = description

	# Reset for animation
	popup_panel.modulate.a = 0.0
	popup_panel.scale = Vector2(0.8, 0.8)
	popup_panel.pivot_offset = popup_panel.size / 2.0

	show()
	AudioManager.play_popup_shown()

	# Animate in with ease
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close_button_pressed() -> void:
	# Animate out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup_panel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(popup_panel, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN)

	await tween.finished
	hide()
	popup_closed.emit()
