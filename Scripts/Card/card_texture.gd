extends TextureRect
class_name CardTexture

# --- Tunables (can be exported if you want to tweak from the editor)
const ROTATE_THRESHOLD: int = 180
const ROTATE_SPEED: float = 0.002
const POSITION_THRESHOLD: int = 200
const INPUT_POSITION_THRESHOLD: int = 140
const THROW_DURATION: float = 0.5
const THROW_DISTANCE: float = 1000
const FLIP_DURATION: float = 0.2

# --- Side constants
const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"

signal card_died
signal card_decision(side: String)      # preview started/changed
signal card_idle                        # preview canceled/cleared
signal card_committed(side: String)     # final commit side

var dragging: bool = false
var mouse_offset: float = 0.0
var original_position: Vector2
var mouse_position_x: float = 0.0

var tween: Tween
var is_flipped: bool = false
var is_thrown: bool = false

# Preview/decision state
var _is_deciding: bool = false
var _is_idle: bool = false
var _decided_side: String = ""          # last previewed side

func _ready() -> void:
	original_position = position
	flip_card()
	_set_idle(true)

func _process(_delta: float) -> void:
	if is_thrown:
		return

	if dragging:
		_update_drag()
	else:
		_update_released()

# --------------------
# Input
# --------------------
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_offset = _compute_mouse_offset()
		dragging = true
	elif event is InputEventMouseButton and not event.pressed:
		dragging = false

# --------------------
# Drag logic
# --------------------
func _update_drag() -> void:
	_apply_position_clamped()
	_apply_rotation_from_x()

	if _over_threshold():
		var side := _current_side()
		if not _is_deciding or _decided_side != side:
			_enter_decision(side)
	else:
		if not _is_idle:
			_exit_decision()

func _update_released() -> void:
	if _over_threshold():
		throw_card()
	else:
		reset_card_transform()

# --------------------
# Transform helpers
# --------------------
func _apply_position_clamped() -> void:
	var gx := get_global_mouse_position().x
	mouse_position_x = gx - mouse_offset

	var min_x := original_position.x - float(POSITION_THRESHOLD)
	var max_x := original_position.x + float(POSITION_THRESHOLD)

	var clamped_x = clamp(mouse_position_x, min_x, max_x)
	position.x = clamped_x

func _apply_rotation_from_x() -> void:
	var dx := original_position.x - position.x
	var clamped = clamp(-dx, -float(ROTATE_THRESHOLD), float(ROTATE_THRESHOLD))
	rotation = clamped * ROTATE_SPEED

func reset_card_transform() -> void:
	position = original_position
	rotation = 0.0
	_exit_decision()   # safe/no-op if already idle

func _compute_mouse_offset() -> float:
	return get_global_mouse_position().x - position.x

func _over_threshold() -> bool:
	return abs(position.x - original_position.x) > float(INPUT_POSITION_THRESHOLD)

func _current_side() -> String:
	if position.x > original_position.x:
		return SIDE_RIGHT
	return SIDE_LEFT

# --------------------
# Decision state helpers
# --------------------
func _enter_decision(side: String) -> void:
	_is_deciding = true
	_set_idle(false)
	_decided_side = side
	card_decision.emit(side)

func _exit_decision() -> void:
	_is_deciding = false
	_decided_side = ""
	_set_idle(true)

func _set_idle(v: bool) -> void:
	if _is_idle == v:
		return
	_is_idle = v
	if _is_idle:
		card_idle.emit()

# --------------------
# Flip
# --------------------
func flip_card() -> void:
	_kill_tween()
	tween = create_tween()
	is_flipped = not is_flipped
	_animate_flip_to_scale()

func _animate_flip_to_scale() -> void:
	tween.tween_property(self, "scale:x", 0.0, FLIP_DURATION)
	tween.tween_property(self, "scale:x", 1.0, FLIP_DURATION)

# --------------------
# Throw / commit
# --------------------
func throw_card() -> void:
	if dragging or is_thrown:
		return

	is_thrown = true

	if tween:
		tween.kill()

	# Finalize side from preview; fallback to live direction if none
	if _decided_side == "":
		_decided_side = _current_side()
	card_committed.emit(_decided_side)

	# Stop any preview visuals
	card_idle.emit()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)

	# ✅ Use the decided side for throw direction (not current position)
	var throw_direction := 1
	if _decided_side == "left":
		throw_direction = -1

	var target_x := position.x + (THROW_DISTANCE * throw_direction)
	var target_rotation := rotation + (PI * float(throw_direction))

	tween.tween_property(self, "position:x", target_x, THROW_DURATION)
	tween.tween_property(self, "position:y", position.y - POSITION_THRESHOLD, THROW_DURATION)
	tween.tween_property(self, "rotation", target_rotation, THROW_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, THROW_DURATION)
	tween.chain().tween_callback(on_card_died)


func _side_to_dir(side: String) -> int:
	if side == SIDE_LEFT:
		return -1
	return 1

func _kill_tween() -> void:
	if tween:
		tween.kill()
		tween = null

func on_card_died() -> void:
	card_died.emit()
	queue_free()
