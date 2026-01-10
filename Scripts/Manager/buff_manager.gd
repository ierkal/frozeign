class_name BuffManager
extends Node

var active_buffs: Dictionary = {}
var buff_database: Dictionary = {}
var _deck: Deck

# Sadece Deck referansı yeterli, EventBus globaldir.
func setup(deck_ref: Deck) -> void:
	_deck = deck_ref
	_load_database()
	
	# Deck üzerindeki mevcut sinyali dinle
	if _deck.has_signal("flag_added_signal"):
		_deck.flag_added_signal.connect(_on_flag_added)

func on_turn_passed() -> void:
	var finished_buffs: Array = []
	for id in active_buffs:
		var buff = active_buffs[id]
		if buff.type == "timed":
			buff.duration_left -= 1
			if buff.duration_left <= 0:
				finished_buffs.append(id)
	
	for id in finished_buffs:
		_end_buff(id)

func _on_flag_added(flag_name: String) -> void:
	for buff_key in buff_database:
		var data = buff_database[buff_key]
		if data.get("trigger_flag") == flag_name:
			_start_buff(buff_key)

func _start_buff(buff_id: String) -> void:
	if active_buffs.has(buff_id): return
	
	var data = buff_database[buff_id]
	var new_buff = ActiveBuff.new(data, buff_id) # ActiveBuff sınıfın varsa
	active_buffs[buff_id] = new_buff
	
	# Global EventBus kullanımı
	EventBus.buff_started.emit(new_buff)
	
	if new_buff.intro_card_id != "" and _deck:
		_deck.force_next_card(new_buff.intro_card_id)
	
	_broadcast_effects()

func _end_buff(buff_id: String) -> void:
	if active_buffs.has(buff_id):
		active_buffs.erase(buff_id)
		EventBus.buff_ended.emit(buff_id)
		_broadcast_effects()

func _load_database() -> void:
	var file = FileAccess.open("res://Json/buffs.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			buff_database = json.data

# O anki tur için geçerli toplam stat değişimlerini döndürür
func get_active_stat_modifiers() -> Dictionary:
	var total_effects = {
		"Hope": 0,
		"Discontent": 0,
		"Order": 0,
		"Faith": 0
	}
	
	for buff_key in active_buffs:
		var buff = active_buffs[buff_key] as ActiveBuff
		
		# Buff'ın içindeki etkileri toplama ekle
		for stat_name in buff.effects:
			if total_effects.has(stat_name):
				total_effects[stat_name] += int(buff.effects[stat_name])
				
	return total_effects
	
func _broadcast_effects() -> void:
	var total = get_active_stat_modifiers()
	EventBus.active_buff_modifiers_changed.emit(total)
