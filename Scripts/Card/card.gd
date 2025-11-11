extends Control
class_name Card

signal card_died
signal card_decision(side: String)
signal card_idle
signal card_committed(side: String)

@export var cfg: CardConfig
@onready var card_drag: Control = $CardDrag
@onready var decision: Node = $CardDecision
@onready var card_tweener: Node = $CardTweener


var _original_pos: Vector2
var _thrown := false

func _ready() -> void:
	_original_pos = position
	card_drag.setup(self, _original_pos)
	decision.set_origin_x(_original_pos.x)

	# drag signals
	card_drag.drag_started.connect(_on_drag_started)
	card_drag.drag_updated.connect(_on_drag_updated)
	card_drag.drag_ended.connect(_on_drag_ended)

	# decision signals
	decision.decision_changed.connect(func(side): card_decision.emit(side))
	decision.decision_cleared.connect(func(): card_idle.emit())
	decision.committed.connect(_on_committed)

	# animator finish
	card_tweener.thrown_finished.connect(_on_thrown_finished)

	flip_card() # optional initial flip

func flip_card() -> void:
	card_tweener.flip(self)

func _on_drag_started() -> void:
	# no-op for now; place to start preview fx
	pass

func _on_drag_updated(current_x: float, rot: float) -> void:
	if _thrown:
		return
	var threshold_ok = card_drag.over_input_threshold()
	var side_now = card_drag.current_side()
	decision.on_drag_updated(current_x, rot, threshold_ok, side_now)

func _on_drag_ended() -> void:
	if _thrown:
		return
	var threshold_ok = card_drag.over_input_threshold()
	var side_now = card_drag.current_side()
	if decision.commit_if_threshold(threshold_ok, side_now):
		_throw_with(decision.last_side())
	else:
		card_tweener.reset_transform(self, _original_pos)
		card_idle.emit()

func _throw_with(side: String) -> void:
	if _thrown:
		return
	_thrown = true
	card_committed.emit(side)
	card_idle.emit() # stop any preview fx
	card_tweener.throw_out(self, side, _original_pos)

func _on_committed(side: String) -> void:
	# If other systems want to hook here (audio, vfx), they can.
	pass

func _on_thrown_finished() -> void:
	card_died.emit()
	queue_free()
