extends Node2D
class_name GameManager

@onready var deck: Deck = $Deck
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

func _ready() -> void:
	card_ui.request_deck_draw.connect(_on_request_deck_draw)
	card_ui.card_effect_committed.connect(_on_card_effect_committed)
	stats.stats_changed.connect(_on_stats_changed)
	stats.stat_threshold_reached.connect(_on_stat_threshold_reached)
	card_ui.card_count_reached.connect(_on_card_count_reach)

	await deck.load_from_file("res://Json/frozeign.json")
	_on_request_deck_draw()

func _on_request_deck_draw() -> void:
	if _death_phase == DeathPhase.EXPLANATION_NEXT:
		var death_id := _get_death_card_id()
		var raw = deck.find_card_by_id(death_id)
		if raw.is_empty():
			push_error("GameManager: death card not found: %s" % death_id)
		else:
			var presented := deck.prepare_presented(raw)
			card_ui.receive_presented_card(presented)
			_death_phase = DeathPhase.FINAL_NEXT
			return

	if _death_phase == DeathPhase.FINAL_NEXT:
		var final_card := _build_final_death_card()
		card_ui.receive_presented_card(final_card)
		_death_phase = DeathPhase.GAME_OVER
		return

	var raw := deck.draw()
	var presented := deck.prepare_presented(raw)
	card_ui.receive_presented_card(presented)

func _on_card_effect_committed(effect: Dictionary) -> void:
	stats.apply_effects(effect)

	if _death_phase == DeathPhase.GAME_OVER:
		_soft_reset_game()
		return

func _on_stats_changed(h, d, ho, s) -> void:
	stats_ui.update_stats(h, d, ho, s)

func _on_card_count_reach() -> void:
	survived_days.on_day_survive()

func _on_stat_threshold_reached(stat_name: String, value: int) -> void:
	if _death_phase != DeathPhase.NONE:
		return

	_death_phase = DeathPhase.EXPLANATION_NEXT
	_death_stat = stat_name
	_death_value = value

func _get_death_card_id() -> String:
	var upper_stat := _death_stat.to_upper()
	var threshold := 0
	if _death_value >= 100:
		threshold = 100
	else:
		threshold = 0

	return "DEATH_%s_%d" % [upper_stat, threshold]

func _build_final_death_card() -> Dictionary:
	var no_effect := {
		"text": "",
		"Heat": 0,
		"Discontent": 0,
		"Hope": 0,
		"Survivors": 0
	}

	var card := {
		"id": "DEATH_FINAL",
		"title": "",
		"desc": "",
		"left": no_effect,
		"right": no_effect
	}

	return card

func _soft_reset_game() -> void:
	_death_phase = DeathPhase.NONE
	_death_stat = ""
	_death_value = 0

	stats.reset()
	deck.reset_deck()
	survived_days.reset()
	card_ui.reset()

	_on_request_deck_draw()
