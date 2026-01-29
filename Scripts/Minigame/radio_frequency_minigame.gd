extends Control
class_name RadioFrequencyMinigame

signal minigame_completed(success: bool)

enum Phase {
	NONE,
	WAITING_TO_START,
	ADJUSTING,
	COMPLETED
}

# Configuration - exposed to inspector
@export var time_limit: float = 20.0  ## Seconds to complete the minigame
@export var match_threshold: float = 0.05  ## How close values need to be (0-1 range)
@export var match_time_required: float = 1.5  ## Seconds to hold match for success

# Export textures for customization
@export_group("Textures")
@export var radio_texture: Texture2D  ## Radio image
@export var slider_handle_texture: Texture2D  ## Slider handle/knob image
@export var background_texture: Texture2D  ## Panel background

# Node references
@onready var background: ColorRect = $Background
@onready var title_label: Label = $ContentContainer/VBoxContainer/TitleLabel
@onready var timer_label: Label = $ContentContainer/VBoxContainer/TimerLabel
@onready var instruction_label: Label = $ContentContainer/VBoxContainer/InstructionLabel
@onready var radio_panel: Control = $ContentContainer/VBoxContainer/RadioPanel
@onready var radio_image: TextureRect = $ContentContainer/VBoxContainer/RadioPanel/RadioImage
@onready var wave_display: Control = $ContentContainer/VBoxContainer/RadioPanel/WaveContainer/WaveDisplay
@onready var frequency_slider: VSlider = $ContentContainer/VBoxContainer/RadioPanel/FrequencySlider
@onready var phase_slider: HSlider = $ContentContainer/VBoxContainer/RadioPanel/PhaseSlider
@onready var tap_area: Control = $TapArea

# State
var _current_phase: Phase = Phase.NONE
var _card_data: Dictionary = {}
var _time_remaining: float = 0.0
var _target_frequency: float = 0.0  # 0-1 range
var _target_phase: float = 0.0  # 0-1 range
var _match_timer: float = 0.0  # Time spent in matching state
var _wave_time: float = 0.0  # For wave animation


func _ready() -> void:
	hide()

	# Setup tap area for starting
	tap_area.gui_input.connect(_on_tap_area_input)

	# Block input on background
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect slider signals
	frequency_slider.value_changed.connect(_on_slider_changed)
	phase_slider.value_changed.connect(_on_slider_changed)

	# Apply textures if set
	_apply_textures()


func _process(delta: float) -> void:
	if _current_phase == Phase.ADJUSTING:
		# Update timer
		_time_remaining -= delta
		timer_label.text = "Time: %.1f" % max(0, _time_remaining)

		# Check for timeout
		if _time_remaining <= 0:
			_complete_minigame(false)
			return

		# Check if player is matching
		var freq_diff = abs(frequency_slider.value - _target_frequency)
		var phase_diff = abs(phase_slider.value - _target_phase)

		if freq_diff <= match_threshold and phase_diff <= match_threshold:
			_match_timer += delta
			instruction_label.text = "Hold it! %.1f" % max(0, match_time_required - _match_timer)
			instruction_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))

			if _match_timer >= match_time_required:
				_complete_minigame(true)
				return
		else:
			_match_timer = 0.0
			instruction_label.text = "Adjust the frequency!"
			instruction_label.remove_theme_color_override("font_color")

	# Update wave animation
	_wave_time += delta
	wave_display.queue_redraw()


func show_minigame(card_data: Dictionary) -> void:
	_card_data = card_data
	_reset_state()

	title_label.text = "Radio Tuning"
	instruction_label.text = "Tap to begin!"
	timer_label.text = "Time: %.1f" % time_limit

	# Show tap area for starting
	tap_area.show()
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP

	# Disable sliders until started
	frequency_slider.editable = false
	phase_slider.editable = false

	show()
	_current_phase = Phase.WAITING_TO_START


func _reset_state() -> void:
	_time_remaining = time_limit
	_match_timer = 0.0
	_wave_time = 0.0

	# Generate random target values
	_target_frequency = randf_range(0.2, 0.8)
	_target_phase = randf_range(0.2, 0.8)

	# Reset sliders to middle
	frequency_slider.value = 0.5
	phase_slider.value = 0.5

	wave_display.queue_redraw()


func _apply_textures() -> void:
	if radio_texture and radio_image:
		radio_image.texture = radio_texture

	# Slider handle textures would need custom theme overrides
	# For now we use default slider style


func _on_tap_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_tap()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_tap()


func _on_tap() -> void:
	if _current_phase == Phase.WAITING_TO_START:
		_start_adjusting()


func _start_adjusting() -> void:
	_current_phase = Phase.ADJUSTING
	instruction_label.text = "Adjust the frequency!"

	# Hide tap area, enable sliders
	tap_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frequency_slider.editable = true
	phase_slider.editable = true


func _on_slider_changed(_value: float) -> void:
	wave_display.queue_redraw()


func _complete_minigame(success: bool) -> void:
	_current_phase = Phase.COMPLETED

	# Disable sliders
	frequency_slider.editable = false
	phase_slider.editable = false

	if success:
		instruction_label.text = "Signal locked!"
		instruction_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	else:
		instruction_label.text = "Signal lost..."
		instruction_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

	await get_tree().create_timer(1.5).timeout

	hide()
	_current_phase = Phase.NONE
	minigame_completed.emit(success)


# Getters for wave drawer
func get_target_frequency() -> float:
	return _target_frequency


func get_target_phase() -> float:
	return _target_phase


func get_player_frequency() -> float:
	return frequency_slider.value if frequency_slider else 0.5


func get_player_phase() -> float:
	return phase_slider.value if phase_slider else 0.5


func get_wave_time() -> float:
	return _wave_time


func is_adjusting() -> bool:
	return _current_phase == Phase.ADJUSTING or _current_phase == Phase.WAITING_TO_START


func get_match_threshold() -> float:
	return match_threshold
