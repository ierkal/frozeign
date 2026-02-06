extends Control
class_name ShopPanel

signal item_purchased(item_id: String, item_data: Dictionary)
signal shop_closed

@onready var close_btn: Button = $CloseBtn
@onready var title_label: Label = %TitleLabel
@onready var items_container: VBoxContainer = %ItemsContainer
@onready var coin_label: Label = %CoinLabel

var _shop_item_scene: PackedScene = preload("res://Scenes/shop_item.tscn")
var _currency_manager: CurrencyManager = null
var _item_manager: ItemManager = null
var _shop_items: Dictionary = {}  # { item_id: ShopItem }

func _ready() -> void:
	hide()
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

func setup(currency_manager: CurrencyManager, item_manager: ItemManager) -> void:
	_currency_manager = currency_manager
	_item_manager = item_manager

	if _currency_manager:
		_currency_manager.coins_changed.connect(_on_coins_changed)

	if _item_manager:
		_item_manager.stock_changed.connect(_on_stock_changed)

func show_shop() -> void:
	_populate_shop()
	_update_coin_display()
	_update_all_affordability()
	show()

func _populate_shop() -> void:
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()

	_shop_items.clear()

	if not _item_manager:
		return

	var items = _item_manager.get_shop_items()
	for item_data in items:
		var shop_item = _shop_item_scene.instantiate() as ShopItem
		items_container.add_child(shop_item)
		shop_item.setup(item_data)
		shop_item.buy_pressed.connect(_on_item_buy_pressed)
		_shop_items[item_data.get("id", "")] = shop_item

func _update_coin_display() -> void:
	if coin_label and _currency_manager:
		coin_label.text = str(_currency_manager.get_coins())

func _update_all_affordability() -> void:
	if not _currency_manager:
		return

	var player_coins = _currency_manager.get_coins()
	for item_id in _shop_items.keys():
		var shop_item = _shop_items[item_id]
		if shop_item and is_instance_valid(shop_item):
			shop_item.update_affordability(player_coins)

func _on_coins_changed(new_amount: int) -> void:
	if coin_label:
		coin_label.text = str(new_amount)
	_update_all_affordability()

func _on_stock_changed(item_id: String, current_stock: int) -> void:
	if _shop_items.has(item_id):
		var shop_item = _shop_items[item_id]
		if shop_item and is_instance_valid(shop_item):
			shop_item.update_stock(current_stock)
			if _currency_manager:
				shop_item.update_affordability(_currency_manager.get_coins())

func _on_item_buy_pressed(item_id: String) -> void:
	if not _currency_manager or not _item_manager:
		return

	# Check stock
	if not _item_manager.is_in_stock(item_id):
		return

	var item_data = _item_manager.get_item_data(item_id)
	var price = item_data.get("price", 0)

	# Check if can afford
	if not _currency_manager.has_coins(price):
		return

	# Process purchase
	if _currency_manager.spend_coins(price):
		_item_manager.purchase_item(item_id)
		item_purchased.emit(item_id, item_data)

func _on_close_pressed() -> void:
	hide()
	shop_closed.emit()
