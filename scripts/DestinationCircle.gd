extends Area2D

@export var hue_step: float = 1.0  # 颜色变化速度
@export var gradient_colors: Array[Color] = []  # 颜色渐变数组
@export var scale_values: Array[float] = [0.8, 1.0, 1.2]  # 离散缩放值
@export var scale_step: float = 1  # 缩放变化速度
@export var snap_distance_px: float = 0.0  # 吸附距离（像素）
@export var move_duration: float = 1.0  # 吸入效果持续时间（秒）
@export var spin_speed: float = 0.0  # 精灵自转速度（弧度/秒）

var _color_index_t: float = 0.0
var _scale_index_t: float = 0.0
var last_captured_speed: float = 0.0  # 最后捕获的速度（用作分数）
var _capturing: Dictionary = {}  # 正在被吸附的球：{ ball: Tween }
var _sprite: Sprite2D
var _level_state: Node  # 缓存 LevelState 节点

func _ready():
	# 获取 Sprite2D 子节点
	_sprite = $Sprite2D if has_node("Sprite2D") else null
	if not _sprite:
		push_error("Sprite2D node not found")
	
	# 缓存 LevelState 或 level_score 节点
	_level_state = get_node_or_null("/root/LevelState")
	if _level_state == null:
		var candidates = get_tree().get_nodes_in_group("level_score")
		if candidates.size() > 0:
			_level_state = candidates[0]
	if _level_state and not _level_state.has_method("add_score"):
		push_warning("LevelState does not have add_score method")
		_level_state = null
	
	# 连接 Area2D 信号
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)
	if not is_connected("body_exited", _on_body_exited):
		connect("body_exited", _on_body_exited)
	print("Area2D signals connected")

func _process(delta: float):
	# 颜色渐变
	if gradient_colors.size() > 0:
		var count = gradient_colors.size()
		_color_index_t = fposmod(_color_index_t + hue_step * delta, float(count))
		var seg_index = int(floor(_color_index_t)) % count
		var c = gradient_colors[seg_index]
		if _sprite:
			_sprite.modulate = Color(c.r, c.g, c.b, _sprite.modulate.a)
	
	if _sprite and spin_speed != 0.0:
		_sprite.rotation += spin_speed * delta

	# 缩放动画
	if scale_values.size() > 0:
		var scale_count = scale_values.size()
		_scale_index_t = fposmod(_scale_index_t + scale_step * delta, float(scale_count))
		var scale_index = int(floor(_scale_index_t)) % scale_count
		var current_scale = scale_values[scale_index]
		if _sprite:
			_sprite.scale = Vector2(current_scale, current_scale)

func _on_body_entered(body: Node):
	if body is CharacterBody2D:
		print("CharacterBody2D entered: ", body.name)
		_try_capture_body(body)

func _on_body_exited(body: Node):
	if body is CharacterBody2D and _capturing.has(body):
		print("CharacterBody2D exited: ", body.name)
		if _capturing[body].is_running():
			_capturing[body].kill()  # 停止 Tween
		_capturing.erase(body)

func _try_capture_body(body: CharacterBody2D):
	if _capturing.has(body):
		return
	
	# 获取并记录初始速度
	var initial_speed = body.velocity.length()
	if initial_speed <= 0.0:
		return
	
	# 检查是否直接吸附
	var distance = (global_position - body.global_position).length()
	if distance <= snap_distance_px:
		body.global_position = global_position
		body.velocity = Vector2.ZERO
		last_captured_speed = initial_speed
		_add_score(int(ceil(initial_speed)))
		body.queue_free()
		print("Immediate capture, score added: ", int(ceil(initial_speed)))
		return
	
	# 开始吸附动画
	body.velocity = Vector2.ZERO  # 立即归零速度
	var tween = create_tween().set_parallel(true)
	tween.tween_property(body, "global_position", global_position, move_duration)
	tween.tween_property(body, "scale", Vector2(0.0001, 0.0001), move_duration)
	tween.tween_callback(_on_absorb_complete.bind(body, initial_speed)).set_delay(move_duration)
	_capturing[body] = tween
	print("Capturing ball, initial speed: ", initial_speed)

func _on_absorb_complete(ball: CharacterBody2D, initial_speed: float):
	if not is_instance_valid(ball):
		_capturing.erase(ball)
		return
	ball.global_position = global_position
	last_captured_speed = initial_speed
	_add_score(int(ceil(initial_speed)))
	if is_instance_valid(ball.trail):
		ball.trail.score = initial_speed
	_capturing.erase(ball)
	ball.queue_free()
	print("Ball absorbed, score added: ", int(ceil(initial_speed)))

func _add_score(amount: int):
	if _level_state and _level_state.has_method("add_score"):
		print("Adding score: ", amount, " at time: ", Time.get_ticks_msec())
		_level_state.add_score(amount)
	else:
		push_warning("No LevelState or level_score node found")
