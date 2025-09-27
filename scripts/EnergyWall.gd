extends AnimatableBody2D

@export var speed_boost: float = 1.2  # 速度提升倍数
@export var min_rotation_degrees: float = -180.0  # 最小旋转角度（度）
@export var max_rotation_degrees: float = 180.0  # 最大旋转角度（度）
@export var rotation_step: float = 5.0  # 每次滚轮旋转的角度（度）
@export var rotation_smoothing: float = 100.0  # 旋转平滑速度（越大越快）

var mouse_inside: bool = false  # 鼠标是否在 TouchArea 内
var target_rotation: float = 0.0  # 目标旋转（弧度）
var interaction_area: Area2D

func _ready():
	# 初始化目标旋转
	target_rotation = rotation
	
	# 获取 TouchArea 节点
	interaction_area = $TouchArea if has_node("TouchArea") else null
	if interaction_area and interaction_area is Area2D:
		interaction_area.input_pickable = true
		# 连接鼠标进入/离开信号
		if not interaction_area.is_connected("mouse_entered", _on_mouse_entered):
			interaction_area.connect("mouse_entered", _on_mouse_entered)
		if not interaction_area.is_connected("mouse_exited", _on_mouse_exited):
			interaction_area.connect("mouse_exited", _on_mouse_exited)
		# 连接输入事件
		if not interaction_area.is_connected("input_event", _on_touch_area_input_event):
			interaction_area.connect("input_event", _on_touch_area_input_event)
		print("TouchArea signals connected")
	else:
		push_error("TouchArea not found or not an Area2D")

func _on_mouse_entered():
	mouse_inside = true
	print("Mouse entered TouchArea")

func _on_mouse_exited():
	mouse_inside = false
	print("Mouse exited TouchArea")

func _on_touch_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if mouse_inside and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# 滚轮上滚，顺时针旋转
			var new_rotation_deg = rad_to_deg(target_rotation) + rotation_step
			new_rotation_deg = clamp(new_rotation_deg, min_rotation_degrees, max_rotation_degrees)
			target_rotation = deg_to_rad(new_rotation_deg)
			print("Wheel up, target rotation: ", new_rotation_deg)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# 滚轮下滚，逆时针旋转
			var new_rotation_deg = rad_to_deg(target_rotation) - rotation_step
			new_rotation_deg = clamp(new_rotation_deg, min_rotation_degrees, max_rotation_degrees)
			target_rotation = deg_to_rad(new_rotation_deg)
			print("Wheel down, target rotation: ", new_rotation_deg)

func _process(delta: float):
	# 平滑旋转到目标角度
	if abs(rotation - target_rotation) > 0.01:  # 避免微小抖动
		rotation = lerp_angle(rotation, target_rotation, rotation_smoothing * delta)
