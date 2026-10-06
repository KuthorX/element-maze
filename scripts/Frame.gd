extends Control
## The frame edge: one dim hairline around the image.

const LINE := Color(0.56, 0.56, 0.54, 0.5)

## Distance from the screen edge to the hairline, in viewport pixels.
@export var inset := 32.0


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0), LINE, false, 2.0)
