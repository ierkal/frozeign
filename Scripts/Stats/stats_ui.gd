extends Control
class_name StatsUI

@onready var hope: TextureProgressBar = %Hope
@onready var discontent: TextureProgressBar = %Discontent
@onready var order: TextureProgressBar = %Order
@onready var faith: TextureProgressBar = %Faith

@onready var hope_point: TextureRect = %HopePoint
@onready var discontent_point: TextureRect = %DiscontentPoint
@onready var order_point: TextureRect = %OrderPoint
@onready var faith_point: TextureRect = %FaithPoint

var _tweens := {}          # value tweens
var _color_tweens := {}    # color tweens
var _base_tint := {}       # default fill tints per bar

func _ready() -> void:
	add_to_group("StatsUI")
	_store_default_tint(hope)
	_store_default_tint(discontent)
	_store_default_tint(order)
	_store_default_tint(faith)
	clear_preview()

func _store_default_tint(bar: TextureProgressBar) -> void:
	_base_tint[bar] = bar.tint_progress

# --------------------------------------------------------
# Smooth bar animation
# --------------------------------------------------------
func animate_bar(bar: TextureProgressBar, target: int, duration: float = 0.35) -> void:
	if _tweens.has(bar) and _tweens[bar].is_valid():
		_tweens[bar].kill()

	var tween := get_tree().create_tween()
	tween.tween_property(bar, "value", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[bar] = tween

# --------------------------------------------------------
# Red/Green flash on FILL image only
# --------------------------------------------------------
func flash_change(bar: TextureProgressBar, old_value: int, new_value: int) -> void:
	if _color_tweens.has(bar) and _color_tweens[bar].is_valid():
		_color_tweens[bar].kill()

	if not _base_tint.has(bar):
		_base_tint[bar] = bar.tint_progress

	var base_color: Color = _base_tint[bar]
	var flash_color: Color = base_color

	if new_value > old_value:
		flash_color = Color(0.3, 1.0, 0.3)  # green-ish
	else:
		if new_value < old_value:
			flash_color = Color(1.0, 0.3, 0.3)  # red-ish
		else:
			return  # no change, no flash

	bar.tint_progress = flash_color

	var tween := get_tree().create_tween()
	tween.tween_property(bar, "tint_progress", base_color, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_color_tweens[bar] = tween

# --------------------------------------------------------
# Public: Update + animate + flash
# --------------------------------------------------------
func update_stats(h: int, d: int, o: int, f: int) -> void:
	apply_stat_change(hope, h)
	apply_stat_change(discontent, d)
	apply_stat_change(order, o)
	apply_stat_change(faith, f)

func apply_stat_change(bar: TextureProgressBar, new_value: int) -> void:
	var clamped_value = clamp(new_value, int(bar.min_value), int(bar.max_value))
	var old_value := int(bar.value)

	if clamped_value == old_value:
		return

	flash_change(bar, old_value, clamped_value)
	animate_bar(bar, clamped_value)

# --------------------------------------------------------
# Preview system
# --------------------------------------------------------
func show_preview(effect: Dictionary) -> void:
	var h = int(effect.get("Hope", 0))
	var d = int(effect.get("Discontent", 0))
	var o = int(effect.get("Order", 0))
	var f = int(effect.get("Faith", 0))

	hope_point.visible = h != 0
	discontent_point.visible = d != 0
	order_point.visible = o != 0
	faith_point.visible = f != 0

func clear_preview() -> void:
	hope_point.visible = false
	discontent_point.visible = false
	order_point.visible = false
	faith_point.visible = false
