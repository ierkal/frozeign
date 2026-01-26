extends Node
class_name InterviewManager

signal interview_started(profession: String)
signal interview_ended(profession: String, hired_name: String)
signal npc_hired(profession: String, name: String)

# Persistent data (survives chief deaths and game restarts)
var _hired_npcs: Dictionary = {}  # { "Foreman": "Marcus", "Hunter": "Viktor" }
var _used_names: Array = []       # Names that can never be reused

# Session data (reset per interview)
var _name_pool: Array = []
var _current_interview_profession: String = ""
var _current_interview_names: Dictionary = {}  # { 1: "Marcus", 2: "Viktor", 3: "Aldric", 4: "Garrett" }

# Hunters special interview state (hire 3 from 4)
var _hunters_hired: Array = []  # Candidate indices that were hired (1-4)
var _hunters_interview_active: bool = false
var _hunters_pending: Array = []  # Candidate indices still to be seen this round
var _hunters_retry_triggered: bool = false  # Guard against multiple retry triggers
var _setup_done: bool = false  # Guard against multiple signal connections

var _deck: Deck

const SAVE_PATH := "user://interview_save.json"
const NAMES_PATH := "res://Json/npcnames.json"
const CANDIDATE_COUNT := 4
const HUNTERS_REQUIRED := 3


func _ready() -> void:
	_load_name_pool()
	# _load_persistent_data()  # Disabled for testing
	print("InterviewManager ready. Name pool size: ", _name_pool.size())


func setup(deck_ref: Deck) -> void:
	if _setup_done:
		print("InterviewManager: setup() already called, skipping")
		return
	_setup_done = true
	_deck = deck_ref
	_deck.flag_added_signal.connect(_on_flag_added)
	_deck.pool_unlocked.connect(_on_pool_unlocked)
	_deck.card_committed_signal.connect(_on_card_committed)
	print("InterviewManager: setup() completed, signals connected")


# ---------------------------------------------------
# Name Pool Management
# ---------------------------------------------------

func _load_name_pool() -> void:
	if not FileAccess.file_exists(NAMES_PATH):
		push_error("InterviewManager: Names file not found: " + NAMES_PATH)
		return
	var file = FileAccess.open(NAMES_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_name_pool = json.data.get("profession_names", [])


func _get_available_names() -> Array:
	var available: Array = []
	for name in _name_pool:
		if not _used_names.has(name):
			available.append(name)
	return available


func _select_interview_names() -> void:
	_current_interview_names.clear()
	var available = _get_available_names()
	available.shuffle()

	for i in range(CANDIDATE_COUNT):
		if i < available.size():
			_current_interview_names[i + 1] = available[i]
		else:
			_current_interview_names[i + 1] = "Candidate %d" % (i + 1)

	# Debug: Print assigned names
	print("Interview names assigned: ", _current_interview_names)


# ---------------------------------------------------
# Interview Flow Control
# ---------------------------------------------------

func _on_pool_unlocked(pool_name: String) -> void:
	print("Pool unlocked: ", pool_name)
	# Detect interview pool unlock (e.g., "Foreman_Interview")
	if pool_name.ends_with("_Interview"):
		var profession = pool_name.replace("_Interview", "")
		print("Detected interview pool for: ", profession)

		# Special handling for Hunters interview
		if profession == "Hunters":
			if not _hunters_interview_active:
				_start_hunters_interview()
			return

		# Don't restart if already interviewing for same profession
		if _current_interview_profession != profession:
			_start_interview(profession)
		else:
			print("Already interviewing for this profession, skipping")


func _start_interview(profession: String) -> void:
	print("_start_interview called for: ", profession)
	# Don't start if already hired for this profession
	if _hired_npcs.has(profession):
		print("Already hired for ", profession, ", skipping interview")
		return

	_current_interview_profession = profession
	_select_interview_names()
	print("Interview started for ", profession, " with names: ", _current_interview_names)
	interview_started.emit(profession)


func _on_flag_added(flag_name: String) -> void:
	# Handle Hunters interview flags
	if _hunters_interview_active:
		_handle_hunters_flag(flag_name)

	if _current_interview_profession == "":
		return

	var profession_lower = _current_interview_profession.to_lower()

	# Check for hire flags: "steward_foreman_X_interview_end_yes"
	for i in range(1, CANDIDATE_COUNT + 1):
		var hire_flag = "steward_%s_%d_interview_end_yes" % [profession_lower, i]
		if flag_name == hire_flag:
			_hire_candidate(i)
			return


func _hire_candidate(candidate_index: int) -> void:
	var hired_name = _current_interview_names.get(candidate_index, "Unknown")

	# Permanently assign name to profession
	_hired_npcs[_current_interview_profession] = hired_name
	_used_names.append(hired_name)

	# Emit signals
	npc_hired.emit(_current_interview_profession, hired_name)
	interview_ended.emit(_current_interview_profession, hired_name)

	# Save persistent data - disabled for testing
	# _save_persistent_data()

	# Reset interview state
	_current_interview_profession = ""
	_current_interview_names.clear()


func _auto_hire_npc(profession: String, specific_npc: String = "") -> void:
	"""Automatically hire an NPC for a profession without interview.
	If specific_npc is provided, hire that NPC. Otherwise pick a random one."""
	# Don't hire if already hired for this profession
	if _hired_npcs.has(profession):
		print("InterviewManager: Already hired for %s, skipping auto-hire" % profession)
		return

	var hired_name: String

	if specific_npc != "":
		# Use the specific NPC that was shown on the card
		hired_name = specific_npc
	else:
		# Pick a random available name
		var available = _get_available_names()
		if available.is_empty():
			push_error("InterviewManager: No available names for auto-hire")
			return
		available.shuffle()
		hired_name = available[0]

	# Register the hire
	_hired_npcs[profession] = hired_name
	_used_names.append(hired_name)

	print("InterviewManager: Auto-hired %s %s" % [profession, hired_name])

	# Emit signals
	npc_hired.emit(profession, hired_name)
	interview_ended.emit(profession, hired_name)


# ---------------------------------------------------
# Title Injection (called from Deck.prepare_presented)
# ---------------------------------------------------

func get_dynamic_title(card: Dictionary) -> String:
	var card_id = str(card.get("Id", ""))
	var candidate_index_raw = card.get("InterviewCandidate", 0)
	var candidate_index: int = int(candidate_index_raw)
	var profession = str(card.get("InterviewProfession", ""))
	var pool = str(card.get("Pool", ""))
	var npc_name = str(card.get("NpcName", ""))
	var original_title = str(card.get("Title", ""))

	# Debug: Print what we're looking up
	if candidate_index > 0:
		print("get_dynamic_title: card=%s, candidate=%d, profession=%s, hired=%s, names=%s" % [card_id, candidate_index, profession, _hired_npcs, _current_interview_names])

	# Steward decision cards keep their original title (e.g., "Steward Elias")
	if card_id.begins_with("steward_"):
		return original_title

	# Regular NPC cards with NpcName field - created when first met
	if npc_name != "":
		# If there's a title prefix (like "Worker"), combine with name
		if original_title != "":
			return "%s %s" % [original_title, npc_name]
		return npc_name

	# Check if this is a regular profession card (Pool matches a hired profession)
	# e.g., Pool = "Foreman" and we hired a Foreman
	if _hired_npcs.has(pool):
		return "%s %s" % [pool, _hired_npcs[pool]]

	# Interview cards with explicit InterviewProfession field
	if candidate_index > 0 and profession != "":
		# Already hired for this profession - show with profession prefix
		if _hired_npcs.has(profession):
			return "%s %s" % [profession, _hired_npcs[profession]]

		# During interview - show just the candidate's name (no profession prefix)
		if _current_interview_names.has(candidate_index):
			return _current_interview_names[candidate_index]

	# Fallback to original title
	return original_title


func is_profession_hired(profession: String) -> bool:
	return _hired_npcs.has(profession)


func get_hired_npc_name(profession: String) -> String:
	return _hired_npcs.get(profession, "")


func get_all_hired_npcs() -> Dictionary:
	return _hired_npcs.duplicate()


func get_interview_candidate_name(candidate_index: int) -> String:
	"""Get the name of a candidate by index (1-4) during an active interview."""
	return _current_interview_names.get(candidate_index, "")


func get_current_interview_profession() -> String:
	"""Get the profession being interviewed for, or empty if no active interview."""
	return _current_interview_profession


# ---------------------------------------------------
# Persistence (survives game restarts)
# ---------------------------------------------------

func _save_persistent_data() -> void:
	var save_data = {
		"hired_npcs": _hired_npcs,
		"used_names": _used_names
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))


func _load_persistent_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			_hired_npcs = data.get("hired_npcs", {})
			_used_names = data.get("used_names", [])


func clear_save_data() -> void:
	# For testing or new game - clears all persistent data
	_hired_npcs.clear()
	_used_names.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------------------------------------------
# Card Commit Handler
# ---------------------------------------------------

func _on_card_committed(card_id: String, side: String, pending_hire_npc: String = "") -> void:
	# Check for priest_believing_in_faith - auto-hire the shown citizen as Priest
	if card_id == "priest_believing_in_faith":
		_auto_hire_npc("Priest", pending_hire_npc)
		return

	# Check for our_inventory_manager_2 - auto-hire the shown citizen as Inventory Manager
	if card_id == "our_inventory_manager_2":
		_auto_hire_npc("Inventory Manager", pending_hire_npc)
		return

	if not _hunters_interview_active:
		return

	# Check if this is a hunter interview card
	for i in range(1, CANDIDATE_COUNT + 1):
		if card_id == "hunter_%d_interview" % i:
			_on_hunter_candidate_decided(i, side)
			return


# ---------------------------------------------------
# Hunters Interview (Special: hire 3 from 4)
# ---------------------------------------------------

func _start_hunters_interview() -> void:
	print("InterviewManager: Starting Hunters interview (hire 3 from 4)")
	_hunters_interview_active = true
	_hunters_hired.clear()
	_hunters_pending = [1, 2, 3, 4]  # All 4 candidates pending
	_select_interview_names()
	_current_interview_profession = "Hunter"
	interview_started.emit("Hunter")


func _on_hunter_candidate_decided(candidate_index: int, side: String) -> void:
	print("InterviewManager: _on_hunter_candidate_decided called - candidate=%d, side=%s, pending=%s, hired=%s" % [candidate_index, side, _hunters_pending, _hunters_hired])

	# Only process if this candidate is in the current pending list
	if not _hunters_pending.has(candidate_index):
		print("InterviewManager: Ignoring candidate %d (not in pending list)" % candidate_index)
		return

	# Remove from pending list
	_hunters_pending.erase(candidate_index)
	print("InterviewManager: Candidate %d decided, pending remaining: %s" % [candidate_index, _hunters_pending])

	# If hired (left swipe), track it
	if side == "left":
		if not _hunters_hired.has(candidate_index):
			_hunters_hired.append(candidate_index)
			var hired_name = _current_interview_names.get(candidate_index, "Hunter %d" % candidate_index)
			print("InterviewManager: Hunter candidate %d (%s) hired. Total: %d/%d" % [candidate_index, hired_name, _hunters_hired.size(), HUNTERS_REQUIRED])
			# Emit npc_hired for each hunter
			npc_hired.emit("Hunter", hired_name)
	else:
		print("InterviewManager: Hunter candidate %d rejected" % candidate_index)

	# Check if we have enough hunters
	if _hunters_hired.size() >= HUNTERS_REQUIRED:
		print("InterviewManager: Enough hunters hired! (%d/%d)" % [_hunters_hired.size(), HUNTERS_REQUIRED])
		# Clear any remaining hunter cards from the queue
		_deck.clear_queued_cards_by_prefix("hunter_")
		# Also clear any "not enough" cards that might be queued
		_deck.clear_queued_cards_by_prefix("steward_hunters_hire")
		_deck.add_flag("hunters_all_hired")
		# Queue the success card immediately
		_deck.queue_card("steward_hunters_hired")
		_end_hunters_interview()
		return

	# Check if all pending candidates have been seen
	if _hunters_pending.is_empty():
		print("InterviewManager: All candidates seen this round. Hired: %d/%d" % [_hunters_hired.size(), HUNTERS_REQUIRED])
		# Not enough hunters - queue the "not enough" card to force another retry
		# Clear any existing not enough cards first
		_deck.clear_queued_cards_by_prefix("steward_hunters_hire")
		# Remove the decided flag so it can trigger again when player swipes the card
		_deck.remove_flag("steward_hunters_hire_not_enough_decided")
		_deck.unlock_card("steward_hunters_hire_not_enough")
		_deck.queue_card("steward_hunters_hire_not_enough")
		# Reset retry guard so the flag handler can process the next retry
		_hunters_retry_triggered = false
		print("InterviewManager: Queued steward_hunters_hire_not_enough for retry (retry_triggered reset to false)")


func _handle_hunters_flag(flag_name: String) -> void:
	# Check if player acknowledged "not enough" message - reset for another round
	if flag_name == "steward_hunters_hire_not_enough_decided":
		# Guard against multiple triggers - only reset if pending is empty
		if _hunters_pending.is_empty() and not _hunters_retry_triggered:
			print("InterviewManager: Not enough flag received, triggering retry")
			_hunters_retry_triggered = true
			_reset_hunters_for_retry()
		else:
			print("InterviewManager: Ignoring not enough flag (pending=%s, triggered=%s)" % [_hunters_pending, _hunters_retry_triggered])
		return


func _reset_hunters_for_retry() -> void:
	print("InterviewManager: Resetting hunters interview for retry")

	# Clear any existing hunter cards from queue to prevent duplicates
	_deck.clear_queued_cards_by_prefix("hunter_")
	_deck.clear_queued_cards_by_prefix("steward_hunters_hire")

	# Reset pending list to rejected candidates only
	_hunters_pending.clear()
	for i in range(1, CANDIDATE_COUNT + 1):
		if not _hunters_hired.has(i):
			_hunters_pending.append(i)
			var card_id = "hunter_%d_interview" % i
			_deck.unlock_card(card_id)
			_deck.queue_card(card_id)  # Queue immediately so they show right away
			print("InterviewManager: Unlocked and queued rejected candidate card: ", card_id)

	# Reset the retry guard - will be set again when all pending are processed
	_hunters_retry_triggered = false

	print("InterviewManager: Retry round with %d candidates pending: %s" % [_hunters_pending.size(), _hunters_pending])


func _end_hunters_interview() -> void:
	print("InterviewManager: Hunters interview ended. Hired %d hunters." % _hunters_hired.size())
	_hunters_interview_active = false
	_hunters_pending.clear()
	_current_interview_profession = ""
	_current_interview_names.clear()
	interview_ended.emit("Hunter", "")


func get_hunters_hired_count() -> int:
	return _hunters_hired.size()


func is_hunters_interview_active() -> bool:
	return _hunters_interview_active
