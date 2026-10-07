extends Button
## Invisible hit area over the edge-print sound label ("Sound ●●○"); each click steps the
## volume down one notch, wrapping from off back to full. M toggles mute (see Audio.gd).

## The pixel-font label that shows the volume.
@export var label_path: NodePath

var _label: Label


func _ready() -> void:
	_label = get_node(label_path)
	pressed.connect(_on_pressed)
	Audio.volume_changed.connect(_on_volume_changed)
	_on_volume_changed(Audio.volume_level)


func _on_pressed() -> void:
	Audio.cycle_volume()
	Audio.play("ui_click")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_on_volume_changed(Audio.volume_level)


func _on_volume_changed(level: int) -> void:
	var meter := tr("HUD_SOUND_OFF") if level == 0 else "●".repeat(level) + "○".repeat(Audio.MAX_VOLUME_LEVEL - level)
	_label.text = "%s %s" % [tr("HUD_SOUND"), meter]
