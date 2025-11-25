extends Control
class_name StatsUI

@onready var heat: TextureProgressBar = %Heat
@onready var discontent: TextureProgressBar = %Order
@onready var hope: TextureProgressBar = %Hope
@onready var survivors: TextureProgressBar = %Survivors

@onready var heat_point: TextureRect = %HeatPoint
@onready var discontent_point: TextureRect = %OrderPoint
@onready var hope_point: TextureRect = %HopePoint
@onready var survivors_point: TextureRect = %SurvivorsPoint

var _tweens := {}          # value tweens
var _color_tweens := {}    # color tweens
var _base_tint := {}       # default fill tints per bar

func _ready() -> void:
	add_to_group("StatsUI")
	_store_default_tint(heat)
	_store_default_tint(discontent)
	_store_default_tint(hope)
	_store_default_tint(survivors)
	clear_preview()

func _store_default_tint(bar: TextureProgressBar) -> void:
	_base_tint[bar] = bar.tint_progress


# --------------------------------------------------------
# Smooth bar animation (unchanged)
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
func update_stats(h: int, d: int, ho: int, s: int) -> void:
	apply_stat_change(heat, h)
	apply_stat_change(discontent, d)
	apply_stat_change(hope, ho)
	apply_stat_change(survivors, s)

func apply_stat_change(bar: TextureProgressBar, new_value: int) -> void:
	var clamped_value = clamp(new_value, int(bar.min_value), int(bar.max_value))
	var old_value := int(bar.value)

	if clamped_value == old_value:
		return

	flash_change(bar, old_value, clamped_value)
	animate_bar(bar, clamped_value)


# --------------------------------------------------------
# Preview system (unchanged)
# --------------------------------------------------------
func show_preview(effect: Dictionary) -> void:
	var h = int(effect.get("Heat", 0))
	var d = int(effect.get("Discontent", 0))
	var ho = int(effect.get("Hope", 0))
	var s = int(effect.get("Survivors", 0))

	heat_point.visible = h != 0
	discontent_point.visible = d != 0
	hope_point.visible = ho != 0
	survivors_point.visible = s != 0

func clear_preview() -> void:
	heat_point.visible = false
	discontent_point.visible = false
	hope_point.visible = false
	survivors_point.visible = false
