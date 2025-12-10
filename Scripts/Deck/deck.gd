extends Node
class_name Deck

var _raw_cards: Array = []   # cards as loaded from JSON
var _deck: Array = []        # working deck (shuffled)

func _ready() -> void:
	randomize()

# ---- Loading ----

func load_from_json_string(json_text: String) -> void:
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Deck: JSON root must be an array")
		return
	_raw_cards = parsed.duplicate(true)
	_refill_deck()

@warning_ignore("redundant_await")
func load_from_file(path: String) -> void:
	await get_tree().process_frame

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Deck: cannot open %s" % path)
		return

	var text := f.get_as_text()
	load_from_json_string(text)

# ---- Deck ops ----

func _refill_deck() -> void:
	_deck.clear()

	for card in _raw_cards:
		var id = card.get("Id", "")
		var is_death := false
		if id.begins_with("DEATH_"):
			is_death = true

		if not is_death:
			_deck.append(card)

	_deck.shuffle()

func draw() -> Dictionary:
	if _deck.is_empty():
		_refill_deck()
	if _deck.is_empty():
		return {}
	return _deck.pop_back()

func find_card_by_id(id: String) -> Dictionary:
	for card in _raw_cards:
		if card.get("Id", "") == id:
			return card
	return {}

func prepare_presented(card: Dictionary) -> Dictionary:
	var present := {
		"id": card.get("Id", ""),
		"title": card.get("Title", ""),
		"desc": card.get("Description", ""),
		"left": {},
		"right": {}
	}

	var left := {
		"text": card.get("LeftText", ""),
		"Heat": card.get("LeftHeat", 0),
		"Discontent": card.get("LeftDiscontent", 0),
		"Hope": card.get("LeftHope", 0),
		"Survivors": card.get("LeftSurvivors", 0)
	}
	var right := {
		"text": card.get("RightText", ""),
		"Heat": card.get("RightHeat", 0),
		"Discontent": card.get("RightDiscontent", 0),
		"Hope": card.get("RightHope", 0),
		"Survivors": card.get("RightSurvivors", 0)
	}

	var swap := randi() % 2 == 0
	if swap:
		present.left = right
		present.right = left
	else:
		present.left = left
		present.right = right

	return present
func reset_deck() -> void:
	_refill_deck()
