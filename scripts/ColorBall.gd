extends CharacterBody2D

@export var speed: float = 400.0  # 初始速度幅度
@export var friction: float = 0.999  # 速度衰减率（<1 表示逐渐减速）
@export var rotation_factor: float = 0.01  # 速度到角速度的转换系数（从上一版本保留）
## Balls that leave this world-space rect are lost (freed); the print ends long before it.
@export var world_bounds := Rect2(-600, -800, 3800, 2050)

var direction: Vector2 = Vector2.RIGHT  # 初始方向
## Bubble track this ball leaves on the film; owned by the tracks layer, outlives the ball.
var trail: BubbleTrack


func _ready():
	add_to_group("color_ball")
	velocity = direction * speed  # 设置初始速度


func _physics_process(delta: float):
	# 计算角速度，与当前速度模成正比（从上一版本保留）
	var angular_speed = velocity.length() * rotation_factor
	rotation += angular_speed * delta  # 更新旋转

	# 应用速度衰减（如果速度不为零）
	if velocity.length() > 0.1:  # 避免浮点误差导致永不停止
		velocity *= friction

	# 移动并检测碰撞
	var collision_info = move_and_collide(velocity * delta)
	if collision_info:
		var collider = collision_info.get_collider()
		if collider is AnimatableBody2D:
			# 先计算反弹
			velocity = velocity.bounce(collision_info.get_normal())

			# 获取能量板的 speed_boost 参数
			var boost = collider.speed_boost if "speed_boost" in collider else 1.0  # 默认1.0如果未设置

			# 提升速度模（保持方向）
			var current_speed = velocity.length()
			velocity = velocity.normalized() * (current_speed * boost)

			# 处理剩余运动（反弹并应用提升）
			var remainder = collision_info.get_remainder().bounce(collision_info.get_normal())
			remainder = remainder.normalized() * (remainder.length() * boost)  # 应用提升到剩余向量
			move_and_collide(remainder)
			if is_instance_valid(trail):
				trail.spawn_impact(global_position, collision_info.get_normal())

	_extend_trail()
	if not world_bounds.has_point(global_position):
		queue_free()


func _extend_trail() -> void:
	if is_instance_valid(trail):
		trail.add_point(global_position, velocity.length())
