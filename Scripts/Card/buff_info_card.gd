extends Control
class_name BuffInfoCard

signal card_died
signal card_decision(side: String)
signal card_idle
signal card_committed(side: String)

@export var cfg: CardConfig

@onready var card_drag: Control = $CardDrag
@onready var decision: Node = $CardDecision
@onready var card_tweener: Node = $CardTweener
@onready var card_texture: TextureRect = $CardTexture
@onready var content_container: VBoxContainer = $CardTexture/ContentContainer
@onready var icon_texture: TextureRect = %Icon
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel

var _original_pos: Vector2
var _thrown := false


func _ready() -> void:
	_original_pos = position
	card_drag.setup(self, _original_pos)
	decision.set_origin_x(_original_pos.x)

	card_drag.drag_started.connect(_on_drag_started)
	card_drag.drag_updated.connect(_on_drag_updated)
	card_drag.drag_ended.connect(_on_drag_ended)

	decision.decision_changed.connect(func(side): card_decision.emit(side))
	decision.decision_cleared.connect(func(): card_idle.emit())
	decision.committed.connect(_on_committed)

	card_tweener.thrown_finished.connect(_on_thrown_finished)
	card_tweener.flip_finished.connect(_on_flip_finished)

	flip_card()


func setup_buff_info(buff_data: Dictionary) -> void:
	if buff_data.has("title"):
		title_label.text = buff_data["title"]
	if buff_data.has("description"):
		description_label.text = buff_data["description"]
	if buff_data.has("icon_path") and buff_data["icon_path"] != "":
		var icon = load(buff_data["icon_path"])
		if icon:
			icon_texture.texture = icon
	


func flip_card() -> void:
	card_drag.set_input_enabled(false)
	card_tweener.flip(self)


func _on_flip_finished() -> void:
	card_drag.set_input_enabled(true)
	if content_container:
		content_container.visible = true


func _on_drag_started() -> void:
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
	card_idle.emit()
	card_tweener.throw_out(self, side, _original_pos)


func _on_committed(side: String) -> void:
	pass


func _on_thrown_finished() -> void:
	card_died.emit()
	queue_free()
