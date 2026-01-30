extends Control
class_name PipePatchMinigame

signal minigame_completed(success: bool)

enum Phase {
	NONE,
	WAITING_TO_START,
	ACTIVE,
	BETWEEN_PASSES,
	BETWEEN_RUNS,
	COMPLETED
}

enum NeedleDirection {
	LEFT_TO_RIGHT,
	RIGHT_TO_LEFT
}

# Configuration - exposed to inspector
@export var needle_speed: float = 300.0  ## Pixels per second
@export var passes_per_run: int = 2  ## How many times needle goes back and forth
@export var total_runs: int = 2  ## How many pipes to patch (runs)
@export var spots_per_run: int = 3  ## Number of spots to patch per run
@export var spot_width: float = 60.0  ## Width of each patch spot
@export var allowed_misses_per_run: int = 1  ## Can miss this many spots per run
@export var between_run_delay: float = 2.0  ## Seconds between runs
@export var tap_tolerance: float = 30.0  ## Extra pixels for tap detection
@export var camera_shake_enabled: bool = true  ## Enable camera shake on tap
@export var camera_shake_strength: float = 5.0  ## Shake intensity
@export var camera_shake_duration: float = 0.1  ## Shake duration

# Export textures for customization
@export_group("Textures")
@export var pipe_background_texture: Texture2D  ## Pipe bar background
@export var unpatched_texture: Texture2D  ## Unpatched spot image
@export var patched_texture: Texture2D  ## Patched spot image
@export var needle_texture: Texture2D  ## Needle/indicator image
@export var checkmark_texture: Texture2D  ## Checkmark for completed runs

# Node references
@onready var background: ColorRect = $Background
@onready var title_label: Label = $ContentContainer/VBoxContainer/TitleLabel
@onready var instruction_label: Label = $ContentContainer/VBoxContainer/InstructionLabel
@onready var hint_label: Label = $ContentContainer/VBoxContainer/HintLabel
@onready var pipe_container: Control = $ContentContainer/VBoxContainer/PipeContainer
@onready var pipe_bar: Control = $ContentContainer/VBoxContainer/PipeContainer/PipeBar
@onready var needle: ColorRect = $ContentContainer/VBoxContainer/PipeContainer/PipeBar/Needle
@onready var spots_container: Control = $ContentContainer/VBoxContainer/PipeContainer/PipeBar/SpotsContainer
@onready var checkbox_container: HBoxContainer = $ContentContainer/VBoxContainer/CheckboxContainer
@onready var taps_label: Label = $ContentContainer/VBoxContainer/TapsLabel
@onready var tap_area: Control = $TapArea

# State
var _current_phase: Phase = Phase.NONE
var _card_data: Dictionary = {}
var _current_run: int = 0
var _current_pass: int = 0
var _needle_direction: NeedleDirection = NeedleDirection.LEFT_TO_RIGHT
var _needle_position: float = 0.0
var _bar_width: float = 0.0
var _bar_height: float = 0.0

# Spot tracking
var _spot_positions: Array[float] = []  # X positions of spots
var _spot_patched: Array[bool] = []  # Whether each spot is patched
var _spot_nodes: Array[Control] = []  # Visual nodes for spots
var _misses_this_run: int = 0
var _taps_remaining: int = 0  # Tap limit per run
var _tap_cooldown: float = 0.0  # Prevent double taps

# Checkbox tracking
var _checkboxes: Array[Panel] = []
var _checkmarks: Array[TextureRect] = []

# Camera shake
var _original_position: Vector2 = Vector2.ZERO
var _shake_timer: float = 0.0


func _ready() -> void:
	hide()

	# Load checkmark texture if not set
	if not checkmark_texture:
		checkmark_texture = load("res://Assets/Sprites/check-mark.png")

	# Setup tap area
	tap_area.gui_input.connect(_on_tap_area_input)

	# Block input on background
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	# Setup checkboxes
	_setup_checkboxes()


func _process(delta: float) -> void:
	# Handle tap cooldown
	if _tap_cooldown > 0:
		_tap_cooldown -= delta

	# Handle camera shake
	if _shake_timer > 0:
		_shake_timer -= delta
		if _shake_timer <= 0:
			pipe_container.position = _original_position
		else:
			var shake_offset = Vector2(
				randf_range(-camera_shake_strength, camera_shake_strength),
				randf_range(-camera_shake_strength, camera_shake_strength)
			)
			pipe_container.position = _original_position + shake_offset

	if _current_phase != Phase.ACTIVE:
		return

	# Move needle
	var move_delta = needle_speed * delta
	if _needle_direction == NeedleDirection.LEFT_TO_RIGHT:
		_needle_position += move_delta
		if _needle_position >= _bar_width:
			_needle_position = _bar_width
			_on_pass_complete()
	else:
		_needle_position -= move_delta
		if _needle_position <= 0:
			_needle_position = 0
			_on_pass_complete()

	# Update needle visual
	needle.position.x = _needle_position - needle.size.x / 2.0


func show_minigame(card_data: Dictionary) -> void:
	_card_data = card_data
	_reset_state()

	title_label.text = "Pipe Repair"
	instruction_label.text = "Tap to begin!"
	hint_label.text = "Tap when the needle is over green areas"
	_taps_remaining = spots_per_run
	_update_taps_label()

	show()

	# Wait for layout to complete before getting bar width
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for safety
	_bar_width = pipe_bar.size.x
	_bar_height = pipe_bar.size.y
	_original_position = pipe_container.position

	# Only allow input AFTER layout is ready
	tap_area.show()
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_current_phase = Phase.WAITING_TO_START


func _reset_state() -> void:
	_current_run = 0
	_current_pass = 0
	_needle_direction = NeedleDirection.LEFT_TO_RIGHT
	_needle_position = 0.0
	_misses_this_run = 0

	# Reset checkboxes
	for i in range(_checkboxes.size()):
		var checkbox = _checkboxes[i]
		var checkmark = _checkmarks[i]
		checkbox.self_modulate = Color(0.3, 0.3, 0.35, 1.0)
		if checkmark:
			checkmark.modulate.a = 0.0
			checkmark.scale = Vector2.ZERO

	# Clear existing spots
	_clear_spots()

	# Reset needle position
	if needle:
		needle.position.x = -needle.size.x / 2.0


func _setup_checkboxes() -> void:
	_checkboxes.clear()
	_checkmarks.clear()

	for i in range(total_runs):
		if i < checkbox_container.get_child_count():
			var checkbox = checkbox_container.get_child(i) as Panel
			if checkbox:
				_checkboxes.append(checkbox)

				# Get or create checkmark
				var checkmark: TextureRect
				if checkbox.get_child_count() > 0:
					checkmark = checkbox.get_child(0) as TextureRect
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


func _clear_spots() -> void:
	_spot_positions.clear()
	_spot_patched.clear()
	for node in _spot_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_spot_nodes.clear()


func _generate_spots() -> void:
	_clear_spots()

	if _bar_width <= 0:
		return

	# Calculate available space (with margins)
	var margin = spot_width * 1.5
	var available_width = _bar_width - (margin * 2)
	var min_spacing = spot_width * 1.2  # Minimum space between spots

	# Generate random positions that don't overlap
	var positions: Array[float] = []
	var attempts = 0
	var max_attempts = 100

	while positions.size() < spots_per_run and attempts < max_attempts:
		attempts += 1
		var x_pos = margin + randf() * available_width

		# Check if this position overlaps with existing spots
		var valid = true
		for existing_pos in positions:
			if abs(x_pos - existing_pos) < min_spacing:
				valid = false
				break

		if valid:
			positions.append(x_pos)

	# Sort positions left to right for better gameplay
	positions.sort()

	# Create spots at the random positions
	for x_pos in positions:
		_spot_positions.append(x_pos)
		_spot_patched.append(false)

		# Create visual spot
		var spot_node = _create_spot_visual(x_pos)
		_spot_nodes.append(spot_node)


func _create_spot_visual(x_pos: float) -> Control:
	var height = _bar_height if _bar_height > 0 else 120.0  # Fallback height

	# Create spot as ColorRect directly (simpler and more reliable)
	var spot = ColorRect.new()
	spot.color = Color(0.2, 0.95, 0.3, 0.9)  # Bright green
	spot.size = Vector2(spot_width, height)
	spot.position = Vector2(x_pos - spot_width / 2.0, 0)
	spot.name = "Spot_%d" % _spot_nodes.size()

	# Add a border/outline effect with inner ColorRect
	var inner = ColorRect.new()
	inner.color = Color(0.1, 0.7, 0.2, 1.0)  # Darker green border
	inner.position = Vector2(4, 4)
	inner.size = Vector2(spot_width - 8, height - 8)
	inner.name = "SpotInner"
	spot.add_child(inner)

	# Unpatched indicator
	if unpatched_texture:
		var tex_rect = TextureRect.new()
		tex_rect.texture = unpatched_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.position = Vector2.ZERO
		tex_rect.size = Vector2(spot_width, height)
		tex_rect.name = "UnpatchedImage"
		spot.add_child(tex_rect)

	# Patched indicator (hidden initially)
	var patched_indicator = ColorRect.new()
	patched_indicator.position = Vector2.ZERO
	patched_indicator.size = Vector2(spot_width, height)
	patched_indicator.color = Color(0.5, 0.5, 0.5, 0.0)  # Transparent initially
	patched_indicator.name = "PatchedIndicator"
	spot.add_child(patched_indicator)

	if patched_texture:
		var tex_rect = TextureRect.new()
		tex_rect.texture = patched_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.position = Vector2.ZERO
		tex_rect.size = Vector2(spot_width, height)
		tex_rect.modulate.a = 0.0
		tex_rect.name = "PatchedImage"
		spot.add_child(tex_rect)

	if spots_container:
		spots_container.add_child(spot)
	else:
		pipe_bar.add_child(spot)  # Fallback
	return spot


func _on_tap_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_tap()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_tap()


func _on_tap() -> void:
	# Prevent double taps
	if _tap_cooldown > 0:
		return

	match _current_phase:
		Phase.WAITING_TO_START:
			_tap_cooldown = 0.6  # Longer cooldown when starting
			_start_run()
		Phase.ACTIVE:
			_tap_cooldown = 0.1  # Short cooldown between patches
			_try_patch()


func _start_run() -> void:
	_current_run += 1
	_current_pass = 0
	_misses_this_run = 0
	_needle_direction = NeedleDirection.LEFT_TO_RIGHT
	_needle_position = 0.0

	# Set phase to prevent immediate taps
	_current_phase = Phase.BETWEEN_PASSES

	# Generate new spots for this run
	_generate_spots()

	# Reset tap limit to match number of spots
	_taps_remaining = spots_per_run
	_update_taps_label()

	instruction_label.text = "Get ready..."
	hint_label.text = "Pipe %d of %d" % [_current_run, total_runs]

	# Small delay before starting so player can see spots
	await get_tree().create_timer(0.5).timeout

	instruction_label.text = "Tap when over green spots!"
	_start_pass()


func _start_pass() -> void:
	_current_pass += 1
	_current_phase = Phase.ACTIVE


func _on_pass_complete() -> void:
	_current_phase = Phase.BETWEEN_PASSES

	if _current_pass >= passes_per_run:
		# Run complete - check results
		_on_run_complete()
	else:
		# Switch direction for next pass
		_needle_direction = NeedleDirection.RIGHT_TO_LEFT if _needle_direction == NeedleDirection.LEFT_TO_RIGHT else NeedleDirection.LEFT_TO_RIGHT
		_start_pass()


func _try_patch() -> void:
	# Check if we have taps remaining
	if _taps_remaining <= 0:
		return

	# Apply camera shake if enabled
	if camera_shake_enabled:
		_shake_timer = camera_shake_duration

	# Decrement tap counter
	_taps_remaining -= 1
	_update_taps_label()

	# Check if needle is over any unpatched spot
	var patched_something = false
	for i in range(_spot_positions.size()):
		if _spot_patched[i]:
			continue

		var spot_x = _spot_positions[i]
		var distance = abs(_needle_position - spot_x)

		if distance <= (spot_width / 2.0) + tap_tolerance:
			# Successful patch!
			_patch_spot(i)
			patched_something = true
			break

	if not patched_something:
		# Tapped outside valid areas - visual feedback
		_show_miss_feedback()

	# Check if out of taps with unpatched spots remaining
	if _taps_remaining <= 0:
		var unpatched_count = 0
		for patched in _spot_patched:
			if not patched:
				unpatched_count += 1

		if unpatched_count > allowed_misses_per_run:
			# Out of taps and too many spots left - fail
			_current_phase = Phase.BETWEEN_PASSES
			await get_tree().create_timer(0.3).timeout
			_on_run_complete()


func _update_taps_label() -> void:
	if taps_label:
		taps_label.text = "Taps: %d" % _taps_remaining
		if _taps_remaining <= 1:
			LabelUtils.set_font_color(taps_label, Color(0.9, 0.3, 0.2))
		else:
			LabelUtils.remove_font_color(taps_label)


func _patch_spot(index: int) -> void:
	_spot_patched[index] = true

	# Update visual
	var spot_node = _spot_nodes[index] as ColorRect
	if spot_node:
		var tween = create_tween()
		# Fade out the green spot (the spot itself is a ColorRect now)
		tween.tween_property(spot_node, "color", Color(0.3, 0.5, 0.7, 0.8), 0.2)

		# Fade out inner green
		var inner = spot_node.get_node_or_null("SpotInner")
		if inner:
			tween.parallel().tween_property(inner, "color", Color(0.2, 0.4, 0.6, 1.0), 0.2)

		# Hide unpatched image
		var unpatched_img = spot_node.get_node_or_null("UnpatchedImage")
		if unpatched_img:
			tween.parallel().tween_property(unpatched_img, "modulate:a", 0.0, 0.2)

		# Show patched indicator
		var patched_indicator = spot_node.get_node_or_null("PatchedIndicator")
		if patched_indicator:
			tween.parallel().tween_property(patched_indicator, "color", Color(0.4, 0.6, 0.8, 0.6), 0.2)

		# Show patched image
		var patched_img = spot_node.get_node_or_null("PatchedImage")
		if patched_img:
			tween.parallel().tween_property(patched_img, "modulate:a", 1.0, 0.2)

	# Success feedback
	instruction_label.text = "Patched!"
	LabelUtils.set_font_color(instruction_label, Color(0.2, 0.8, 0.3))

	# Reset instruction after brief delay
	await get_tree().create_timer(0.3).timeout
	if _current_phase == Phase.ACTIVE:
		instruction_label.text = "Keep going!"
		LabelUtils.remove_font_color(instruction_label)


func _show_miss_feedback() -> void:
	# Brief red flash on instruction
	LabelUtils.set_font_color(instruction_label, Color(0.9, 0.3, 0.2))
	await get_tree().create_timer(0.15).timeout
	if _current_phase == Phase.ACTIVE:
		LabelUtils.remove_font_color(instruction_label)


func _on_run_complete() -> void:
	# Count unpatched spots
	var unpatched_count = 0
	for patched in _spot_patched:
		if not patched:
			unpatched_count += 1

	# Check if run passed (missed <= allowed)
	var run_success = unpatched_count <= allowed_misses_per_run

	if run_success:
		# Show checkmark for this run
		_show_checkmark(_current_run - 1, true)
		instruction_label.text = "Pipe %d repaired!" % _current_run
		LabelUtils.set_font_color(instruction_label, Color(0.2, 0.8, 0.3))
	else:
		# Run failed
		_show_checkmark(_current_run - 1, false)
		instruction_label.text = "Pipe %d failed!" % _current_run
		LabelUtils.set_font_color(instruction_label, Color(0.9, 0.2, 0.2))
		await get_tree().create_timer(1.0).timeout
		_complete_minigame(false)
		return

	if _current_run >= total_runs:
		# All runs complete - success!
		await get_tree().create_timer(1.0).timeout
		_complete_minigame(true)
	else:
		# Prepare for next run
		_current_phase = Phase.BETWEEN_RUNS
		hint_label.text = "Next pipe in %.0f seconds..." % between_run_delay
		await get_tree().create_timer(between_run_delay).timeout

		if _current_phase == Phase.BETWEEN_RUNS:
			LabelUtils.remove_font_color(instruction_label)
			_start_run()


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

	if success and checkmark:
		# Animate checkmark appearance
		checkmark.pivot_offset = checkbox.size / 2.0
		tween.parallel().tween_property(checkmark, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(checkmark, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _complete_minigame(success: bool) -> void:
	_current_phase = Phase.COMPLETED
	tap_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if success:
		instruction_label.text = "All pipes repaired!"
		LabelUtils.set_font_color(instruction_label, Color(0.2, 0.8, 0.3))
	else:
		instruction_label.text = "Repair failed!"
		LabelUtils.set_font_color(instruction_label, Color(0.9, 0.2, 0.2))

	await get_tree().create_timer(1.5).timeout

	hide()
	_current_phase = Phase.NONE
	minigame_completed.emit(success)


# Getters for potential visual components
func get_needle_position() -> float:
	return _needle_position


func get_bar_width() -> float:
	return _bar_width


func is_active() -> bool:
	return _current_phase == Phase.ACTIVE
