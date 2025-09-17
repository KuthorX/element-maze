extends Sprite2D

@export var angular_speed: float = deg_to_rad(90.0)
@export var momentum: float = 0.0
@export var momentum_decay_per_second: float = 80.0
@export var direction: Vector2 = Vector2.RIGHT

var velocity: Vector2 = Vector2.ZERO

func _physics_process(delta):
	self.rotation += angular_speed * delta

	# 将当前动量转换为速度向量
	if momentum > 0.0:
		velocity = direction.normalized() * momentum
		global_position += velocity * delta
		momentum = max(0.0, momentum - momentum_decay_per_second * delta)
	else:
		velocity = Vector2.ZERO
