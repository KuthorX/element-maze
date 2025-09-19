extends Sprite2D

@export var hue_step: float = 1
@export var gradient_colors: Array[Color] = []
@export var snap_distance_px: float = 2.0

var _color_index_t: float = 0.0
var last_captured_momentum: int = 0

const ColorBallScript := preload("res://scripts/ColorBall.gd")

# 正在被减速吸附的球：{ ball: { initial:int, original_decay:float } }
var _capturing: Dictionary = {}

var _area: Area2D

func _is_color_ball(node: Node) -> bool:
	return node != null and node.get_script() == ColorBallScript

func _ready():
	_area = get_node("Area2D")

	# 连接进入事件（也可在编辑器中直接连接）
	if not _area.is_connected("body_entered", Callable(self, "_on_body_entered")):
		_area.connect("body_entered", Callable(self, "_on_body_entered"))
	if not _area.is_connected("area_entered", Callable(self, "_on_area_entered")):
		_area.connect("area_entered", Callable(self, "_on_area_entered"))
	if not _area.is_connected("body_exited", Callable(self, "_on_body_exited")):
		_area.connect("body_exited", Callable(self, "_on_body_exited"))
	if not _area.is_connected("area_exited", Callable(self, "_on_area_exited")):
		_area.connect("area_exited", Callable(self, "_on_area_exited"))

func _process(delta: float) -> void:
	# 仅依据给定的颜色数组进行离散跳变
	var count := gradient_colors.size()
	if count == 0:
		return
	_color_index_t = fposmod(_color_index_t + hue_step * delta, float(count))
	var seg_index: int = int(floor(_color_index_t)) % count
	var c: Color = gradient_colors[seg_index]
	modulate = Color(c.r, c.g, c.b, modulate.a)

func _physics_process(_delta: float) -> void:
	# 对正在被吸附的球，持续引导其以恰好在圆心停下
	for ball in _capturing.keys():
		if not is_instance_valid(ball):
			_capturing.erase(ball)
			continue
		_guide_ball_to_center(ball)

func _on_body_entered(body: Node) -> void:
	GameLogger.debug("on_body_entered", "DestinationCircle")
	_try_capture_from_node(body)

func _on_area_entered(area: Node) -> void:
	GameLogger.debug("on_area_entered", "DestinationCircle")
	_try_capture_from_node(area)

func _on_body_exited(body: Node) -> void:
	GameLogger.debug("on_body_exited", "DestinationCircle")
	_release_if_tracking(body)

func _on_area_exited(area: Node) -> void:
	GameLogger.debug("on_area_exited", "DestinationCircle")
	_release_if_tracking(area)

func _try_capture_from_node(node: Node) -> void:
	# 直接是 ColorBall
	if _is_color_ball(node):
		_begin_capturing(node)
		return
	# 进入的是子节点（例如有碰撞形状的子体），则沿父链寻找 ColorBall
	var current: Node = node
	while current:
		if _is_color_ball(current):
			_begin_capturing(current)
			return
		current = current.get_parent()

func _begin_capturing(ball: Node) -> void:
	if not _is_color_ball(ball):
		return
	if _capturing.has(ball):
		return
	var v: float = float(ball.momentum)
	if v <= 0.0:
		return
	var d: float = (self.global_position - ball.global_position).length()
	if d <= snap_distance_px:
		# 直接吸附到中心并结算
		var captured_immediate: int = int(ceil(v))
		last_captured_momentum = captured_immediate
		ball.global_position = self.global_position
		ball.momentum = 0.0
		_add_score(captured_immediate)
		return
	# 保存原衰减，记录初始分数，开始引导
	var info := {
		"initial": int(ceil(v)),
		"original_decay": ball.momentum_decay_per_second
	}
	_capturing[ball] = info
	_apply_guidance(ball)

func _guide_ball_to_center(ball: Node) -> void:
	if not _is_color_ball(ball):
		_capturing.erase(ball)
		return
	var v: float = float(ball.momentum)
	var to_center: Vector2 = self.global_position - ball.global_position
	var d: float = to_center.length()
	if d <= snap_distance_px or v <= 0.0:
		# 吸附并结算
		ball.global_position = self.global_position
		ball.momentum = 0.0
		if _capturing.has(ball):
			var info = _capturing[ball]
			last_captured_momentum = int(info.initial)
			_restore_decay(ball, float(info.original_decay))
			_add_score(int(info.initial))
			_capturing.erase(ball)
		return
	# 持续将方向指向中心，并设置恰好在中心停下的减速
	ball.direction = to_center.normalized()
	var a: float = max(0.0001, (v * v) / max(0.001, 2.0 * d))
	ball.momentum_decay_per_second = a

func _apply_guidance(ball: Node) -> void:
	# 初始时也需要设置一次方向与减速
	_guide_ball_to_center(ball)

func _release_if_tracking(node: Node) -> void:
	# 离开检测区，停止吸附并恢复参数（若尚未结算）
	var ball := _find_ball_from_node(node)
	if ball and _capturing.has(ball):
		var info = _capturing[ball]
		_restore_decay(ball, float(info.original_decay))
		_capturing.erase(ball)

func _find_ball_from_node(node: Node) -> Node:
	if _is_color_ball(node):
		return node
	var current: Node = node
	while current:
		if _is_color_ball(current):
			return current
		current = current.get_parent()
	return null

func _restore_decay(ball: Node, original_decay: float) -> void:
	if _is_color_ball(ball):
		ball.momentum_decay_per_second = original_decay

func _add_score(amount: int) -> void:
	var ls := get_node_or_null("/root/LevelScore")
	if ls == null:
		var candidates := get_tree().get_nodes_in_group("level_score")
		if candidates.size() > 0:
			ls = candidates[0]
	if ls and ls.has_method("add_score"):
		ls.add_score(amount)
