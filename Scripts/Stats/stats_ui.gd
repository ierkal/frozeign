extends Control
class_name StatsUI

# --- BARLAR ---
@onready var morale: TextureProgressBar = %Morale
@onready var dissent: TextureProgressBar = %Dissent
@onready var authority: TextureProgressBar = %Authority
@onready var devotion: TextureProgressBar = %Devotion

# --- NOKTALAR (Kart Önizlemesi İçin) ---
# Bunlar sadece oyuncu kartı sürüklerken "bak burası etkilenecek" demek için
@onready var morale_point: TextureRect = %MoralePoint
@onready var dissent_point: TextureRect = %DissentPoint
@onready var authority_point: TextureRect = %AuthorityPoint
@onready var devotion_point: TextureRect = %DevotionPoint

# --- OKLAR (Buff/Debuff Durumu İçin) ---
# Bunlar "şu an üzerinde bir etki var" demek için (Yeni eklediklerin)
@onready var morale_arrow: TextureRect = %MoraleArrow
@onready var dissent_arrow: TextureRect = %DissentArrow
@onready var authority_arrow: TextureRect = %AuthorityArrow
@onready var devotion_arrow: TextureRect = %DevotionArrow

# --- AYARLAR ---
@export var arrow_up_texture: Texture2D 
@export var arrow_down_texture: Texture2D

var color_positive := Color("00b140") # Yeşil (İyi durum)
var color_negative := Color("e74c3c") # Kırmızı (Kötü durum)

var _tweens := {}
var _color_tweens := {}
var _base_tint := {}

func _ready() -> void:
	add_to_group("StatsUI")
	_store_default_tint(morale)
	_store_default_tint(dissent)
	_store_default_tint(authority)
	_store_default_tint(devotion)

	# Başlangıç temizliği
	clear_preview() # Noktaları gizle
	_reset_arrows() # Okları gizle

	# Buff sistemini dinle
	EventBus.active_buff_modifiers_changed.connect(_on_buff_modifiers_changed)

	# Apply safe area for mobile notch handling
	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)

func _store_default_tint(bar: TextureProgressBar) -> void:
	_base_tint[bar] = bar.tint_progress


func _apply_safe_area() -> void:
	# Get screen size and safe area
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()

	# Calculate top inset (for notch at top)
	var top_inset := safe_area.position.y

	# Get viewport size for proper scaling
	var viewport_size := get_viewport_rect().size

	# Scale inset to viewport coordinates
	var scale_y := viewport_size.y / float(screen_size.y) if screen_size.y > 0 else 1.0
	var scaled_top := top_inset * scale_y

	# Push down from top to avoid notch
	#offset_top = scaled_top

# --------------------------------------------------------
# 1. BÖLÜM: PREVIEW SİSTEMİ (NOKTALAR)
# Oyuncu kartı sağa sola çektiğinde çalışır
# --------------------------------------------------------
func show_preview(effect: Dictionary) -> void:
	# Noktaları göster (Sadece etki varsa)
	morale_point.visible = effect.has("Morale") and effect["Morale"] != 0
	dissent_point.visible = effect.has("Dissent") and effect["Dissent"] != 0
	authority_point.visible = effect.has("Authority") and effect["Authority"] != 0
	devotion_point.visible = effect.has("Devotion") and effect["Devotion"] != 0

func clear_preview() -> void:
	morale_point.visible = false
	dissent_point.visible = false
	authority_point.visible = false
	devotion_point.visible = false

# --------------------------------------------------------
# 2. BÖLÜM: BUFF SİSTEMİ (OKLAR)
# Buff başladığında veya bittiğinde çalışır
# --------------------------------------------------------
func _reset_arrows() -> void:
	if morale_arrow: morale_arrow.visible = false
	if dissent_arrow: dissent_arrow.visible = false
	if authority_arrow: authority_arrow.visible = false
	if devotion_arrow: devotion_arrow.visible = false

func _on_buff_modifiers_changed(effects: Dictionary) -> void:
	# Morale, Authority, Devotion: Normal mantık (Artış iyi, Azalış kötü)
	# Dissent: Ters mantık (Artış kötü, Azalış iyi)

	_update_arrow(morale_arrow, effects.get("Morale", 0), false)
	_update_arrow(dissent_arrow, effects.get("Dissent", 0), true)
	_update_arrow(authority_arrow, effects.get("Authority", 0), false)
	_update_arrow(devotion_arrow, effects.get("Devotion", 0), false)

func _update_arrow(arrow: TextureRect, value: int, is_inverse_stat: bool) -> void:
	if not arrow: return
	
	# Eğer etki yoksa (0 ise) oku gizle
	if value == 0:
		arrow.visible = false
		return
	
	arrow.visible = true
	
	# --- A. TEXTURE AYARI (Yön) ---
	# Değer pozitifse Yukarı, negatifse Aşağı
	if value > 0:
		arrow.texture = arrow_up_texture
	else:
		arrow.texture = arrow_down_texture
		
	# --- B. RENK AYARI (İyi mi Kötü mü?) ---
	var is_good_effect: bool
	
	if is_inverse_stat:
		# Dissent için: Azalması (-) iyidir (Yeşil), Artması (+) kötüdür (Kırmızı)
		is_good_effect = (value < 0)
	else:
		# Diğerleri için: Artması (+) iyidir (Yeşil), Azalması (-) kötüdür (Kırmızı)
		is_good_effect = (value > 0)
	
	if is_good_effect:
		arrow.modulate = color_positive
	else:
		arrow.modulate = color_negative

# --------------------------------------------------------
# 3. BÖLÜM: UPDATE & ANIMATION (BARLAR)
# --------------------------------------------------------
func update_stats(h: int, d: int, o: int, f: int) -> void:
	apply_stat_change(morale, h)
	apply_stat_change(dissent, d)
	apply_stat_change(authority, o)
	apply_stat_change(devotion, f)

func apply_stat_change(bar: TextureProgressBar, new_value: int) -> void:
	var clamped_value = clamp(new_value, int(bar.min_value), int(bar.max_value))
	var old_value := int(bar.value)

	if clamped_value == old_value:
		return

	flash_change(bar, old_value, clamped_value)
	animate_bar(bar, clamped_value)

func animate_bar(bar: TextureProgressBar, target: int, duration: float = 0.35) -> void:
	if _tweens.has(bar) and _tweens[bar].is_valid():
		_tweens[bar].kill()

	var tween := get_tree().create_tween()
	tween.tween_property(bar, "value", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[bar] = tween

func flash_change(bar: TextureProgressBar, old_val: int, new_val: int) -> void:
	if _color_tweens.has(bar) and _color_tweens[bar].is_valid():
		_color_tweens[bar].kill()

	# Önce rengi orijinal haline (base_tint) döndürelim ki üst üste binmesin
	bar.tint_progress = _base_tint[bar]
	var base_color = _base_tint[bar]

	# Değişim İYİ mi KÖTÜ mü?
	var is_good_change: bool = false
	
	if bar == dissent:
		# Dissent için: AZALMASI (new < old) İYİDİR
		is_good_change = (new_val < old_val)
	else:
		# Morale, Authority, Devotion için: ARTMASI (new > old) İYİDİR
		is_good_change = (new_val > old_val)

	# Rengi seç
	var target_flash_color = color_positive if is_good_change else color_negative
	
	# Barın rengini anında flaş rengine çek
	bar.tint_progress = target_flash_color

	# Yavaşça orijinal rengine (base_color) geri tween et
	var tween := get_tree().create_tween()
	tween.tween_property(bar, "tint_progress", base_color, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_color_tweens[bar] = tween