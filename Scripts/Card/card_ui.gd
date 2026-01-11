extends Control
class_name CardUI

signal request_deck_draw
signal card_effect_committed(effect: Dictionary)
signal card_count_reached

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"

@export var card_scene: PackedScene
@export var buff_info_card_scene: PackedScene

@onready var card_owner_name: Label = %CardOwnerName
@onready var card_description: Label = %CardDescription
@onready var texture_parent: TextureRect = %TextureParent
@onready var card_slot: Panel = %CardSlot
@onready var choice_bg_left: Panel = %ChoiceBGLeft
@onready var choice_bg_right: Panel = %ChoiceBGRight
@onready var left_text: Label = %LeftText
@onready var right_text: Label = %RightText

var commited_card_count : int = 0
var _card: Node = null
var _current_presented: Dictionary = {}
var _preview_side: String = ""
var _is_buff_info_card: bool = false

var _tween_left: Tween = null
var _tween_right: Tween = null

func _ready() -> void:
	_reset_preview_ui()
	_apply_safe_area()
	request_deck_draw.emit()
	# Re-sync card slot and safe area when the UI resizes
	resized.connect(_on_resized)
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	pivot_offset = size / 2
	
# --------------------
# External entrypoint (called by GameManager)
# --------------------
func receive_presented_card(presented: Dictionary) -> void:
	_is_buff_info_card = false
	_current_presented = presented

	card_owner_name.text = str(_current_presented.get("title", ""))
	card_description.text = str(_current_presented.get("desc", ""))

	var left_dict: Dictionary = _side_dict(SIDE_LEFT)
	var right_dict: Dictionary = _side_dict(SIDE_RIGHT)
	left_text.text = str(left_dict.get("text", ""))
	right_text.text = str(right_dict.get("text", ""))

	_spawn_card()


func receive_buff_info_card(buff_data: Dictionary) -> void:
	_is_buff_info_card = true
	_current_presented = {}

	card_owner_name.text = ""
	card_description.text = "This will be affecting the chief until his death."
	left_text.text = ""
	right_text.text = ""

	_spawn_buff_info_card(buff_data)

func _spawn_card() -> void:
	_clear_texture_parent()
	_reset_preview_ui()

	_card = card_scene.instantiate()
	texture_parent.add_child(_card)

	_card.card_died.connect(_on_card_died)
	_card.card_idle.connect(_on_card_idle)
	_card.card_decision.connect(_on_card_decision)
	_card.card_committed.connect(_on_card_committed)

	# Sync card slot background to match card texture position/size
	_sync_card_slot.call_deferred()


func _spawn_buff_info_card(buff_data: Dictionary) -> void:
	_clear_texture_parent()
	_reset_preview_ui()

	if not buff_info_card_scene:
		push_warning("buff_info_card_scene not set, falling back to regular card")
		_spawn_card()
		return

	_card = buff_info_card_scene.instantiate()
	texture_parent.add_child(_card)

	_card.setup_buff_info(buff_data)

	_card.card_died.connect(_on_card_died)
	_card.card_idle.connect(_on_card_idle)
	_card.card_decision.connect(_on_card_decision)
	_card.card_committed.connect(_on_buff_info_card_committed)

	# Sync card slot background to match card texture position/size
	_sync_card_slot.call_deferred()

func _clear_texture_parent() -> void:
	for c in texture_parent.get_children():
		c.queue_free()


func _sync_card_slot() -> void:
	if not _card or not is_instance_valid(_card):
		return

	# Get the CardTexture node from the card
	var card_texture: Control = _card.get_node_or_null("CardTexture")
	if not card_texture:
		return

	# Get CardTexture's global rect
	var texture_global_rect := card_texture.get_global_rect()

	# Convert to local coordinates relative to CardSlot's parent
	var slot_parent := card_slot.get_parent() as Control
	if not slot_parent:
		return

	var local_pos := slot_parent.get_global_transform().affine_inverse() * texture_global_rect.position

	# Set CardSlot to match exactly
	card_slot.position = local_pos
	card_slot.size = texture_global_rect.size


func _on_resized() -> void:
	_sync_card_slot.call_deferred()


func _on_viewport_size_changed() -> void:
	_apply_safe_area()
	_sync_card_slot.call_deferred()


func _apply_safe_area() -> void:
	# Get screen size and safe area
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()

	# Calculate insets (how much the safe area is inset from screen edges)
	var top_inset := safe_area.position.y
	var bottom_inset := screen_size.y - (safe_area.position.y + safe_area.size.y)

	# Get viewport size for proper scaling
	var viewport_size := get_viewport_rect().size

	# Scale insets to viewport coordinates (in case viewport differs from screen)
	var scale_y := viewport_size.y / float(screen_size.y) if screen_size.y > 0 else 1.0
	var scaled_top := top_inset * scale_y
	var scaled_bottom := bottom_inset * scale_y

	# Apply as offsets - these add to the anchor-based positioning
	# TODO: Enable when ready to implement notch handling
	#offset_top = scaled_top
	#offset_bottom = -scaled_bottom


func _reset_preview_ui() -> void:
	_preview_side = ""
	choice_bg_left.scale.y = 0.0
	choice_bg_right.scale.y = 0.0
	_kill_tween(_tween_left)
	_kill_tween(_tween_right)
	_tween_left = null
	_tween_right = null

func _on_card_died() -> void:
	request_deck_draw.emit()

func _on_card_decision(side: String) -> void:
	# Buff info cards don't have side effects, skip preview
	if _is_buff_info_card:
		return

	if _preview_side != "" and _preview_side != side:
		_set_side_open(_preview_side, false)

	_set_side_open(side, true)
	_preview_side = side

	var effect := _effect_for(side)
	get_tree().call_group("StatsUI", "show_preview", effect)

func _on_card_idle() -> void:
	if _preview_side != "":
		_set_side_open(_preview_side, false)
	_preview_side = ""
	get_tree().call_group("StatsUI", "clear_preview")

func _on_card_committed(side: String) -> void:
	var effect := _effect_for(side)

	card_effect_committed.emit(effect)
	commited_card_count += 1
	await get_tree().create_timer(0.15).timeout
	get_tree().call_group("StatsUI", "clear_preview")

	card_count_reached.emit()


func _on_buff_info_card_committed(_side: String) -> void:
	# Buff info cards don't have effects, just dismiss and draw next card
	await get_tree().create_timer(0.15).timeout
	get_tree().call_group("StatsUI", "clear_preview")

func _effect_for(side: String) -> Dictionary:
	var base := _side_dict(side)
	var effect := base.duplicate(true)

	# Bu kartın ID'sini ekle
	effect["card_id"] = _current_presented.get("id", "")

	# Kullanıcının tıkladığı UI tarafı (sol/sağ) - istersen debug için
	effect["side"] = side

	# JSON'daki orijinal taraf (left/right)
	var original_side := ""
	if side == SIDE_LEFT:
		original_side = String(_current_presented.get("ui_left_original", "left"))
	else:
		original_side = String(_current_presented.get("ui_right_original", "right"))

	effect["original_side"] = original_side

	return effect


func _side_dict(side: String) -> Dictionary:
	if side == SIDE_LEFT:
		return _current_presented.left
	return _current_presented.right

func _kill_tween(t: Tween) -> void:
	if t:
		t.kill()

func _set_side_open(side: String, open: bool) -> void:
	if side == SIDE_LEFT:
		_toggle_panel(choice_bg_left, open, true)
	else:
		_toggle_panel(choice_bg_right, open, false)

func _toggle_panel(p: Panel, open: bool, is_left: bool) -> void:
	if is_left:
		_kill_tween(_tween_left)
		_tween_left = create_tween()
		if open:
			_tween_left.tween_property(p, "scale:y", 1.0, 0.1).from_current()
		else:
			_tween_left.tween_property(p, "scale:y", 0.0, 0.1).from_current()
	else:
		_kill_tween(_tween_right)
		_tween_right = create_tween()
		if open:
			_tween_right.tween_property(p, "scale:y", 1.0, 0.1).from_current()
		else:
			_tween_right.tween_property(p, "scale:y", 0.0, 0.1).from_current()



# --------------------
# SOFT RESET SUPPORT
# --------------------
func reset() -> void:
	commited_card_count = 0
	_current_presented.clear()
	_clear_texture_parent()
	_reset_preview_ui()

	card_owner_name.text = ""
	card_description.text = ""
	left_text.text = ""
	right_text.text = ""

	# Just in case any preview is left on-screen
	get_tree().call_group("StatsUI", "clear_preview")
