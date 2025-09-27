extends Camera2D

var is_dragging = false # 是否正在拖动
var last_mouse_pos = Vector2() # 上一次鼠标位置

func _ready():
	# 确保 Camera2D 启用
	enabled = true

func _input(event):
	# 检查 Z 键是否按下
	var z_pressed = Input.is_key_pressed(KEY_Z)
	
	# 鼠标左键按下事件
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if z_pressed and event.pressed:
			# Z 键按下且鼠标左键按下，开始拖动
			is_dragging = true
			last_mouse_pos = event.position
		elif event.is_released():
			# 鼠标左键释放，停止拖动
			is_dragging = false
	
	# 鼠标移动事件
	if event is InputEventMouseMotion and is_dragging and z_pressed:
		# 计算鼠标移动的偏移量
		var mouse_delta = event.position - last_mouse_pos
		# 更新相机位置（注意坐标系，鼠标向下移动应增加 Y 坐标）
		position -= mouse_delta * zoom  # 考虑缩放比例
		last_mouse_pos = event.position
