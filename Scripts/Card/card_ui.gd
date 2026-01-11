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
	request_deck_draw.emit()

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

func _clear_texture_parent() -> void:
	for c in texture_parent.get_children():
		c.queue_free()

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
