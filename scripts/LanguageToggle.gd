extends Button
## Invisible hit area over the edge-print language label ("ZH" in English, "EN" in Chinese).

## The pixel-font label that shows the toggle text.
@export var label_path: NodePath

var _label: Label


func _ready() -> void:
	_label = get_node(label_path)
	pressed.connect(Localization.toggle_locale)
	Localization.locale_changed.connect(_on_locale_changed)
	_on_locale_changed(Localization.current_locale)


func _on_locale_changed(locale: String) -> void:
	_label.text = "EN" if locale == Localization.LOCALE_ZH else "ZH"
