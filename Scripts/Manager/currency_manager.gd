extends Node
class_name CurrencyManager

signal coins_changed(new_amount: int)

# ===========================================
# DEBUG: Inspector controls for testing
# ===========================================
@export_group("Debug Controls")
@export var debug_coins_to_add: int = 10
@export var debug_add_coins: bool = false:
	set(value):
		if value and not Engine.is_editor_hint():
			add_coins(debug_coins_to_add)
			print("CurrencyManager: Added %d coins (Total: %d)" % [debug_coins_to_add, _coins])
		debug_add_coins = false

var _coins: int = 0

func get_coins() -> int:
	return _coins

func add_coins(amount: int) -> void:
	_coins += amount
	coins_changed.emit(_coins)

func spend_coins(amount: int) -> bool:
	if _coins >= amount:
		_coins -= amount
		coins_changed.emit(_coins)
		return true
	return false

func has_coins(amount: int) -> bool:
	return _coins >= amount

func reset() -> void:
	_coins = 0
	coins_changed.emit(_coins)
