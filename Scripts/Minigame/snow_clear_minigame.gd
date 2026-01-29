extends Control
class_name SnowClearMinigame

signal minigame_completed(success: bool)

enum Phase {
	NONE,
	WAITING_TO_START,
	ACTIVE,
	COMPLETED
}

# Configuration - exposed to inspector
@export var time_limit: float = 20.0  ## Seconds to clear all snow
@export var clear_radius: float = 50.0  ## Radius of clearing per swipe
@export var snow_opacity_decrease: float = 0.08  ## How much opacity decreases per swipe

@export_group("Particle Settings")
@export var particle_spawn_interval: float = 0.5  ## Seconds between particle spawns
@export var particles_per_spawn: int = 3  ## Number of particles to spawn
@export var particle_min_size: float = 4.0  ## Minimum particle radius
@export var particle_max_size: float = 12.0  ## Maximum particle radius
@export var particle_fall_speed: float = 80.0  ## Pixels per second
@export var particle_lifetime: float = 1.0  ## Seconds before particle fades

@export_group("Textures")
@export var background_images: Array[Texture2D] = []  ## 3 images for the 3 prompts

# Node references
@onready var background_image: TextureRect = $BackgroundImage
@onready var snow_container: Control = $SnowContainer
@onready var particle_container: Control = $ParticleContainer
@onready var tap_area: Control = $TapArea

# Pre-game UI (center panel)
@onready var pre_game_panel: Control = $PreGamePanel
@onready var title_label: Label = $PreGamePanel/VBoxContainer/TitleLabel
@onready var instruction_label: Label = $PreGamePanel/VBoxContainer/InstructionLabel
@onready var tap_to_start_label: Label = $PreGamePanel/VBoxContainer/TapToStartLabel

# In-game UI
@onready var timer_label: Label = $TimerLabel
@onready var hint_label: Label = $HintLabel

# State
var _current_phase: Phase = Phase.NONE
var _card_data: Dictionary = {}
var _time_remaining: float = 0.0
var _selected_prompt_index: int = 0

# Snow patches
var _snow_patches: Array[ColorRect] = []
var _snow_opacities: Array[float] = []

# Particle system
var _particle_timer: float = 0.0
var _active_particles: Array[Dictionary] = []

# Input tracking
var _is_clearing: bool = false
var _last_clear_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	hide()
	tap_area.gui_input.connect(_on_tap_area_input)


func _process(delta: float) -> void:
	# Always update particles (even during completion)
	if _current_phase == Phase.ACTIVE or _current_phase == Phase.COMPLETED:
		_update_particles(delta)
		# Decrement particle spawn timer
		if _particle_timer > 0:
			_particle_timer -= delta

	if _current_phase != Phase.ACTIVE:
		return

	# Update timer
	_time_remaining -= delta
	_update_timer_label()

	if _time_remaining <= 0:
		_time_remaining = 0
		_complete_minigame(false)
		return

	# Check win condition
	if _all_snow_cleared():
		_complete_minigame(true)
		return

	# Handle continuous clearing when touching/dragging
	if _is_clearing:
		_clear_snow_at(_last_clear_position)


func show_minigame(card_data: Dictionary) -> void:
	_card_data = card_data
	_reset_state()

	# Get description from raw card via GameManager
	var description = ""
	var card_id = str(card_data.get("card_id", ""))
	if card_id != "":
		var game_manager = get_tree().get_first_node_in_group("GameManager") as GameManager
		if game_manager and game_manager.deck:
			var raw_card = game_manager.deck.find_card_by_id(card_id)
			if not raw_card.is_empty():
				description = str(raw_card.get("Description", ""))

	# Split description by ;; (with or without spaces)
	var prompts: Array[String] = []
	if description.contains(";;"):
		var parts = description.split(";;")
		for part in parts:
			var trimmed = part.strip_edges()
			if trimmed != "":
				prompts.append(trimmed)

	# Select random prompt if we have multiple
	if prompts.size() > 1:
		_selected_prompt_index = randi() % prompts.size()
		instruction_label.text = prompts[_selected_prompt_index]
	elif prompts.size() == 1:
		_selected_prompt_index = 0
		instruction_label.text = prompts[0]
	else:
		# Fallback - use description as-is or default
		instruction_label.text = description if description != "" else "Clear the snow!"
		_selected_prompt_index = 0

	# Set background image based on prompt index
	if _selected_prompt_index < background_images.size() and background_images[_selected_prompt_index] != null:
		background_image.texture = background_images[_selected_prompt_index]
		background_image.visible = true
	else:
		background_image.visible = false

	# Show pre-game UI
	title_label.text = "Clear the Snow!"
	tap_to_start_label.text = "Tap to start!"
	pre_game_panel.visible = true

	# Hide in-game UI
	timer_label.visible = false
	hint_label.visible = false

	# Don't generate snow yet - wait for tap to start
	_time_remaining = time_limit

	show()

	# Wait for layout
	await get_tree().process_frame
	await get_tree().process_frame

	# Enable input for tap to start
	tap_area.show()
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_current_phase = Phase.WAITING_TO_START


func _start_game() -> void:
	# Hide pre-game UI
	pre_game_panel.visible = false

	# Show in-game UI
	timer_label.visible = true
	hint_label.visible = true
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))  # Orange like timer
	_update_timer_label()

	# Generate snow patches (fullscreen)
	_generate_snow_patches()

	_current_phase = Phase.ACTIVE


func _reset_state() -> void:
	_time_remaining = time_limit
	_is_clearing = false
	_particle_timer = 0.0

	# Clear existing snow patches
	for patch in _snow_patches:
		if is_instance_valid(patch):
			patch.queue_free()
	_snow_patches.clear()
	_snow_opacities.clear()

	# Clear particles
	for particle in _active_particles:
		var node = particle.get("node")
		if is_instance_valid(node):
			node.queue_free()
	_active_particles.clear()


func _generate_snow_patches() -> void:
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2(1080, 1920)  # Fallback

	# Create overlapping snow patches that cover the entire screen
	var cols = 4
	var rows = 6

	var patch_width = screen_size.x / float(cols)
	var patch_height = screen_size.y / float(rows)

	for row in range(rows):
		for col in range(cols):
			var patch = ColorRect.new()

			# Calculate base position with overlap
			var x = col * patch_width - patch_width * 0.15
			var y = row * patch_height - patch_height * 0.15

			# Add random offset
			x += randf_range(-15, 15)
			y += randf_range(-15, 15)

			# Size with overlap
			var w = patch_width * 1.4
			var h = patch_height * 1.4

			patch.position = Vector2(x, y)
			patch.size = Vector2(w, h)

			# White snow color with slight variation
			var snow_brightness = randf_range(0.92, 1.0)
			patch.color = Color(snow_brightness, snow_brightness + 0.02, 1.0, 1.0)
			patch.name = "SnowPatch_%d" % _snow_patches.size()

			snow_container.add_child(patch)
			_snow_patches.append(patch)
			_snow_opacities.append(1.0)


func _on_tap_area_input(event: InputEvent) -> void:
	if _current_phase == Phase.WAITING_TO_START:
		# Handle tap to start
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_start_game()
		elif event is InputEventScreenTouch:
			if event.pressed:
				_start_game()
		return

	if _current_phase != Phase.ACTIVE:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_clearing = event.pressed
			if event.pressed:
				_last_clear_position = _get_local_position(event.position)
				_clear_snow_at(_last_clear_position)
	elif event is InputEventMouseMotion:
		if _is_clearing:
			_last_clear_position = _get_local_position(event.position)
	elif event is InputEventScreenTouch:
		_is_clearing = event.pressed
		if event.pressed:
			_last_clear_position = _get_local_position(event.position)
			_clear_snow_at(_last_clear_position)
	elif event is InputEventScreenDrag:
		_last_clear_position = _get_local_position(event.position)
		if _is_clearing:
			_clear_snow_at(_last_clear_position)


func _get_local_position(global_pos: Vector2) -> Vector2:
	# Convert to local position relative to this control
	return get_local_mouse_position()


func _clear_snow_at(pos: Vector2) -> void:
	var did_clear = false

	# Clear snow patches near the position
	for i in range(_snow_patches.size()):
		if _snow_opacities[i] <= 0:
			continue

		var patch = _snow_patches[i]
		if not is_instance_valid(patch):
			continue

		# Check if position is near this patch
		var patch_center = patch.position + patch.size / 2.0
		var distance = pos.distance_to(patch_center)

		# Also check if position is inside the patch bounds
		var in_bounds = (
			pos.x >= patch.position.x and
			pos.x <= patch.position.x + patch.size.x and
			pos.y >= patch.position.y and
			pos.y <= patch.position.y + patch.size.y
		)

		if in_bounds or distance < clear_radius + patch.size.length() / 3.0:
			# Decrease opacity based on distance
			var clear_amount = snow_opacity_decrease
			if not in_bounds:
				clear_amount *= 0.3  # Less clearing if not directly on patch

			_snow_opacities[i] = max(0.0, _snow_opacities[i] - clear_amount)
			patch.color.a = _snow_opacities[i]
			did_clear = true

			# Add visual feedback
			if _snow_opacities[i] <= 0:
				patch.visible = false

	# Only spawn particles if we actually cleared some snow (with rate limiting)
	if did_clear and _particle_timer <= 0:
		_particle_timer = particle_spawn_interval
		_spawn_particles(pos)


func _all_snow_cleared() -> bool:
	# All patches must be fully cleared
	for opacity in _snow_opacities:
		if opacity > 0.05:  # Any patch above 5% means not done
			return false
	return true


func _spawn_particles(pos: Vector2) -> void:
	for i in range(particles_per_spawn):
		var particle = ColorRect.new()

		# Random size
		var psize = randf_range(particle_min_size, particle_max_size)
		particle.size = Vector2(psize, psize)

		# Position with random offset
		var offset_x = randf_range(-30, 30)
		var offset_y = randf_range(-10, 10)
		particle.position = pos + Vector2(offset_x, offset_y) - particle.size / 2.0

		# White color
		particle.color = Color(1.0, 1.0, 1.0, 0.9)

		particle_container.add_child(particle)

		_active_particles.append({
			"node": particle,
			"velocity": Vector2(randf_range(-20, 20), particle_fall_speed),
			"lifetime": particle_lifetime,
			"max_lifetime": particle_lifetime
		})


func _update_particles(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(_active_particles.size()):
		var p = _active_particles[i]
		var node = p.get("node") as ColorRect

		if not is_instance_valid(node):
			to_remove.append(i)
			continue

		# Update position
		node.position += p["velocity"] * delta

		# Update lifetime
		p["lifetime"] -= delta

		# Fade out
		var alpha = p["lifetime"] / p["max_lifetime"]
		node.color.a = alpha * 0.9

		if p["lifetime"] <= 0:
			to_remove.append(i)
			node.queue_free()

	# Remove dead particles (reverse order)
	to_remove.reverse()
	for idx in to_remove:
		_active_particles.remove_at(idx)


func _update_timer_label() -> void:
	var seconds = int(_time_remaining)
	var color = Color(1.0, 0.7, 0.2, 1.0)  # Orange default

	if _time_remaining <= 5:
		color = Color(0.9, 0.3, 0.2, 1.0)  # Red when low

	timer_label.text = "Time: %d" % seconds
	timer_label.add_theme_color_override("font_color", color)


func _complete_minigame(success: bool) -> void:
	_current_phase = Phase.COMPLETED
	_is_clearing = false
	tap_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Show result in hint label
	if success:
		hint_label.text = "Snow cleared!"
		hint_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))  # Green for success
	else:
		hint_label.text = "Not cleared!"
		hint_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Red for fail

	await get_tree().create_timer(1.5).timeout

	hide()
	_current_phase = Phase.NONE
	minigame_completed.emit(success)
