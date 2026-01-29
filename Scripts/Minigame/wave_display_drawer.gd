extends Control
class_name WaveDisplayDrawer

# Colors
const TARGET_WAVE_COLOR := Color(0.2, 0.8, 0.3, 0.6)  # Green, semi-transparent
const PLAYER_WAVE_COLOR := Color(0.9, 0.6, 0.1, 0.9)  # Orange/yellow
const MATCH_WAVE_COLOR := Color(0.2, 1.0, 0.3, 1.0)   # Bright green when matching
const BACKGROUND_COLOR := Color(0.1, 0.1, 0.15, 1.0)
const GRID_COLOR := Color(0.2, 0.2, 0.25, 0.5)

var _minigame: RadioFrequencyMinigame


func _ready() -> void:
	# Get parent minigame reference
	var parent = get_parent()
	while parent and not parent is RadioFrequencyMinigame:
		parent = parent.get_parent()
	_minigame = parent as RadioFrequencyMinigame


func _draw() -> void:
	if not _minigame:
		return

	var rect_size = size

	# Draw background
	draw_rect(Rect2(Vector2.ZERO, rect_size), BACKGROUND_COLOR)

	# Draw grid lines
	_draw_grid(rect_size)

	# Draw center line
	var center_y = rect_size.y / 2.0
	draw_line(Vector2(0, center_y), Vector2(rect_size.x, center_y), GRID_COLOR, 2.0)

	if not _minigame.is_adjusting():
		return

	var wave_time = _minigame.get_wave_time()

	# Draw target wave (behind)
	var target_freq = _minigame.get_target_frequency()
	var target_phase = _minigame.get_target_phase()
	_draw_wave(rect_size, target_freq, target_phase, wave_time, TARGET_WAVE_COLOR, 3.0)

	# Draw player wave (on top)
	var player_freq = _minigame.get_player_frequency()
	var player_phase = _minigame.get_player_phase()

	# Check if matching for color (use minigame's threshold)
	var threshold = _minigame.get_match_threshold()
	var freq_diff = abs(player_freq - target_freq)
	var phase_diff = abs(player_phase - target_phase)
	var is_matching = freq_diff <= threshold and phase_diff <= threshold

	# When matching, snap player wave visually to target for clean alignment
	var draw_freq = target_freq if is_matching else player_freq
	var draw_phase = target_phase if is_matching else player_phase

	var player_color = MATCH_WAVE_COLOR if is_matching else PLAYER_WAVE_COLOR
	_draw_wave(rect_size, draw_freq, draw_phase, wave_time, player_color, 2.0)


func _draw_grid(rect_size: Vector2) -> void:
	# Vertical grid lines
	var grid_spacing = 30.0
	var x = grid_spacing
	while x < rect_size.x:
		draw_line(Vector2(x, 0), Vector2(x, rect_size.y), GRID_COLOR, 1.0)
		x += grid_spacing

	# Horizontal grid lines
	var y = grid_spacing
	while y < rect_size.y:
		draw_line(Vector2(0, y), Vector2(rect_size.x, y), GRID_COLOR, 1.0)
		y += grid_spacing


func _draw_wave(rect_size: Vector2, frequency: float, phase: float, time: float, color: Color, line_width: float) -> void:
	var points: PackedVector2Array = []
	var center_y = rect_size.y / 2.0
	var amplitude = rect_size.y * 0.35  # Wave amplitude

	# Map frequency (0-1) to actual wave frequency (cycles across display)
	var wave_freq = 2.0 + frequency * 6.0  # 2 to 8 cycles

	# Map phase (0-1) to radians
	var phase_offset = phase * TAU

	# Time-based animation offset
	var time_offset = time * 2.0

	# Generate wave points
	var step = 2.0  # Pixel step
	var x = 0.0
	while x <= rect_size.x:
		var normalized_x = x / rect_size.x
		var angle = normalized_x * wave_freq * TAU + phase_offset + time_offset
		var y = center_y + sin(angle) * amplitude
		points.append(Vector2(x, y))
		x += step

	# Draw the wave as connected lines
	if points.size() > 1:
		draw_polyline(points, color, line_width, true)
