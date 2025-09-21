extends RefCounted
class_name GameLogger

## 通用日志输出处理方案
## 支持不同日志级别、颜色输出、文件保存等功能

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
	FATAL = 4
}

# 日志级别名称映射
const LEVEL_NAMES = {
	LogLevel.DEBUG: "DEBUG",
	LogLevel.INFO: "INFO", 
	LogLevel.WARN: "WARN",
	LogLevel.ERROR: "ERROR",
	LogLevel.FATAL: "FATAL"
}

# 日志级别颜色映射（ANSI颜色代码）
const LEVEL_COLORS = {
	LogLevel.DEBUG: "\\033[36m",  # 青色
	LogLevel.INFO: "\\033[32m",   # 绿色
	LogLevel.WARN: "\\033[33m",   # 黄色
	LogLevel.ERROR: "\\033[31m",  # 红色
	LogLevel.FATAL: "\\033[35m"   # 紫色
}

const RESET_COLOR = "\\033[0m"

# 全局配置
static var current_level: LogLevel = LogLevel.DEBUG
static var enable_colors: bool = true
static var enable_timestamp: bool = true
static var enable_caller_info: bool = true
static var log_to_file: bool = true
static var log_file_path: String = "log/game.log"
static var max_log_files: int = 10
static var max_file_size_mb: int = 5
static var rotation_by_time: bool = true
static var rotation_interval_hours: int = 24

# 内部变量
static var _log_file: FileAccess
static var _last_rotation_time: int = 0
static var _current_log_start_time: int = 0

## 设置日志级别
static func set_level(level: LogLevel) -> void:
	current_level = level

## 设置是否启用颜色输出
static func set_colors_enabled(enabled: bool) -> void:
	enable_colors = enabled

## 设置是否启用时间戳
static func set_timestamp_enabled(enabled: bool) -> void:
	enable_timestamp = enabled

## 设置是否启用调用者信息
static func set_caller_info_enabled(enabled: bool) -> void:
	enable_caller_info = enabled

## 设置是否保存到文件
static func set_file_logging(enabled: bool, file_path: String = "log/game.log") -> void:
	log_to_file = enabled
	log_file_path = file_path
	
	if enabled:
		_setup_log_file()
	else:
		_close_log_file()

## 设置日志文件轮转参数
static func set_file_rotation(max_files: int = 10, max_size_mb: int = 5, time_rotation: bool = true, interval_hours: int = 24) -> void:
	max_log_files = max_files
	max_file_size_mb = max_size_mb
	rotation_by_time = time_rotation
	rotation_interval_hours = interval_hours

## 调试日志
static func debug(message: String, context: String = "") -> void:
	_log(LogLevel.DEBUG, message, context)

## 信息日志
static func info(message: String, context: String = "") -> void:
	_log(LogLevel.INFO, message, context)

## 警告日志
static func warn(message: String, context: String = "") -> void:
	_log(LogLevel.WARN, message, context)

## 错误日志
static func error(message: String, context: String = "") -> void:
	_log(LogLevel.ERROR, message, context)

## 致命错误日志
static func fatal(message: String, context: String = "") -> void:
	_log(LogLevel.FATAL, message, context)

## 核心日志方法
static func _log(level: LogLevel, message: String, context: String = "") -> void:
	# 检查日志级别
	if level < current_level:
		return
	
	var log_entry := _format_log_entry(level, message, context)
	
	# 输出到控制台
	_output_to_console(log_entry, level)
	
	# 输出到文件
	if log_to_file:
		_output_to_file(log_entry)

## 格式化日志条目
static func _format_log_entry(level: LogLevel, message: String, context: String = "") -> String:
	var parts: Array[String] = []
	
	# 时间戳
	if enable_timestamp:
		var time = Time.get_datetime_string_from_system()
		parts.append("[%s]" % time)
	
	# 日志级别
	parts.append("[%s]" % LEVEL_NAMES[level])
	
	# 调用者信息
	if enable_caller_info:
		var caller_info = _get_caller_info()
		if caller_info != "":
			parts.append("[%s]" % caller_info)
	
	# 上下文信息
	if context != "":
		parts.append("[%s]" % context)
	
	# 消息内容
	parts.append(message)
	
	return " ".join(parts)

## 获取调用者信息
static func _get_caller_info() -> String:
	var stack = get_stack()
	if stack.size() >= 3:
		var caller = stack[2]
		var file = caller.get("source", "")
		var function = caller.get("function", "")
		var line = caller.get("line", 0)
		
		# 提取文件名（不含路径）
		if file != "":
			file = file.get_file()
		
		if file != "" and function != "":
			return "%s:%s:%d" % [file, function, line]
		elif file != "":
			return "%s:%d" % [file, line]
	
	return ""

## 输出到控制台
static func _output_to_console(log_entry: String, level: LogLevel) -> void:
	if enable_colors:
		var colored_entry = LEVEL_COLORS[level] + log_entry + RESET_COLOR
		print(colored_entry)
	else:
		print(log_entry)

## 输出到文件
static func _output_to_file(log_entry: String) -> void:
	if not _log_file or not _log_file.is_open():
		_setup_log_file()
	
	if _log_file and _log_file.is_open():
		_log_file.store_line(log_entry)
		_log_file.flush()
		
		# 检查是否需要轮转（基于时间或大小）
		_check_rotation_needed()

## 设置日志文件
static func _setup_log_file() -> void:
	_close_log_file()
	
	# 确保日志目录存在
	var dir_path = log_file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	_log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if _log_file:
		_current_log_start_time = int(Time.get_unix_time_from_system())
		_last_rotation_time = _current_log_start_time
		_log_file.store_line("=== Log session started at %s ===" % Time.get_datetime_string_from_system())
		_log_file.flush()

## 关闭日志文件
static func _close_log_file() -> void:
	if _log_file and _log_file.is_open():
		_log_file.store_line("=== Log session ended at %s ===" % Time.get_datetime_string_from_system())
		_log_file.close()
		_log_file = null

## 检查是否需要轮转
static func _check_rotation_needed() -> void:
	if not _log_file or not _log_file.is_open():
		return
	
	var should_rotate = false
	
	# 检查文件大小
	var file_size = _log_file.get_length()
	var max_size_bytes = max_file_size_mb * 1024 * 1024
	if file_size >= max_size_bytes:
		should_rotate = true
		GameLogger.debug("Log rotation triggered by file size: %d bytes >= %d bytes" % [file_size, max_size_bytes], "GameLogger")
	
	# 检查时间间隔
	if rotation_by_time and not should_rotate:
		var current_time = int(Time.get_unix_time_from_system())
		var time_since_rotation = current_time - _last_rotation_time
		var rotation_interval_seconds = rotation_interval_hours * 3600
		
		if time_since_rotation >= rotation_interval_seconds:
			should_rotate = true
			GameLogger.debug("Log rotation triggered by time: %d seconds >= %d seconds" % [time_since_rotation, rotation_interval_seconds], "GameLogger")
	
	if should_rotate:
		_rotate_log_files()

## 轮转日志文件
static func _rotate_log_files() -> void:
	_close_log_file()
	
	# 轮转现有文件
	for i in range(max_log_files - 1, 0, -1):
		var old_file = log_file_path + ".%d" % i
		var new_file = log_file_path + ".%d" % (i + 1)
		
		if FileAccess.file_exists(old_file):
			if i == max_log_files - 1:
				# 删除最旧的文件
				DirAccess.remove_absolute(old_file)
			else:
				# 重命名文件
				DirAccess.rename_absolute(old_file, new_file)
	
	# 轮转当前日志文件
	if FileAccess.file_exists(log_file_path):
		DirAccess.rename_absolute(log_file_path, log_file_path + ".1")
	
	# 更新轮转时间
	_last_rotation_time = int(Time.get_unix_time_from_system())
	
	# 重新打开日志文件
	_setup_log_file()

## 清理日志文件
static func cleanup_log_files() -> void:
	_close_log_file()
	
	# 删除所有日志文件
	if FileAccess.file_exists(log_file_path):
		DirAccess.remove_absolute(log_file_path)
	
	for i in range(1, max_log_files + 1):
		var file = log_file_path + ".%d" % i
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)

## 获取当前日志配置信息
static func get_config_info() -> String:
	return """Logger Configuration:
Level: %s
Colors: %s
Timestamp: %s
Caller Info: %s
File Logging: %s
Log File: %s
Max Files: %d
Max Size: %d MB
Time Rotation: %s
Rotation Interval: %d hours""" % [
	LEVEL_NAMES[current_level],
	enable_colors,
	enable_timestamp,
	enable_caller_info,
	log_to_file,
	log_file_path,
	max_log_files,
	max_file_size_mb,
	rotation_by_time,
	rotation_interval_hours
]

## 便捷方法：打印配置信息
static func print_config() -> void:
	info(get_config_info())
