extends Button

func _ready() -> void:
    # 连接按钮按下事件
    pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
    """当按钮被按下时发送重置信号"""
    # 查找 LevelState 节点并发送重置信号
    var level_state = _find_level_state_node()
    if level_state and level_state.has_signal("reset_requested"):
        level_state.reset_requested.emit()
        GameLogger.info("Reset requested from ButtonReplay", "ButtonReplay")

func _find_level_state_node() -> Node:
    """查找 LevelState 节点"""
    # 首先尝试在当前场景中查找
    var level_state = get_tree().get_first_node_in_group("level_score")
    if level_state:
        return level_state
    
    # 如果没找到，尝试从根节点递归查找
    return _find_node_recursive(get_tree().current_scene, "LevelState")

func _find_node_recursive(parent: Node, node_name: String) -> Node:
    """递归查找指定名称的节点"""
    if parent.name == node_name:
        return parent
    
    for child in parent.get_children():
        var result = _find_node_recursive(child, node_name)
        if result:
            return result
    
    return null
