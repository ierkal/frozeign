extends Node2D
class_name GameManager
@onready var deck: Deck = %Deck

@onready var stats: StatsManager = $StatsManager
@onready var card_ui: CardUI = %Card_UI
@onready var stats_ui: StatsUI = %StatsUI
@onready var survived_days: SurvivedDaysUI = %SurvivedDays
@onready var quest_manager: QuestManager = %QuestManager
@onready var home_menu_ui : HomeMenuUI = %HomeMenuUI
@onready var chief_manager: ChiefManager = %ChiefManager
# Interview system for hiring profession NPCs
var interview_manager: InterviewManager

# New dynamic NPC system
var npc_generator: NpcGenerator
var npc_image_composer: NpcImageComposer

var _dead_chiefs_history: Array = [] # { "name": String, "start_day": int, "death_day": int, "index": int }
var _current_chief_start_day: int = 0  # Track when current chief started (cumulative day)
var _last_card_had_effect: bool = false
@onready var character_repository: CharacterRepository = %CharacterRepository

enum DeathPhase {
	NONE,
	EXPLANATION_NEXT,
	FINAL_NEXT,
	GAME_OVER
}

var _death_phase: int = DeathPhase.NONE
var _death_stat: String = ""
var _death_value: int = 0
var _death_is_storm: bool = false   # Track if this is a storm death
var _current_chief_index: int = 0   # Number of chiefs so far
var _dying_chief_name: String = ""  # Store dying chief's name before picking new one
var _chief_token_active: bool = false

@onready var reward_ui = %QuestCompletedNotification
@onready var card_unlock_animation: CardUnlockAnimation = %CardUnlockAnimation
@onready var death_screen: DeathScreen = %DeathScreen
@onready var skill_check_minigame: SkillCheckMinigame = %SkillCheckMinigame
@onready var radio_frequency_minigame: RadioFrequencyMinigame = %RadioFrequencyMinigame
@onready var generator_heat_minigame: GeneratorHeatMinigame = %GeneratorHeatMinigame
@onready var pipe_patch_minigame: PipePatchMinigame = %PipePatchMinigame
@onready var snow_clear_minigame: SnowClearMinigame = %SnowClearMinigame
@onready var currency_manager: CurrencyManager = %CurrencyManager
@onready var reward_popup: RewardPopup = %RewardPopup
@onready var hub_ui: HubUI = %HubUI
@onready var item_manager: ItemManager = %ItemManager
@onready var shop_panel: ShopPanel = %ShopPanel
@onready var art_sequence: ArtSequence = %ArtSequence

var _minigame_active: bool = false
var _shop_active: bool = false
var _art_sequence_active: bool = false
var _pending_ending_type: String = ""

const ENDING_CARDS := {
	"volcano_ending": "volcano",
	"oracle_ending": "oracle",
	"city_ending": "city"
}
const MID_SEQUENCE_CARD := "steward_city_growth"
var _pending_minigame_result: Dictionary = {}  # Stores minigame result while popup is shown
var _pending_shop_purchase: Dictionary = {}  # Stores purchase result while popup is shown
var _coin_icon: Texture2D = preload("res://Assets/Sprites/dollar.png")

func _ready() -> void:
	add_to_group("GameManager")

	# Hide game UI and show art sequence black background immediately,
	# before the await below, to prevent any flash during loading.
	if art_sequence and not art_sequence.intro_images.is_empty():
		_set_game_ui_visible(false)
		art_sequence.show()

	quest_manager.quest_reward_triggered.connect(_on_quest_reward_triggered)
	card_ui.request_deck_draw.connect(_on_request_deck_draw)
	card_ui.card_effect_committed.connect(_on_card_effect_committed)
	stats.stats_changed.connect(_on_stats_changed)
	stats.stat_threshold_reached.connect(_on_stat_threshold_reached)
	card_ui.card_count_reached.connect(_on_card_count_reach)
	deck.pool_unlocked.connect(_on_pool_unlocked)
	chief_manager.load_names()
	survived_days.update_ui(chief_manager.current_chief_name)
	deck.set_current_chief_index(_current_chief_index)
	character_repository = CharacterRepository.new()
	character_repository.load_data(GameConstants.JSON_PATH_CHARACTERS)
	await deck.load_from_file(GameConstants.JSON_PATH_CARDS)

	# Setup interview manager for profession hiring
	interview_manager = InterviewManager.new()
	add_child(interview_manager)
	interview_manager.setup(deck)
	deck.set_interview_manager(interview_manager)
	interview_manager.npc_hired.connect(_on_npc_hired)

	# Setup new dynamic NPC system (lazy generation - only creates NPCs when needed)
	npc_generator = NpcGenerator.new()
	add_child(npc_generator)

	npc_image_composer = NpcImageComposer.new()
	add_child(npc_image_composer)
	npc_image_composer.setup(npc_generator)

	# Initialize for lazy generation (don't create all NPCs at start)
	npc_generator.initialize_lazy()

	# Only create Steward and Captain at game start
	npc_generator.create_council_npcs()

	# Connect deck to NPC systems
	deck.set_npc_systems(npc_generator, npc_image_composer)

	# Setup NPC name resolver for reaction system
	EventBus.npc_name_resolver = _resolve_npc_name

	if home_menu_ui:
		home_menu_ui.setup(self)
	if card_unlock_animation:
		card_unlock_animation.set_target(card_ui.card_slot)
	if death_screen:
		death_screen.restart_requested.connect(_on_death_screen_restart)
		death_screen.need_quest_data.connect(_on_death_screen_needs_quest_data)
		death_screen.need_new_chief_name.connect(_on_death_screen_needs_new_chief_name)

	# Connect minigame signals
	EventBus.minigame_requested.connect(_on_minigame_requested)
	if skill_check_minigame:
		skill_check_minigame.minigame_completed.connect(_on_skill_check_completed)
	if radio_frequency_minigame:
		radio_frequency_minigame.minigame_completed.connect(_on_radio_frequency_completed)
	if generator_heat_minigame:
		generator_heat_minigame.minigame_completed.connect(_on_generator_heat_completed)
	if pipe_patch_minigame:
		pipe_patch_minigame.minigame_completed.connect(_on_pipe_patch_completed)
	if snow_clear_minigame:
		snow_clear_minigame.minigame_completed.connect(_on_snow_clear_completed)

	# Setup reward popup
	if reward_popup:
		reward_popup.popup_closed.connect(_on_reward_popup_closed)

	# Setup item manager
	if item_manager:
		item_manager.setup(stats)
		item_manager.load_items_from_file(GameConstants.JSON_PATH_ITEMS)

	# Setup hub UI with currency manager and item manager
	if hub_ui:
		hub_ui.setup(currency_manager, item_manager)
		hub_ui.item_use_requested.connect(_on_item_use_requested)

	# Setup shop panel
	if shop_panel:
		shop_panel.setup(currency_manager, item_manager)
		shop_panel.item_purchased.connect(_on_shop_item_purchased)
		shop_panel.shop_closed.connect(_on_shop_closed)

	# Connect shop signal
	EventBus.shop_requested.connect(_on_shop_requested)

	# Connect art sequence
	if art_sequence:
		art_sequence.sequence_finished.connect(_on_art_sequence_finished)

	# Connect ending reset from death screen
	if death_screen:
		death_screen.ending_reset_requested.connect(_on_ending_reset)

	# Start game - play intro if images exist, otherwise begin normally
	if art_sequence and not art_sequence.intro_images.is_empty():
		_art_sequence_active = true
		card_ui.set_input_blocked(true)
		art_sequence.play_sequence("intro")
	else:
		_set_game_ui_visible(true)
		deck.begin_starter_phase()
		_on_request_deck_draw()

func _on_quest_reward_triggered(text: String) -> void:
	reward_ui.play_notification(text)

func _on_npc_hired(profession: String, npc_name: String) -> void:
	reward_ui.play_notification("Hired: %s %s" % [profession, npc_name])
	# Assign profession to NPC (image will be refreshed automatically via signal)
	if npc_generator:
		# Ensure NPC exists (lazy creation) before assigning profession
		npc_generator.get_or_create_npc(npc_name)
		npc_generator.assign_profession(npc_name, profession)

func _on_pool_unlocked(_pool_name: String) -> void:
	reward_ui.play_notification("New cards unlocked!")
	if card_unlock_animation:
		_play_card_unlock_animation_delayed()

func _play_card_unlock_animation_delayed() -> void:
	# Wait for the new card to be drawn and settled
	await get_tree().create_timer(0.6).timeout
	if card_unlock_animation:
		card_unlock_animation.play_animation()

func _on_request_deck_draw() -> void:
	# Skip drawing if minigame, shop, or art sequence is active
	if _minigame_active or _shop_active or _art_sequence_active:
		return

	# A) Check for Game Over first - show death screen before reset
	if _death_phase == DeathPhase.GAME_OVER:
		_show_death_screen()
		return

	# Death explanation phase 1
	if _death_phase == DeathPhase.EXPLANATION_NEXT:
		var death_id := _get_death_card_id()
		var raw = deck.find_card_by_id(death_id)
		if raw.is_empty():
			push_error("Missing death card: %s" % death_id)
		else:
			var presented = deck.prepare_presented(raw)
			# Assign random NPC to deliver death news
			presented = _assign_death_npc(presented)
			card_ui.receive_presented_card(presented)
			_death_phase = DeathPhase.FINAL_NEXT
			return

	# Death final card
	if _death_phase == DeathPhase.FINAL_NEXT:
		# Check if this is a storm death - use storm death card instead
		if _death_is_storm:
			var raw = deck.find_card_by_id("death_storm_event")
			if not raw.is_empty():
				var presented = deck.prepare_presented(raw)
				card_ui.receive_presented_card(presented)
				_death_phase = DeathPhase.GAME_OVER
				return

		var final_card := _build_final_death_card()
		card_ui.receive_presented_card(final_card)
		_death_phase = DeathPhase.GAME_OVER
		return

	# Normal draw
	var raw = deck.draw()
	var presented = deck.prepare_presented(raw)
	card_ui.receive_presented_card(presented)


# 3. Update this function to REMOVE the immediate soft reset
func _on_card_effect_committed(effect: Dictionary) -> void:
	_last_card_had_effect = false

	# Progress shop restock timers
	if item_manager:
		item_manager.on_card_swiped()

	# Check if the card itself has any stat changes
	var card_has_stat_changes = false
	for key in GameConstants.ALL_STATS:
		if effect.has(key) and effect[key] != 0:
			card_has_stat_changes = true
			break

	# Check if there are any final stat changes (for day counting)
	for key in GameConstants.ALL_STATS:
		if effect.has(key) and effect[key] != 0:
			_last_card_had_effect = true
			break

	stats.apply_effects(effect)
	var card_id := String(effect.get("card_id", ""))
	var original_side := String(effect.get("original_side", ""))

	if card_id != "" and original_side != "":
		deck.on_card_committed(card_id, original_side)

	# Queue NPC reactions (after deck processes flags so met_* flags are available)
	if card_ui.reaction_display and card_id != "" and original_side != "":
		card_ui.reaction_display.on_card_committed(card_id, original_side)

	# Check for ending or mid-game art sequences
	if card_id in ENDING_CARDS and art_sequence:
		_pending_ending_type = ENDING_CARDS[card_id]
		_art_sequence_active = true
		card_ui.set_input_blocked(true)
		art_sequence.play_sequence(_pending_ending_type)
	elif card_id == MID_SEQUENCE_CARD and art_sequence:
		_art_sequence_active = true
		card_ui.set_input_blocked(true)
		art_sequence.play_sequence("mid")

func _on_stats_changed(h: int, d: int, o: int, f: int) -> void:
	stats_ui.update_stats(h, d, o, f)

func _on_card_count_reach() -> void:
	if _last_card_had_effect:
		survived_days.on_day_survive()

func _on_stat_threshold_reached(stat_name: String, value: int) -> void:
	if _death_phase != DeathPhase.NONE:
		return

	if _chief_token_active:
		_chief_token_active = false
		survived_days.set_token_active(false)
		stats.set(stat_name, GameConstants.DEFAULT_STAT_VALUE)
		stats_ui.update_stats(stats.morale, stats.dissent, stats.authority, stats.devotion)
		reward_ui.play_notification("Chief's Token saved your life!")
		return

	_death_phase = DeathPhase.EXPLANATION_NEXT
	_death_stat = stat_name
	_death_value = value
	_death_is_storm = _is_in_storm_event()  # Store storm state when death triggers


func _is_in_storm_event() -> bool:
	"""Check if player is currently in the storm event sequence (between storm_1 and storm_7)."""
	# Check if storm has started (any storm event flag exists)
	var storm_started = false
	for i in range(1, 8):
		if deck.has_flag("steward_event_storm_%d_decided" % i):
			storm_started = true
			break

	# Check if storm has completed
	var storm_completed = deck.has_flag("steward_event_storm_7_decided")

	return storm_started and not storm_completed


func _get_death_card_id() -> String:
	# Check if this is a storm death - use storm death card instead
	if _death_is_storm:
		return "steward_event_storm_fail"

	var upper := _death_stat.to_upper()
	var suffix := "LOW"
	if _death_value > 100:
		suffix = "HIGH"
	return "DEATH_%s_%s" % [upper, suffix]


func _assign_death_npc(presented: Dictionary) -> Dictionary:
	"""Assign a random created NPC to deliver the death news."""
	if npc_generator and npc_image_composer:
		var all_npcs = npc_generator.get_all_npcs()
		var npc_names = all_npcs.keys()

		if not npc_names.is_empty():
			var random_npc_name = npc_names[randi() % npc_names.size()]
			presented["title"] = random_npc_name
			presented["npc_image"] = npc_image_composer.get_or_compose_image(random_npc_name)

	return presented


func _build_final_death_card() -> Dictionary:
	var no_eff := {
		"text": "",
		"Morale": 0,
		"Dissent": 0,
		"Authority": 0,
		"Devotion": 0
	}

	return {
		"id": "DEATH_FINAL",
		"title": chief_manager.current_chief_name,
		"desc": "Your people left you to freeze.",
		"left": no_eff,
		"right": no_eff
	}


func _show_death_screen() -> void:
	"""Show the death screen with timeline before restarting."""
	# Store the dying chief's name BEFORE the death screen picks a new one
	_dying_chief_name = chief_manager.current_chief_name

	var death_day = _current_chief_start_day + survived_days.current_days
	var current_chief_data = {
		"name": _dying_chief_name,
		"start_day": _current_chief_start_day,
		"death_day": death_day,
		"index": _current_chief_index + 1
	}

	if death_screen:
		death_screen.show_death_screen(_dead_chiefs_history, current_chief_data)


func _on_death_screen_restart() -> void:
	"""Called when player taps to restart from death screen."""
	_soft_reset_game()


func _soft_reset_game() -> void:
	# Calculate death day for current chief
	var death_day = _current_chief_start_day + survived_days.current_days
	# Use the stored dying chief's name (captured before new chief was picked)
	var chief_data = {
		"name": _dying_chief_name,
		"start_day": _current_chief_start_day,
		"death_day": death_day,
		"index": _current_chief_index + 1
	}
	_dead_chiefs_history.append(chief_data)

	# Sort by days survived (death_day - start_day) descending
	_dead_chiefs_history.sort_custom(func(a, b):
		var a_days = a.get("death_day", 0) - a.get("start_day", 0)
		var b_days = b.get("death_day", 0) - b.get("start_day", 0)
		return a_days > b_days
	)

	# Keep only top 4
	if _dead_chiefs_history.size() > 4:
		_dead_chiefs_history.pop_back()

	# Update start day for next chief
	_current_chief_start_day = death_day

	_current_chief_index += 1
	_death_phase = DeathPhase.NONE
	_death_is_storm = false
	_chief_token_active = false
	survived_days.set_token_active(false)

	# Reset stats
	stats.reset_stats()
	survived_days.reset_days()

	# Note: chief_manager.pick_random_name() is already called in _on_death_screen_needs_new_chief_name
	survived_days.update_ui(chief_manager.current_chief_name)
	if _current_chief_index <= 1:
		deck.begin_starter_phase()
	else:
		_on_request_deck_draw()
	# Desteyi sıfırla ama kilitli havuzları açma!
	deck.set_current_chief_index(_current_chief_index)
	deck.soft_reset_deck() # Yeni yazdığımız fonksiyon
	
	# UI'ı güncelle
	stats_ui.update_stats(stats.morale, stats.dissent, stats.authority, stats.devotion)
	
	# Yeni liderle ilk kartı çek
	_on_request_deck_draw()

func _on_ui_needs_quest_data() -> void:
	if quest_manager and home_menu_ui.quest_ui:
	# Yeni fonksiyonu çağırıyoruz
		var display_list = quest_manager.get_quest_display_data()
		home_menu_ui.quest_ui.show_quests(display_list)

func _on_ui_needs_npc_data() -> void:
	if not home_menu_ui.npc_ui:
		return

	var npc_list: Array = []

	# Add all generated NPCs from the new system
	if npc_generator:
		var all_npcs = npc_generator.get_all_npcs()
		for npc_name in all_npcs.keys():
			var npc_data = all_npcs[npc_name]
			var profession = npc_data.get("profession", "")
			var npc_image: Texture2D = null

			if npc_image_composer:
				npc_image = npc_image_composer.get_cached_image(npc_name)

			npc_list.append({
				"name": npc_name,
				"profession": profession,
				"is_met": true,  # All generated NPCs are "known"
				"npc_image": npc_image
			})

	home_menu_ui.npc_ui.show_npcs(npc_list)

func _on_death_screen_needs_quest_data() -> void:
	if quest_manager and death_screen:
		var display_list = quest_manager.get_quest_display_data()
		death_screen.set_quest_data(display_list)

func _on_death_screen_needs_new_chief_name() -> void:
	if chief_manager and death_screen:
		# Pre-pick the next chief name so we can show it in death screen
		chief_manager.pick_random_name()
		death_screen.set_new_chief_name(chief_manager.current_chief_name)


# ===== NPC Name Resolver (for reaction system) =====
func _resolve_npc_name(npc_pool: String) -> String:
	# Council NPCs (Captain, Steward) - check if player has met them via deck flags
	if npc_pool == "Captain":
		if deck.has_flag("met_captain") and npc_generator:
			var npc_data = npc_generator.get_npc_for_profession("Captain")
			if not npc_data.is_empty():
				return npc_data.get("name", "")
		return ""

	if npc_pool == "Steward":
		if deck.has_flag("met_steward") and npc_generator:
			var npc_data = npc_generator.get_npc_for_profession("Steward")
			if not npc_data.is_empty():
				return npc_data.get("name", "")
		return ""

	# Hired profession NPCs - check via interview_manager
	if interview_manager and interview_manager.is_profession_hired(npc_pool):
		return interview_manager.get_hired_npc_name(npc_pool)

	# Check assigned NPCs via npc_generator (e.g. auto-hired)
	if npc_generator:
		var npc_data = npc_generator.get_npc_for_profession(npc_pool)
		if not npc_data.is_empty():
			return npc_data.get("name", "")

	return ""


# ===== Minigame Handling =====
func _on_minigame_requested(minigame_id: String, card_data: Dictionary) -> void:
	if minigame_id == "skill_check" and skill_check_minigame:
		_minigame_active = true
		card_ui.set_input_blocked(true)
		skill_check_minigame.show_minigame(card_data)
	elif minigame_id == "radio_frequency" and radio_frequency_minigame:
		_minigame_active = true
		card_ui.set_input_blocked(true)
		radio_frequency_minigame.show_minigame(card_data)
	elif minigame_id == "generator_heat" and generator_heat_minigame:
		_minigame_active = true
		card_ui.set_input_blocked(true)
		generator_heat_minigame.show_minigame(card_data)
	elif minigame_id == "pipe_patch" and pipe_patch_minigame:
		_minigame_active = true
		card_ui.set_input_blocked(true)
		pipe_patch_minigame.show_minigame(card_data)
	elif minigame_id == "snow_clear" and snow_clear_minigame:
		_minigame_active = true
		card_ui.set_input_blocked(true)
		snow_clear_minigame.show_minigame(card_data)


func _handle_minigame_completed(minigame_id: String, success: bool) -> void:
	if success:
		# Store result for after popup closes
		_pending_minigame_result = {
			"minigame_id": minigame_id,
			"success": success
		}

		# Award coin
		if currency_manager:
			currency_manager.add_coins(1)

		# Show reward popup (minigame stays hidden, popup handles everything)
		if reward_popup:
			reward_popup.show_reward(
				_coin_icon,
				"Coin",
				"Currency used for upgrades and trade.",
				minigame_id
			)
		else:
			# Fallback if no popup
			_finalize_minigame_completion(minigame_id, success)
	else:
		# Failed - proceed normally without popup
		_finalize_minigame_completion(minigame_id, success)


func _on_reward_popup_closed() -> void:
	if not _pending_minigame_result.is_empty():
		var minigame_id = _pending_minigame_result.get("minigame_id", "")
		var success = _pending_minigame_result.get("success", false)
		_pending_minigame_result.clear()
		_finalize_minigame_completion(minigame_id, success)
	elif not _pending_shop_purchase.is_empty():
		# Shop purchase popup closed - just clear the pending data
		# Shop panel is still open, player can continue shopping
		_pending_shop_purchase.clear()


func _finalize_minigame_completion(minigame_id: String, success: bool) -> void:
	_minigame_active = false
	card_ui.set_input_blocked(false)

	# Notify deck of minigame result
	deck.on_minigame_completed(minigame_id, success)

	# Emit signal for other systems
	EventBus.minigame_completed.emit(minigame_id, success)

	# Draw the next card (result card)
	_on_request_deck_draw()


func _on_skill_check_completed(success: bool) -> void:
	_handle_minigame_completed("skill_check", success)


func _on_radio_frequency_completed(success: bool) -> void:
	_handle_minigame_completed("radio_frequency", success)


func _on_generator_heat_completed(success: bool) -> void:
	_handle_minigame_completed("generator_heat", success)


func _on_pipe_patch_completed(success: bool) -> void:
	_handle_minigame_completed("pipe_patch", success)


func _on_snow_clear_completed(success: bool) -> void:
	_handle_minigame_completed("snow_clear", success)


# ===== Shop Handling =====
func _on_shop_requested(_card_id: String) -> void:
	if shop_panel:
		_shop_active = true
		card_ui.set_input_blocked(true)
		shop_panel.show_shop()


func _on_shop_item_purchased(item_id: String, item_data: Dictionary) -> void:
	# Store purchase for after popup closes
	_pending_shop_purchase = {
		"item_id": item_id,
		"item_data": item_data
	}

	# Show reward popup for purchased item
	if reward_popup:
		var icon_path = item_data.get("icon", "")
		var icon: Texture2D = null
		if icon_path != "" and FileAccess.file_exists(icon_path):
			icon = load(icon_path)
		else:
			icon = _coin_icon  # Fallback

		reward_popup.show_reward(
			icon,
			item_data.get("name", "Item"),
			item_data.get("description", "You purchased an item."),
			"shop_purchase"
		)


func _on_shop_closed() -> void:
	_shop_active = false
	card_ui.set_input_blocked(false)
	EventBus.shop_closed.emit()
	_on_request_deck_draw()


func _on_item_use_requested(item_id: String) -> void:
	if not item_manager:
		return

	var result = item_manager.use_item(item_id)
	if result.get("success", false):
		var item_data = item_manager.get_item_data(item_id)
		var message = result.get("message", "Item used")
		reward_ui.play_notification(message)

		if result.get("effect_type", "") == "prevent_death":
			_chief_token_active = true
			survived_days.set_token_active(true)


# ===== Art Sequence & Ending Handling =====
func _set_game_ui_visible(is_visible: bool) -> void:
	# Background panels (children 0 and 1 of Container_UI)
	var container = card_ui.get_parent()
	if container.get_child_count() > 0:
		container.get_child(0).visible = is_visible  # PanelContainer (bg texture)
	if container.get_child_count() > 1:
		container.get_child(1).visible = is_visible  # Panel (overlay)
	card_ui.visible = is_visible
	stats_ui.visible = is_visible
	survived_days.visible = is_visible

func _on_art_sequence_finished(sequence_type: String) -> void:
	_art_sequence_active = false
	card_ui.set_input_blocked(false)

	match sequence_type:
		"intro":
			_set_game_ui_visible(true)
			deck.begin_starter_phase()
			_on_request_deck_draw()
		"mid":
			_on_request_deck_draw()
		"volcano", "oracle", "city":
			_show_ending_death_screen()


func _show_ending_death_screen() -> void:
	var death_day = _current_chief_start_day + survived_days.current_days
	var all_chiefs: Array = _dead_chiefs_history.duplicate()

	# Add current chief as the final entry
	all_chiefs.append({
		"name": chief_manager.current_chief_name,
		"start_day": _current_chief_start_day,
		"death_day": death_day,
		"index": _current_chief_index + 1
	})

	if death_screen:
		death_screen.show_ending_screen(all_chiefs, death_day)


func _on_ending_reset() -> void:
	# Full game reset
	_dead_chiefs_history.clear()
	_current_chief_start_day = 0
	_current_chief_index = 0
	_death_phase = DeathPhase.NONE
	_death_is_storm = false
	_pending_ending_type = ""
	_chief_token_active = false
	survived_days.set_token_active(false)

	# Reset deck completely
	deck.full_reset()
	deck.set_current_chief_index(0)

	# Reset stats and days
	stats.reset_stats()
	survived_days.current_days = 0
	survived_days.total_days = 0
	survived_days.reset_days()

	# Pick a new chief
	chief_manager.pick_random_name()
	survived_days.update_ui(chief_manager.current_chief_name)

	# Update UI
	stats_ui.update_stats(stats.morale, stats.dissent, stats.authority, stats.devotion)

	# Restart with intro if available
	if art_sequence and not art_sequence.intro_images.is_empty():
		_art_sequence_active = true
		card_ui.set_input_blocked(true)
		art_sequence.play_sequence("intro")
	else:
		_set_game_ui_visible(true)
		deck.begin_starter_phase()
		_on_request_deck_draw()
