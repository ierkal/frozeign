extends Node2D# CharacterRepository.gd
class_name CharacterRepository

var _characters: Array[CharacterDef] = []

# Load the data from the JSON file
func load_data(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		push_error("Character file not found: " + file_path)
		return
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse character JSON")
		return
	var data = json.data
	if typeof(data) == TYPE_ARRAY:
		_parse_characters(data)

# Helper to parse the array
func _parse_characters(data_array: Array) -> void:
	_characters.clear()
	
	for entry in data_array:
		# Avoid ternary operators as requested
		var char_id = ""
		if entry.has("id"):
			char_id = entry["id"]
			
		var char_name = ""
		if entry.has("name"):
			char_name = entry["name"]
			
		var char_flag = ""
		if entry.has("flag"):
			char_flag = entry["flag"]
			
		var char_desc = ""
		if entry.has("description"):
			char_desc = entry["description"]
		var new_char = CharacterDef.new(char_id, char_name, char_flag, char_desc)
		_characters.append(new_char)

# Public API to get total count
func get_total_count() -> int:
	return _characters.size()

# Public API to get met count based on provided flags
func get_met_count(player_flags: Array) -> int:
	var met_count = 0
	
	for char_def in _characters:
		# Check if the player's flag list contains the required flag
		if player_flags.has(char_def.flag_required):
			met_count += 1
			
	return met_count