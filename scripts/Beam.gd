extends Node2D
## Incoming beam: a few straight, fast tracks entering from the left edge of the frame
## and ending at the collimator, which shows where (and which way) balls are launched.

@export var from_x := -700.0
@export var lanes := 5
@export var lane_gap := 15.0


func _ready() -> void:
	for i in lanes:
		var track := BubbleTrack.new()
		add_child(track)
		track.remove_from_group("track")  # the beam is scenery; it never fades with ball tracks
		var y := (i - (lanes - 1) / 2.0) * lane_gap + randf_range(-2.0, 2.0)
		track.add_point(Vector2(from_x + randf_range(0.0, 80.0), y), 3000.0)
		track.add_point(Vector2(-randf_range(70.0, 95.0), y), 3000.0)
