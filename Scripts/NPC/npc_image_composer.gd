extends Node
class_name NpcImageComposer

const PARTS_BASE_PATH := "res://Assets/Sprites/npc/"

# Profession-specific part overrides (hat, body when hired)
const PROFESSION_PARTS := {
	"Foreman": { "hat": "", "body": "" },  # Will be filled when assets exist
	"Steward": { "hat": "", "body": "" },
	"Captain": { "hat": "", "body": "" },
	"Hunter": { "hat": "", "body": "" },
	"Priest": { "hat": "", "body": "" },
	"Inventory Manager": { "hat": "", "body": "" },
	"Guild": { "hat": "", "body": "" },
	"Syndicate": { "hat": "", "body": "" }
}

# Layer order for compositing (back to front)
const LAYER_ORDER := ["body", "face", "nose", "mouth", "eye", "hat"]

# Cached composed images: { "Barnaby": ImageTexture }
var _image_cache: Dictionary = {}

# Reference to NPC generator for getting NPC data
var _npc_generator: NpcGenerator


func setup(generator: NpcGenerator) -> void:
	_npc_generator = generator
	_npc_generator.npc_profession_changed.connect(_on_npc_profession_changed)


func _on_npc_profession_changed(npc_name: String, _profession: String) -> void:
	# Recompose image when profession changes (new hat/body)
	refresh_npc_image(npc_name)


func compose_all_npcs() -> void:
	"""Compose images for all NPCs at game start."""
	if not _npc_generator:
		push_error("NpcImageComposer: No generator set")
		return

	var all_npcs = _npc_generator.get_all_npcs()
	for npc_name in all_npcs.keys():
		compose_npc_image(npc_name)

	print("NpcImageComposer: Composed %d NPC images" % _image_cache.size())


func compose_npc_image(npc_name: String) -> ImageTexture:
	"""Compose an NPC's image from parts and cache it (lazy creation)."""
	if not _npc_generator:
		return null

	# Use get_or_create_npc for lazy generation support
	var npc_data = _npc_generator.get_or_create_npc(npc_name)
	if npc_data.is_empty():
		return null

	var composed = _compose_from_parts(npc_data)
	if composed:
		_image_cache[npc_name] = composed

	return composed


func _compose_from_parts(npc_data: Dictionary) -> ImageTexture:
	"""Layer parts into a single image."""
	var profession = npc_data.get("profession", "")
	var base_image: Image = null
	var base_size := Vector2i(256, 256)  # Default size, will be set by first loaded image

	for layer in LAYER_ORDER:
		var part_name = _get_part_for_layer(npc_data, layer, profession)
		if part_name == "":
			continue

		var part_path = _get_part_path(layer, part_name)
		if not ResourceLoader.exists(part_path):
			continue

		var part_texture = load(part_path) as Texture2D
		if not part_texture:
			continue

		var part_image = part_texture.get_image()
		if not part_image:
			continue

		# Initialize base image with first valid layer
		if base_image == null:
			base_size = part_image.get_size()
			base_image = Image.create(base_size.x, base_size.y, false, Image.FORMAT_RGBA8)
			base_image.fill(Color(0, 0, 0, 0))  # Transparent

		# Resize part if needed
		if part_image.get_size() != base_size:
			part_image.resize(base_size.x, base_size.y)

		# Blend part onto base (alpha compositing)
		_blend_images(base_image, part_image)

	if base_image == null:
		# No parts found, create placeholder
		base_image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		base_image.fill(Color(0.3, 0.3, 0.3, 1.0))

	return ImageTexture.create_from_image(base_image)


func _get_part_for_layer(npc_data: Dictionary, layer: String, profession: String) -> String:
	"""Get the part name for a layer, considering profession overrides."""
	# Check profession override first
	if profession != "" and PROFESSION_PARTS.has(profession):
		var prof_parts = PROFESSION_PARTS[profession]
		if prof_parts.has(layer) and prof_parts[layer] != "":
			return prof_parts[layer]

	# Fall back to NPC's random part
	return npc_data.get(layer, "")


func _get_part_path(layer: String, part_name: String) -> String:
	"""Get the full path to a part image."""
	return PARTS_BASE_PATH + layer + "/" + part_name + ".png"


func _blend_images(base: Image, overlay: Image) -> void:
	"""Blend overlay onto base using Godot's optimized C++ method."""
	# Define the source rectangle (the whole overlay image)
	var src_rect = Rect2i(Vector2i.ZERO, overlay.get_size())
	# Define the destination position (top-left corner)
	var dst_point = Vector2i.ZERO
	
	# This operation is instant compared to GDScript loops
	base.blend_rect(overlay, src_rect, dst_point)

func get_cached_image(npc_name: String) -> ImageTexture:
	"""Get cached image for an NPC, compose if not cached (lazy generation)."""
	if _image_cache.has(npc_name):
		return _image_cache[npc_name]

	# Compose on demand if not cached (supports lazy NPC creation)
	return compose_npc_image(npc_name)


func get_or_compose_image(npc_name: String) -> ImageTexture:
	"""Get or create NPC and compose their image (full lazy support)."""
	if _image_cache.has(npc_name):
		return _image_cache[npc_name]

	if not _npc_generator:
		return null

	# This will create NPC on-demand if they don't exist
	var npc_data = _npc_generator.get_or_create_npc(npc_name)
	if npc_data.is_empty():
		return null

	return compose_npc_image(npc_name)


func get_image_for_profession(profession: String) -> ImageTexture:
	"""Get the image for the NPC assigned to a profession (with lazy creation)."""
	if not _npc_generator:
		return null

	var npc_data = _npc_generator.get_npc_for_profession(profession)
	if npc_data.is_empty():
		return null

	var npc_name = npc_data.get("name", "")
	# Use get_or_compose for lazy support
	return get_or_compose_image(npc_name)


func refresh_npc_image(npc_name: String) -> void:
	"""Recompose an NPC's image (e.g., after profession change)."""
	# Remove old cached image
	if _image_cache.has(npc_name):
		_image_cache.erase(npc_name)

	# Recompose
	compose_npc_image(npc_name)
	print("NpcImageComposer: Refreshed image for %s" % npc_name)


func clear_cache() -> void:
	"""Clear all cached images."""
	_image_cache.clear()
