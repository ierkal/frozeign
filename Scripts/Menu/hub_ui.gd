extends Control
class_name HubUI

signal item_use_requested(item_id: String)

enum Tab { INVENTORY, TRADE_ROUTE, UPGRADES }

# Exported icons for tab buttons (set these in the editor)
@export var inventory_icon: Texture2D
@export var trade_route_icon: Texture2D
@export var upgrades_icon: Texture2D

@onready var close_btn: Button = $CloseBtn
@onready var title_label: Label = %TitleLabel
@onready var tab_inventory: Button = %TabInventory
@onready var tab_trade_route: Button = %TabTradeRoute
@onready var tab_upgrades: Button = %TabUpgrades
@onready var content_container: Control = %ContentContainer

# Content panels for each tab
@onready var inventory_content: Control = %InventoryContent
@onready var trade_route_content: Control = %TradeRouteContent
@onready var upgrades_content: Control = %UpgradesContent

# Coin display
@onready var coin_label: Label = %CoinLabel

# Items section
@onready var items_container: VBoxContainer = %ItemsContainer
@onready var items_section: Control = %ItemsSection

var _current_tab: Tab = Tab.INVENTORY
var _currency_manager: CurrencyManager = null
var _item_manager: ItemManager = null
var _inventory_item_scene: PackedScene = preload("res://Scenes/inventory_item.tscn")

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_on_close_button_pressed)
	tab_inventory.pressed.connect(_on_tab_inventory_pressed)
	tab_trade_route.pressed.connect(_on_tab_trade_route_pressed)
	tab_upgrades.pressed.connect(_on_tab_upgrades_pressed)

	_apply_tab_icons()
	_switch_tab(Tab.INVENTORY)
	EventBus.hub_ui_requested.connect(_on_hub_ui_requested)

func setup(currency_manager: CurrencyManager, item_manager: ItemManager = null) -> void:
	_currency_manager = currency_manager
	_item_manager = item_manager
	if _currency_manager:
		_currency_manager.coins_changed.connect(_on_coins_changed)
		_update_coin_display(_currency_manager.get_coins())
	if _item_manager:
		_item_manager.inventory_changed.connect(_on_inventory_changed)

func _on_coins_changed(new_amount: int) -> void:
	_update_coin_display(new_amount)

func _update_coin_display(amount: int) -> void:
	if coin_label:
		coin_label.text = str(amount)

func _apply_tab_icons() -> void:
	if inventory_icon and tab_inventory:
		tab_inventory.icon = inventory_icon
	if trade_route_icon and tab_trade_route:
		tab_trade_route.icon = trade_route_icon
	if upgrades_icon and tab_upgrades:
		tab_upgrades.icon = upgrades_icon

func _on_hub_ui_requested() -> void:
	# Refresh coin display when UI is shown
	if _currency_manager:
		_update_coin_display(_currency_manager.get_coins())
	_update_items_display()
	show()
	_switch_tab(_current_tab)

func _on_inventory_changed() -> void:
	_update_items_display()

func _update_items_display() -> void:
	if not items_container or not _item_manager:
		return

	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()

	var items = _item_manager.get_inventory_items()

	# Show/hide items section based on whether we have items
	if items_section:
		items_section.visible = not items.is_empty()

	for item_data in items:
		var inventory_item = _inventory_item_scene.instantiate() as InventoryItem
		items_container.add_child(inventory_item)
		inventory_item.setup(item_data)
		inventory_item.use_pressed.connect(_on_item_use_pressed)

func _on_item_use_pressed(item_id: String) -> void:
	item_use_requested.emit(item_id)

func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	_update_title()
	_update_tab_styles()
	_update_content_visibility()

func _update_title() -> void:
	if not title_label:
		return
	match _current_tab:
		Tab.INVENTORY:
			title_label.text = "Inventory"
		Tab.TRADE_ROUTE:
			title_label.text = "Trade Route"
		Tab.UPGRADES:
			title_label.text = "Upgrades"

func _update_tab_styles() -> void:
	if not tab_inventory or not tab_trade_route or not tab_upgrades:
		return

	var active_color = GameConstants.Colors.ITEM_ACTIVE
	var inactive_color = Color(0.5, 0.5, 0.5, 1.0)

	tab_inventory.modulate = inactive_color
	tab_trade_route.modulate = inactive_color
	tab_upgrades.modulate = inactive_color

	match _current_tab:
		Tab.INVENTORY:
			tab_inventory.modulate = active_color
		Tab.TRADE_ROUTE:
			tab_trade_route.modulate = active_color
		Tab.UPGRADES:
			tab_upgrades.modulate = active_color

func _update_content_visibility() -> void:
	if inventory_content:
		inventory_content.visible = (_current_tab == Tab.INVENTORY)
	if trade_route_content:
		trade_route_content.visible = (_current_tab == Tab.TRADE_ROUTE)
	if upgrades_content:
		upgrades_content.visible = (_current_tab == Tab.UPGRADES)

func _on_tab_inventory_pressed() -> void:
	if _current_tab != Tab.INVENTORY:
		_switch_tab(Tab.INVENTORY)

func _on_tab_trade_route_pressed() -> void:
	if _current_tab != Tab.TRADE_ROUTE:
		_switch_tab(Tab.TRADE_ROUTE)

func _on_tab_upgrades_pressed() -> void:
	if _current_tab != Tab.UPGRADES:
		_switch_tab(Tab.UPGRADES)

func _on_close_button_pressed() -> void:
	hide()
