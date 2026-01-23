extends Control
class_name DeathScreen

signal restart_requested
signal need_quest_data
signal need_new_chief_name

# Node references
@onready var background: ColorRect = $Background
@onready var banner: Control = $Banner
@onready var banner_label: Label = $Banner/BannerLabel
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var timeline_content: Control = $ScrollContainer/TimelineContent
@onready var timeline_bar_bg: ColorRect = $ScrollContainer/TimelineContent/TimelineBarBg
@onready var markers_container: Control = $ScrollContainer/TimelineContent/MarkersContainer
@onready var following_line: ColorRect = $ScrollContainer/TimelineContent/FollowingLine
@onready var total_days_label: Label = $ScrollContainer/TimelineContent/FollowingLine/TotalDaysLabel
@onready var new_chief_intro: Control = $ScrollContainer/TimelineContent/NewChiefIntro
@onready var new_chief_label: Label = $ScrollContainer/TimelineContent/NewChiefIntro/NewChiefLabel
@onready var footer: Control = $Footer
@onready var chief_info_container: Control = $Footer/ChiefInfoContainer
@onready var chief_name_label: Label = $Footer/ChiefInfoContainer/ChiefNameLabel
@onready var chief_days_label: Label = $Footer/ChiefInfoContainer/ChiefDaysLabel
@onready var quest_container: VBoxContainer = $Footer/QuestContainer
@onready var advance_button: Button = $Footer/MarginContainer/AdvanceButton
@onready var tap_to_continue: Label = $TapToContinue

# Visual Configuration/
const PIXELS_PER_DAY := 15.0
const MARKER_SIZE := Vector2(12, 12)
const BAR_HEIGHT := 6.0
const ANIMATION_DURATION := 2.5
const TIMELINE_PADDING := 400.0
const MARKER_POP_DURATION := 0.3
const BANNER_SLIDE_DURATION := 0.8
const FOOTER_TRANSITION_DURATION := 0.6
const QUEST_BOX_SIZE := 50.0

# Input Configuration
const TAP_THRESHOLD := 20.0 

# Colors
const COLOR_BAR_ACTIVE := Color(0.3, 0.5, 1.0, 1.0)
const COLOR_BAR_HISTORY := Color(0.3, 0.4, 0.5, 1)
const COLOR_MARKER_ACTIVE := Color(1, 1, 1, 1)
const COLOR_MARKER_HISTORY := Color(0.5, 0.5, 0.55, 1)
const COLOR_INFO_ACTIVE := Color(1, 1, 1, 1)
const COLOR_INFO_HISTORY := Color(0.6, 0.6, 0.65, 1)
const COLOR_QUEST_INCOMPLETE := Color(0.3, 0.3, 0.35, 1)
const COLOR_QUEST_COMPLETE := Color(0.2, 0.7, 0.3, 1)

# Camera/Scroll Logic
const START_SCREEN_RATIO := 0.5
const CAMERA_LOCK_RATIO := 0.6

# Phase enum
enum Phase {
	NONE,
	BANNER_SHOWING,
	WAITING_INPUT,
	BANNER_HIDING,
	TIMELINE_PLAYING,
	NEW_CHIEF_INTRO,
	FOOTER_TRANSITION,
	QUEST_DISPLAY,
	QUEST_DISMISSAL,
	COMPLETE
}

# Data
var _dead_chiefs: Array = []
var _current_chief_data: Dictionary = {}
var _new_chief_name: String = ""
var _quest_data: Array = []
var _total_days: int = 0
var _current_phase: int = Phase.NONE
var _tween: Tween
var _phase_tween: Tween
var _checkmark_texture: Texture2D

# Animation references
var _active_bar: ColorRect
var _active_start_marker: ColorRect
var _active_end_marker: ColorRect
var _quest_items: Array = []

# Input Tracking
var _touch_start_pos: Vector2
var _is_tracking_touch: bool = false

# External references
var home_menu_ui: HomeMenuUI

func _ready() -> void:
	hide()
	following_line.hide()
	new_chief_intro.hide()
	advance_button.pressed.connect(_on_advance_pressed)
	advance_button.hide()
	tap_to_continue.hide()

	_checkmark_texture = load("res://Assets/Sprites/check-mark.png")

	# Mouse Filter Setup
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	timeline_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	following_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_chief_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	banner.position.y = -200

func _input(event: InputEvent) -> void:
	if not visible:
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
		Phase.WAITING_INPUT:
			_advance_from_waiting()
		Phase.BANNER_SHOWING, Phase.BANNER_HIDING:
			_skip_banner_animation()
		Phase.TIMELINE_PLAYING:
			_skip_timeline_animation()
		Phase.NEW_CHIEF_INTRO:
			_skip_new_chief_intro()
		Phase.FOOTER_TRANSITION:
			_skip_footer_transition()
		Phase.QUEST_DISPLAY:
			_skip_quest_display()
		Phase.QUEST_DISMISSAL:
			_skip_quest_dismissal()

func _on_advance_pressed() -> void:
	restart_requested.emit()
	hide()
	_current_phase = Phase.NONE
	advance_button.hide()
	_cleanup_markers()
	_cleanup_quests()

func setup_home_menu(hm: HomeMenuUI) -> void:
	home_menu_ui = hm

func set_quest_data(quests: Array) -> void:
	_quest_data = quests

func set_new_chief_name(chief_name: String) -> void:
	_new_chief_name = chief_name

func show_death_screen(dead_chiefs_history: Array, current_chief: Dictionary) -> void:
	_dead_chiefs = dead_chiefs_history.duplicate()
	_current_chief_data = current_chief
	_current_phase = Phase.NONE
	advance_button.hide()
	tap_to_continue.hide()
	new_chief_intro.hide()

	# Calculate total days
	_total_days = 0
	for chief in _dead_chiefs:
		_total_days = chief.get("death_day", 0)

	_setup_footer_info()
	_setup_timeline()
	_create_history_markers()

	need_quest_data.emit()
	need_new_chief_name.emit()

	show()

	await get_tree().process_frame
	_start_banner_animation()

func _setup_footer_info() -> void:
	var chief_name: String = _current_chief_data.get("name", "Unknown")
	var start_day: int = _current_chief_data.get("start_day", 0)
	var death_day: int = _current_chief_data.get("death_day", 0)

	chief_name_label.text = chief_name
	chief_days_label.text = "Days %d - %d" % [start_day, death_day]

	chief_info_container.position.x = 0
	quest_container.position.x = get_viewport_rect().size.x + 400

func _setup_timeline() -> void:
	var screen_width := get_viewport_rect().size.x
	var start_offset := screen_width * START_SCREEN_RATIO
	var max_day: int = _current_chief_data.get("death_day", 0)
	var timeline_width: float = start_offset + (max_day * PIXELS_PER_DAY) + TIMELINE_PADDING

	timeline_content.custom_minimum_size.x = timeline_width
	var content_height := scroll_container.size.y
	var bar_y := content_height * 0.5
	timeline_bar_bg.position.y = bar_y
	timeline_bar_bg.size.y = BAR_HEIGHT
	markers_container.position.y = bar_y - (MARKER_SIZE.y - BAR_HEIGHT) / 2.0
	scroll_container.scroll_horizontal = 0

func _create_history_markers() -> void:
	_cleanup_markers()
	for chief in _dead_chiefs:
		_create_chief_segment(chief, false)

func _cleanup_markers() -> void:
	ContainerUtils.clear_children(markers_container)

func _cleanup_quests() -> void:
	ContainerUtils.clear_children(quest_container)
	_quest_items.clear()

func _create_chief_segment(chief: Dictionary, is_active: bool) -> void:
	var screen_width := get_viewport_rect().size.x
	var global_start_offset := screen_width * START_SCREEN_RATIO
	var start_day: int = chief.get("start_day", 0)
	var death_day: int = chief.get("death_day", 0)
	var chief_name: String = chief.get("name", "Unknown")

	var start_x := global_start_offset + (start_day * PIXELS_PER_DAY)
	var end_x := global_start_offset + (death_day * PIXELS_PER_DAY)
	var bar_width := (death_day - start_day) * PIXELS_PER_DAY
	var bar_y := (MARKER_SIZE.y - BAR_HEIGHT) / 2.0

	var bar_color := COLOR_BAR_ACTIVE if is_active else COLOR_BAR_HISTORY
	var marker_color := COLOR_MARKER_ACTIVE if is_active else COLOR_MARKER_HISTORY
	var info_color := COLOR_INFO_ACTIVE if is_active else COLOR_INFO_HISTORY

	var bar := ColorRect.new()
	bar.color = bar_color
	bar.position = Vector2(start_x, bar_y)
	bar.size = Vector2(bar_width if not is_active else 0.0, BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers_container.add_child(bar)

	if is_active:
		_active_bar = bar

	var start_marker := ColorRect.new()
	start_marker.color = marker_color
	start_marker.position = Vector2(start_x - MARKER_SIZE.x / 2.0, 0)
	start_marker.size = MARKER_SIZE
	start_marker.pivot_offset = MARKER_SIZE / 2.0
	start_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_active:
		start_marker.scale = Vector2.ZERO
		_active_start_marker = start_marker

	markers_container.add_child(start_marker)

	var info_container := Control.new()
	info_container.position = Vector2(start_x, -60)
	info_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers_container.add_child(info_container)

	var name_label := Label.new()
	name_label.text = chief_name
	name_label.add_theme_color_override("font_color", info_color)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.position = Vector2(-50, 0)
	name_label.size = Vector2(100, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_container.add_child(name_label)

	var days_label := Label.new()
	days_label.text = "%d-%d" % [start_day, death_day]
	days_label.add_theme_color_override("font_color", info_color)
	days_label.add_theme_font_size_override("font_size", 14)
	days_label.position = Vector2(-50, 22)
	days_label.size = Vector2(100, 18)
	days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_container.add_child(days_label)

	if not is_active:
		var end_marker := ColorRect.new()
		end_marker.color = marker_color
		end_marker.position = Vector2(end_x - MARKER_SIZE.x / 2.0, 0)
		end_marker.size = MARKER_SIZE
		end_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		markers_container.add_child(end_marker)

# ===== PHASE 1: Banner Animation =====
func _start_banner_animation() -> void:
	_current_phase = Phase.BANNER_SHOWING
	banner.position.y = -200
	if _phase_tween: _phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_property(banner, "position:y", 100, BANNER_SLIDE_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_phase_tween.tween_callback(_on_banner_shown)

func _on_banner_shown() -> void:
	_current_phase = Phase.WAITING_INPUT
	tap_to_continue.show()
	var blink_tween := create_tween().set_loops()
	blink_tween.tween_property(tap_to_continue, "modulate:a", 0.3, 0.8)
	blink_tween.tween_property(tap_to_continue, "modulate:a", 1.0, 0.8)

func _skip_banner_animation() -> void:
	if _phase_tween: _phase_tween.kill()
	banner.position.y = 100
	_on_banner_shown()

func _advance_from_waiting() -> void:
	tap_to_continue.hide()
	_current_phase = Phase.BANNER_HIDING
	if _phase_tween: _phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_property(banner, "position:y", -200, BANNER_SLIDE_DURATION * 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_phase_tween.tween_callback(_start_timeline_animation)

# ===== PHASE 2: Timeline Animation =====
func _start_timeline_animation() -> void:
	_current_phase = Phase.TIMELINE_PLAYING
	var screen_width := get_viewport_rect().size.x
	var global_start_offset := screen_width * START_SCREEN_RATIO
	var start_day: int = _current_chief_data.get("start_day", 0)
	var death_day: int = _current_chief_data.get("death_day", 0)

	_create_chief_segment(_current_chief_data, true)

	var start_x := global_start_offset + (start_day * PIXELS_PER_DAY)
	var content_height := scroll_container.size.y
	following_line.position.x = start_x + 3
	following_line.position.y = content_height * 0.31
	following_line.size.y = content_height * 0.2
	following_line.show()

	_scroll_to_position(start_x)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_active_start_marker, "scale", Vector2.ONE, MARKER_POP_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.2)
	_tween.tween_method(_update_animation_step, float(start_day), float(death_day), ANIMATION_DURATION)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_on_timeline_complete)

func _skip_timeline_animation() -> void:
	if _tween: _tween.kill()
	var death_day: int = _current_chief_data.get("death_day", 0)
	_update_animation_step(float(death_day))
	if _active_start_marker: _active_start_marker.scale = Vector2.ONE
	_on_timeline_complete()

func _update_animation_step(current_day_float: float) -> void:
	var screen_width := get_viewport_rect().size.x
	var global_start_offset := screen_width * START_SCREEN_RATIO
	var start_day: int = _current_chief_data.get("start_day", 0)
	var days_passed := current_day_float - start_day
	var current_bar_width := days_passed * PIXELS_PER_DAY

	if _active_bar: _active_bar.size.x = current_bar_width
	var tip_x := global_start_offset + (start_day * PIXELS_PER_DAY) + current_bar_width
	following_line.position.x = tip_x - 1
	total_days_label.text = "Day %d" % int(current_day_float)

	var camera_lock_x := screen_width * CAMERA_LOCK_RATIO
	if tip_x > camera_lock_x:
		scroll_container.scroll_horizontal = int(tip_x - camera_lock_x)

func _scroll_to_position(target_x: float) -> void:
	var screen_width := get_viewport_rect().size.x
	var camera_lock_x := screen_width * CAMERA_LOCK_RATIO
	if target_x > camera_lock_x:
		scroll_container.scroll_horizontal = int(target_x - camera_lock_x)
	else:
		scroll_container.scroll_horizontal = 0

func _on_timeline_complete() -> void:
	var screen_width := get_viewport_rect().size.x
	var global_start_offset := screen_width * START_SCREEN_RATIO
	var death_day: int = _current_chief_data.get("death_day", 0)
	var end_x := global_start_offset + (death_day * PIXELS_PER_DAY)

	_active_end_marker = ColorRect.new()
	_active_end_marker.color = COLOR_MARKER_ACTIVE
	_active_end_marker.position = Vector2(end_x - MARKER_SIZE.x / 2.0, 0)
	_active_end_marker.size = MARKER_SIZE
	_active_end_marker.pivot_offset = MARKER_SIZE / 2.0
	_active_end_marker.scale = Vector2.ZERO
	_active_end_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers_container.add_child(_active_end_marker)

	var pop_tween := create_tween()
	pop_tween.tween_property(_active_end_marker, "scale", Vector2.ONE, MARKER_POP_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_callback(_start_new_chief_intro)

# ===== PHASE 3: New Chief Intro (UPDATED) =====
func _start_new_chief_intro() -> void:
	_current_phase = Phase.NEW_CHIEF_INTRO
	if _new_chief_name.is_empty():
		_start_footer_transition()
		return
	var screen_width := get_viewport_rect().size.x
	var global_start_offset := screen_width * START_SCREEN_RATIO
	var death_day: int = _current_chief_data.get("death_day", 0)
	
	# X Position: Death Mark
	var end_x := global_start_offset + (death_day * PIXELS_PER_DAY)
	
	# Y Position: Below the timeline bar
	var content_height := scroll_container.size.y
	var bar_y := content_height * 0.5
	var label_y_offset := 5.0 # Distance below the timeline

	new_chief_label.text = _new_chief_name
	
	# Center the container
	new_chief_intro.custom_minimum_size.x = 300
	new_chief_intro.size.x = 300
	new_chief_intro.position.x = end_x - (new_chief_intro.size.x / 2.0)
	new_chief_intro.position.y = bar_y + label_y_offset
	
	# Ensure label is centered inside
	new_chief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_chief_label.anchors_preset = Control.PRESET_FULL_RECT
	
	new_chief_intro.modulate.a = 0
	new_chief_intro.show()

	if _phase_tween: _phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_property(new_chief_intro, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_phase_tween.tween_interval(1.0)
	_phase_tween.tween_callback(_start_footer_transition)

func _skip_new_chief_intro() -> void:
	if _phase_tween: _phase_tween.kill()
	new_chief_intro.modulate.a = 1.0
	_start_footer_transition()

# ===== PHASE 4: Footer Transition =====
func _start_footer_transition() -> void:
	_current_phase = Phase.FOOTER_TRANSITION
	if _phase_tween: _phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_property(chief_info_container, "position:x", -500, FOOTER_TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_phase_tween.tween_callback(_start_quest_display)

func _skip_footer_transition() -> void:
	if _phase_tween: _phase_tween.kill()
	chief_info_container.position.x = -500
	_start_quest_display()

# ===== PHASE 5: Quest Display =====
func _start_quest_display() -> void:
	_current_phase = Phase.QUEST_DISPLAY
	_cleanup_quests()

	var sorted_quests := _get_priority_quests()
	if sorted_quests.is_empty():
		_on_all_phases_complete()
		return

	for i in range(min(3, sorted_quests.size())):
		var quest = sorted_quests[i]
		var quest_item := _create_quest_item(quest)
		quest_container.add_child(quest_item)
		_quest_items.append({
			"container": quest_item,
			"is_completed": quest.get("is_completed", false)
		})

	quest_container.position.x = 400
	if _phase_tween: _phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_property(quest_container, "position:x", 0, FOOTER_TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_phase_tween.tween_interval(0.3)
	_phase_tween.tween_callback(_animate_quest_checkmarks)

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
	container.add_theme_constant_override("separation", 10)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE 

	var box := ColorRect.new()
	box.custom_minimum_size = Vector2(QUEST_BOX_SIZE, QUEST_BOX_SIZE)
	box.color = GameConstants.Colors.QUEST_INCOMPLETE
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
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(200, 0)
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
			check_tween.tween_property(box, "color", GameConstants.Colors.QUEST_COMPLETE, 0.3)
			check_tween.parallel().tween_property(checkmark, "modulate:a", 1.0, 0.2)
			check_tween.parallel().tween_property(checkmark, "scale", Vector2.ONE, MARKER_POP_DURATION)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay += 0.2

	if _phase_tween: _phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_interval(delay + 0.5)
	_phase_tween.tween_callback(_start_quest_dismissal)

func _skip_quest_display() -> void:
	if _phase_tween: _phase_tween.kill()
	quest_container.position.x = 0
	for item in _quest_items:
		if item.get("is_completed", false):
			var container: Control = item.get("container")
			var box: ColorRect = container.get_meta("box")
			var checkmark: TextureRect = box.get_meta("checkmark")
			box.color = GameConstants.Colors.QUEST_COMPLETE
			checkmark.modulate.a = 1.0
			checkmark.scale = Vector2.ONE
	
	_start_quest_dismissal()

# ===== PHASE 6: Quest Dismissal =====
func _start_quest_dismissal() -> void:
	_current_phase = Phase.QUEST_DISMISSAL
	var completion_found := false
	var parallel_tween := create_tween().set_parallel(true)
	var delay := 0.0

	for item in _quest_items:
		if item.get("is_completed", false):
			completion_found = true
			var container: Control = item.get("container")
			
			var idx = container.get_index()
			var spacer = Control.new()
			spacer.custom_minimum_size = container.size
			quest_container.add_child(spacer)
			quest_container.move_child(spacer, idx)
			
			var start_pos = container.global_position
			container.top_level = true
			container.global_position = start_pos
			
			parallel_tween.tween_interval(0.2)
			parallel_tween.tween_property(spacer, "custom_minimum_size:y", 0.0, 0.4)\
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
			
			var target_x = get_viewport_rect().size.x + 50
			parallel_tween.tween_property(container, "global_position:x", target_x, 0.6)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(delay)
			parallel_tween.tween_property(container, "modulate:a", 0.0, 0.5).set_delay(delay)
			
			delay += 0.1

	if completion_found:
		if _phase_tween: _phase_tween.kill()
		_phase_tween = parallel_tween
		_phase_tween.chain().tween_callback(_on_all_phases_complete)
	else:
		_on_all_phases_complete()

func _skip_quest_dismissal() -> void:
	if _phase_tween: _phase_tween.kill()
	for item in _quest_items:
		if item.get("is_completed", false):
			var container: Control = item.get("container")
			container.hide()
			container.queue_free()
	
	for child in quest_container.get_children():
		if child is Control and not child is HBoxContainer:
			child.custom_minimum_size.y = 0
			child.hide()

	_on_all_phases_complete()

# ===== Completion =====
func _on_all_phases_complete() -> void:
	_current_phase = Phase.COMPLETE
	advance_button.show()
