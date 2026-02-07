extends Control
class_name SplashScreen

@export var top_image: Texture2D
@export var bottom_image: Texture2D
@export var display_duration: float = 3.0
@export var use_fade: bool = false
@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 1.0

@onready var top_texture: TextureRect = $VBoxContainer/TopImage
@onready var bottom_texture: TextureRect = $VBoxContainer/BottomImage

func _ready() -> void:
	# Set viewport clear color to black at runtime so scene transitions don't flash gray
	RenderingServer.set_default_clear_color(Color.BLACK)

	if top_image:
		top_texture.texture = top_image
	if bottom_image:
		bottom_texture.texture = bottom_image

	if use_fade:
		$VBoxContainer.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property($VBoxContainer, "modulate:a", 1.0, fade_in_duration)
		tween.tween_interval(display_duration)
		tween.tween_property($VBoxContainer, "modulate:a", 0.0, fade_out_duration)
		tween.tween_interval(0.3)
		tween.tween_callback(_go_to_game)
	else:
		var tween := create_tween()
		tween.tween_interval(display_duration)
		tween.tween_callback(_go_to_game)

func _go_to_game() -> void:
	AudioManager.play_general_music()
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
