class_name TweenUtils

## Utility class for tween management.
## Centralizes the repeated tween kill pattern found across the codebase.

static func kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
