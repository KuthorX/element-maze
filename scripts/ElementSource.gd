extends Sprite2D

const ColorBallScene := preload("res://nodes/ColorBall.tscn")

@export var initial_momentum: float = 400.0
@export var initial_direction: Vector2 = Vector2.RIGHT
@export var initial_momentum_decay_per_second: float = 80.0
@export var initial_angular_speed: float = deg_to_rad(90.0)

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
	GameLogger.info("ColorBall spawned successfully", "ElementSource")
