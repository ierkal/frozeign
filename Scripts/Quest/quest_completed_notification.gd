extends Control

@onready var label = $Label # Şeridin içindeki yazı alanı


func _ready() -> void:
	# Script başladığında merkezi ayarları yapalım
	# Pivot'u tam orta nokta yapıyoruz ki büyüme/küçülme merkezden olsun
	pivot_offset = size / 2
	
	# Başlangıçta görünmez ve ekranın yukarısında (yukarıdaki anchor dışı)
	modulate.a = 0
	hide()

func play_notification(text: String) -> void:
	label.text = text
	show()
	
	# Ekran boyutunu alıyoruz
	var screen_size = get_viewport_rect().size
	
	# Hedef noktamız ekranın tam ortası (Vector2(0.5, 0.5) anchor karşılığı)
	# Ancak Control düğümünün pozisyonu sol üst köşedir, bu yüzden size/2 çıkartıyoruz
	var target_pos = (screen_size / 2) - (size / 2)
	
	# Başlangıç pozisyonu: Ekranın üstünde, yatayda ortalı
	var start_pos = Vector2(target_pos.x, -size.y)
	position = start_pos

	var tween = create_tween().set_parallel(false)
	
	# 1. ADIM: Tam merkeze kayış (TRANS_BACK ile hafif sekme efekti)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.7)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.4)
	
	# 2. ADIM: 2 Saniye Bekle
	tween.tween_interval(2.0)
	
	# 3. ADIM: Yukarı geri fırlat (TRANS_SINE ile yumuşak çıkış)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", -size.y, 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	
	tween.tween_callback(hide)