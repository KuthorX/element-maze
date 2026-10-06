class_name BubbleTrack
extends Node2D
## A particle track as it appears on bubble-chamber film: a chain of bubbles.
## Fast particles leave sparse, bright bubbles; slow ones leave dense, dim ones,
## so a track shows where its ball was fast.

const MAX_BUBBLES := 2500
const RADIUS := 3.0
const COLOR := Color(0.93, 0.93, 0.9)
const MIN_SPACING := 6.0
const MAX_SPACING := 18.0
const SPEED_PER_SPACING := 45.0
const MIN_ALPHA := 0.3
const FULL_ALPHA_SPEED := 1200.0

## Score of the ball that left this track (0 if it never reached the goal).
var score := 0.0

var _points := PackedVector2Array()
var _alphas := PackedFloat32Array()
var _last := Vector2.INF
var _carry := 0.0


func _ready() -> void:
	add_to_group("track")


## Number of bubbles laid so far.
func length() -> int:
	return _points.size()


## Extend the track to `pos`, laying bubbles along the way.
func add_point(pos: Vector2, speed: float) -> void:
	if _points.size() >= MAX_BUBBLES:
		return
	if _last == Vector2.INF:
		_last = pos
		_bubble(pos, speed)
		return
	var seg := pos - _last
	var seg_length := seg.length()
	if seg_length <= 0.0:
		return
	var spacing := clampf(speed / SPEED_PER_SPACING, MIN_SPACING, MAX_SPACING)
	var t := spacing - _carry
	while t <= seg_length:
		_bubble(_last + seg * (t / seg_length), speed)
		t += spacing
	_carry = seg_length - (t - spacing)
	_last = pos


## Impact: a short spray of fast secondary tracks around the surface normal.
func spawn_impact(origin: Vector2, normal: Vector2) -> void:
	for i in 4:
		var spray := BubbleTrack.new()
		get_parent().add_child(spray)
		var dir := normal.rotated(randf_range(-1.1, 1.1))
		spray.add_point(origin, 2400.0)
		spray.add_point(origin + dir * randf_range(28.0, 64.0), 2400.0)


func _bubble(pos: Vector2, speed: float) -> void:
	_points.append(pos)
	_alphas.append(clampf(speed / FULL_ALPHA_SPEED, MIN_ALPHA, 1.0))
	queue_redraw()


func _draw() -> void:
	for i in _points.size():
		draw_circle(_points[i], RADIUS, Color(COLOR, _alphas[i]), true, -1.0, true)
