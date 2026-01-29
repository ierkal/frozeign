extends Control
class_name SafeZoneDrawer

# Colors
const SAFE_ZONE_COLOR := Color(0.2, 0.8, 0.3, 0.8)
const ARC_WIDTH := 20.0

var _minigame: SkillCheckMinigame


func _ready() -> void:
	# Get parent minigame reference
	var parent = get_parent()
	while parent and not parent is SkillCheckMinigame:
		parent = parent.get_parent()
	_minigame = parent as SkillCheckMinigame


func _draw() -> void:
	if not _minigame:
		return

	# Don't draw if safe zone should be hidden
	if not _minigame.is_safe_zone_visible():
		return

	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - ARC_WIDTH / 2.0

	var start_angle = deg_to_rad(_minigame.get_safe_zone_start() - 90.0)  # Offset by -90 to match rotation
	var end_angle = deg_to_rad(_minigame.get_safe_zone_start() + _minigame.get_safe_zone_angle() - 90.0)

	# Draw arc as a series of line segments
	var points := 32
	var angle_step = (end_angle - start_angle) / points

	for i in range(points):
		var angle1 = start_angle + angle_step * i
		var angle2 = start_angle + angle_step * (i + 1)

		var inner_radius = radius - ARC_WIDTH / 2.0
		var outer_radius = radius + ARC_WIDTH / 2.0

		var p1_inner = center + Vector2(cos(angle1), sin(angle1)) * inner_radius
		var p2_inner = center + Vector2(cos(angle2), sin(angle2)) * inner_radius
		var p1_outer = center + Vector2(cos(angle1), sin(angle1)) * outer_radius
		var p2_outer = center + Vector2(cos(angle2), sin(angle2)) * outer_radius

		# Draw as polygon
		draw_polygon(
			PackedVector2Array([p1_inner, p2_inner, p2_outer, p1_outer]),
			PackedColorArray([SAFE_ZONE_COLOR, SAFE_ZONE_COLOR, SAFE_ZONE_COLOR, SAFE_ZONE_COLOR])
		)
