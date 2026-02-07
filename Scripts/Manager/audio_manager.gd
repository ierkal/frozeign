extends Node

# =============================================================================
# Music streams (assign in inspector)
# =============================================================================
@export_group("Music")
@export var splash_music_stream: AudioStream
@export var splash_music_volume_db: float = 0.0
@export var general_music_stream: AudioStream
@export var general_music_volume_db: float = 0.0
@export var intro_art_music_stream: AudioStream
@export var intro_art_music_volume_db: float = 0.0
@export var mid_art_music_stream: AudioStream
@export var mid_art_music_volume_db: float = 0.0
@export var ending_art_music_stream: AudioStream
@export var ending_art_music_volume_db: float = 0.0

# =============================================================================
# SFX streams – one-shot (assign in inspector)
# =============================================================================
@export_group("SFX – One-shot")
@export var menu_click_stream: AudioStream
@export var menu_click_volume_db: float = 0.0
@export var card_appearance_stream: AudioStream
@export var card_appearance_volume_db: float = 0.0
@export var card_committed_stream: AudioStream
@export var card_committed_volume_db: float = 0.0
@export var volcano_card_stream: AudioStream
@export var volcano_card_volume_db: float = 0.0
@export var popup_shown_stream: AudioStream
@export var popup_shown_volume_db: float = 0.0
@export var notification_stream: AudioStream
@export var notification_volume_db: float = 0.0
@export var card_unlock_stream: AudioStream
@export var card_unlock_volume_db: float = 0.0

# =============================================================================
# SFX streams – looping minigame (assign in inspector)
# =============================================================================
@export_group("SFX – Minigame Loops")
@export var radio_minigame_stream: AudioStream
@export var radio_minigame_volume_db: float = 0.0
@export var snow_clear_minigame_stream: AudioStream
@export var snow_clear_minigame_volume_db: float = 0.0
@export var pipe_patch_minigame_stream: AudioStream
@export var pipe_patch_minigame_volume_db: float = 0.0
@export var skill_check_minigame_stream: AudioStream
@export var skill_check_minigame_volume_db: float = 0.0
@export var steam_hub_heat_minigame_stream: AudioStream
@export var steam_hub_heat_minigame_volume_db: float = 0.0

# =============================================================================
# Internal players
# =============================================================================
var _splash_player: AudioStreamPlayer
var _general_player: AudioStreamPlayer
var _art_player: AudioStreamPlayer

var _sfx_players: Dictionary = {}  # "name" -> AudioStreamPlayer
var _minigame_players: Dictionary = {}  # minigame_id -> AudioStreamPlayer

var _fade_tween: Tween

# Minigame ID -> stream/volume mapping (resolved in _ready)
var _minigame_map: Dictionary = {}

func _ready() -> void:
	# --- Music players ---
	_splash_player = _create_player("Music", splash_music_stream, splash_music_volume_db)
	_general_player = _create_player("Music", general_music_stream, general_music_volume_db)
	_art_player = _create_player("Music", null, 0.0)

	# --- One-shot SFX players ---
	_sfx_players["menu_click"] = _create_player("SFX", menu_click_stream, menu_click_volume_db)
	_sfx_players["card_appearance"] = _create_player("SFX", card_appearance_stream, card_appearance_volume_db)
	_sfx_players["card_committed"] = _create_player("SFX", card_committed_stream, card_committed_volume_db)
	_sfx_players["volcano_card"] = _create_player("SFX", volcano_card_stream, volcano_card_volume_db)
	_sfx_players["popup_shown"] = _create_player("SFX", popup_shown_stream, popup_shown_volume_db)
	_sfx_players["notification"] = _create_player("SFX", notification_stream, notification_volume_db)
	_sfx_players["card_unlock"] = _create_player("SFX", card_unlock_stream, card_unlock_volume_db)

	# --- Minigame looping SFX players ---
	_minigame_map = {
		"skill_check": { "stream": skill_check_minigame_stream, "volume": skill_check_minigame_volume_db },
		"radio_frequency": { "stream": radio_minigame_stream, "volume": radio_minigame_volume_db },
		"generator_heat": { "stream": steam_hub_heat_minigame_stream, "volume": steam_hub_heat_minigame_volume_db },
		"pipe_patch": { "stream": pipe_patch_minigame_stream, "volume": pipe_patch_minigame_volume_db },
		"snow_clear": { "stream": snow_clear_minigame_stream, "volume": snow_clear_minigame_volume_db },
	}

	for mg_id in _minigame_map:
		var info: Dictionary = _minigame_map[mg_id]
		_minigame_players[mg_id] = _create_player("SFX", info["stream"], info["volume"])

	# --- EventBus connections ---
	EventBus.minigame_requested.connect(_on_minigame_requested)
	EventBus.minigame_completed.connect(_on_minigame_completed)

	# --- Auto-connect buttons for menu click SFX ---
	get_tree().node_added.connect(_on_node_added)

	# --- Start initial music (deferred so the scene tree is settled) ---
	call_deferred("_start_initial_music")


# =============================================================================
# Player factory
# =============================================================================
func _create_player(bus: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume_db
	if stream:
		player.stream = stream
	add_child(player)
	return player


# =============================================================================
# Initial music
# =============================================================================
func _start_initial_music() -> void:
	# If the current scene is the splash screen, play splash music
	var root := get_tree().current_scene
	if root is SplashScreen:
		play_splash_music()
	else:
		play_general_music()


# =============================================================================
# Music – public API
# =============================================================================
func play_splash_music() -> void:
	_stop_music_players()
	if _splash_player.stream:
		_splash_player.play()

func play_general_music() -> void:
	_stop_music_players()
	if _general_player.stream:
		_general_player.volume_db = general_music_volume_db
		_general_player.play()

func stop_all_music() -> void:
	_stop_music_players()


# =============================================================================
# Art sequence music
# =============================================================================
func play_art_sequence_music(type: String) -> void:
	# Choose stream based on type
	var stream: AudioStream = null
	var vol: float = 0.0

	match type:
		"intro":
			stream = intro_art_music_stream
			vol = intro_art_music_volume_db
		"mid":
			stream = mid_art_music_stream
			vol = mid_art_music_volume_db
		"volcano", "oracle", "city":
			stream = ending_art_music_stream
			vol = ending_art_music_volume_db

	# Fade out general music
	if _fade_tween:
		_fade_tween.kill()
	if _general_player.playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_general_player, "volume_db", -80.0, 1.0)
		_fade_tween.tween_callback(_general_player.stop)

	# Start art music
	if stream:
		_art_player.stream = stream
		_art_player.volume_db = vol
		_art_player.play()

func stop_art_sequence_music() -> void:
	_art_player.stop()

	# Fade general music back in
	if _general_player.stream:
		_general_player.volume_db = -80.0
		_general_player.play()
		if _fade_tween:
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_general_player, "volume_db", general_music_volume_db, 1.0)


# =============================================================================
# SFX – one-shot public API
# =============================================================================
func play_menu_click() -> void:
	_play_sfx("menu_click")

func play_card_appearance() -> void:
	_play_sfx("card_appearance")

func play_card_committed() -> void:
	_play_sfx("card_committed")

func play_volcano_card() -> void:
	_play_sfx("volcano_card")

func play_popup_shown() -> void:
	_play_sfx("popup_shown")

func play_notification() -> void:
	_play_sfx("notification")

func play_card_unlock() -> void:
	_play_sfx("card_unlock")


# =============================================================================
# Minigame audio – public API
# =============================================================================
func start_minigame_audio(id: String) -> void:
	var player: AudioStreamPlayer = _minigame_players.get(id)
	if player and player.stream:
		player.play()

func stop_minigame_audio() -> void:
	for player in _minigame_players.values():
		if player.playing:
			player.stop()


# =============================================================================
# Volume control – public API (0-100 percent)
# =============================================================================
func set_music_volume(percent: float) -> void:
	var db := _percent_to_db(percent)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)

func set_sfx_volume(percent: float) -> void:
	var db := _percent_to_db(percent)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)


# =============================================================================
# Internal helpers
# =============================================================================
func _play_sfx(key: String) -> void:
	var player: AudioStreamPlayer = _sfx_players.get(key)
	if player and player.stream:
		player.play()

func _stop_music_players() -> void:
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	_splash_player.stop()
	_general_player.stop()
	_art_player.stop()

func _percent_to_db(percent: float) -> float:
	percent = clampf(percent, 0.0, 100.0)
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)

func _on_node_added(node: Node) -> void:
	if node is Button:
		if not node.pressed.is_connected(play_menu_click):
			node.pressed.connect(play_menu_click)

func _on_minigame_requested(minigame_id: String, _data: Dictionary) -> void:
	start_minigame_audio(minigame_id)

func _on_minigame_completed(_minigame_id: String, _success: bool) -> void:
	stop_minigame_audio()
