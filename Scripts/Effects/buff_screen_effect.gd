extends ColorRect
class_name BuffScreenEffect

@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.5

var _tween: Tween


func _ready() -> void:
	# Start invisible
	material.set_shader_parameter("intensity", 0.0)
	hide()


func show_effect() -> void:
	show()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_intensity, 0.0, 1.0, fade_in_duration)


func hide_effect() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_intensity, 1.0, 0.0, fade_out_duration)
	_tween.tween_callback(hide)


func _set_intensity(value: float) -> void:
	material.set_shader_parameter("intensity", value)
