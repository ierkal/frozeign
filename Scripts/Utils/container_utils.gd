class_name ContainerUtils

## Utility class for common container operations.
## Centralizes the repeated "clear children" pattern found across the codebase.

static func clear_children(container: Node) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
