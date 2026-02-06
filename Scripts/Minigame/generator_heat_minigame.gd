extends Control
class_name GeneratorHeatMinigame

signal minigame_completed(success: bool)

enum Phase {
	NONE,
	WAITING_TO_START,
	ACTIVE,
	COMPLETED
}

# Configuration - exposed to inspector
@export var time_limit: float = 20.0  ## Seconds to complete the minigame
@export var drop_force: float = 25.0  ## How fast the needle drops per second (percentage)
@export var tap_boost: float = 15.0  ## How much each tap increases the needle (percentage)
@export var success_threshold: float = 0.80  ## Must stay above this (80%)
@export var overload_threshold: float = 1.0  ## Instant fail above this (100%)
@export var danger_threshold: float = 0.20  ## Countdown starts below this (20%)
@export var hold_time_required: float = 2.0  ## Seconds to hold above success threshold
@export var danger_countdown: float = 3.0  ## Seconds before fail when below danger threshold

# Export textures for customization
@export_group("Textures")
@export var generator_texture: Texture2D  ## Generator image
@export var needle_texture: Texture2D  ## Needle/indicator image
@export var background_texture: Texture2D  ## Panel background

# Node references
@onready var background: ColorRect = $Background
@onready var title_label: Label = $ContentContainer/VBoxContainer/TitleLabel
@onready var timer_label: Label = $ContentContainer/VBoxContainer/TimerLabel
@onready var instruction_label: Label = $ContentContainer/VBoxContainer/InstructionLabel
@onready var hint_label: Label = $ContentContainer/VBoxContainer/HintLabel
@onready var generator_panel: Control = $ContentContainer/VBoxContainer/GeneratorPanel
@onready var heat_bar: Control = $ContentContainer/VBoxContainer/GeneratorPanel/HeatBarContainer/HeatBar
@onready var heat_fill: ColorRect = $ContentContainer/VBoxContainer/GeneratorPanel/HeatBarContainer/HeatBar/HeatFill
@onready var success_line: ColorRect = $ContentContainer/VBoxContainer/GeneratorPanel/HeatBarContainer/HeatBar/SuccessLine
@onready var danger_line: ColorRect = $ContentContainer/VBoxContainer/GeneratorPanel/HeatBarContainer/HeatBar/DangerLine
@onready var tap_area: Control = $TapArea

# State
var _current_phase: Phase = Phase.NONE
var _card_data: Dictionary = {}
var _time_remaining: float = 0.0
var _heat_value: float = 0.5  # Current heat level (0-1)
var _success_timer: float = 0.0  # Time spent in success zone
var _danger_timer: float = 0.0  # Time spent in danger zone


func _ready() -> void:
	hide()

	# Setup tap area
	tap_area.gui_input.connect(_on_tap_area_input)

	# Block input on background
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	# Apply textures if set
	_apply_textures()


func _process(delta: float) -> void:
	if _current_phase == Phase.ACTIVE:
		# Update timer
		_time_remaining -= delta
		timer_label.text = "Time: %.1f" % max(0, _time_remaining)

		# Check for timeout
		if _time_remaining <= 0:
			_complete_minigame(false)
			return

		# Apply gravity/drop force
		_heat_value -= drop_force * delta / 100.0
		_heat_value = clamp(_heat_value, 0.0, 1.0)

		# Check for overload (instant fail)
		if _heat_value >= overload_threshold:
			instruction_label.text = "OVERLOAD!"
			LabelUtils.set_font_color(instruction_label, Color(0.9, 0.2, 0.1))
			_complete_minigame(false)
			return

		# Check success zone (above 80%)
		if _heat_value >= success_threshold:
			_success_timer += delta
			_danger_timer = 0.0  # Reset danger timer

			var remaining = hold_time_required - _success_timer
			instruction_label.text = "HOLD IT! %.1f" % max(0, remaining)
			LabelUtils.set_font_color(instruction_label, Color(0.2, 0.8, 0.3))

			if _success_timer >= hold_time_required:
				_complete_minigame(true)
				return

		# Check danger zone (below 20%)
		elif _heat_value <= danger_threshold:
			_danger_timer += delta
			_success_timer = 0.0  # Reset success timer

			var countdown = danger_countdown - _danger_timer
			if countdown > 0:
				instruction_label.text = "DANGER! %.0f" % ceil(countdown)
				LabelUtils.set_font_color(instruction_label, Color(0.9, 0.3, 0.1))
			else:
				instruction_label.text = "SHUTDOWN!"
				LabelUtils.set_font_color(instruction_label, Color(0.8, 0.2, 0.2))
				_complete_minigame(false)
				return

		# Normal zone
		else:
			_success_timer = 0.0
			_danger_timer = 0.0
			instruction_label.text = "TAP TO HEAT UP!"
			LabelUtils.remove_font_color(instruction_label)

		# Update visual
		_update_heat_bar()


func show_minigame(card_data: Dictionary) -> void:
	_card_data = card_data
	_reset_state()

	title_label.text = "Steam Hub Heat"
	instruction_label.text = "Tap to begin!"
	hint_label.text = "Tap rapidly to maintain heat above the green line"
	timer_label.text = "Time: %.1f" % time_limit

	# Show tap area for starting
	tap_area.show()
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP

	show()
	_current_phase = Phase.WAITING_TO_START


func _reset_state() -> void:
	_time_remaining = time_limit
	_heat_value = 0.5  # Start at 50%
	_success_timer = 0.0
	_danger_timer = 0.0

	_update_heat_bar()


func _apply_textures() -> void:
	# Apply textures if provided
	# For now using color rects as placeholders
	pass


func _on_tap_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_tap()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_tap()


func _on_tap() -> void:
	if _current_phase == Phase.WAITING_TO_START:
		_start_game()
	elif _current_phase == Phase.ACTIVE:
		# Add heat on tap
		_heat_value += tap_boost / 100.0
		_heat_value = clamp(_heat_value, 0.0, 1.05)  # Allow slight overshoot for overload
		_update_heat_bar()


func _start_game() -> void:
	_current_phase = Phase.ACTIVE
	instruction_label.text = "TAP TO HEAT UP!"
	hint_label.text = "Keep it above 80% - Don't overload!"


func _update_heat_bar() -> void:
	if not heat_fill or not heat_bar:
		return

	# Update fill height based on heat value
	var bar_height = heat_bar.size.y
	var fill_height = bar_height * clamp(_heat_value, 0.0, 1.0)

	# Position fill from bottom
	heat_fill.size.y = fill_height
	heat_fill.position.y = bar_height - fill_height

	# Update color based on zone
	if _heat_value >= success_threshold:
		heat_fill.color = Color(0.2, 0.8, 0.3, 1.0)  # Green in success zone
	elif _heat_value <= danger_threshold:
		heat_fill.color = Color(0.9, 0.2, 0.1, 1.0)  # Red in danger zone
	elif _heat_value >= 0.9:
		heat_fill.color = Color(0.9, 0.6, 0.1, 1.0)  # Orange near overload
	else:
		heat_fill.color = Color(0.9, 0.5, 0.1, 1.0)  # Normal orange


func _complete_minigame(success: bool) -> void:
	_current_phase = Phase.COMPLETED

	if success:
		instruction_label.text = "Steam Hub Stable!"
		LabelUtils.set_font_color(instruction_label, Color(0.2, 0.8, 0.3))
	else:
		if _heat_value >= overload_threshold:
			instruction_label.text = "Steam Hub Overloaded!"
		elif _heat_value <= danger_threshold:
			instruction_label.text = "Steam Hub Shutdown!"
		else:
			instruction_label.text = "Time's Up!"
		LabelUtils.set_font_color(instruction_label, Color(0.8, 0.2, 0.2))

	await get_tree().create_timer(1.5).timeout

	hide()
	_current_phase = Phase.NONE
	minigame_completed.emit(success)


# Getters for potential visual components
func get_heat_value() -> float:
	return _heat_value


func get_success_threshold() -> float:
	return success_threshold


func get_danger_threshold() -> float:
	return danger_threshold


func is_active() -> bool:
	return _current_phase == Phase.ACTIVE
