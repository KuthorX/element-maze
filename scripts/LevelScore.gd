extends Control

@export var score_tween_duration: float = 5

var score: int = 0
var display_score: int = 0
var target_score: int = 0
var score_tween: Tween

func _ready() -> void:
    add_to_group("level_score")
    display_score = score
    target_score = score

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
    var score_value_node = get_node_or_null("./Score/Value")
    if score_value_node and score_value_node.has_method("set_text"):
        score_value_node.set_text(str(display_score))
    elif score_value_node and "text" in score_value_node:
        score_value_node.text = str(display_score)

func _print_score() -> void:
    print("Score: ", score)
