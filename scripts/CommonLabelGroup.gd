extends Control

@export var gradient_colors: Array[Color] = []
@export var color_step: float = 1.0
@export var auto_find_labels: bool = true

var _color_index_t: float = 0.0
var _labels: Array[Label] = []

func _ready() -> void:
	if auto_find_labels:
		_find_all_labels()

func _find_all_labels() -> void:
	_labels.clear()
	_collect_labels_recursive(self)

func _collect_labels_recursive(node: Node) -> void:
	if node is Label:
		_labels.append(node)
	
	for child in node.get_children():
		_collect_labels_recursive(child)

func _process(delta: float) -> void:
	if _labels.is_empty():
		return
	
	# 仅依据给定的颜色数组进行离散跳变
	var count := gradient_colors.size()
	if count == 0:
		return
	
	_color_index_t = fposmod(_color_index_t + color_step * delta, float(count))
	var seg_index: int = int(floor(_color_index_t)) % count
	var c: Color = gradient_colors[seg_index]
	
	# 对所有找到的 Label 应用颜色变化
	for label in _labels:
		if is_instance_valid(label):
			label.modulate = Color(c.r, c.g, c.b, label.modulate.a)

# 手动添加 Label 到组中
func add_label(label: Label) -> void:
	if label not in _labels:
		_labels.append(label)

# 从组中移除 Label
func remove_label(label: Label) -> void:
	var index := _labels.find(label)
	if index != -1:
		_labels.remove_at(index)

# 清空所有 Label
func clear_labels() -> void:
	_labels.clear()

# 刷新 Label 列表（重新搜索）
func refresh_labels() -> void:
	_find_all_labels()
