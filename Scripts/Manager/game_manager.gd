extends Node2D
class_name GameManager
@onready var deck: Deck = %Deck

@onready var stats: StatsManager = $StatsManager
@onready var card_ui: CardUI = %Card_UI
@onready var stats_ui: StatsUI = %StatsUI
@onready var survived_days: SurvivedDaysUI = %SurvivedDays

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


func _ready() -> void:
	card_ui.request_deck_draw.connect(_on_request_deck_draw)
	card_ui.card_effect_committed.connect(_on_card_effect_committed)
	stats.stats_changed.connect(_on_stats_changed)
	stats.stat_threshold_reached.connect(_on_stat_threshold_reached)
	card_ui.card_count_reached.connect(_on_card_count_reach)

	deck.set_current_chief_index(_current_chief_index)
	await deck.load_from_file("res://Json/frozeign.json")

	deck.begin_starter_phase()   # show Pool:"Starter" cards first
	_on_request_deck_draw()


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
	stats.apply_effects(effect)

	var card_id := String(effect.get("card_id", ""))
	var original_side := String(effect.get("original_side", ""))

	if card_id != "" and original_side != "":
		# Deck JSON'daki orijinal LEFT/RIGHT'a göre karar verecek
		deck.on_card_committed(card_id, original_side)

	if _death_phase == DeathPhase.GAME_OVER:
		_soft_reset_game()


func _on_stats_changed(h: int, d: int, o: int, f: int) -> void:
	stats_ui.update_stats(h, d, o, f)


func _on_card_count_reach() -> void:
	survived_days.on_day_survive()


func _on_stat_threshold_reached(stat_name: String, value: int) -> void:
	if _death_phase != DeathPhase.NONE:
		return

	_death_phase = DeathPhase.EXPLANATION_NEXT
	_death_stat = stat_name
	_death_value = value


func _get_death_card_id() -> String:
	var upper := _death_stat.to_upper()
	var t := 0
	if _death_value >= 100:
		t = 100
	return "DEATH_%s_%d" % [upper, t]


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


func _soft_reset_game() -> void:
	_death_phase = DeathPhase.NONE
	_death_stat = ""
	_death_value = 0

	_current_chief_index += 1
	deck.set_current_chief_index(_current_chief_index)

	stats.reset()
	deck.reset_deck()
	survived_days.reset()
	card_ui.reset()

	deck.begin_starter_phase()  # new chief intro
	_on_request_deck_draw()
