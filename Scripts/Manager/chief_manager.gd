extends Node
class_name ChiefManager
var _all_names: Array = []
var current_chief_name: String = ""
var _npc_blacklist: Array = ["Jonas", "Barnaby", "Percival", "John"] # Önemli NPC'ler


func load_names() -> void:
	var file_path = "res://Json/chief_names.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		json.parse(file.get_as_text())
		_all_names = json.data["names"]
		pick_random_name()

func pick_random_name() -> void:
	if _all_names.size() > 0:
		var selected_name = ""
		var attempts = 0
		
		while attempts < 10:
			var candidate = _all_names.pick_random().split(" ")[0] # Sadece ilk ismi al
			if not _npc_blacklist.has(candidate):
				selected_name = candidate
				break
			attempts += 1
			
		if selected_name == "":
			selected_name = "Chief" # Güvenli çıkış
			
		current_chief_name = selected_name
