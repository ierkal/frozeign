extends Control
class_name NpcReactionDisplay

var _reactions_by_card: Dictionary = {}  # { "card_id": [ {side, npc_pool, text}, ... ] }
var _pending_reactions: Array = []  # [ {npc_pool, text}, ... ]
var _active_items: Array = []  # Currently displayed reaction nodes
var card_description_ref: Control = null  # Set by card_ui.gd

@export var stagger_delay := 0.15  ## Delay between each reaction appearing
@export var stay_duration := 3.0  ## How long reactions stay visible before fading out

const REACTION_SLIDE_DISTANCE := 20.0
const REACTION_FADE_IN_DURATION := 0.3
const REACTION_FADE_OUT_DURATION := 0.5
const REACTION_MARGIN_BOTTOM := 6
const REACTION_PADDING_X := 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_reactions()


func _load_reactions() -> void:
	var data = JsonLoader.load_json(GameConstants.JSON_PATH_REACTIONS)
	if data == null or not data is Array:
		return

	for entry in data:
		var card_id = str(entry.get("card_id", ""))
		if card_id == "":
			continue
		if not _reactions_by_card.has(card_id):
			_reactions_by_card[card_id] = []
		_reactions_by_card[card_id].append({
			"side": str(entry.get("side", "")),
			"npc_pool": str(entry.get("npc_pool", "")),
			"text": str(entry.get("text", ""))
		})


func on_card_committed(card_id: String, original_side: String) -> void:
	_pending_reactions.clear()

	if not _reactions_by_card.has(card_id):
		return

	var entries = _reactions_by_card[card_id]
	for entry in entries:
		if entry["side"] != original_side:
			continue

		var npc_pool = entry["npc_pool"]
		var npc_name := ""

		if EventBus.npc_name_resolver.is_valid():
			npc_name = EventBus.npc_name_resolver.call(npc_pool)

		# Only show if NPC is met/hired
		if npc_name == "":
			continue

		_pending_reactions.append({
			"npc_pool": npc_pool,
			"text": entry["text"]
		})


func show_pending_reactions() -> void:
	if _pending_reactions.is_empty():
		return

	# Create all items hidden so layout can calculate heights
	var items: Array = []
	var item_width := size.x - REACTION_PADDING_X * 2
	for reaction in _pending_reactions:
		var item := _create_reaction_item(reaction["npc_pool"], reaction["text"])
		item.size.x = item_width
		item.position.x = REACTION_PADDING_X
		item.modulate.a = 0.0
		add_child(item)
		items.append(item)
		_active_items.append(item)

	_pending_reactions.clear()

	# Wait one frame so PanelContainer calculates its height from text content
	await get_tree().process_frame

	var base_y := _get_base_y()
	var item_count := items.size()

	# Track target positions so shifts accumulate correctly even mid-tween
	var target_y_map: Array = []
	target_y_map.resize(item_count)

	# Each new item appears at the bottom, previous items get pushed up
	for i in range(item_count):
		var item: PanelContainer = items[i]
		if not is_instance_valid(item):
			continue
		var item_height: float = item.size.y
		var appear_y: float = base_y - item_height
		target_y_map[i] = appear_y

		# Fade in at bottom position with slide-up
		item.position.y = appear_y + REACTION_SLIDE_DISTANCE
		var appear_tween := create_tween().set_parallel(true)
		appear_tween.tween_property(item, "modulate:a", 1.0, REACTION_FADE_IN_DURATION)
		appear_tween.tween_property(item, "position:y", appear_y, REACTION_FADE_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Push all previous items up
		var shift: float = item_height + REACTION_MARGIN_BOTTOM
		for j in range(i):
			target_y_map[j] -= shift
			var prev: PanelContainer = items[j]
			if is_instance_valid(prev):
				create_tween().tween_property(prev, "position:y", target_y_map[j], REACTION_FADE_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Wait before showing next item
		if i < item_count - 1:
			await get_tree().create_timer(stagger_delay).timeout

	# All visible — wait stay_duration then fade out top-to-bottom (oldest first)
	await get_tree().create_timer(stay_duration).timeout

	for i in range(item_count):
		var item: PanelContainer = items[i]
		if is_instance_valid(item):
			var fade_tween := create_tween()
			fade_tween.tween_property(item, "modulate:a", 0.0, REACTION_FADE_OUT_DURATION)
			fade_tween.tween_callback(item.queue_free)
			fade_tween.tween_callback(_active_items.erase.bind(item))
		if i < item_count - 1:
			await get_tree().create_timer(stagger_delay).timeout


func _get_base_y() -> float:
	if card_description_ref and is_instance_valid(card_description_ref):
		var desc_global_pos := card_description_ref.global_position
		var local_pos := get_global_transform().affine_inverse() * desc_global_pos
		return local_pos.y
	return size.y * 0.75


func _create_reaction_item(npc_pool: String, text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 10

	# Dark semi-transparent rounded background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "%s: %s" % [npc_pool, text]
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)

	return panel


func clear_reactions() -> void:
	_pending_reactions.clear()
	for item in _active_items:
		if is_instance_valid(item):
			item.queue_free()
	_active_items.clear()
