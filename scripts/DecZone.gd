extends Area2D

@export var deceleration_rate: float = 0.5  # 减速速率（每秒损失的比例，0.0-1.0）
@export var opacity_speed: float = 2.0  # 不透明度变化速度（周期/秒）
@export var min_opacity: float = 0.3  # 最小不透明度（0.0-1.0）
@export var max_opacity: float = 1.0  # 最大不透明度（0.0-1.0）

var bodies_inside: Array[CharacterBody2D] = []  # 跟踪进入的 CharacterBody2D
var _sprite: CanvasItem
var _opacity_timer: float = 0.0  # 用于不透明度变化的计时器
var _fizz_timer: float = 0.0

const FIZZ_REPEAT := 0.5  # seconds between fizz bursts while a ball boils through
const FIZZ_MIN_SPEED := 25.0

func _ready():
	# 获取 Sprite2D 子节点
	_sprite = $Visual if has_node("Visual") else null
	if not _sprite:
		push_warning("Visual node not found")
	
	# 连接信号
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)
	if not is_connected("body_exited", _on_body_exited):
		connect("body_exited", _on_body_exited)
	print("DecelerationZone signals connected")

func _process(delta: float):
	# 更新不透明度
	if _sprite:
		_opacity_timer += delta * opacity_speed
		var t = (sin(_opacity_timer) + 1.0) / 2.0  # 映射到 [0, 1]
		var opacity = lerp(min_opacity, max_opacity, t)
		_sprite.modulate.a = opacity

func _physics_process(delta: float):
	# 处理减速
	for body in bodies_inside:
		if is_instance_valid(body):
			# 应用减速（velocity 乘以 (1 - rate * delta)）
			body.velocity *= (1 - deceleration_rate * delta)
			# 防止速度反转或过小
			if body.velocity.length() < 1.0:
				body.velocity = Vector2.ZERO
	_update_fizz(delta)


## Keeps the zone boiling audibly while a moving ball is inside it.
func _update_fizz(delta: float) -> void:
	var moving := bodies_inside.any(func(b): return is_instance_valid(b) and b.velocity.length() > FIZZ_MIN_SPEED)
	if not moving:
		_fizz_timer = 0.0
		return
	_fizz_timer += delta
	if _fizz_timer >= FIZZ_REPEAT:
		_fizz_timer = 0.0
		Audio.play("fizz")

func _on_body_entered(body: Node):
	if body is CharacterBody2D:
		bodies_inside.append(body)
		Audio.play("fizz")
		print("CharacterBody2D entered deceleration zone: ", body.name)

func _on_body_exited(body: Node):
	if body is CharacterBody2D:
		bodies_inside.erase(body)
		print("CharacterBody2D exited deceleration zone: ", body.name)
