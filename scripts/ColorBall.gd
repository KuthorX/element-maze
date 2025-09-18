extends Sprite2D

@export var angular_speed: float = deg_to_rad(90.0)
@export var momentum: float = 0.0
@export var momentum_decay_per_second: float = 80.0
@export var direction: Vector2 = Vector2.RIGHT

@export var energy_full_alpha: float = 100000.0
@export var energy_zero_alpha: float = 1.0
@export var mass: float = 1.0

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
		
	# 基于动能映射不透明度；速度为 0 时立即销毁
	var current_speed: float = velocity.length()
	if is_zero_approx(current_speed):
		queue_free()
		return
	var current_energy: float = 0.5 * mass * current_speed * current_speed
	var low_energy: float = min(energy_full_alpha, energy_zero_alpha) as float
	var high_energy: float = max(energy_full_alpha, energy_zero_alpha) as float
	if current_energy >= high_energy:
		modulate.a = 1.0
	else:
		var denom_e: float = max(0.0001, high_energy - low_energy)
		var t: float = (current_energy - low_energy) / denom_e
		modulate.a = clamp(t, 0.0, 1.0)


func check_collisions():
	# 使用射线检测来检查是否与 BounceFlat 碰撞
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(previous_position, global_position)
	query.exclude = [self]  # 排除自身
	
	var result = space_state.intersect_ray(query)
	if result and result.collider:
		var collider = result.collider
		# 检查是否是 BounceFlat
		if collider.name == "BounceFlatStaticBody2D" and collider.get_parent().has_method("handle_colorball_collision"):
			# 触发 BounceFlat 的碰撞处理
			collider.get_parent().handle_colorball_collision(self)

func _on_screen_exited():
	queue_free()
