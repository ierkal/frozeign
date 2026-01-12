extends Node
class_name NpcImageManager

const CONFIG_PATH := "res://Json/npc_images.json"
const SAVE_PATH := "user://npc_images_save.json"

# Image pools loaded from JSON
var _generic_pool: Array = []
var _profession_images: Dictionary = {}
var _character_images: Dictionary = {}

# Assigned images for each NPC (persisted)
var _assigned_images: Dictionary = {}  # { "npc_name": "image_path" }

# Track which images from the pool are still available
var _available_pool: Array = []


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("NpcImageManager: Config file not found: " + CONFIG_PATH)
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.data
		_generic_pool = data.get("generic_pool", [])
		_profession_images = data.get("profession_images", {})
		_character_images = data.get("character_images", {})
		_available_pool = _generic_pool.duplicate()
	file.close()


func initialize_all_npcs(name_list: Array) -> void:
	"""Pre-assign images to all NPCs at game start."""
	# Reset available pool
	_available_pool = _generic_pool.duplicate()
	_available_pool.shuffle()

	for npc_name in name_list:
		if not _assigned_images.has(npc_name):
			_assign_random_image(npc_name)

	print("NpcImageManager: Initialized %d NPCs with images" % name_list.size())


func _assign_random_image(npc_name: String) -> void:
	"""Assign a random image from the pool to an NPC."""
	if _available_pool.is_empty():
		# Pool exhausted, refill and reshuffle
		_available_pool = _generic_pool.duplicate()
		_available_pool.shuffle()

	if not _available_pool.is_empty():
		var image_path = _available_pool.pop_front()
		_assigned_images[npc_name] = image_path


func get_image_for_npc(npc_id: String) -> String:
	"""Get the assigned image for an NPC."""
	# Check if it's a story character with fixed image
	if _character_images.has(npc_id):
		return _character_images[npc_id]

	# Check assigned images
	if _assigned_images.has(npc_id):
		return _assigned_images[npc_id]

	# Fallback: assign now if not pre-assigned
	_assign_random_image(npc_id)
	return _assigned_images.get(npc_id, "")


func get_image_for_character(char_id: String) -> String:
	"""Get image for a story character by their ID."""
	return _character_images.get(char_id, "")


func assign_profession_image(npc_name: String, profession: String) -> void:
	"""Override NPC's image with profession-specific image when hired."""
	if _profession_images.has(profession):
		_assigned_images[npc_name] = _profession_images[profession]
		print("NpcImageManager: %s now uses %s profession image" % [npc_name, profession])


func get_profession_image(profession: String) -> String:
	"""Get the image path for a profession."""
	return _profession_images.get(profession, "")


# ---------------------------------------------------
# Persistence
# ---------------------------------------------------

func save_data() -> void:
	var save_data = {
		"assigned_images": _assigned_images
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			_assigned_images = data.get("assigned_images", {})
		file.close()


func clear_save_data() -> void:
	_assigned_images.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
