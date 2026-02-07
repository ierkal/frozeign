extends Control
class_name ArtSequence

signal sequence_finished(sequence_type: String)

@export_group("Intro Sequence")
@export var intro_images: Array[Texture2D] = []
@export var intro_subtitles: Array[String] = []
@export var intro_image_duration: float = 6.0

@export_group("Mid Sequence")
@export var mid_images: Array[Texture2D] = []
@export var mid_subtitles: Array[String] = []
@export var mid_image_duration: float = 6.0

@export_group("Volcano Ending")
@export var volcano_images: Array[Texture2D] = []
@export var volcano_subtitles: Array[String] = []
@export var volcano_image_duration: float = 6.0

@export_group("Oracle Ending")
@export var oracle_images: Array[Texture2D] = []
@export var oracle_subtitles: Array[String] = []
@export var oracle_image_duration: float = 6.0

@export_group("City Ending")
@export var city_images: Array[Texture2D] = []
@export var city_subtitles: Array[String] = []
@export var city_image_duration: float = 6.0

@export_group("Fade Settings")
@export var fade_to_black_duration: float = 1.0
@export var fade_in_first_image_duration: float = 1.5

@export_group("Skip Settings")
@export var skip_hold_duration: float = 3.0
@export var skip_hint_show_duration: float = 3.0

# Node references
@onready var background: ColorRect = $Background
@onready var current_image: TextureRect = $CurrentImage
@onready var next_image: TextureRect = $NextImage
@onready var subtitle_label: Label = $SubtitleLabel
@onready var skip_hint_label: Label = $SkipContainer/SkipHintLabel
@onready var skip_circle: SkipCircleDrawer = $SkipContainer/SkipCircle

# State
var _active_type: String = ""
var _images: Array[Texture2D] = []
var _subtitles: Array[String] = []
var _image_duration: float = 6.0
var _current_index: int = 0
var _image_tween: Tween
var _crossfade_tween: Tween
var _hint_tween: Tween

# Skip state
var _skip_active: bool = false
var _skip_hold_time: float = 0.0
var _elapsed_time: float = 0.0

# Input tracking
var _is_pressing: bool = false

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not visible or _active_type.is_empty():
		return

	_elapsed_time += delta

	if _is_pressing:
		_skip_hold_time += delta
		skip_circle.progress = _skip_hold_time / skip_hold_duration
		skip_circle.queue_redraw()

		if _skip_hold_time >= skip_hold_duration:
			_is_pressing = false
			_skip_sequence()

func _input(event: InputEvent) -> void:
	if not visible or _active_type.is_empty():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press_start()
			else:
				_on_press_end()

	elif event is InputEventScreenTouch:
		if event.index == 0:
			if event.pressed:
				_on_press_start()
			else:
				_on_press_end()

func _on_press_start() -> void:
	_is_pressing = true
	_skip_hold_time = 0.0
	# Kill the auto-fade tween so it doesn't override our visibility
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	skip_hint_label.visible = true
	skip_hint_label.modulate.a = 1.0
	skip_circle.visible = true
	skip_circle.progress = 0.0
	skip_circle.queue_redraw()

func _on_press_end() -> void:
	_is_pressing = false
	_skip_hold_time = 0.0
	skip_circle.progress = 0.0
	skip_circle.queue_redraw()
	# Hide skip UI after release
	skip_hint_label.visible = false
	skip_circle.visible = false

func play_sequence(type: String) -> void:
	_active_type = type

	match type:
		"intro":
			_images = intro_images
			_subtitles = intro_subtitles
			_image_duration = intro_image_duration
		"mid":
			_images = mid_images
			_subtitles = mid_subtitles
			_image_duration = mid_image_duration
		"volcano":
			_images = volcano_images
			_subtitles = volcano_subtitles
			_image_duration = volcano_image_duration
		"oracle":
			_images = oracle_images
			_subtitles = oracle_subtitles
			_image_duration = oracle_image_duration
		"city":
			_images = city_images
			_subtitles = city_subtitles
			_image_duration = city_image_duration
		_:
			_finish_sequence()
			return

	if _images.is_empty():
		_finish_sequence()
		return

	_current_index = 0
	_elapsed_time = 0.0
	_skip_hold_time = 0.0
	_is_pressing = false

	# Reset visuals - start with black screen, images hidden
	current_image.texture = null
	current_image.modulate.a = 0.0
	next_image.texture = null
	next_image.modulate.a = 0.0
	subtitle_label.text = ""
	subtitle_label.visible = false

	# Show skip hint initially
	skip_hint_label.visible = true
	skip_hint_label.modulate.a = 1.0
	skip_circle.visible = false
	skip_circle.progress = 0.0

	show()
	AudioManager.play_art_sequence_music(type)

	# Fade out skip hint after initial show period
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(skip_hint_show_duration)
	_hint_tween.tween_property(skip_hint_label, "modulate:a", 0.0, 0.5)
	_hint_tween.tween_callback(func(): skip_hint_label.visible = false)

	# For intro, start fully black (nothing behind to fade from).
	# For mid/endings, fade to black over the game UI.
	if type == "intro":
		background.modulate.a = 1.0
		_begin_first_image()
	else:
		background.modulate.a = 0.0
		var open_tween := create_tween()
		open_tween.tween_property(background, "modulate:a", 1.0, fade_to_black_duration)
		open_tween.tween_callback(_begin_first_image)

func _begin_first_image() -> void:
	# Set the first image texture but keep it invisible
	if _current_index >= _images.size():
		_fade_out_and_finish()
		return

	current_image.texture = _images[_current_index]
	current_image.modulate.a = 0.0

	# Set subtitle
	if _current_index < _subtitles.size() and not _subtitles[_current_index].is_empty():
		subtitle_label.text = _subtitles[_current_index]
		subtitle_label.visible = true
		subtitle_label.modulate.a = 0.0
	else:
		subtitle_label.text = ""
		subtitle_label.visible = false

	# Phase 2: Fade in the first image from black
	var fade_in := create_tween()
	fade_in.tween_property(current_image, "modulate:a", 1.0, fade_in_first_image_duration)
	if subtitle_label.visible:
		fade_in.parallel().tween_property(subtitle_label, "modulate:a", 1.0, fade_in_first_image_duration)

	# After fade-in, wait for duration then proceed to next
	fade_in.tween_interval(_image_duration)
	fade_in.tween_callback(_crossfade_to_next)

func _show_image(index: int) -> void:
	if index >= _images.size():
		_fade_out_and_finish()
		return

	current_image.texture = _images[index]

	# Set subtitle
	if index < _subtitles.size() and not _subtitles[index].is_empty():
		subtitle_label.text = _subtitles[index]
		subtitle_label.visible = true
	else:
		subtitle_label.text = ""
		subtitle_label.visible = false

	# Wait for duration then crossfade to next
	if _image_tween:
		_image_tween.kill()
	_image_tween = create_tween()
	_image_tween.tween_interval(_image_duration)
	_image_tween.tween_callback(_crossfade_to_next)

func _crossfade_to_next() -> void:
	_current_index += 1

	if _current_index >= _images.size():
		_fade_out_and_finish()
		return

	# Setup next image behind current, then crossfade
	next_image.texture = _images[_current_index]
	next_image.modulate.a = 0.0

	if _crossfade_tween:
		_crossfade_tween.kill()
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_property(next_image, "modulate:a", 1.0, 1.0)
	_crossfade_tween.tween_callback(_swap_images)

func _swap_images() -> void:
	current_image.texture = next_image.texture
	next_image.texture = null
	next_image.modulate.a = 0.0

	# Update subtitle
	if _current_index < _subtitles.size() and not _subtitles[_current_index].is_empty():
		subtitle_label.text = _subtitles[_current_index]
		subtitle_label.visible = true
	else:
		subtitle_label.text = ""
		subtitle_label.visible = false

	# Wait for duration then go to next
	if _image_tween:
		_image_tween.kill()
	_image_tween = create_tween()
	_image_tween.tween_interval(_image_duration)
	_image_tween.tween_callback(_crossfade_to_next)

func _fade_out_and_finish() -> void:
	if _image_tween:
		_image_tween.kill()
	if _crossfade_tween:
		_crossfade_tween.kill()

	var fade_tween := create_tween()
	fade_tween.tween_property(current_image, "modulate:a", 0.0, 1.0)
	fade_tween.parallel().tween_property(subtitle_label, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(_finish_sequence)

func _skip_sequence() -> void:
	if _image_tween:
		_image_tween.kill()
	if _crossfade_tween:
		_crossfade_tween.kill()
	if _hint_tween:
		_hint_tween.kill()
	_finish_sequence()

func _finish_sequence() -> void:
	var type := _active_type
	_active_type = ""
	_is_pressing = false
	_skip_hold_time = 0.0

	# Reset visuals
	background.modulate.a = 1.0
	current_image.modulate.a = 1.0
	subtitle_label.modulate.a = 1.0
	skip_hint_label.visible = false
	skip_circle.visible = false

	AudioManager.stop_art_sequence_music()
	hide()
	sequence_finished.emit(type)
