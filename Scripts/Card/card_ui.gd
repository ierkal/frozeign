extends Control
class_name CardUI

signal request_deck_draw
signal card_effect_committed(effect: Dictionary)

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"

# Your card orchestrator scene
@export var card_scene: PackedScene

@onready var card_owner_name: Label = %CardOwnerName
@onready var card_description: Label = %CardDescription
@onready var texture_parent: TextureRect = %TextureParent
@onready var choice_bg_left: Panel = %ChoiceBGLeft
@onready var choice_bg_right: Panel = %ChoiceBGRight
@onready var left_text: Label = %LeftText
@onready var right_text: Label = %RightText

var _card: Node = null
var _current_presented: Dictionary = {}
var _preview_side: String = ""

var _tween_left: Tween = null
var _tween_right: Tween = null

func _ready() -> void:
	# Ask the outside world (GameDirector/Deck) to provide the first presented card.
	# The director should respond by calling: receive_presented_card(presented)
	_reset_preview_ui()
	request_deck_draw.emit()

# --------------------
# External entrypoint (called by GameDirector)
# --------------------
func receive_presented_card(presented: Dictionary) -> void:
	_current_presented = presented

	# Bind UI text
	card_owner_name.text = str(_current_presented.get("title", ""))
	card_description.text = str(_current_presented.get("desc", ""))

	var left_dict: Dictionary = _side_dict(SIDE_LEFT)
	var right_dict: Dictionary = _side_dict(SIDE_RIGHT)
	left_text.text = str(left_dict.get("text", ""))
	right_text.text = str(right_dict.get("text", ""))

	# Spawn a fresh card visual and wire its signals
	_spawn_card()

# --------------------
# Card lifecycle
# --------------------
func _spawn_card() -> void:
	_clear_texture_parent()
	_reset_preview_ui()

	_card = card_scene.instantiate()
	texture_parent.add_child(_card)

	# Wire signals from the card orchestrator (Card / CardTexture)
	_card.card_died.connect(_on_card_died)
	_card.card_idle.connect(_on_card_idle)
	_card.card_decision.connect(_on_card_decision)
	_card.card_committed.connect(_on_card_committed)

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

# --------------------
# Signals from Card
# --------------------
func _on_card_died() -> void:
	# Don’t spawn or draw here; ask director to supply the next presented card.
	request_deck_draw.emit()

func _on_card_decision(side: String) -> void:
	# Close previous side if switching
	if _preview_side != "" and _preview_side != side:
		_set_side_open(_preview_side, false)

	# Open the new/current side
	_set_side_open(side, true)
	_preview_side = side

	# Notify stats preview UI
	var effect := _effect_for(side)
	get_tree().call_group("StatsUI", "show_preview", effect)

func _on_card_idle() -> void:
	if _preview_side != "":
		_set_side_open(_preview_side, false)
	_preview_side = ""
	get_tree().call_group("StatsUI", "clear_preview")

func _on_card_committed(side: String) -> void:
	var effect := _effect_for(side)

	# Tell the outside world to apply effects; CardUI doesn't touch StatsManager directly.
	card_effect_committed.emit(effect)

	# brief hold so the user reads the highlight
	await get_tree().create_timer(0.15).timeout
	get_tree().call_group("StatsUI", "clear_preview")

# --------------------
# UI helpers
# --------------------
func _effect_for(side: String) -> Dictionary:
	return _side_dict(side)

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
