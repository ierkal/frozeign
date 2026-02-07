extends Control
class_name HomeMenuUI

# Paneller (Hiyerarşide PanelContainer altındaki sahneler)
@onready var home_panel: HomeUI = %HomeUI
@onready var quest_ui: QuestUI = %QuestUI
@onready var npc_ui: NpcUI = %NpcUI
@onready var settings_panel: Control = %SettingsUI

# Butonlar
@onready var home_button: Button = %Home
@onready var settings_button: Button = %Settings
@onready var close_button: Button = %CloseBtn # Kapatma butonu
var game_manager: GameManager

func _ready() -> void:
	# Buton Sinyal Bağlantıları
	home_button.pressed.connect(_on_home_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	
	if close_button:
		close_button.pressed.connect(hide)
	if home_panel:
		home_panel.quest_menu_requested.connect(_on_quest_menu_requested)
		home_panel.npc_panel_requested.connect(_on_npc_panel_requested)
	# Global event dinleyicisi
	EventBus.home_menu_requested.connect(show_menu)	
	# ÖNEMLİ: Başlangıçta tüm panelleri kapatıp sadece Home'u açıyoruz
	# Bu işlem editördeki açık kalmış 'visible' ayarlarını temizler
	_switch_tab(home_panel)
	hide()

func show_menu() -> void:
	show()
	_refresh_current_view()

# Bu fonksiyonu GameManager çağıracak (Dependency Injection)
func setup(gm: GameManager) -> void:
	game_manager = gm

	# QuestUI bağlantısını burada güvenle yapabiliriz
	if quest_ui and game_manager:
		if not quest_ui.need_quest_data.is_connected(game_manager._on_ui_needs_quest_data):
			quest_ui.need_quest_data.connect(game_manager._on_ui_needs_quest_data)

	# NpcUI bağlantısı
	if npc_ui and game_manager:
		if not npc_ui.need_npc_data.is_connected(game_manager._on_ui_needs_npc_data):
			npc_ui.need_npc_data.connect(game_manager._on_ui_needs_npc_data) 

func _refresh_current_view() -> void:
	# Artık arama yapmıyoruz, enjekte edilen değişkeni kullanıyoruz
	if not game_manager:
		return

	if home_panel.visible:
		home_panel.refresh_data(game_manager)

	if quest_ui.visible:
		quest_ui.need_quest_data.emit()
		
func _switch_tab(target_tab: Control) -> void:
	# 1. ADIM: Tüm panelleri istisnasız kapatıyoruz.
	# Bu, Remote panelde gördüğün çakışmayı engeller.
	home_panel.hide()
	if settings_panel:
		settings_panel.hide()
	
	# 2. ADIM: Sadece hedef paneli görünür yapıyoruz.
	if target_tab:
		target_tab.show()
	
	# 3. ADIM: Veriyi tazeliyoruz.
	_refresh_current_view()
# Buton Fonksiyonları
func _on_home_button_pressed() -> void:
	_switch_tab(home_panel)

func _on_settings_button_pressed() -> void:
	_switch_tab(settings_panel)

func _on_quest_menu_requested() -> void:
	quest_ui.show()
	quest_ui.need_quest_data.emit()

func _on_npc_panel_requested() -> void:
	npc_ui.show()
	npc_ui.need_npc_data.emit()
