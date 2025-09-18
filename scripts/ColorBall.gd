extends Sprite2D

@export var angular_speed: float = deg_to_rad(90.0)
@export var momentum: float = 0.0
@export var momentum_decay_per_second: float = 80.0
@export var direction: Vector2 = Vector2.RIGHT

var velocity: Vector2 = Vector2.ZERO
var previous_position: Vector2

func _ready():
	previous_position = global_position
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.connect("screen_exited", Callable(self, "_on_screen_exited"))

func _physics_process(delta):
	# 检测碰撞
	check_collisions()

	self.rotation += angular_speed * delta
	
	# 更新前一个位置
	previous_position = global_position

	# 将当前动量转换为速度向量
	if momentum > 0.0:
		velocity = direction.normalized() * momentum
		global_position += velocity * delta
		momentum = max(0.0, momentum - momentum_decay_per_second * delta)
	else:
		velocity = Vector2.ZERO
	

func check_collisions():
	# 使用射线检测来检查是否与 BounceFlat 碰撞
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(previous_position, global_position)
	query.exclude = [self]  # 排除自身
	
	var result = space_state.intersect_ray(query)
	print("check_collisions result", result)
	if result and result.collider:
		var collider = result.collider
		# 检查是否是 BounceFlat
		if collider.name == "BounceFlatStaticBody2D" and collider.get_parent().has_method("handle_colorball_collision"):
			# 触发 BounceFlat 的碰撞处理
			print("hit BounceFlatStaticBody2D")
			collider.get_parent().handle_colorball_collision(self)

func _on_screen_exited():
	queue_free()
