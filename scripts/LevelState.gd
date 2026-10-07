extends Control

signal reset_requested

enum State { TITLE, PLAYING, ENDED }

@export var score_tween_duration: float = 5
@export var initial_remain_balls: int = 10
@export var goal_score: int = 36200
## A ball slower than this (px/s) counts as settled when deciding the round is over.
@export var settled_speed: float = 25.0
## Grace period after the last ball settles before the result is shown.
@export var end_delay: float = 1.2

var score: int = 0
var display_score: int = 0
var target_score: int = 0
var score_tween: Tween
var remain_balls: int = 0
var state: State = State.TITLE

var _settled_time: float = 0.0

const FADED_TRACK_ALPHA := 0.15
const SCAN_IN_STEP := 0.12
## On the result screen the level is "powered off" to this grey.
const POWERED_OFF := Color(0.3, 0.3, 0.3)
const POWER_OFF_TIME := 0.4

@onready var _imprint: Control = %Imprint
@onready var _balls_label: Label = %BallsLabel
@onready var _speed_readout: Label = %SpeedReadout


# Joined on enter_tree (not _ready) so world nodes that look this node up in their own
# _ready find it regardless of tree order.
func _enter_tree() -> void:
	add_to_group("level_score")


func _ready() -> void:
	display_score = score
	target_score = score
	remain_balls = initial_remain_balls
	_update_remain_balls_display()
	reset_requested.connect(_reset_to_initial_values)
	_imprint.show_title()
	_hide_level()
	Audio.play_music("scanning_table")


func is_playing() -> bool:
	return state == State.PLAYING


func add_score(amount: int) -> void:
	if amount == 0:
		return
	score += amount
	_update_score_animation()
	_print_score()


func set_score(new_score: int) -> void:
	if new_score == score:
		return
	score = new_score
	_update_score_animation()
	_print_score()


func _update_score_animation() -> void:
	target_score = score
	if score_tween:
		score_tween.kill()
	score_tween = create_tween()
	score_tween.set_ease(Tween.EASE_OUT)
	score_tween.set_trans(Tween.TRANS_EXPO)
	score_tween.tween_method(_update_display_score, display_score, target_score, score_tween_duration)
	score_tween.tween_callback(_on_score_animation_finished)


func _update_display_score(value: int) -> void:
	display_score = int(value)
	_update_score_display()


func _on_score_animation_finished() -> void:
	display_score = target_score
	_update_score_display()


func _update_score_display() -> void:
	_imprint.set_score(display_score)


func consume_ball() -> bool:
	"""消耗一个球，返回是否成功消耗"""
	if remain_balls <= 0:
		GameLogger.info("No balls remaining, cannot spawn", "LevelState")
		return false
	remain_balls -= 1
	_update_remain_balls_display()
	GameLogger.info("Ball consumed, remaining: %d" % remain_balls, "LevelState")
	return true


func get_remain_balls() -> int:
	return remain_balls


## "BALLS ●●●●●●○○○○": filled = still to launch.
func _update_remain_balls_display() -> void:
	var used := initial_remain_balls - remain_balls
	_balls_label.text = "%s  %s%s" % [tr("HUD_BALLS_LEFT"), "●".repeat(remain_balls), "○".repeat(used)]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_remain_balls_display()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	_update_speed_readout()
	if score >= goal_score:
		_end_round()
		return
	if remain_balls > 0 or _any_ball_active():
		_settled_time = 0.0
		return
	_settled_time += delta
	if _settled_time >= end_delay:
		_end_round()


## Reticle readout: the speed of the fastest ball in flight (what it would score now).
func _update_speed_readout() -> void:
	var fastest := 0.0
	for ball in get_tree().get_nodes_in_group("color_ball"):
		fastest = maxf(fastest, ball.velocity.length())
	_speed_readout.text = tr("HUD_SPEED") % format_number(int(fastest))


func _any_ball_active() -> bool:
	for ball in get_tree().get_nodes_in_group("color_ball"):
		# A ball being absorbed by the goal shrinks first; its score is still pending.
		if ball.velocity.length() > settled_speed or ball.scale.x < 0.999:
			return true
	return false


func _end_round() -> void:
	state = State.ENDED
	_highlight_best_track()
	_power_level(POWERED_OFF)
	_speed_readout.text = ""
	_imprint.show_end(score >= goal_score, score, goal_score)
	Audio.play("target_met" if score >= goal_score else "out_of_balls")
	Audio.duck_music(true)
	GameLogger.info("Round ended with score %d" % score, "LevelState")


## On the result screen every track fades back except the best one: the highest-scoring
## ball, or the longest track if no ball reached the goal.
func _highlight_best_track() -> void:
	var best: BubbleTrack = null
	for track in get_tree().get_nodes_in_group("ball_track"):
		if best == null or [track.score, track.length()] > [best.score, best.length()]:
			best = track
	for track in get_tree().get_nodes_in_group("track"):
		track.modulate.a = 1.0 if track == best else FADED_TRACK_ALPHA


## Tints every level piece (walls, zones, launcher, goal) towards `tint`.
func _power_level(tint: Color) -> void:
	var tween := create_tween().set_parallel()
	for piece in get_tree().get_nodes_in_group("scan_in") + get_tree().get_nodes_in_group("power"):
		tween.tween_property(piece, "modulate", Color(tint, piece.modulate.a), POWER_OFF_TIME)


## Level pieces "scan in" one after another, left to right, when the first round starts.
func _scan_in_level() -> void:
	var pieces := get_tree().get_nodes_in_group("scan_in")
	pieces.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var tween := create_tween()
	for piece in pieces:
		tween.tween_property(piece, "modulate:a", 1.0, SCAN_IN_STEP)


func _hide_level() -> void:
	for piece in get_tree().get_nodes_in_group("scan_in"):
		piece.modulate.a = 0.0


func _start_round() -> void:
	if state == State.TITLE:
		_scan_in_level()
	elif state == State.ENDED:
		_power_level(Color.WHITE)
	state = State.PLAYING
	_settled_time = 0.0
	Audio.play("ui_confirm")
	Audio.play_music("exposure")
	_imprint.show_play(goal_score)
	_update_score_display()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.TITLE and _is_start_event(event):
		get_viewport().set_input_as_handled()
		_start_round()


func _is_start_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _input(event: InputEvent) -> void:
	if state != State.TITLE and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		reset_requested.emit()



func _reset_to_initial_values() -> void:
	"""重置分数和剩余球数为初始值"""
	if score_tween and score_tween.is_valid():
		score_tween.kill()
	score = 0
	display_score = 0
	target_score = 0
	remain_balls = initial_remain_balls
	_update_score_display()
	_update_remain_balls_display()
	_start_round()
	GameLogger.info("Reset to initial values: Score=0, RemainBalls=%d" % initial_remain_balls, "LevelState")


func _print_score() -> void:
	GameLogger.info("Score: %d" % score, "LevelScore")


## 36200 -> "36,200".
static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
