extends Node
## Chooses the UI language (saved choice > OS language) and persists toggles.

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "general"
const SETTINGS_KEY_LOCALE := "locale"
const LOCALE_EN := "en"
const LOCALE_ZH := "zh"

var current_locale: String = LOCALE_EN


func _ready() -> void:
	_apply_locale(_load_saved_locale())


func toggle_locale() -> void:
	var next_locale := LOCALE_EN if current_locale == LOCALE_ZH else LOCALE_ZH
	_apply_locale(next_locale)
	_save_locale(next_locale)


func _apply_locale(locale: String) -> void:
	current_locale = locale
	TranslationServer.set_locale(locale)
	DisplayServer.window_set_title(tr("GAME_TITLE"))
	GameLogger.info("Locale set to %s" % locale, "Localization")


func _detect_os_locale() -> String:
	return LOCALE_ZH if OS.get_locale_language() == LOCALE_ZH else LOCALE_EN


func _load_saved_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return _detect_os_locale()
	var saved: String = config.get_value(SETTINGS_SECTION, SETTINGS_KEY_LOCALE, "")
	if saved == LOCALE_EN or saved == LOCALE_ZH:
		return saved
	return _detect_os_locale()


func _save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY_LOCALE, locale)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		GameLogger.error("Failed to save locale (error %d)" % err, "Localization")
