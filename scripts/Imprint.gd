extends Control
## The big pixel type of the frame. Each screen gets its own composition:
## title centred high (with the rules), live score bottom-right, result centred.
## Amber marks only what changes (the score); everything static is grey.
## Font sizes are whole multiples of the 12 px pixel font, so every glyph stays on one grid.

const LevelStateScript := preload("res://scripts/LevelState.gd")

enum Mode { TITLE, PLAY, END }

const MARGIN := 16
const TITLE_SIZE := 48
const SCORE_SIZE := 24
const PLAY_BOTTOM_CLEARANCE := 18  # keeps the score above the balls line
const TITLE_TOP := 40
const BACKING_PAD := 8  # black margin around the result, in layer pixels
const AMBER := Color(0.941, 0.627, 0.251)
const PAPER := Color(0.93, 0.93, 0.9)

# Looked up on use: LevelState may call in before this node is ready.
@onready var _backing: ColorRect = get_node("Backing")
@onready var _lines: VBoxContainer = get_node("Lines")
@onready var _big: Label = get_node("Lines/Big")
@onready var _rule: ColorRect = get_node("Lines/Rule")
@onready var _small: Label = get_node("Lines/Small")
@onready var _rules: Label = get_node("Lines/Rules")

var _mode := Mode.TITLE
var _won := false
var _score := 0
var _goal := 0


func show_title() -> void:
	_mode = Mode.TITLE
	_refresh()


func show_play(goal: int) -> void:
	_mode = Mode.PLAY
	_goal = goal
	_score = 0
	_refresh()


func set_score(value: int) -> void:
	_score = value
	if _mode == Mode.PLAY:
		_refresh()


func show_end(won: bool, score: int, goal: int) -> void:
	_mode = Mode.END
	_won = won
	_score = score
	_goal = goal
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var score := LevelStateScript.format_number(_score)
	var goal := LevelStateScript.format_number(_goal)
	match _mode:
		Mode.TITLE:
			_big.text = tr("GAME_TITLE")
			_small.text = tr("TITLE_START")
		Mode.PLAY:
			_big.text = score
			_small.text = tr("IMPRINT_TARGET") % goal
		Mode.END:
			_big.text = score
			_small.text = "%s   %s" % [tr("END_WIN") if _won else tr("END_OUT"), tr("END_SCORE") % goal]
	_layout()
	# Wall labels and readouts belong to the level, which is only revealed once play starts.
	for note in get_tree().get_nodes_in_group("annotation"):
		note.visible = _mode != Mode.TITLE


func _layout() -> void:
	_rules.visible = _mode == Mode.TITLE
	_rule.visible = _mode == Mode.END
	_big.add_theme_font_size_override("font_size", SCORE_SIZE if _mode == Mode.PLAY else TITLE_SIZE)
	_big.add_theme_color_override("font_color", PAPER if _mode == Mode.TITLE else AMBER)
	var align := HORIZONTAL_ALIGNMENT_CENTER
	var preset := PRESET_CENTER_TOP
	match _mode:
		Mode.PLAY:
			align = HORIZONTAL_ALIGNMENT_RIGHT
			preset = PRESET_BOTTOM_RIGHT
		Mode.END:
			preset = PRESET_CENTER
	for label: Label in [_big, _small, _rules]:
		label.horizontal_alignment = align
	_lines.reset_size()
	_lines.set_anchors_and_offsets_preset(preset, PRESET_MODE_MINSIZE, MARGIN)
	if _mode == Mode.PLAY:
		_lines.offset_top -= PLAY_BOTTOM_CLEARANCE
		_lines.offset_bottom -= PLAY_BOTTOM_CLEARANCE
	elif _mode == Mode.TITLE:
		_lines.offset_top += TITLE_TOP
		_lines.offset_bottom += TITLE_TOP
	# The result sits in a black window outlined like the frame, so faded tracks never cross it.
	_backing.visible = _mode == Mode.END
	_backing.position = _lines.position - Vector2.ONE * BACKING_PAD
	_backing.size = _lines.size + Vector2.ONE * BACKING_PAD * 2.0


func _ready() -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()
