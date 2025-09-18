extends Sprite2D

@export var momentum_absorption_rate: float = 0.3  # 动量吸收率 (0.0-1.0)
@export var bounce_efficiency: float = 0.8  # 反弹效率

func _ready():
	pass

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
