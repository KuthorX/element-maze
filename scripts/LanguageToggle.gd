extends Button
## Title-bar style "中文 / EN" switch; text is fixed, locale handled by Localization autoload.


func _ready() -> void:
	pressed.connect(Localization.toggle_locale)
