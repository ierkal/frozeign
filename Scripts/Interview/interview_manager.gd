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

var _deck: Deck

const SAVE_PATH := "user://interview_save.json"
const NAMES_PATH := "res://Json/names.json"
const CANDIDATE_COUNT := 4


func _ready() -> void:
	_load_name_pool()
	# _load_persistent_data()  # Disabled for testing
	print("InterviewManager ready. Name pool size: ", _name_pool.size())


func setup(deck_ref: Deck) -> void:
	_deck = deck_ref
	_deck.flag_added_signal.connect(_on_flag_added)
	_deck.pool_unlocked.connect(_on_pool_unlocked)


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


# ---------------------------------------------------
# Title Injection (called from Deck.prepare_presented)
# ---------------------------------------------------

func get_dynamic_title(card: Dictionary) -> String:
	var card_id = str(card.get("Id", ""))
	var candidate_index_raw = card.get("InterviewCandidate", 0)
	var candidate_index: int = int(candidate_index_raw)
	var profession = str(card.get("InterviewProfession", ""))

	# Debug: Print what we're looking up
	if candidate_index > 0:
		print("get_dynamic_title: card=%s, candidate=%d, profession=%s, hired=%s, names=%s" % [card_id, candidate_index, profession, _hired_npcs, _current_interview_names])

	# Not an interview card
	if candidate_index == 0 or profession == "":
		return str(card.get("Title", ""))

	# Steward decision cards keep their original title (e.g., "Steward Elias")
	if card_id.begins_with("steward_"):
		return str(card.get("Title", ""))

	# Already hired for this profession - show with profession prefix
	if _hired_npcs.has(profession):
		return "%s %s" % [profession, _hired_npcs[profession]]

	# During interview - show just the candidate's name (no profession prefix)
	if _current_interview_names.has(candidate_index):
		return _current_interview_names[candidate_index]

	# Fallback to original title
	return str(card.get("Title", ""))


func is_profession_hired(profession: String) -> bool:
	return _hired_npcs.has(profession)


func get_hired_npc_name(profession: String) -> String:
	return _hired_npcs.get(profession, "")


func get_all_hired_npcs() -> Dictionary:
	return _hired_npcs.duplicate()


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
