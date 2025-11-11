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

# Awaitable loader (so you can: await Deck.load_from_file("res://cards.json"))
@warning_ignore("redundant_await")
func load_from_file(path: String) -> void:
	# make this function awaitable and let the scene settle for one frame
	await get_tree().process_frame

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Deck: cannot open %s" % path)
		return

	var text := f.get_as_text()
	load_from_json_string(text)

# ---- Deck ops ----

func _refill_deck() -> void:
	_deck = _raw_cards.duplicate(true)
	_deck.shuffle()

func draw() -> Dictionary:
	if _deck.is_empty():
		_refill_deck()
	if _deck.is_empty():
		return {}  # still empty -> nothing loaded yet
	return _deck.pop_back()

# Build a UI-ready card with possibly swapped choices for randomness
# Returns:
# {
#   id, title, desc,
#   left:  { text, Heat, Discontent, Hope, Survivors },
#   right: { text, Heat, Discontent, Hope, Survivors }
# }
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
