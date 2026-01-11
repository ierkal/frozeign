extends ColorRect
class_name BuffScreenEffect

@export_category("Timing")
@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.5

@export_category("Color Adjustments")
@export_range(0.0, 2.0) var contrast: float = 1.2
@export_range(0.0, 2.0) var saturation: float = 0.8
@export_range(-1.0, 1.0) var brightness: float = 0.0
@export var tint_color: Color = Color(1.0, 0.9, 0.7, 1.0)
@export_range(0.0, 1.0) var tint_strength: float = 0.3

var _tween: Tween


func _ready() -> void:
	material.set_shader_parameter("intensity", 0.0)
	_apply_color_settings()


func _apply_color_settings() -> void:
	material.set_shader_parameter("contrast", contrast)
	material.set_shader_parameter("saturation", saturation)
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("tint_color", tint_color)
	material.set_shader_parameter("tint_strength", tint_strength)


func show_effect() -> void:
	show()
	_apply_color_settings()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_intensity, 0.0, 1.0, fade_in_duration)


func hide_effect() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_intensity, 1.0, 0.0, fade_out_duration)
	_tween.tween_callback(hide)


func _set_intensity(value: float) -> void:
	material.set_shader_parameter("intensity", value)
