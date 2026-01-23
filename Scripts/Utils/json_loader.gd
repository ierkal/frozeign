class_name JsonLoader

## Utility class for loading and saving JSON files.
## Centralizes the repeated JSON loading pattern found across the codebase.

static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JsonLoader: File not found: " + path)
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("JsonLoader: Could not open file: " + path)
		return null
	var json = JSON.new()
	var content = file.get_as_text()
	file.close()
	if json.parse(content) == OK:
		return json.data
	push_error("JsonLoader: Failed to parse: " + path)
	return null


static func save_json(path: String, data: Variant) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		return true
	push_error("JsonLoader: Could not write to file: " + path)
	return false
