extends Button

func _ready() -> void:
	# Fonksiyon ismini de güncelledik
	self.pressed.connect(_on_home_menu_button_pressed)

func _on_home_menu_button_pressed() -> void:
	print("Home menu requested")
	# Yeni sinyali tetikliyoruz
	EventBus.home_menu_requested.emit()