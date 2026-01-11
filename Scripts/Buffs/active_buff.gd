class_name ActiveBuff
extends RefCounted

var id: String
var title: String
var description: String
var icon_path: String
var type: String
var duration_left: int
var effects: Dictionary = {}

func _init(data: Dictionary, buff_id: String) -> void:
	id = buff_id
	title = data.get("title", "Unknown")
	description = data.get("description", "")
	icon_path = data.get("icon_path", "")
	type = data.get("type", "timed")
	duration_left = int(data.get("duration", 3))
	effects = data.get("effects", {})