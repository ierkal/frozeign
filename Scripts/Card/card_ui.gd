extends Control
class_name CardUI

signal request_deck_draw
signal card_effect_committed(effect: Dictionary)
signal card_count_reached

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"

@export var card_scene: PackedScene
@export var npcless_card_scene: PackedScene
@export var card_slot_padding: Vector4 = Vector4(0, 0, 0, 0)  ## Padding for CardSlot (left, top, right, bottom)
@export var choice_bg_texture: Texture2D  ## Assign a gradient image to replace the shader gradient

@onready var card_owner_name: Label = %CardOwnerName
@onready var card_description: Label = %CardDescription
@onready var texture_parent: TextureRect = %TextureParent
@onready var card_slot: Panel = %CardSlot
@onready var choice_bg: TextureRect = %ChoiceBG
@onready var choice_text: Label = %ChoiceText
@onready var reaction_display: NpcReactionDisplay = %ReactionContainer

var commited_card_count : int = 0
var _card: Node = null
var _current_presented: Dictionary = {}
var _preview_side: String = ""
var _is_npcless_card: bool = false
var _input_blocked: bool = false

var _choice_bg_offset: Vector2 = Vector2.ZERO  # ChoiceBG origin in CardTexture local space
var _choice_bg_size: Vector2 = Vector2.ZERO
var _choice_tracking := true
var _last_choice_side: String = ""

func _ready() -> void:
	if choice_bg_texture:
		choice_bg.texture = choice_bg_texture
		choice_bg.material = null
	if reaction_display:
		reaction_display.card_description_ref = card_description
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
	AudioManager.play_card_appearance()
	if presented.get("npc_pool", "") == "Volcano":
		AudioManager.play_volcano_card()
	_reset_preview_ui()
	_current_presented = presented

	var npc_image = _current_presented.get("npc_image", null)

	if npc_image == null:
		# Npcless card: description is shown inside the card
		_is_npcless_card = true
		card_owner_name.text = ""
		card_description.text = ""
		_spawn_npcless_card(presented)
	else:
		# Normal card with NPC
		_is_npcless_card = false
		card_owner_name.text = str(_current_presented.get("title", ""))
		card_description.text = str(_current_presented.get("desc", ""))
		_spawn_card()

	# Show any pending NPC reactions from the previous card
	if reaction_display:
		reaction_display.show_pending_reactions()


func _spawn_card() -> void:
	_clear_texture_parent()
	_reset_preview_ui()

	_card = card_scene.instantiate()
	texture_parent.add_child(_card)

	# Set NPC image if available in presented data
	var npc_image = _current_presented.get("npc_image", null)
	if npc_image and _card.has_method("set_npc_image"):
		_card.set_npc_image(npc_image)

	_card.card_died.connect(_on_card_died)
	_card.card_idle.connect(_on_card_idle)
	_card.card_decision.connect(_on_card_decision)
	_card.card_committed.connect(_on_card_committed)

	# Sync card slot background to match card texture position/size
	_sync_card_slot.call_deferred()


func _spawn_npcless_card(presented: Dictionary) -> void:
	_clear_texture_parent()
	_reset_preview_ui()

	if not npcless_card_scene:
		push_warning("npcless_card_scene not set, falling back to regular card")
		_spawn_card()
		return

	_card = npcless_card_scene.instantiate()
	texture_parent.add_child(_card)

	_card.setup_npcless(presented)

	_card.card_died.connect(_on_card_died)
	_card.card_idle.connect(_on_card_idle)
	_card.card_decision.connect(_on_card_decision)
	_card.card_committed.connect(_on_card_committed)

	# Sync card slot background to match card texture position/size
	_sync_card_slot.call_deferred()

func _clear_texture_parent() -> void:
	ContainerUtils.clear_children(texture_parent)


func _sync_card_slot() -> void:
	if not _card or not is_instance_valid(_card):
		return

	# Get the CardTexture node from the card
	var card_texture: TextureRect = _card.get_node_or_null("CardTexture")
	if not card_texture:
		return

	# Calculate the actual visible texture rect (accounting for aspect ratio)
	var visible_rect := _get_visible_texture_rect(card_texture)

	# Convert to local coordinates relative to CardSlot's parent
	var slot_parent := card_slot.get_parent() as Control
	if not slot_parent:
		return

	var local_pos := slot_parent.get_global_transform().affine_inverse() * visible_rect.position

	# Apply padding (left, top, right, bottom)
	var padded_pos := local_pos + Vector2(card_slot_padding.x, card_slot_padding.y)
	var padded_size := visible_rect.size - Vector2(card_slot_padding.x + card_slot_padding.z, card_slot_padding.y + card_slot_padding.w)

	# Set CardSlot to match with padding
	card_slot.position = padded_pos
	card_slot.size = padded_size

	# Compute ChoiceBG offset in CardTexture's local space (for following during drag)
	var ct_xform := card_texture.get_global_transform()
	var parent_xform := slot_parent.get_global_transform()
	var bg_global_pos := parent_xform * padded_pos
	_choice_bg_offset = ct_xform.affine_inverse() * bg_global_pos
	_choice_bg_size = Vector2(padded_size.x, padded_size.y * 0.30)

	# Initial placement (card at rest, no rotation)
	choice_bg.position = padded_pos
	choice_bg.size = _choice_bg_size
	choice_bg.rotation = 0.0


func _process(_delta: float) -> void:
	if not _choice_tracking or not _card or not is_instance_valid(_card):
		return

	var ratio: float = _card.card_drag.swipe_ratio()
	choice_bg.modulate.a = ratio

	if ratio > 0.0:
		_update_choice_bg_transform()
		var side: String = _card.card_drag.current_side()
		if side != _last_choice_side and not _current_presented.is_empty():
			_last_choice_side = side
			var side_dict := _side_dict(side)
			choice_text.text = str(side_dict.get("text", ""))
			if side == SIDE_LEFT:
				choice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			else:
				choice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		_last_choice_side = ""

func _update_choice_bg_transform() -> void:
	if not _card or not is_instance_valid(_card):
		return
	var card_texture: TextureRect = _card.get_node_or_null("CardTexture")
	if not card_texture:
		return
	var ct_xform := card_texture.get_global_transform()
	var bg_global_pos := ct_xform * _choice_bg_offset
	var parent := choice_bg.get_parent() as Control
	if not parent:
		return
	choice_bg.position = parent.get_global_transform().affine_inverse() * bg_global_pos
	choice_bg.rotation = _card.rotation

func _get_visible_texture_rect(tex_rect: TextureRect) -> Rect2:
	"""Calculate the actual visible texture rect accounting for stretch mode."""
	var texture := tex_rect.texture
	if not texture:
		return tex_rect.get_global_rect()

	var container_rect := tex_rect.get_global_rect()
	var texture_size := Vector2(texture.get_width(), texture.get_height())

	# For STRETCH_KEEP_ASPECT_CENTERED (mode 5), calculate actual visible size
	if tex_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		var container_size: Vector2 = container_rect.size
		var scale_x: float = container_size.x / texture_size.x
		var scale_y: float = container_size.y / texture_size.y
		var tex_scale: float = min(scale_x, scale_y)

		var visible_size: Vector2 = texture_size * tex_scale
		var offset: Vector2 = (container_size - visible_size) / 2.0

		return Rect2(container_rect.position + offset, visible_size)

	# For other modes, just return the container rect
	return container_rect


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
	_last_choice_side = ""
	_choice_tracking = true
	choice_bg.modulate.a = 0.0
	choice_bg.rotation = 0.0
	choice_text.text = ""

func _on_card_died() -> void:
	request_deck_draw.emit()

func _on_card_decision(side: String) -> void:
	_preview_side = side
	var effect := _effect_for(side)
	get_tree().call_group("StatsUI", "show_preview", effect)

func _on_card_idle() -> void:
	_preview_side = ""
	get_tree().call_group("StatsUI", "clear_preview")

func _on_card_committed(side: String) -> void:
	AudioManager.play_card_committed()
	_choice_tracking = false
	choice_bg.modulate.a = 0.0

	var effect := _effect_for(side)

	card_effect_committed.emit(effect)
	commited_card_count += 1
	await get_tree().create_timer(0.15).timeout
	get_tree().call_group("StatsUI", "clear_preview")

	card_count_reached.emit()

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


# --------------------
# INPUT BLOCKING (for minigames)
# --------------------
func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked
	if _card and _card.has_method("set_input_blocked"):
		_card.set_input_blocked(blocked)



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
	choice_text.text = ""

	# Clear any active NPC reactions
	if reaction_display:
		reaction_display.clear_reactions()

	# Just in case any preview is left on-screen
	get_tree().call_group("StatsUI", "clear_preview")
