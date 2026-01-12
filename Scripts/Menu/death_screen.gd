extends Control
class_name DeathScreen

signal restart_requested

@onready var background: ColorRect = $Background
@onready var scroll_container: ScrollContainer = $ContentContainer/ScrollContainer
@onready var timeline_bar: Control = $ContentContainer/ScrollContainer/TimelineBar
@onready var markers_container: Control = $ContentContainer/ScrollContainer/TimelineBar/MarkersContainer
@onready var chief_info_label: Label = $ContentContainer/ChiefInfoLabel
@onready var tap_prompt: Label = $TapPrompt

# Configuration
const PIXELS_PER_DAY := 15.0  # How many pixels represent one day
const MARKER_SIZE := Vector2(8, 40)  # Width, Height of square markers
const TIMELINE_HEIGHT := 20.0
const ANIMATION_DURATION := 2.0
const TIMELINE_PADDING := 100.0  # Extra padding on right side

var _dead_chiefs: Array = []
var _current_chief_data: Dictionary = {}
var _max_day: int = 0
var _animation_complete: bool = false
var _tween: Tween


func _ready() -> void:
	hide()
	tap_prompt.hide()
	chief_info_label.text = ""


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _animation_complete:
		if event is InputEventMouseButton and event.pressed:
			_on_restart()
		elif event is InputEventScreenTouch and event.pressed:
			_on_restart()


func _on_restart() -> void:
	restart_requested.emit()
	hide()
	_animation_complete = false
	tap_prompt.hide()
	chief_info_label.text = ""
	# Clear markers
	for child in markers_container.get_children():
		child.queue_free()


func show_death_screen(dead_chiefs_history: Array, current_chief: Dictionary) -> void:
	_dead_chiefs = dead_chiefs_history.duplicate()
	_current_chief_data = current_chief
	_animation_complete = false

	# Calculate max day for timeline width
	_calculate_max_day()

	# Setup timeline
	_setup_timeline()

	# Create markers for previous chiefs
	_create_chief_markers()

	# Show and start animation
	show()
	_animate_current_chief()


func _calculate_max_day() -> void:
	_max_day = _current_chief_data.get("death_day", 0)
	for chief in _dead_chiefs:
		var death_day = chief.get("death_day", 0)
		if death_day > _max_day:
			_max_day = death_day

	# Ensure minimum width
	_max_day = max(_max_day, 10)


func _setup_timeline() -> void:
	var timeline_width = _max_day * PIXELS_PER_DAY + TIMELINE_PADDING
	timeline_bar.custom_minimum_size.x = timeline_width


func _create_chief_markers() -> void:
	# Clear existing markers
	for child in markers_container.get_children():
		child.queue_free()

	# Create markers for each dead chief (previous chiefs)
	for chief in _dead_chiefs:
		_create_segment_for_chief(chief, Color(0.4, 0.4, 0.5, 0.8))


func _create_segment_for_chief(chief: Dictionary, color: Color) -> void:
	"""Create a segment showing the chief's reign from start_day to death_day."""
	var start_day = chief.get("start_day", 0)
	var death_day = chief.get("death_day", 0)
	var start_x = start_day * PIXELS_PER_DAY
	var width = (death_day - start_day) * PIXELS_PER_DAY

	# Create the segment bar
	var segment = ColorRect.new()
	segment.color = color
	segment.position = Vector2(start_x, 0)
	segment.size = Vector2(max(width, MARKER_SIZE.x), MARKER_SIZE.y)
	markers_container.add_child(segment)

	# Create start marker (square)
	var start_marker = ColorRect.new()
	start_marker.color = Color.WHITE
	start_marker.position = Vector2(start_x, 0)
	start_marker.size = MARKER_SIZE
	markers_container.add_child(start_marker)

	# Create end marker (square)
	var end_marker = ColorRect.new()
	end_marker.color = Color.WHITE
	end_marker.position = Vector2(start_x + width - MARKER_SIZE.x, 0)
	end_marker.size = MARKER_SIZE
	markers_container.add_child(end_marker)


func _animate_current_chief() -> void:
	_animation_complete = false

	var start_day = _current_chief_data.get("start_day", 0)
	var death_day = _current_chief_data.get("death_day", 0)
	var start_x = start_day * PIXELS_PER_DAY
	var end_x = death_day * PIXELS_PER_DAY
	var segment_width = (death_day - start_day) * PIXELS_PER_DAY

	# Create animated segment for current chief
	var animated_segment = ColorRect.new()
	animated_segment.color = Color(0.8, 0.3, 0.3, 0.9)  # Red-ish for current chief
	animated_segment.position = Vector2(start_x, 0)
	animated_segment.size = Vector2(MARKER_SIZE.x, MARKER_SIZE.y)  # Start small
	markers_container.add_child(animated_segment)

	# Create start marker for current chief
	var start_marker = ColorRect.new()
	start_marker.color = Color(1.0, 0.8, 0.2)  # Gold color
	start_marker.position = Vector2(start_x, 0)
	start_marker.size = MARKER_SIZE
	markers_container.add_child(start_marker)

	# Kill any existing tween
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)

	# Animate segment growth (width expands to show reign duration)
	_tween.tween_property(animated_segment, "size:x", segment_width, ANIMATION_DURATION)

	# Scroll to follow animation
	var scroll_start = max(0, start_x - 100)
	var scroll_end = max(0, end_x - scroll_container.size.x / 2)
	_tween.parallel().tween_method(
		_scroll_to,
		scroll_start,
		scroll_end,
		ANIMATION_DURATION
	)

	_tween.tween_callback(_on_animation_complete)


func _scroll_to(scroll_val: float) -> void:
	scroll_container.scroll_horizontal = int(scroll_val)


func _on_animation_complete() -> void:
	_animation_complete = true

	# Create end marker for current chief
	var death_day = _current_chief_data.get("death_day", 0)
	var end_x = death_day * PIXELS_PER_DAY

	var end_marker = ColorRect.new()
	end_marker.color = Color(1.0, 0.8, 0.2)  # Gold color
	end_marker.position = Vector2(end_x - MARKER_SIZE.x, 0)
	end_marker.size = MARKER_SIZE
	markers_container.add_child(end_marker)

	# Show chief info
	var chief_name = _current_chief_data.get("name", "Unknown")
	var start_day = _current_chief_data.get("start_day", 0)
	var death_day_val = _current_chief_data.get("death_day", 0)
	var days_lived = death_day_val - start_day

	chief_info_label.text = "%s - lived %d days" % [chief_name, days_lived]

	# Show tap prompt
	tap_prompt.show()
