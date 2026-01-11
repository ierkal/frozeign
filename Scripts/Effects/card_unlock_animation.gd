extends Control
class_name CardUnlockAnimation

@export var card_slot_scene: PackedScene
@export var card_count: int = 5
@export var animation_duration: float = 0.7
@export var spawn_delay: float = 0.1

var _target_control: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_target(target_control: Control) -> void:
	_target_control = target_control


func play_animation() -> void:
	# Get target rect from the texture parent
	var target_rect: Rect2
	var card_size: Vector2

	if _target_control:
		target_rect = _target_control.get_global_rect()
		card_size = target_rect.size
	else:
		var screen_size = get_viewport_rect().size
		card_size = Vector2(200, 300)
		target_rect = Rect2((screen_size - card_size) / 2, card_size)

	# Start from top-left corner (off screen)
	var start_pos = Vector2(-card_size.x - 50, -card_size.y - 50)

	# Center position is the target rect position
	var center_pos = target_rect.position

	for i in range(card_count):
		_spawn_card_with_delay(i, start_pos, center_pos, card_size)


func _spawn_card_with_delay(index: int, start_pos: Vector2, center_pos: Vector2, size: Vector2) -> void:
	await get_tree().create_timer(index * spawn_delay).timeout
	_create_and_animate_card(start_pos, center_pos, size)


func _create_and_animate_card(start_pos: Vector2, center_pos: Vector2, size: Vector2) -> void:
	var card: Control
	if card_slot_scene:
		card = card_slot_scene.instantiate()
	else:
		card = Panel.new()
	card.size = size
	card.position = start_pos
	card.rotation = -0.4
	card.pivot_offset = size / 2
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	# Small random offset from center for each card
	var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	var target = center_pos + offset

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Move card to center
	tween.tween_property(card, "position", target, animation_duration)

	# Rotate to nearly straight
	tween.tween_property(card, "rotation", randf_range(-0.05, 0.05), animation_duration)

	# Fade out after reaching center
	tween.chain().tween_interval(0.15)
	tween.chain().tween_property(card, "modulate:a", 0.0, 0.25)

	# Remove card after animation
	tween.chain().tween_callback(card.queue_free)
