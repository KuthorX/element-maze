extends Sprite2D

const ColorBallScene := preload("res://nodes/ColorBall.tscn")

@export var initial_momentum: float = 400.0
@export var initial_direction: Vector2 = Vector2.RIGHT
@export var initial_momentum_decay_per_second: float = 80.0
@export var initial_angular_speed: float = deg_to_rad(90.0)

# 跟踪已生成的 ColorBall 实例
var spawned_balls: Array[Node] = []

func _ready() -> void:
	# 连接重置信号
	var level_state = get_tree().get_first_node_in_group("level_score")
	if level_state and level_state.has_signal("reset_requested"):
		level_state.reset_requested.connect(_clear_all_balls)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		GameLogger.info("press ui_accept", "ElementSource")
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
	parent_node.add_child(ball)
	ball.global_position = global_position
	# 配置初始运动参数（方向与动量）
	ball.direction = initial_direction.normalized()
	ball.momentum = initial_momentum
	ball.momentum_decay_per_second = initial_momentum_decay_per_second
	ball.angular_speed = initial_angular_speed
	
	# 将球添加到跟踪列表中
	spawned_balls.append(ball)
	
	# 连接球的 tree_exited 信号，当球被销毁时从列表中移除
	if ball.has_signal("tree_exited"):
		ball.tree_exited.connect(_on_ball_tree_exited.bind(ball))
	
	GameLogger.info("ColorBall spawned successfully, total balls: %d" % spawned_balls.size(), "ElementSource")

func _clear_all_balls() -> void:
	"""清理所有已生成的 ColorBall"""
	var cleared_count = 0
	for ball in spawned_balls:
		if is_instance_valid(ball) and ball.is_inside_tree():
			ball.queue_free()
			cleared_count += 1
	
	spawned_balls.clear()
	GameLogger.info("Cleared %d ColorBalls from ElementSource" % cleared_count, "ElementSource")

func _on_ball_tree_exited(ball: Node) -> void:
	"""当球被销毁时从跟踪列表中移除"""
	if ball in spawned_balls:
		spawned_balls.erase(ball)
		GameLogger.info("ColorBall removed from tracking, remaining: %d" % spawned_balls.size(), "ElementSource")
