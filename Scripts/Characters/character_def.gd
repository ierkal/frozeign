# CharacterDef.gd
class_name CharacterDef
extends RefCounted

var id: String
var name: String
var flag_required: String
var description: String
var image_path: String

func _init(p_id: String, p_name: String, p_flag: String, p_desc: String, p_image: String = ""):
	id = p_id
	name = p_name
	flag_required = p_flag
	description = p_desc
	image_path = p_image