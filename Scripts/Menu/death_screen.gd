extends Control
class_name DeathScreen

signal restart_requested
signal need_quest_data
signal need_new_chief_name
signal ending_reset_requested

# Node references
@onready var background: ColorRect = $Background
@onready var content_container: VBoxContainer = $ContentContainer
@onready var days_count_label: Label = $ContentContainer/DaysCountContainer/DaysCountLabel
@onready var days_increment_label: Label = $ContentContainer/DaysCountContainer/DaysIncrementLabel
@onready var days_lived_label: Label = $ContentContainer/DaysLivedLabel
@onready var chief_container: VBoxContainer = $ContentContainer/ChiefContainer
@onready var new_chief_title: Label = $ContentContainer/ChiefContainer/NewChiefTitle
@onready var chief_name_label: Label = $ContentContainer/ChiefContainer/ChiefNameLabel
@onready var quest_container: VBoxContainer = $ContentContainer/QuestContainer
@onready var continue_button: Button = $ContinueButton
@onready var tap_hint: Label = $TapHint
@onready var ending_skip_container: Control = $EndingSkipContainer
@onready var ending_skip_hint: Label = $EndingSkipContainer/EndingSkipHint
@onready var ending_skip_circle: SkipCircleDrawer = $EndingSkipContainer/EndingSkipCircle
@onready var reset_popup: Control = $ResetPopup
@onready var reset_ok_button: Button = $ResetPopup/VBoxContainer/ResetOKButton

# Configuration
const COUNT_ANIMATION_DURATION := 2.0
const POP_SCALE_UP_DURATION := 0.25
const POP_SCALE_DOWN_DURATION := 0.15
const POP_OVERSHOOT := 1.15
const QUEST_POP_DELAY := 0.12
const QUEST_CHECK_DELAY := 0.15
const QUEST_BOX_SIZE := 40.0

# Colors
const COLOR_QUEST_INCOMPLETE := Color(0.25, 0.25, 0.3, 1)
const COLOR_QUEST_COMPLETE := Color(0.2, 0.7, 0.3, 1)

# Phase enum
enum Phase {
	NONE,
	COUNTING,
	CHIEF_REVEAL,
	QUEST_DISPLAY,
	COMPLETE,
	ENDING_COUNTDOWN
}

# Data
var _current_phase: int = Phase.NONE
var _previous_total_days: int = 0
var _current_total_days: int = 0
var _days_this_chief: int = 0
var _new_chief_name: String = ""
var _quest_data: Array = []
var _quest_items: Array = []

# Animation references
var _count_tween: Tween
var _phase_tween: Tween
var _checkmark_texture: Texture2D

# Input tracking
var _touch_start_pos: Vector2
var _is_tracking_touch: bool = false
const TAP_THRESHOLD := 20.0

# Ending mode
var _is_ending_mode: bool = false
var _all_chiefs_history: Array = []
var _ending_total_days: int = 0
var _ending_skip_hold_time: float = 0.0
var _ending_skip_active: bool = false
var _ending_countdown_tween: Tween
var _sorted_chiefs_for_countdown: Array = []
var _current_chief_display_index: int = 0
const ENDING_SKIP_HOLD_DURATION := 3.0

func _ready() -> void:
	hide()
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.hide()
	tap_hint.hide()
	chief_container.visible = false
	ending_skip_container.visible = false
	reset_popup.visible = false
	reset_ok_button.pressed.connect(_on_reset_ok_pressed)

	_checkmark_texture = load("res://Assets/Sprites/check-mark.png")

func _process(delta: float) -> void:
	if not visible or not _is_ending_mode:
		return

	if _ending_skip_active:
		_ending_skip_hold_time += delta
		ending_skip_circle.progress = _ending_skip_hold_time / ENDING_SKIP_HOLD_DURATION
		ending_skip_circle.queue_redraw()

		if _ending_skip_hold_time >= ENDING_SKIP_HOLD_DURATION:
			_ending_skip_active = false
			_skip_ending_countdown()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _is_ending_mode and _current_phase == Phase.ENDING_COUNTDOWN:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_ending_press_start()
				else:
					_ending_press_end()
		elif event is InputEventScreenTouch:
			if event.index == 0:
				if event.pressed:
					_ending_press_start()
				else:
					_ending_press_end()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_press(event.position)
			else:
				_handle_release(event.position)

	elif event is InputEventScreenTouch:
		if event.index == 0:
			if event.pressed:
				_handle_press(event.position)
			else:
				_handle_release(event.position)

func _handle_press(pos: Vector2) -> void:
	_touch_start_pos = pos
	_is_tracking_touch = true

func _handle_release(pos: Vector2) -> void:
	if not _is_tracking_touch:
		return

	_is_tracking_touch = false
	var distance = pos.distance_to(_touch_start_pos)

	if distance < TAP_THRESHOLD:
		_handle_skip_input()

func _handle_skip_input() -> void:
	match _current_phase:
		Phase.COUNTING:
			_skip_counting()
		Phase.CHIEF_REVEAL:
			_skip_chief_reveal()
		Phase.QUEST_DISPLAY:
			_skip_quest_display()

func set_quest_data(quests: Array) -> void:
	_quest_data = quests

func set_new_chief_name(chief_name: String) -> void:
	_new_chief_name = chief_name

func show_death_screen(dead_chiefs_history: Array, current_chief: Dictionary) -> void:
	# Calculate previous total (before this chief died)
	_previous_total_days = current_chief.get("start_day", 0)
	_current_total_days = current_chief.get("death_day", 0)
	_days_this_chief = _current_total_days - _previous_total_days

	# Reset UI
	_current_phase = Phase.NONE
	continue_button.hide()
	tap_hint.hide()
	chief_container.visible = false
	chief_container.scale = Vector2.ONE
	days_increment_label.modulate.a = 1.0

	# Set initial values
	days_count_label.text = str(_previous_total_days)
	days_increment_label.text = "+%d" % _days_this_chief
	days_lived_label.text = "DAYS LIVED"

	# Request data
	need_quest_data.emit()
	need_new_chief_name.emit()

	# Clear previous quests
	_cleanup_quests()

	show()

	await get_tree().process_frame
	_start_counting_animation()

func _start_counting_animation() -> void:
	_current_phase = Phase.COUNTING
	tap_hint.show()
	_start_tap_hint_blink()

	if _count_tween:
		_count_tween.kill()

	_count_tween = create_tween()

	# Animate the count from previous total to current total
	_count_tween.tween_method(_update_count_display, float(_previous_total_days), float(_current_total_days), COUNT_ANIMATION_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fade out the increment label during the animation
	_count_tween.parallel().tween_property(days_increment_label, "modulate:a", 0.0, COUNT_ANIMATION_DURATION * 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_count_tween.tween_callback(_on_counting_complete)

func _update_count_display(value: float) -> void:
	days_count_label.text = str(int(value))

func _skip_counting() -> void:
	if _count_tween:
		_count_tween.kill()

	days_count_label.text = str(_current_total_days)
	days_increment_label.modulate.a = 0.0
	_on_counting_complete()

func _on_counting_complete() -> void:
	_start_chief_reveal()

func _start_chief_reveal() -> void:
	_current_phase = Phase.CHIEF_REVEAL

	if _new_chief_name.is_empty():
		_start_quest_display()
		return

	chief_name_label.text = _new_chief_name

	# Setup for pop animation
	chief_container.scale = Vector2.ZERO
	chief_container.visible = true

	# Wait a frame for layout to calculate, then set pivot
	await get_tree().process_frame
	chief_container.pivot_offset = chief_container.size / 2

	if _phase_tween:
		_phase_tween.kill()

	# Pop animation: 0 -> 1.15 -> 1.0
	_phase_tween = create_tween()
	_phase_tween.tween_property(chief_container, "scale", Vector2.ONE * POP_OVERSHOOT, POP_SCALE_UP_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_phase_tween.tween_property(chief_container, "scale", Vector2.ONE, POP_SCALE_DOWN_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_phase_tween.tween_interval(0.3)
	_phase_tween.tween_callback(_start_quest_display)

func _skip_chief_reveal() -> void:
	if _phase_tween:
		_phase_tween.kill()

	chief_container.visible = true
	chief_container.scale = Vector2.ONE
	_start_quest_display()

func _start_quest_display() -> void:
	_current_phase = Phase.QUEST_DISPLAY
	_cleanup_quests()

	var sorted_quests := _get_priority_quests()
	if sorted_quests.is_empty():
		_on_all_phases_complete()
		return

	# Create quest items with initial scale 0
	for i in range(min(3, sorted_quests.size())):
		var quest = sorted_quests[i]
		var quest_item := _create_quest_item(quest)
		quest_item.scale = Vector2.ZERO
		quest_container.add_child(quest_item)
		_quest_items.append({
			"container": quest_item,
			"is_completed": quest.get("is_completed", false)
		})

	# Wait for layout to calculate sizes
	await get_tree().process_frame

	# Set pivot offsets now that sizes are known
	for item in _quest_items:
		var container: Control = item.get("container")
		container.pivot_offset = container.size / 2

	# Pop in each quest item sequentially with overshoot
	_animate_quest_pop(0)

func _animate_quest_pop(index: int) -> void:
	if index >= _quest_items.size():
		# All quests popped, wait a bit then animate checkmarks
		if _phase_tween:
			_phase_tween.kill()
		_phase_tween = create_tween()
		_phase_tween.tween_interval(0.2)
		_phase_tween.tween_callback(_animate_quest_checkmarks)
		return

	var item = _quest_items[index]
	var container: Control = item.get("container")

	if _phase_tween:
		_phase_tween.kill()

	# Pop animation: 0 -> 1.15 -> 1.0
	_phase_tween = create_tween()
	_phase_tween.tween_property(container, "scale", Vector2.ONE * POP_OVERSHOOT, POP_SCALE_UP_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_phase_tween.tween_property(container, "scale", Vector2.ONE, POP_SCALE_DOWN_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_phase_tween.tween_callback(_animate_quest_pop.bind(index + 1))

func _get_priority_quests() -> Array:
	var completed := []
	var active := []
	for quest in _quest_data:
		if quest.get("is_completed", false):
			completed.append(quest)
		elif quest.get("is_unlocked", false):
			active.append(quest)
	return completed + active

func _create_quest_item(quest: Dictionary) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, QUEST_BOX_SIZE)
	container.add_theme_constant_override("separation", 12)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := ColorRect.new()
	box.custom_minimum_size = Vector2(QUEST_BOX_SIZE, QUEST_BOX_SIZE)
	box.color = COLOR_QUEST_INCOMPLETE
	box.pivot_offset = Vector2(QUEST_BOX_SIZE / 2, QUEST_BOX_SIZE / 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(box)

	var checkmark := TextureRect.new()
	checkmark.texture = _checkmark_texture
	checkmark.custom_minimum_size = Vector2(QUEST_BOX_SIZE * 0.7, QUEST_BOX_SIZE * 0.7)
	checkmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	checkmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	checkmark.position = Vector2(QUEST_BOX_SIZE * 0.15, QUEST_BOX_SIZE * 0.15)
	checkmark.size = Vector2(QUEST_BOX_SIZE * 0.7, QUEST_BOX_SIZE * 0.7)
	checkmark.modulate = Color(1, 1, 1, 0)
	checkmark.pivot_offset = checkmark.size / 2
	checkmark.scale = Vector2.ZERO
	checkmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(checkmark)

	var desc_label := Label.new()
	desc_label.text = quest.get("description", quest.get("title", "Quest"))
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(desc_label)

	box.set_meta("checkmark", checkmark)
	container.set_meta("box", box)
	return container

func _animate_quest_checkmarks() -> void:
	var delay := 0.0
	for item in _quest_items:
		if item.get("is_completed", false):
			var container: Control = item.get("container")
			var box: ColorRect = container.get_meta("box")
			var checkmark: TextureRect = box.get_meta("checkmark")

			var check_tween := create_tween()
			check_tween.tween_interval(delay)
			check_tween.tween_property(box, "color", COLOR_QUEST_COMPLETE, 0.25)
			check_tween.parallel().tween_property(checkmark, "modulate:a", 1.0, 0.15)
			check_tween.parallel().tween_property(checkmark, "scale", Vector2.ONE, 0.25)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay += QUEST_CHECK_DELAY

	if _phase_tween:
		_phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_interval(delay + 0.5)
	_phase_tween.tween_callback(_on_all_phases_complete)

func _skip_quest_display() -> void:
	if _phase_tween:
		_phase_tween.kill()

	for item in _quest_items:
		var container: Control = item.get("container")
		container.scale = Vector2.ONE
		if item.get("is_completed", false):
			var box: ColorRect = container.get_meta("box")
			var checkmark: TextureRect = box.get_meta("checkmark")
			box.color = COLOR_QUEST_COMPLETE
			checkmark.modulate.a = 1.0
			checkmark.scale = Vector2.ONE

	_on_all_phases_complete()

func _cleanup_quests() -> void:
	for child in quest_container.get_children():
		child.queue_free()
	_quest_items.clear()

func _on_all_phases_complete() -> void:
	_current_phase = Phase.COMPLETE
	tap_hint.hide()
	continue_button.show()

func _start_tap_hint_blink() -> void:
	var blink_tween := create_tween().set_loops()
	blink_tween.tween_property(tap_hint, "modulate:a", 0.3, 0.8)
	blink_tween.tween_property(tap_hint, "modulate:a", 1.0, 0.8)

func _on_continue_pressed() -> void:
	restart_requested.emit()
	hide()
	_current_phase = Phase.NONE
	_is_ending_mode = false
	continue_button.hide()
	_cleanup_quests()


# ===== Ending Mode =====
func show_ending_screen(all_chiefs: Array, total_days: int) -> void:
	_is_ending_mode = true
	_all_chiefs_history = all_chiefs
	_ending_total_days = total_days
	_ending_skip_hold_time = 0.0
	_ending_skip_active = false

	# Reset UI for ending mode
	_current_phase = Phase.NONE
	continue_button.hide()
	tap_hint.hide()
	chief_container.visible = false
	quest_container.visible = false
	days_increment_label.visible = false
	ending_skip_container.visible = true
	ending_skip_hint.visible = true
	ending_skip_hint.modulate.a = 1.0
	ending_skip_circle.visible = false
	ending_skip_circle.progress = 0.0
	reset_popup.visible = false

	# Set initial display
	days_count_label.text = str(total_days)
	days_lived_label.text = "DAYS LIVED"

	# Show current/last chief name
	if not all_chiefs.is_empty():
		chief_container.visible = true
		chief_container.scale = Vector2.ONE
		new_chief_title.text = ""
		chief_name_label.text = all_chiefs.back().get("name", "")

	show()

	await get_tree().process_frame
	_start_ending_countdown()


func _start_ending_countdown() -> void:
	_current_phase = Phase.ENDING_COUNTDOWN

	# Sort chiefs by death_day descending for pop-animation during countdown
	_sorted_chiefs_for_countdown = _all_chiefs_history.duplicate()
	_sorted_chiefs_for_countdown.sort_custom(func(a, b):
		return a.get("death_day", 0) > b.get("death_day", 0)
	)
	_current_chief_display_index = 0

	# Calculate countdown duration (scales with total days, capped)
	var duration := minf(_ending_total_days * 0.1, 10.0)
	duration = maxf(duration, 2.0)

	if _ending_countdown_tween:
		_ending_countdown_tween.kill()

	_ending_countdown_tween = create_tween()
	_ending_countdown_tween.tween_method(_update_ending_count, float(_ending_total_days), 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ending_countdown_tween.tween_callback(_on_ending_countdown_finished)

	# Fade out skip hint after a few seconds
	var hint_tween := create_tween()
	hint_tween.tween_interval(3.0)
	hint_tween.tween_property(ending_skip_hint, "modulate:a", 0.0, 0.5)


func _update_ending_count(value: float) -> void:
	var int_value := int(value)
	days_count_label.text = str(int_value)

	# Check if we crossed a chief boundary
	if _current_chief_display_index < _sorted_chiefs_for_countdown.size():
		var next_chief = _sorted_chiefs_for_countdown[_current_chief_display_index]
		var boundary_day = next_chief.get("start_day", 0)

		if int_value <= boundary_day:
			_current_chief_display_index += 1
			# Show the previous chief (the one who was chief at this day count)
			if _current_chief_display_index < _sorted_chiefs_for_countdown.size():
				var prev_chief = _sorted_chiefs_for_countdown[_current_chief_display_index]
				_pop_chief_name(prev_chief.get("name", ""))
			else:
				# We've passed all chiefs - show first chief
				_pop_chief_name(_sorted_chiefs_for_countdown.back().get("name", ""))


func _pop_chief_name(chief_name: String) -> void:
	chief_name_label.text = chief_name

	# Pop animation
	chief_container.pivot_offset = chief_container.size / 2.0
	var pop_tween := create_tween()
	pop_tween.tween_property(chief_container, "scale", Vector2.ONE * POP_OVERSHOOT, POP_SCALE_UP_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(chief_container, "scale", Vector2.ONE, POP_SCALE_DOWN_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_ending_countdown_finished() -> void:
	days_count_label.text = "0"
	_show_reset_popup()


func _skip_ending_countdown() -> void:
	if _ending_countdown_tween:
		_ending_countdown_tween.kill()
	days_count_label.text = "0"
	ending_skip_container.visible = false
	_show_reset_popup()


func _show_reset_popup() -> void:
	_current_phase = Phase.COMPLETE
	ending_skip_container.visible = false
	reset_popup.visible = true


func _ending_press_start() -> void:
	_ending_skip_active = true
	_ending_skip_hold_time = 0.0
	ending_skip_hint.visible = true
	ending_skip_hint.modulate.a = 1.0
	ending_skip_circle.visible = true
	ending_skip_circle.progress = 0.0
	ending_skip_circle.queue_redraw()


func _ending_press_end() -> void:
	_ending_skip_active = false
	_ending_skip_hold_time = 0.0
	ending_skip_circle.progress = 0.0
	ending_skip_circle.queue_redraw()


func _on_reset_ok_pressed() -> void:
	reset_popup.visible = false
	_is_ending_mode = false
	_current_phase = Phase.NONE
	hide()
	ending_reset_requested.emit()
