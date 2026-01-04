extends Node

func _ready() -> void:
	_update_json_file()

func _update_json_file() -> void:
	# Make sure this path matches where your file is located
	var path = "res://Json/frozeign.json" 
	
	if not FileAccess.file_exists(path):
		print("Error: File not found at " + path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return
		
	var data = json.data
	
	if typeof(data) == TYPE_ARRAY:
		var count = 0
		for card in data:
			# Add the new fields if they don't exist
			if not card.has("OnLeftUnlockPools"):
				card["OnLeftUnlockPools"] = []
			
			if not card.has("OnRightUnlockPools"):
				card["OnRightUnlockPools"] = []
			
			count += 1
		
		# Save the updated file back
		var new_content = JSON.stringify(data, "\t")
		var file_write = FileAccess.open(path, FileAccess.WRITE)
		file_write.store_string(new_content)
		file_write.close()
		
		print("Success! Updated " + str(count) + " cards with new pool unlock fields.")
	else:
		print("Error: JSON root is not an Array.")