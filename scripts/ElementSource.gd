extends Sprite2D

const ColorBallScene := preload("res://nodes/ColorBall.tscn")

@export var initial_momentum: float = 400.0
@export var initial_direction: Vector2 = Vector2.RIGHT

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        _spawn_color_ball()

func _spawn_color_ball() -> void:
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
    if ball.has_variable("direction"):
        ball.direction = initial_direction.normalized()
    if ball.has_variable("momentum"):
        ball.momentum = initial_momentum

