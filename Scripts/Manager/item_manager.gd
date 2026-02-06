extends Node
class_name ItemManager

signal inventory_changed
signal item_used(item_id: String, effect_result: Dictionary)
signal stock_changed(item_id: String, current_stock: int)

var _items_data: Dictionary = {}  # { "item_id": { item_data } }
var _inventory: Dictionary = {}  # { "item_id": count }
var _stock: Dictionary = {}  # { "item_id": current_stock }
var _restock_progress: Dictionary = {}  # { "item_id": cards_since_last_restock }
var _stats_manager: StatsManager = null

func setup(stats_manager: StatsManager) -> void:
	_stats_manager = stats_manager

func load_items_from_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ItemManager: cannot open %s" % path)
		return
	var text := f.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ItemManager: JSON root must be an array")
		return

	for item in parsed:
		var item_id = item.get("id", "")
		if item_id != "":
			_items_data[item_id] = item
			# Initialize stock to max
			var max_stock = item.get("max_stock", 3)
			_stock[item_id] = max_stock
			_restock_progress[item_id] = 0

func get_all_items_data() -> Dictionary:
	return _items_data

func get_item_data(item_id: String) -> Dictionary:
	return _items_data.get(item_id, {})

func get_shop_items() -> Array:
	var result: Array = []
	for item_id in _items_data.keys():
		var item = _items_data[item_id].duplicate()
		item["current_stock"] = _stock.get(item_id, 0)
		result.append(item)
	return result

func get_stock(item_id: String) -> int:
	return _stock.get(item_id, 0)

func get_max_stock(item_id: String) -> int:
	var item_data = _items_data.get(item_id, {})
	return item_data.get("max_stock", 3)

func is_in_stock(item_id: String) -> bool:
	return get_stock(item_id) > 0

func purchase_item(item_id: String) -> bool:
	if not is_in_stock(item_id):
		return false

	_stock[item_id] -= 1
	add_item_to_inventory(item_id)
	stock_changed.emit(item_id, _stock[item_id])
	return true

func on_card_swiped() -> void:
	# Called every time a card is swiped to progress restock timers
	for item_id in _items_data.keys():
		var current_stock = _stock.get(item_id, 0)
		var max_stock = get_max_stock(item_id)

		# Only progress if not at max stock
		if current_stock < max_stock:
			_restock_progress[item_id] = _restock_progress.get(item_id, 0) + 1

			var item_data = _items_data.get(item_id, {})
			var restock_cards = item_data.get("restock_cards", 20)

			# Check if we should restock one item
			if _restock_progress[item_id] >= restock_cards:
				_restock_progress[item_id] = 0
				_stock[item_id] = current_stock + 1
				stock_changed.emit(item_id, _stock[item_id])

func add_item_to_inventory(item_id: String, count: int = 1) -> void:
	if not _items_data.has(item_id):
		push_error("ItemManager: Unknown item %s" % item_id)
		return

	if not _inventory.has(item_id):
		_inventory[item_id] = 0
	_inventory[item_id] += count
	inventory_changed.emit()

func remove_item_from_inventory(item_id: String, count: int = 1) -> bool:
	if not _inventory.has(item_id) or _inventory[item_id] < count:
		return false

	_inventory[item_id] -= count
	if _inventory[item_id] <= 0:
		_inventory.erase(item_id)
	inventory_changed.emit()
	return true

func get_inventory_count(item_id: String) -> int:
	return _inventory.get(item_id, 0)

func get_inventory_items() -> Array:
	var result: Array = []
	for item_id in _inventory.keys():
		var item_data = _items_data.get(item_id, {}).duplicate()
		item_data["count"] = _inventory[item_id]
		result.append(item_data)
	return result

func has_items_in_inventory() -> bool:
	return not _inventory.is_empty()

func use_item(item_id: String) -> Dictionary:
	if not _inventory.has(item_id) or _inventory[item_id] <= 0:
		return {"success": false, "message": "Item not in inventory"}

	var item_data = _items_data.get(item_id, {})
	var effect = item_data.get("effect", {})
	var effect_type = effect.get("type", "")

	var result: Dictionary = {"success": true, "item_id": item_id}

	match effect_type:
		"stat_boost":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			if _stats_manager and stat != "":
				_apply_stat_change(stat, value)
				result["stat"] = stat
				result["value"] = value
				result["message"] = "Applied %s %+d" % [stat, value]

		"random_stat_boost":
			var min_val = effect.get("min_value", 5)
			var max_val = effect.get("max_value", 15)
			var value = randi_range(min_val, max_val)
			var stats = ["Morale", "Authority", "Devotion"]
			var random_stat = stats[randi() % stats.size()]
			if _stats_manager:
				_apply_stat_change(random_stat, value)
				result["stat"] = random_stat
				result["value"] = value
				result["message"] = "Applied %s +%d" % [random_stat, value]

		_:
			result["message"] = "Used %s" % item_data.get("name", item_id)

	remove_item_from_inventory(item_id)
	item_used.emit(item_id, result)
	return result

func _apply_stat_change(stat: String, value: int) -> void:
	if not _stats_manager:
		return

	var effect_dict = {}
	effect_dict[stat] = value
	_stats_manager.apply_effects(effect_dict)

func reset() -> void:
	_inventory.clear()
	# Reset stock to max
	for item_id in _items_data.keys():
		var max_stock = get_max_stock(item_id)
		_stock[item_id] = max_stock
		_restock_progress[item_id] = 0
	inventory_changed.emit()
