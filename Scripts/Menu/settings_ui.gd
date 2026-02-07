extends Control
class_name SettingsUI

@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value: Label = %SFXValue
@onready var language_dropdown: OptionButton = %LanguageDropdown
@onready var version_label: Label = %VersionLabel

var current_language: int = 0


func _ready() -> void:
	_on_music_slider_changed(music_slider.value)
	_on_sfx_slider_changed(sfx_slider.value)

	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	version_label.text = "version" + version

	# Set font for dropdown popup
	var popup = language_dropdown.get_popup()
	var font = load("res://Assets/Fonts/PIXELADE.TTF")
	popup.add_theme_font_override("font", font)
	popup.add_theme_font_size_override("font_size", 28)


func _on_music_slider_changed(_value: float) -> void:
	music_value.text = str(roundi(music_slider.value)) + "%"
	AudioManager.set_music_volume(music_slider.value)


func _on_sfx_slider_changed(_value: float) -> void:
	sfx_value.text = str(roundi(sfx_slider.value)) + "%"
	AudioManager.set_sfx_volume(sfx_slider.value)


func _on_language_selected(index: int) -> void:
	current_language = index
	# TODO: Implement language switching when localization is added
	# TranslationServer.set_locale(get_locale_code(index))
