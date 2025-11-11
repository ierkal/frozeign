extends Node2D
class_name GameManager

@onready var deck: Deck = $Deck
@onready var stats: StatsManager = $StatsManager
@onready var card_ui: CardUI = %Card_UI
@onready var stats_ui: StatsUI = %StatsUI

func _ready() -> void:
	# 1️⃣ CardUI wants a card
	card_ui.request_deck_draw.connect(_on_request_deck_draw)
	# 2️⃣ CardUI emits committed effects
	card_ui.card_effect_committed.connect(_on_card_effect_committed)
	# 3️⃣ StatsManager notifies stat changes
	stats.stats_changed.connect(_on_stats_changed)

	await deck.load_from_file("res://Json/frozeign.json")
	_on_request_deck_draw()  # draw the first card

func _on_request_deck_draw() -> void:
	var raw := deck.draw()
	var presented := deck.prepare_presented(raw)
	card_ui.receive_presented_card(presented)

func _on_card_effect_committed(effect: Dictionary) -> void:
	stats.apply_effects(effect)

func _on_stats_changed(h, d, ho, s) -> void:
	stats_ui.update_stats(h, d, ho, s)

	
