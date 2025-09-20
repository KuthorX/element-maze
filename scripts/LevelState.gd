extends Control

signal reset_requested

@export var score_tween_duration: float = 5
@export var initial_remain_balls: int = 10

var score: int = 0
var display_score: int = 0
var target_score: int = 0
var score_tween: Tween
var remain_balls: int = 0

func _ready() -> void:
    add_to_group("level_score")
    display_score = score
    target_score = score
    remain_balls = initial_remain_balls
    _update_remain_balls_display()
    
    # 连接重置信号
    reset_requested.connect(_reset_to_initial_values)

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
    
    # 如果没有动画在进行，创建新动画
    if not score_tween or not score_tween.is_valid():
        _start_score_animation()
    else:
        # 如果动画正在进行，重新计算剩余时间和目标
        _restart_score_animation()

func _start_score_animation() -> void:
    # 停止之前的动画
    if score_tween:
        score_tween.kill()
    
    # 创建新的动画，使用缓动效果
    score_tween = create_tween()
    score_tween.set_ease(Tween.EASE_OUT)  # 缓出效果：开始快，结束慢
    score_tween.set_trans(Tween.TRANS_EXPO)  # 指数过渡，更明显的缓动效果
    score_tween.tween_method(_update_display_score, display_score, target_score, score_tween_duration)
    score_tween.tween_callback(_on_score_animation_finished)

func _restart_score_animation() -> void:
    # 停止当前动画
    if score_tween:
        score_tween.kill()
    
    # 重新开始动画，从当前显示分数到新的目标分数
    score_tween = create_tween()
    score_tween.set_ease(Tween.EASE_OUT)
    score_tween.set_trans(Tween.TRANS_EXPO)
    score_tween.tween_method(_update_display_score, display_score, target_score, score_tween_duration)
    score_tween.tween_callback(_on_score_animation_finished)

func _update_display_score(value: int) -> void:
    display_score = int(value)
    _update_score_display()

func _on_score_animation_finished() -> void:
    # 动画完成，确保显示分数等于目标分数
    display_score = target_score
    _update_score_display()

func _update_score_display() -> void:
    var score_node = _find_child_node_recursive(self, "Score")
    if score_node:
        var score_value_node = _find_child_node_recursive(score_node, "Value")
        if score_value_node and score_value_node.has_method("set_text"):
            score_value_node.set_text(str(display_score))
        elif score_value_node and "text" in score_value_node:
            score_value_node.text = str(display_score)

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
    """获取剩余球数"""
    return remain_balls

func _update_remain_balls_display() -> void:
    """更新剩余球数显示"""
    var remain_balls_node = _find_child_node_recursive(self, "RemainBalls")
    if remain_balls_node:
        var remain_balls_value_node = _find_child_node_recursive(remain_balls_node, "Value")
        if remain_balls_value_node and remain_balls_value_node.has_method("set_text"):
            remain_balls_value_node.set_text(str(remain_balls))
        elif remain_balls_value_node and "text" in remain_balls_value_node:
            remain_balls_value_node.text = str(remain_balls)

func _find_child_node_recursive(parent: Node, node_name: String) -> Node:
    """递归查找子节点"""
    if parent.name == node_name:
        return parent
    
    for child in parent.get_children():
        var result = _find_child_node_recursive(child, node_name)
        if result:
            return result
    
    return null

func _input(event: InputEvent) -> void:
    """处理输入事件"""
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_R:
            reset_requested.emit()

func _reset_to_initial_values() -> void:
    """重置分数和剩余球数为初始值"""
    # 停止当前的分数动画
    if score_tween and score_tween.is_valid():
        score_tween.kill()
    
    # 重置分数
    score = 0
    display_score = 0
    target_score = 0
    
    # 重置剩余球数
    remain_balls = initial_remain_balls
    
    # 更新显示
    _update_score_display()
    _update_remain_balls_display()
    
    GameLogger.info("Reset to initial values: Score=0, RemainBalls=%d" % initial_remain_balls, "LevelState")

func _print_score() -> void:
    GameLogger.info("Score: %d" % score, "LevelScore")
