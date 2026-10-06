extends Label
## A label printed on the film next to a world object (lives in the pixel text layer).
## It follows its anchor when the camera pans.

## World-space node this note describes.
@export var anchor_path: NodePath
## Position of the note's top-left corner relative to the anchor, in layer pixels.
@export var offset := Vector2.ZERO
## Untranslated text (e.g. "×2.4"); leave empty to use `text` as a translation key.
@export var literal := ""

var _anchor: Node2D
var _layer_scale := 1.0


func _ready() -> void:
	_anchor = get_node_or_null(anchor_path)
	if literal != "":
		auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		text = literal
	var container := get_viewport().get_parent() as SubViewportContainer
	_layer_scale = float(container.stretch_shrink) if container else 1.0


func _process(_delta: float) -> void:
	if _anchor == null or not visible:
		return
	position = (_anchor_on_layer() + offset).round()


func _anchor_on_layer() -> Vector2:
	return _anchor.get_global_transform_with_canvas().origin / _layer_scale

