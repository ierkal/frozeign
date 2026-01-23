extends Node
class_name QuestManager

var _all_quests: Array = []
var _active_quests: Array = []
var _completed_quests: Array = []
var _current_tier: int = 1 

signal quest_reward_triggered(text: String) # Yeni sinyal

@export var deck_ref: Deck

func _ready() -> void:
	load_quests_from_file(GameConstants.JSON_PATH_QUESTS)
	if deck_ref:
		deck_ref.connect("flag_added_signal", _on_flag_added)

func load_quests_from_file(path: String) -> void:
	var data = JsonLoader.load_json(path)
	if data:
		_all_quests = data
		_initialize_auto_quests()

func _initialize_auto_quests() -> void:
	for quest in _all_quests:
		if quest.get("auto_start", false) == true:
			activate_quest(quest)

func activate_quest(quest: Dictionary) -> void:
	# Zaten aktifse ekleme
	for aq in _active_quests:
		if aq["id"] == quest["id"]: return
	# Zaten tamamlanmışsa ekleme
	for cq in _completed_quests:
		if cq["id"] == quest["id"]: return
		
	_active_quests.append(quest)

func _on_flag_added(flag_name: String) -> void:
	check_quest_completion(flag_name)

func check_quest_completion(triggered_flag: String) -> void:
	var i = _active_quests.size() - 1
	while i >= 0:
		var quest = _active_quests[i]
		var targets = quest.get("target_flags", [])
		if targets.has(triggered_flag):
			complete_quest(i)
		i -= 1

func complete_quest(index: int) -> void:
	var quest = _active_quests[index]
	var reward = quest.get("reward_text", "completed!")
	
	_active_quests.remove_at(index)
	_completed_quests.append(quest)
	
	# Sinyali ödül metniyle fırlat
	quest_reward_triggered.emit(reward)
	
	_check_for_tier_upgrade()


func _check_for_tier_upgrade() -> void:
	var current_tier_finished = true
	for quest in _all_quests:
		if int(quest.get("order", 1)) == _current_tier:
			var found_in_completed = false
			for cq in _completed_quests:
				if cq["id"] == quest["id"]:
					found_in_completed = true
					break
			if not found_in_completed:
				current_tier_finished = false
				break
	
	if current_tier_finished:
		_current_tier += 1
		

# YENİ: Tüm görevleri durumlarıyla beraber UI'a gönderir
func get_quest_display_data() -> Array:
	var display_list = []
	for quest in _all_quests:
		var q_id = quest.get("id", "")
		var q_order = int(quest.get("order", 1))
		
		# Durum belirleme
		var is_completed = false
		for cq in _completed_quests:
			if cq["id"] == q_id:
				is_completed = true
				break
		
		var is_unlocked = q_order <= _current_tier
		
		display_list.append({
			"title": quest.get("title", ""),
			"description": quest.get("description", ""),
			"is_unlocked": is_unlocked,
			"is_completed": is_completed
		})
	return display_list


# Accessor methods for encapsulation
func get_completed_count() -> int:
	return _completed_quests.size()


func get_all_quests_count() -> int:
	return _all_quests.size()


func get_active_count() -> int:
	return _active_quests.size()


func get_current_tier() -> int:
	return _current_tier