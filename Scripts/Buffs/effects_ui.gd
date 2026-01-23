extends Control
class_name EffectsUI

@export var effect_item_scene: PackedScene
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var effects_list: VBoxContainer = %EffectListVbox

var _buff_manager: BuffManager


func setup(buff_manager: BuffManager) -> void:
	_buff_manager = buff_manager


func _ready() -> void:
	EventBus.buff_started.connect(_on_buff_started)
	EventBus.buff_ended.connect(_on_buff_ended)
	_clear_list()

func refresh_active_buffs(buff_manager: BuffManager) -> void:
	_clear_list()

	if not buff_manager:
		return

	for buff in buff_manager.get_active_buffs():
		_add_buff_item(buff as ActiveBuff)

func _add_buff_item(buff: ActiveBuff) -> void:
	if not effect_item_scene:
		push_error("EffectsUI: effect_item_scene not assigned!")
		return

	var item = effect_item_scene.instantiate()
	effects_list.add_child(item)

	item.title.text = buff.title
	item.description.text = buff.description

	if buff.icon_path != "" and FileAccess.file_exists(buff.icon_path):
		item.icon.texture = load(buff.icon_path)

func _clear_list() -> void:
	ContainerUtils.clear_children(effects_list)

func _on_buff_started(buff: ActiveBuff) -> void:
	_add_buff_item(buff)

func _on_buff_ended(buff_id: String) -> void:
	# Remove items that no longer match any active buff
	# We need to find and remove the item with matching title
	if not effects_list:
		return

	for child in effects_list.get_children():
		# Since buff_id might not match title, we'll do a full refresh
		# This is simpler and safer
		break

	# Schedule a deferred refresh to avoid issues during signal processing
	call_deferred("_deferred_refresh")

func _deferred_refresh() -> void:
	if _buff_manager:
		refresh_active_buffs(_buff_manager)
	else:
		# Fallback to tree search if not setup via DI
		var gm = get_tree().get_first_node_in_group("GameManager")
		if gm and gm.buff_manager:
			refresh_active_buffs(gm.buff_manager)