extends Sprite2D

const ColorBallScene := preload("res://nodes/ColorBall.tscn")

@export var initial_speed: float = 400.0
## Where the bubble tracks of past balls are kept (they stay on the film until replay).
@export var trails_path: NodePath

# 跟踪已生成的 ColorBall 实例
var spawned_balls: Array[Node] = []


func _ready() -> void:
	# 连接重置信号
	var level_state = get_tree().get_first_node_in_group("level_score")
	if level_state and level_state.has_signal("reset_requested"):
		level_state.reset_requested.connect(_clear_all_balls)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var level_state = get_tree().get_first_node_in_group("level_score")
		if level_state and not level_state.is_playing():
			return
		GameLogger.info("press ui_accept", "ElementSource")
		get_viewport().set_input_as_handled()
		_spawn_color_ball()


func _spawn_color_ball() -> void:
	# 检查是否有剩余球数
	var level_state = get_tree().get_first_node_in_group("level_score")
	if level_state and not level_state.consume_ball():
		GameLogger.info("Cannot spawn ball: no remaining balls", "ElementSource")
		return

	var ball := ColorBallScene.instantiate()
	if ball == null:
		return
	# 将实例加入与 ElementSource 相同的父节点，保持层级清晰
	var parent_node := get_parent()
	if parent_node == null:
		return
	ball.speed = initial_speed
	ball.trail = _new_trail()
	parent_node.add_child(ball)
	ball.global_position = global_position

	spawned_balls.append(ball)
	ball.tree_exited.connect(_on_ball_tree_exited.bind(ball))
	GameLogger.info("ColorBall spawned successfully, total balls: %d" % spawned_balls.size(), "ElementSource")


func _new_trail() -> BubbleTrack:
	var trails := get_node_or_null(trails_path)
	if trails == null:
		return null
	var track := BubbleTrack.new()
	track.add_to_group("ball_track")
	trails.add_child(track)
	return track


func _clear_all_balls() -> void:
	"""清理所有已生成的 ColorBall 和它们留下的轨迹"""
	var cleared_count = 0
	for ball in spawned_balls:
		if is_instance_valid(ball) and ball.is_inside_tree():
			ball.queue_free()
			cleared_count += 1
	spawned_balls.clear()
	var trails := get_node_or_null(trails_path)
	if trails:
		for track in trails.get_children():
			track.queue_free()
	GameLogger.info("Cleared %d ColorBalls from ElementSource" % cleared_count, "ElementSource")


func _on_ball_tree_exited(ball: Node) -> void:
	"""当球被销毁时从跟踪列表中移除"""
	if ball in spawned_balls:
		spawned_balls.erase(ball)
		GameLogger.info("ColorBall removed from tracking, remaining: %d" % spawned_balls.size(), "ElementSource")
