extends Node2D
class_name GameManager
@onready var deck: Deck = %Deck

@onready var stats: StatsManager = $StatsManager
@onready var card_ui: CardUI = %Card_UI
@onready var stats_ui: StatsUI = %StatsUI
@onready var survived_days: SurvivedDaysUI = %SurvivedDays
@onready var quest_manager: QuestManager = %QuestManager
@onready var quest_ui: QuestUI = %QuestUI    
var _last_card_had_effect: bool = false

enum DeathPhase {
	NONE,
	EXPLANATION_NEXT,
	FINAL_NEXT,
	GAME_OVER
}

var _death_phase: int = DeathPhase.NONE
var _death_stat: String = ""
var _death_value: int = 0
var _current_chief_index: int = 0   # Number of chiefs so far

@onready var reward_ui = %QuestCompletedNotification

func _ready() -> void:
	quest_manager.quest_reward_triggered.connect(_on_quest_reward_triggered)
	card_ui.request_deck_draw.connect(_on_request_deck_draw)
	card_ui.card_effect_committed.connect(_on_card_effect_committed)
	stats.stats_changed.connect(_on_stats_changed)
	stats.stat_threshold_reached.connect(_on_stat_threshold_reached)
	card_ui.card_count_reached.connect(_on_card_count_reach)

	deck.set_current_chief_index(_current_chief_index)
	await deck.load_from_file("res://Json/frozeign.json")
	if quest_ui:
		quest_ui.need_quest_data.connect(_on_ui_needs_quest_data)
	deck.begin_starter_phase()   # show Pool:"Starter" cards first
	_on_request_deck_draw()

func _on_quest_reward_triggered(text: String) -> void:
	reward_ui.play_notification(text)

func _on_request_deck_draw() -> void:
	# Death explanation phase 1
	if _death_phase == DeathPhase.EXPLANATION_NEXT:
		var death_id := _get_death_card_id()
		var raw = deck.find_card_by_id(death_id)
		if raw.is_empty():
			push_error("Missing death card: %s" % death_id)
		else:
			var presented = deck.prepare_presented(raw)
			card_ui.receive_presented_card(presented)
			_death_phase = DeathPhase.FINAL_NEXT
			return

	# Death final card
	if _death_phase == DeathPhase.FINAL_NEXT:
		var final_card := _build_final_death_card()
		card_ui.receive_presented_card(final_card)
		_death_phase = DeathPhase.GAME_OVER
		return

	# Normal draw
	var raw = deck.draw()
	var presented = deck.prepare_presented(raw)
	card_ui.receive_presented_card(presented)



func _on_card_effect_committed(effect: Dictionary) -> void:
	_last_card_had_effect = false
	var stats_keys = ["Hope", "Discontent", "Order", "Faith"]
	
	for key in stats_keys:
		if effect.has(key) and effect[key] != 0:
			_last_card_had_effect = true
			break
	
	stats.apply_effects(effect)

	var card_id := String(effect.get("card_id", ""))
	var original_side := String(effect.get("original_side", ""))

	if card_id != "" and original_side != "":
		deck.on_card_committed(card_id, original_side)

	if _death_phase == DeathPhase.GAME_OVER:
		_soft_reset_game()


func _on_stats_changed(h: int, d: int, o: int, f: int) -> void:
	stats_ui.update_stats(h, d, o, f)

func _on_card_count_reach() -> void:
	if _last_card_had_effect:
		survived_days.on_day_survive()

func _on_stat_threshold_reached(stat_name: String, value: int) -> void:
	if _death_phase != DeathPhase.NONE:
		return

	_death_phase = DeathPhase.EXPLANATION_NEXT
	_death_stat = stat_name
	_death_value = value


func _get_death_card_id() -> String:
	var upper := _death_stat.to_upper()
	var suffix := "LOW"
	if _death_value > 100:
		suffix = "HIGH"
	return "DEATH_%s_%s" % [upper, suffix]


func _build_final_death_card() -> Dictionary:
	var no_eff := {
		"text": "",
		"Hope": 0,
		"Discontent": 0,
		"Order": 0,
		"Faith": 0
	}

	return {
		"id": "DEATH_FINAL",
		"title": "",
		"desc": "",
		"left": no_eff,
		"right": no_eff
	}


# Scripts/Manager/game_manager.gd

func _soft_reset_game() -> void:
	_current_chief_index += 1 # Yeni lider geliyor
	_death_phase = DeathPhase.NONE
	
	# İstatistikleri sıfırla
	stats.reset_stats() # Varsayılan değerlere dön (stats_manager içinde olmalı)
	if survived_days:
		survived_days.reset_days()
	if _current_chief_index <= 1:
		deck.begin_starter_phase()
	else:
		_on_request_deck_draw()
	# Desteyi sıfırla ama kilitli havuzları açma!
	deck.set_current_chief_index(_current_chief_index)
	deck.soft_reset_deck() # Yeni yazdığımız fonksiyon
	
	# UI'ı güncelle
	stats_ui.update_stats(stats.hope, stats.discontent, stats.order, stats.faith)
	
	# Yeni liderle ilk kartı çek
	_on_request_deck_draw()

func _on_ui_needs_quest_data() -> void:
	if quest_manager and quest_ui:
	# Yeni fonksiyonu çağırıyoruz
		var display_list = quest_manager.get_quest_display_data()
		quest_ui.show_quests(display_list)
