extends Control
class_name ShopItem

signal buy_pressed(item_id: String)

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton
@onready var stock_label: Label = %StockLabel

var _item_id: String = ""
var _price: int = 0
var _current_stock: int = 0
var _max_stock: int = 3

func _ready() -> void:
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)

func setup(item_data: Dictionary) -> void:
	_item_id = item_data.get("id", "")
	_price = item_data.get("price", 0)
	_current_stock = item_data.get("current_stock", item_data.get("max_stock", 3))
	_max_stock = item_data.get("max_stock", 3)

	if icon_texture:
		var icon_path = item_data.get("icon", "")
		if icon_path != "" and FileAccess.file_exists(icon_path):
			icon_texture.texture = load(icon_path)

	if name_label:
		name_label.text = item_data.get("name", "Unknown")

	if description_label:
		description_label.text = item_data.get("description", "")

	if price_label:
		price_label.text = str(_price)

	_update_stock_display()

func _update_stock_display() -> void:
	if stock_label:
		stock_label.text = "Stock: %d/%d" % [_current_stock, _max_stock]
		if _current_stock <= 0:
			stock_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1.0))
		else:
			stock_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))

func update_stock(new_stock: int) -> void:
	_current_stock = new_stock
	_update_stock_display()
	_update_buy_button_state()

func update_affordability(player_coins: int) -> void:
	_update_buy_button_state(player_coins)

func _update_buy_button_state(player_coins: int = -1) -> void:
	if not buy_button:
		return

	var out_of_stock = _current_stock <= 0
	var cannot_afford = player_coins >= 0 and player_coins < _price

	buy_button.disabled = out_of_stock or cannot_afford

	if out_of_stock:
		buy_button.text = "Sold Out"
		buy_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
	elif cannot_afford:
		buy_button.text = "Buy"
		buy_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		buy_button.text = "Buy"
		buy_button.modulate = Color.WHITE

func get_item_id() -> String:
	return _item_id

func get_price() -> int:
	return _price

func is_in_stock() -> bool:
	return _current_stock > 0

func _on_buy_pressed() -> void:
	buy_pressed.emit(_item_id)
