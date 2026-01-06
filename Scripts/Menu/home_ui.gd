extends Control
class_name HomeUI

# UI Component References
@onready var quest_count_item: HomeCountItem = %QuestCount
@onready var npc_list_item: HomeCountItem = %NPCList
@onready var discovered_cards_item: HomeCountItem = %DiscoveredCards
@onready var chief_board: HomeChiefBoard = %DeathHistoryList

# Dependency: We expect GameManager to provide the systems we need
func refresh_data(gm: GameManager) -> void:
	if not gm:
		return
	
	# 1. Quest Progress
	_update_quest_progress(gm.quest_manager)
	
# 2. Card Discovery (UPDATED)
	if gm.deck:
		var discovered = gm.deck.get_discovered_count()
		var total = gm.deck.get_unique_cards_count()
		
		# Format: "12 / 50 Unique cards discovered"
		discovered_cards_item.title.text = "Cards"
		discovered_cards_item.description.text = str(discovered) + " / " + str(total) + " Unique cards discovered"
		
		# Optional: Update progress bar if this item has one
		if total > 0:
			discovered_cards_item.progress_bar.max_value = total
			discovered_cards_item.progress_bar.value = discovered

	# 3. Character / NPC Interaction (Updated)
	# We pass the repository and the current flags to the update function
	_update_character_ui(gm.character_repository, gm.deck._flags)
	
	# 4. Chief History
	_update_chief_board(gm._dead_chiefs_history)

func _update_quest_progress(qm: QuestManager) -> void:
	if not qm:
		return
	
	var all_quests_count = qm._all_quests.size()
	var completed_count = qm._completed_quests.size()
	
	quest_count_item.title.text = "Completed Quests"
	
	# Description: completed / all format
	var progress_text = str(completed_count) + " / " + str(all_quests_count)
	quest_count_item.description.text = progress_text + " quests have been completed"
	
	if all_quests_count > 0:
		quest_count_item.progress_bar.max_value = all_quests_count
		quest_count_item.progress_bar.value = completed_count

func _update_character_ui(repo: CharacterRepository, flags: Dictionary) -> void:
	# Set the title explicitly as requested
	npc_list_item.title.text = "Characters"
	
	# Safety check: if repository hasn't been initialized in GameManager yet
	if repo == null:
		npc_list_item.description.text = "Data not available"
		return

	# Calculate counts using the repository logic
	var total_count = repo.get_total_count()
	
	# We need to convert the Dictionary keys (flags) to an Array for the repository method
	var flag_keys = flags.keys()
	var met_count = repo.get_met_count(flag_keys)
	
	# Description: "Met count / total characters was met"
	var text_output = str(met_count) + " / " + str(total_count) + " was met"
	npc_list_item.description.text = text_output
	
	# Optional: Update Progress Bar if you want visual feedback
	if total_count > 0:
		npc_list_item.progress_bar.max_value = total_count
		npc_list_item.progress_bar.value = met_count

func _update_chief_board(history: Array) -> void:
	chief_board.ChiefOne.text = "-"
	chief_board.ChiefTwo.text = "-"
	chief_board.ChiefThree.text = "-"
	chief_board.ChiefFour.text = "-"
	
	var slots = [chief_board.ChiefOne, chief_board.ChiefTwo, chief_board.ChiefThree, chief_board.ChiefFour]
	
	var index = 0
	for entry in history:
		if index < slots.size():
			var c_name = ""
			if entry.has("name"):
				c_name = entry["name"]
			else:
				c_name = "Unknown"
				
			var c_days = 0
			if entry.has("days"):
				c_days = entry["days"]
				
			slots[index].text = "%s: %d days survived" % [c_name, c_days]
			index += 1
