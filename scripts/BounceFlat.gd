extends Sprite2D

@export var momentum_absorption_rate: float = 0.3  # 动量吸收率 (0.0-1.0)
@export var bounce_efficiency: float = 0.8  # 反弹效率
@export var rotation_speed: float = 2.0  # 旋转速度（度/帧）
@export var min_rotation: float = -90.0  # 最小旋转角度
@export var max_rotation: float = 90.0   # 最大旋转角度

var is_dragging: bool = false
var last_mouse_position: Vector2
var interaction_area: Area2D

func _ready():
	# 获取已存在的 TouchArea
	interaction_area = get_node("TouchArea")
	
	# 确保 TouchArea 可以接收输入事件
	interaction_area.input_pickable = true
	
	# 连接输入事件
	interaction_area.input_event.connect(_on_interaction_area_input_event)
	
	GameLogger.debug("TouchArea setup complete - collision_layer: %d, collision_mask: %d" % [interaction_area.collision_layer, interaction_area.collision_mask], "BounceFlat")

func _on_interaction_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	# 处理交互区域内的输入事件
	handle_input_event(event)

func handle_input_event(event: InputEvent):
	if event is InputEventMouseButton:
		handle_mouse_button_event(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion_event(event)
	elif event is InputEventScreenTouch:
		handle_touch_event(event)

func handle_mouse_button_event(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			GameLogger.debug("Mouse pressed on TouchArea", "BounceFlat")
			# 由于事件已经来自 TouchArea，直接开始拖拽
			is_dragging = true
			last_mouse_position = get_global_mouse_position()
		else:
			# 鼠标释放
			GameLogger.debug("Mouse released from TouchArea", "BounceFlat")
			is_dragging = false

func handle_mouse_motion_event(_event: InputEventMouseMotion):
	if is_dragging:
		var current_mouse_position = get_global_mouse_position()
		var delta_y = current_mouse_position.y - last_mouse_position.y
		
		# 根据鼠标移动方向旋转
		# 向下移动：顺时针旋转（正值）
		# 向上移动：逆时针旋转（负值）
		var rotation_delta = delta_y * rotation_speed
		rotate_bounce_flat(rotation_delta)
		
		last_mouse_position = current_mouse_position

func handle_touch_event(event: InputEventScreenTouch):
	if event.pressed:
		GameLogger.debug("Touch pressed on TouchArea", "BounceFlat")
		# 由于事件已经来自 TouchArea，直接开始拖拽
		is_dragging = true
		last_mouse_position = event.position
	else:
		# 触摸释放
		GameLogger.debug("Touch released from TouchArea", "BounceFlat")
		is_dragging = false

func is_point_in_interaction_area(point: Vector2) -> bool:
	# 检查点是否在 TouchArea 的交互区域内
	var collision_shape = interaction_area.get_child(0) as CollisionShape2D
	
	GameLogger.debug("TouchArea collision_shape: %s" % collision_shape, "BounceFlat")
	
	if collision_shape and collision_shape.shape:
		GameLogger.debug("TouchArea shape type: %s" % collision_shape.shape.get_class(), "BounceFlat")
		
		# 将全局坐标转换为 TouchArea 的局部坐标
		var local_point = interaction_area.to_local(point)
		GameLogger.debug("TouchArea local_point: %s" % local_point, "BounceFlat")
		
		# 根据形状类型进行检测
		if collision_shape.shape is RectangleShape2D:
			var rect_shape = collision_shape.shape as RectangleShape2D
			var half_size = rect_shape.size / 2.0
			GameLogger.debug("TouchArea rect_size: %s, half_size: %s" % [rect_shape.size, half_size], "BounceFlat")
			
			# 检查点是否在矩形内（考虑旋转）
			var rotated_point = local_point.rotated(-interaction_area.rotation)
			if abs(rotated_point.x) <= half_size.x and abs(rotated_point.y) <= half_size.y:
				GameLogger.debug("Point is inside TouchArea rectangle", "BounceFlat")
				return true
				
		elif collision_shape.shape is CircleShape2D:
			var circle_shape = collision_shape.shape as CircleShape2D
			GameLogger.debug("TouchArea circle_radius: %s" % circle_shape.radius, "BounceFlat")
			
			if local_point.length() <= circle_shape.radius:
				GameLogger.debug("Point is inside TouchArea circle", "BounceFlat")
				return true
				
		elif collision_shape.shape is CapsuleShape2D:
			var capsule_shape = collision_shape.shape as CapsuleShape2D
			GameLogger.debug("TouchArea capsule_radius: %s, height: %s" % [capsule_shape.radius, capsule_shape.height], "BounceFlat")
			
			var half_height = capsule_shape.height / 2.0
			var rotated_point = local_point.rotated(-interaction_area.rotation)
			
			if abs(rotated_point.y) <= half_height and abs(rotated_point.x) <= capsule_shape.radius:
				GameLogger.debug("Point is inside TouchArea capsule", "BounceFlat")
				return true
	
	GameLogger.debug("Point is outside TouchArea", "BounceFlat")
	return false

func rotate_bounce_flat(delta_rotation: float):
	# 计算新的旋转角度
	var new_rotation_degrees = rad_to_deg(rotation) + delta_rotation
	
	# 限制旋转角度在指定范围内
	new_rotation_degrees = clamp(new_rotation_degrees, min_rotation, max_rotation)
	
	# 应用旋转
	rotation = deg_to_rad(new_rotation_degrees)

func handle_colorball_collision(colorball):
	# 获取 ColorBall 的当前动量和方向
	var current_momentum = colorball.get("momentum")
	var current_direction = colorball.get("direction")
	
	if current_momentum <= 0:
		return
	
	# 计算 BounceFlat 的法向量（垂直于表面的向量）
	var bounce_normal = get_bounce_normal()
	
	# 计算反射向量：direction = direction - 2 * dot(direction, normal) * normal
	var dot_product = current_direction.dot(bounce_normal)
	var reflected_direction = current_direction - 2 * dot_product * bounce_normal
	
	# 应用动量损失和反弹
	var absorbed_momentum = current_momentum * momentum_absorption_rate
	var remaining_momentum = current_momentum - absorbed_momentum
	var bounced_momentum = remaining_momentum * bounce_efficiency
	
	# 更新 ColorBall 的状态
	colorball.set("momentum", bounced_momentum)
	colorball.set("direction", reflected_direction.normalized())

func get_bounce_normal():
	# 根据 BounceFlat 的旋转角度计算法向量
	# 默认法向量向右边，然后根据旋转角度调整
	var rotation_radians = rotation - deg_to_rad(90)
	return Vector2(sin(rotation_radians), -cos(rotation_radians))
