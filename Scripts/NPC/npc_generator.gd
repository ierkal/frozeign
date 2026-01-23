extends Node
class_name NpcGenerator

signal npcs_generated
signal npc_profession_changed(npc_name: String, profession: String)

const PARTS_BASE_PATH := "res://Assets/Sprites/npc/"
const SAVE_PATH := "user://npc_data_save.json"

# Part pools loaded from file system
var _part_pools: Dictionary = {
	"face": [],
	"eye": [],
	"mouth": [],
	"nose": [],
	"body": [],
	"hat": []
}

# All generated NPCs: { "Barnaby": { npc_data }, ... }
var _npcs: Dictionary = {}

# Name pool from JSON
var _name_pool: Array = []

# Track which names are assigned to council/professions
var _council_npcs: Dictionary = {}  # { "Steward": "Barnaby", "Captain": "Clifford" }
var _profession_npcs: Dictionary = {}  # { "Foreman": "Duncan", ... }


func _ready() -> void:
	_load_name_pool()
	_scan_part_pools()


func _load_name_pool() -> void:
	var data = JsonLoader.load_json(GameConstants.JSON_PATH_NPC_NAMES)
	if data:
		_name_pool = data.get("profession_names", [])
	print("NpcGenerator: Loaded %d names" % _name_pool.size())


func _scan_part_pools() -> void:
	# Scan each part folder for available images
	var part_folders = ["face", "eye", "mouth", "nose", "body", "hat"]

	for folder in part_folders:
		var path = PARTS_BASE_PATH + folder + "/"
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				# FIX: In exported builds, files have .import extension. 
				# We must remove it to see the underlying resource name.
				if file_name.ends_with(".import"):
					file_name = file_name.replace(".import", "")

				# Only add .png files
				if file_name.ends_with(".png"):
					var part_name = file_name.replace(".png", "")
					# Avoid duplicates if both .png and .import exist (rare in export, common in editor)
					if not _part_pools[folder].has(part_name):
						_part_pools[folder].append(part_name)
				
				file_name = dir.get_next()
			dir.list_dir_end()

	print("NpcGenerator: Part pools loaded - face:%d, eye:%d, mouth:%d, nose:%d, body:%d, hat:%d" % [
		_part_pools["face"].size(),
		_part_pools["eye"].size(),
		_part_pools["mouth"].size(),
		_part_pools["nose"].size(),
		_part_pools["body"].size(),
		_part_pools["hat"].size()
	])


func generate_all_npcs() -> void:
	"""Generate all NPCs at game start with random appearances."""
	_npcs.clear()
	_council_npcs.clear()
	_profession_npcs.clear()

	# Shuffle name pool for randomness
	var shuffled_names = _name_pool.duplicate()
	shuffled_names.shuffle()

	for npc_name in shuffled_names:
		var npc_data = _generate_random_appearance(npc_name)
		_npcs[npc_name] = npc_data

	print("NpcGenerator: Generated %d NPCs" % _npcs.size())
	npcs_generated.emit()


func initialize_lazy() -> void:
	"""Initialize for lazy generation - only clears state, doesn't create NPCs."""
	_npcs.clear()
	_council_npcs.clear()
	_profession_npcs.clear()
	print("NpcGenerator: Initialized for lazy generation")


func get_or_create_npc(npc_name: String) -> Dictionary:
	"""Get an NPC by name, creating them on-demand if they don't exist."""
	if _npcs.has(npc_name):
		return _npcs[npc_name]

	# Check if name is valid
	if not _name_pool.has(npc_name):
		push_warning("NpcGenerator: Unknown name '%s', creating anyway" % npc_name)

	# Create NPC on-demand
	var npc_data = _generate_random_appearance(npc_name)
	_npcs[npc_name] = npc_data
	print("NpcGenerator: Created NPC on-demand: %s" % npc_name)

	return npc_data


func _generate_random_appearance(npc_name: String) -> Dictionary:
	"""Generate random appearance parts for an NPC."""
	var npc_data = {
		"name": npc_name,
		"face": _get_random_part("face"),
		"eye": _get_random_part("eye"),
		"mouth": _get_random_part("mouth"),
		"nose": _get_random_part("nose"),
		"body": _get_random_part("body"),
		"hat": _get_random_part("hat"),
		"profession": "",
		"is_council": false
	}
	return npc_data


func _get_random_part(part_type: String) -> String:
	"""Get a random part from the pool, or empty if none available."""
	var pool = _part_pools.get(part_type, [])
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


func create_council_npcs(steward_name: String = "", captain_name: String = "") -> void:
	"""Create council NPCs (Steward, Captain) with lazy generation support."""
	# Get available names from the name pool (not from _npcs which may be empty)
	var available_names = _name_pool.duplicate()
	available_names.shuffle()

	# Remove names already used
	for used_name in _npcs.keys():
		available_names.erase(used_name)

	# Steward
	if steward_name == "":
		if available_names.size() > 0:
			steward_name = available_names.pop_front()
	else:
		available_names.erase(steward_name)

	if steward_name != "":
		# Create NPC on-demand if not exists
		var steward_data = get_or_create_npc(steward_name)
		steward_data["profession"] = "Steward"
		steward_data["is_council"] = true
		_council_npcs["Steward"] = steward_name
		print("NpcGenerator: Assigned Steward to %s" % steward_name)

	# Captain
	if captain_name == "":
		if available_names.size() > 0:
			captain_name = available_names.pop_front()
	else:
		available_names.erase(captain_name)

	if captain_name != "":
		# Create NPC on-demand if not exists
		var captain_data = get_or_create_npc(captain_name)
		captain_data["profession"] = "Captain"
		captain_data["is_council"] = true
		_council_npcs["Captain"] = captain_name
		print("NpcGenerator: Assigned Captain to %s" % captain_name)


func _get_available_names() -> Array:
	"""Get names from the pool that aren't assigned to any profession."""
	var available = []
	# Check all names in the pool
	for npc_name in _name_pool:
		# If NPC exists, check if they have a profession
		if _npcs.has(npc_name):
			var npc = _npcs[npc_name]
			if npc["profession"] == "":
				available.append(npc_name)
		else:
			# NPC not created yet, so available
			available.append(npc_name)
	return available


func get_npc(npc_name: String) -> Dictionary:
	"""Get NPC data by name."""
	return _npcs.get(npc_name, {})


func get_npc_for_profession(profession: String) -> Dictionary:
	"""Get the NPC assigned to a profession."""
	var npc_name = ""

	# Check council first
	if _council_npcs.has(profession):
		npc_name = _council_npcs[profession]
	# Then check other professions
	elif _profession_npcs.has(profession):
		npc_name = _profession_npcs[profession]

	if npc_name != "" and _npcs.has(npc_name):
		return _npcs[npc_name]

	return {}


func get_council_npc(role: String) -> Dictionary:
	"""Get Steward or Captain NPC data."""
	return get_npc_for_profession(role)


func assign_profession(npc_name: String, profession: String) -> void:
	"""Assign a profession to an NPC (when hired)."""
	if not _npcs.has(npc_name):
		push_error("NpcGenerator: Unknown NPC: " + npc_name)
		return

	_npcs[npc_name]["profession"] = profession
	_profession_npcs[profession] = npc_name

	print("NpcGenerator: %s is now %s" % [npc_name, profession])
	npc_profession_changed.emit(npc_name, profession)


func replace_council_member(role: String, new_npc_name: String) -> void:
	"""Replace a council member (when they die and someone is hired)."""
	if not _npcs.has(new_npc_name):
		push_error("NpcGenerator: Unknown NPC: " + new_npc_name)
		return

	# Clear old council member's status
	if _council_npcs.has(role):
		var old_name = _council_npcs[role]
		if _npcs.has(old_name):
			_npcs[old_name]["profession"] = ""
			_npcs[old_name]["is_council"] = false

	# Assign new council member
	_npcs[new_npc_name]["profession"] = role
	_npcs[new_npc_name]["is_council"] = true
	_council_npcs[role] = new_npc_name

	print("NpcGenerator: %s is now the new %s" % [new_npc_name, role])
	npc_profession_changed.emit(new_npc_name, role)


func get_all_npcs() -> Dictionary:
	"""Get all NPC data."""
	return _npcs.duplicate()


func get_name_pool() -> Array:
	"""Get the full name pool."""
	return _name_pool.duplicate()


# ---------------------------------------------------
# Persistence
# ---------------------------------------------------

func save_data() -> void:
	var data = {
		"npcs": _npcs,
		"council_npcs": _council_npcs,
		"profession_npcs": _profession_npcs
	}
	if JsonLoader.save_json(SAVE_PATH, data):
		print("NpcGenerator: Data saved")


func load_data() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var data = JsonLoader.load_json(SAVE_PATH)
	if data:
		_npcs = data.get("npcs", {})
		_council_npcs = data.get("council_npcs", {})
		_profession_npcs = data.get("profession_npcs", {})
		print("NpcGenerator: Data loaded - %d NPCs" % _npcs.size())
		return true

	return false


func clear_save_data() -> void:
	_npcs.clear()
	_council_npcs.clear()
	_profession_npcs.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	print("NpcGenerator: Save data cleared")
