extends Node
class_name CardAnimator

signal thrown_finished

@export var cfg: CardConfig
var _tween: Tween = null

func _kill():
	if _tween:
		_tween.kill()
		_tween = null

func flip(target: Control) -> void:
	_kill()
	_tween = target.create_tween()
	_tween.tween_property(target, "scale:x", 0.0, cfg.flip_duration)
	_tween.tween_property(target, "scale:x", 1.0, cfg.flip_duration)

func reset_transform(target: Control, original_pos: Vector2) -> void:
	_kill()
	target.position = original_pos
	target.rotation = 0.0

func throw_out(target: Control, decided_side: String, original_pos: Vector2) -> void:
	_kill()
	_tween = target.create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_IN)

	var dir := 1
	if decided_side == CardConfig.SIDE_LEFT:
		dir = -1

	var target_x := target.position.x + (cfg.throw_distance * dir)
	var target_rot := target.rotation + (PI * float(dir))

	_tween.tween_property(target, "position:x", target_x, cfg.throw_duration)
	_tween.tween_property(target, "position:y", target.position.y - cfg.position_threshold, cfg.throw_duration)
	_tween.tween_property(target, "rotation", target_rot, cfg.throw_duration)
	_tween.tween_property(target, "modulate:a", 0.0, cfg.throw_duration)
	_tween.chain().tween_callback(func(): thrown_finished.emit())
