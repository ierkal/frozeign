extends Control
class_name SkillCheckMinigame

signal minigame_completed(success: bool)

enum Phase {
	NONE,
	WAITING_TO_START,
	SKILL_CHECK_ACTIVE,
	CHECK_RESULT,
	BETWEEN_CHECKS,
	COMPLETED
}

# Configuration - exposed to inspector
@export var rotation_speed: float = 270.0  ## Degrees per second
@export var safe_zone_angle: float = 45.0  ## Degrees
@export var check_count: int = 3
@export var between_check_delay: float = 1.5
@export var result_display_delay: float = 0.5
@export var completion_delay: float = 1.0

# Node references - assigned in _ready from scene tree
@onready var background: ColorRect = $Background
@onready var title_label: Label = $ContentContainer/VBoxContainer/TitleLabel
@onready var circle_container: Control = $ContentContainer/VBoxContainer/CircleContainer
@onready var safe_zone_drawer: Control = $ContentContainer/VBoxContainer/CircleContainer/SafeZoneDrawer
@onready var needle_anchor: Control = $ContentContainer/VBoxContainer/CircleContainer/NeedleAnchor
@onready var instruction_label: Label = $ContentContainer/VBoxContainer/InstructionLabel
@onready var checkbox_container: HBoxContainer = $ContentContainer/VBoxContainer/CheckboxContainer
@onready var tap_area: Control = $TapArea

# Export variables for textures (can be assigned from inspector)
@export var circle_texture: Texture2D
@export var needle_texture: Texture2D
@export var checkmark_texture: Texture2D

# State
var _current_phase: Phase = Phase.NONE
var _checks_completed: int = 0
var _checks_succeeded: int = 0
var _needle_angle: float = 0.0
var _safe_zone_start: float = 0.0
var _card_data: Dictionary = {}
var _rotation_accumulated: float = 0.0  # Track total rotation for auto-fail
var _safe_zone_visible: bool = false  # Hide safe zone until skill check starts

# Checkbox references
var _checkboxes: Array[Panel] = []
var _checkmarks: Array[TextureRect] = []


func _ready() -> void:
	hide()

	# Load checkmark texture if not set
	if not checkmark_texture:
		checkmark_texture = load("res://Assets/Sprites/check-mark.png")

	# Setup tap area input for both starting and gameplay
	tap_area.gui_input.connect(_on_tap_area_input)

	# Setup checkboxes
	_setup_checkboxes()

	# Block input on background
	background.mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if _current_phase != Phase.SKILL_CHECK_ACTIVE:
		return

	var rotation_delta = rotation_speed * delta
	_needle_angle = fmod(_needle_angle + rotation_delta, 360.0)
	_rotation_accumulated += rotation_delta
	needle_anchor.rotation_degrees = _needle_angle

	# Auto-fail if needle completes a full rotation
	if _rotation_accumulated >= 360.0:
		_auto_fail_check()


func show_minigame(card_data: Dictionary) -> void:
	_card_data = card_data
	_reset_state()

	# Set title based on card
	title_label.text = "Pipe Repair"
	instruction_label.text = "Tap to begin!"

	# Show tap area for starting (full screen tap)
	tap_area.show()
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP

	show()
	_current_phase = Phase.WAITING_TO_START


func _reset_state() -> void:
	_checks_completed = 0
	_checks_succeeded = 0
	_needle_angle = 0.0
	_rotation_accumulated = 0.0
	needle_anchor.rotation_degrees = 0.0

	# Reset checkboxes
	for i in range(_checkboxes.size()):
		var checkbox = _checkboxes[i]
		var checkmark = _checkmarks[i]
		checkbox.self_modulate = Color(0.3, 0.3, 0.35, 1.0)
		checkmark.modulate.a = 0.0
		checkmark.scale = Vector2.ZERO

	# Hide safe zone until player taps to begin
	_safe_zone_visible = false
	safe_zone_drawer.queue_redraw()


func _setup_checkboxes() -> void:
	_checkboxes.clear()
	_checkmarks.clear()

	for i in range(check_count):
		var checkbox = checkbox_container.get_child(i) as Panel
		if checkbox:
			_checkboxes.append(checkbox)

			# Get or create checkmark
			var checkmark: TextureRect
			if checkbox.get_child_count() > 0:
				checkmark = checkbox.get_child(0) as TextureRect
				# Set texture from exported variable
				if checkmark and checkmark_texture:
					checkmark.texture = checkmark_texture
			else:
				checkmark = TextureRect.new()
				checkmark.texture = checkmark_texture
				checkmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				checkmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				checkmark.anchors_preset = Control.PRESET_FULL_RECT
				checkmark.modulate.a = 0.0
				checkmark.scale = Vector2.ZERO
				checkmark.pivot_offset = checkbox.size / 2.0
				checkbox.add_child(checkmark)

			_checkmarks.append(checkmark)


func _on_tap_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_tap()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_tap()


func _on_tap() -> void:
	match _current_phase:
		Phase.WAITING_TO_START:
			_begin_skill_check_with_delay()
		Phase.SKILL_CHECK_ACTIVE:
			_evaluate_and_record()


func _begin_skill_check_with_delay() -> void:
	# Prevent double-tap from triggering immediate evaluation
	_current_phase = Phase.BETWEEN_CHECKS
	_prepare_skill_check()
	instruction_label.text = "Get ready..."
	await get_tree().create_timer(0.5).timeout
	_start_skill_check()


func _prepare_skill_check() -> void:
	# Setup needle and safe zone BEFORE the check starts
	# so player can see where everything is

	# Randomize safe zone for each check and make it visible
	_safe_zone_start = randf_range(0.0, 360.0 - safe_zone_angle)
	_safe_zone_visible = true
	safe_zone_drawer.queue_redraw()

	# Needle always starts at north (0 degrees)
	_needle_angle = 0.0
	_rotation_accumulated = 0.0
	needle_anchor.rotation_degrees = 0.0


func _start_skill_check() -> void:
	instruction_label.text = "Tap when in green zone!"
	_current_phase = Phase.SKILL_CHECK_ACTIVE


func _auto_fail_check() -> void:
	# Called when needle completes a full rotation without tap
	_evaluate_and_record_result(false)


func _evaluate_and_record() -> void:
	var success = _is_in_safe_zone()
	_evaluate_and_record_result(success)


func _evaluate_and_record_result(success: bool) -> void:
	_current_phase = Phase.CHECK_RESULT

	_checks_completed += 1
	if success:
		_checks_succeeded += 1
		_show_checkmark(_checks_completed - 1, true)
	else:
		_show_checkmark(_checks_completed - 1, false)

	# Wait and continue
	await get_tree().create_timer(result_display_delay).timeout

	if _checks_completed >= check_count:
		_complete_minigame()
	else:
		_current_phase = Phase.BETWEEN_CHECKS
		instruction_label.text = "Get ready..."
		# Prepare next check so player can see needle/safe zone positions
		_prepare_skill_check()
		await get_tree().create_timer(between_check_delay).timeout
		_start_skill_check()


func _is_in_safe_zone() -> bool:
	var zone_end = fmod(_safe_zone_start + safe_zone_angle, 360.0)

	# Handle wrap-around case
	if _safe_zone_start < zone_end:
		return _needle_angle >= _safe_zone_start and _needle_angle <= zone_end
	else:
		# Zone wraps around 360
		return _needle_angle >= _safe_zone_start or _needle_angle <= zone_end


func _show_checkmark(index: int, success: bool) -> void:
	if index < 0 or index >= _checkboxes.size():
		return

	var checkbox = _checkboxes[index]
	var checkmark = _checkmarks[index]

	# Set color based on success
	var target_color: Color
	if success:
		target_color = Color(0.2, 0.7, 0.3, 1.0)  # Green
	else:
		target_color = Color(0.8, 0.2, 0.2, 1.0)  # Red

	# Animate checkbox color
	var tween = create_tween()
	tween.tween_property(checkbox, "self_modulate", target_color, 0.2)

	if success:
		# Animate checkmark appearance
		checkmark.pivot_offset = checkbox.size / 2.0
		tween.parallel().tween_property(checkmark, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(checkmark, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _complete_minigame() -> void:
	_current_phase = Phase.COMPLETED
	tap_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var success = _checks_succeeded >= 2  # 2/3 required

	if success:
		instruction_label.text = "Success!"
	else:
		instruction_label.text = "Failed..."

	await get_tree().create_timer(completion_delay).timeout

	hide()
	_current_phase = Phase.NONE
	minigame_completed.emit(success)


# Getter for safe zone parameters (used by SafeZoneDrawer)
func get_safe_zone_start() -> float:
	return _safe_zone_start


func get_safe_zone_angle() -> float:
	return safe_zone_angle


func is_safe_zone_visible() -> bool:
	return _safe_zone_visible
