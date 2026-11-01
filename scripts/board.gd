# board.gd
# 对局控制器：持有 GameCore、负责输入守卫、AI 调度（后台线程）、界面刷新。
extends Control

signal return_to_menu

enum Mode { PVP, PVE, EVE }

const AI_MIN_THINK_MS := 360

@onready var _bg: TextureRect = %Bg
@onready var _canvas: BoardCanvas = %Canvas
@onready var _mode_label: Label = %ModeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _undo_btn: Button = %UndoButton
@onready var _restart_btn: Button = %RestartButton
@onready var _back_btn: Button = %BackButton
@onready var _hint: Label = %HintLabel
@onready var _result: Control = %Result
@onready var _dim: ColorRect = %Dim
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _again_btn: Button = %AgainButton
@onready var _result_undo_btn: Button = %ResultUndoButton
@onready var _result_back_btn: Button = %ResultBackButton

var core := GameCore.new()

var mode: int = Mode.PVP
var difficulty := 1
var ai_is_black := false
var search_depth := 4
var min_think_ms := AI_MIN_THINK_MS

var _ai_black: AIBase = null
var _ai_white: AIBase = null

var _thread: Thread = null
var _thread_move := Vector2i(-1, -1)
var _thinking := false
var _think_start := 0
var _think_ready_at := 0
var _dots := 0
var _dot_timer := 0.0


func _ready() -> void:
	Ui.changed.connect(_on_skin_changed)
	_on_skin_changed()
	_canvas.set_core(core)
	_canvas.cell_clicked.connect(_on_cell_clicked)
	_canvas.cell_hovered.connect(_on_cell_hovered)
	_undo_btn.pressed.connect(_on_undo)
	_restart_btn.pressed.connect(_on_restart)
	_back_btn.pressed.connect(_on_back)
	_again_btn.pressed.connect(_on_restart)
	_result_undo_btn.pressed.connect(_on_undo)
	_result_back_btn.pressed.connect(_on_back)
	_result.visible = false
	_apply_setup()


func _on_skin_changed() -> void:
	theme = Ui.theme
	_bg.texture = Ui.bg_texture()
	if is_instance_valid(_dim):
		_dim.color = Ui.color("scrim")


# 主菜单在 add_child 之前调用；若已经在场景树里则立即生效
func configure(m: int, diff: int, ai_first: bool) -> void:
	mode = m
	difficulty = diff
	ai_is_black = ai_first
	if is_node_ready():
		_apply_setup()


func _apply_setup() -> void:
	_stop_ai()
	_ai_black = null
	_ai_white = null
	match mode:
		Mode.PVE:
			if ai_is_black:
				_ai_black = _make_ai(difficulty)
			else:
				_ai_white = _make_ai(difficulty)
		Mode.EVE:
			_ai_black = _make_ai(difficulty)
			_ai_white = _make_ai(difficulty)
	core.reset()
	_result.visible = false
	_canvas.queue_redraw()
	_update_ui()
	_maybe_start_ai()


func _make_ai(diff: int) -> AIBase:
	var ai: AIBase
	match diff:
		0:
			ai = RandomAI.new()
		2:
			ai = AdvancedAI.new()
			ai.search_depth = search_depth
		_:
			ai = DefensiveAI.new()
	return ai


# ---------------- 回合判断 ----------------

func human_color() -> int:
	return GameCore.WHITE if ai_is_black else GameCore.BLACK


func is_human_turn() -> bool:
	if not core.is_playing():
		return false
	match mode:
		Mode.PVP:
			return true
		Mode.PVE:
			return core.turn == human_color()
	return false


# 人类这一下能不能落：游戏在跑 + 不是 AI 回合 + AI 没在思考
func can_human_play() -> bool:
	if not is_human_turn():
		return false
	if _thinking or _thread != null:
		return false
	return true


func ai_color_name() -> String:
	return "黑" if ai_is_black else "白"


# ---------------- 输入 ----------------

func _on_cell_clicked(cell: Vector2i) -> void:
	if not can_human_play():
		return
	if not core.can_place(cell.x, cell.y):
		return
	core.place(cell.x, cell.y)
	_after_move()


func _on_cell_hovered(_cell: Vector2i) -> void:
	_canvas.show_hover = can_human_play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_on_restart()
			KEY_U:
				_on_undo()
			KEY_ESCAPE:
				_on_back()


func _after_move() -> void:
	_canvas.queue_redraw()
	_update_ui()
	if not core.is_playing():
		_show_result()
	else:
		_maybe_start_ai()


# ---------------- AI 调度 ----------------

func _maybe_start_ai() -> void:
	if not core.is_playing():
		return
	if _thinking or _thread != null:
		return
	if mode == Mode.PVP:
		return
	var is_ai := true
	if mode == Mode.PVE:
		is_ai = core.turn != human_color()
	if not is_ai:
		return
	var ai: AIBase = _ai_black if core.turn == GameCore.BLACK else _ai_white
	if ai == null:
		return

	_thinking = true
	_dots = 0
	_dot_timer = 0.0
	_think_start = Time.get_ticks_msec()
	_think_ready_at = 0
	_thread_move = Vector2i(-1, -1)
	_thread = Thread.new()
	_thread.start(_ai_worker.bind(ai, core.snapshot(), core.turn))
	_update_ui()


func _ai_worker(ai: AIBase, snapshot: Array, player: int) -> void:
	_thread_move = ai.get_next_move(snapshot, player)


func _process(delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
		_think_ready_at = maxi(Time.get_ticks_msec(), _think_start + min_think_ms)

	if _thinking:
		if _thread == null and Time.get_ticks_msec() >= _think_ready_at:
			_apply_ai_move()
		else:
			_dot_timer += delta
			if _dot_timer >= 0.25:
				_dot_timer = 0.0
				_dots = (_dots + 1) % 4
				_update_ui()
		return

	_maybe_start_ai()


func _apply_ai_move() -> void:
	_thinking = false
	_dots = 0
	var mv := _thread_move
	if core.can_place(mv.x, mv.y):
		core.place(mv.x, mv.y)
	else:
		# 兜底：AI 没给出合法点也不能让对局卡死
		var fb := _first_empty()
		if fb.x >= 0:
			core.place(fb.x, fb.y)
	_after_move()


func _first_empty() -> Vector2i:
	for y in range(core.size):
		for x in range(core.size):
			if core.at(x, y) == GameCore.EMPTY:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _stop_ai() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_thinking = false
	_dots = 0


# ---------------- 按钮 ----------------

func _on_undo() -> void:
	_stop_ai()
	_result.visible = false
	if not core.undo():
		_update_ui()
		return
	# 人机模式：撤到"轮到人类"为止（通常撤两步）
	if mode == Mode.PVE and core.turn != human_color():
		core.undo()
	_canvas.queue_redraw()
	_update_ui()


func _on_restart() -> void:
	_stop_ai()
	core.reset()
	_result.visible = false
	_canvas.queue_redraw()
	_update_ui()
	_maybe_start_ai()


func _on_back() -> void:
	_stop_ai()
	return_to_menu.emit()


func _exit_tree() -> void:
	_stop_ai()


# ---------------- 界面刷新 ----------------

func _update_ui() -> void:
	_mode_label.text = _mode_text()
	_status_label.text = _status_text()
	_undo_btn.disabled = core.history.is_empty() or _thinking
	_hint.text = "R 重开 · U 悔棋 · Esc 返回菜单"


func _mode_text() -> String:
	var names: Array[String] = ["简单", "普通", "困难"]
	var diff_name: String = names[clampi(difficulty, 0, 2)]
	match mode:
		Mode.PVP:
			return "双人对战"
		Mode.PVE:
			return "人机对战 · 玩家执%s · %s" % ["黑" if not ai_is_black else "白", diff_name]
		Mode.EVE:
			return "AI 对战 · %s" % diff_name
	return ""


func _status_text() -> String:
	if not core.is_playing():
		return "对局结束"
	if _thinking:
		return "AI 思考中" + ".".repeat(_dots)
	if mode == Mode.PVP:
		return "轮到%s方" % ("黑" if core.turn == GameCore.BLACK else "白")
	if mode == Mode.EVE:
		return "AI 对战中"
	return "轮到你（%s）" % ("黑" if core.turn == GameCore.BLACK else "白")


func _show_result() -> void:
	var who := ""
	match core.state:
		GameCore.State.BLACK_WIN:
			who = "黑方获胜"
		GameCore.State.WHITE_WIN:
			who = "白方获胜"
		GameCore.State.DRAW:
			who = "平局"
	if mode != Mode.PVP and who != "":
		var winner_color := GameCore.BLACK if core.state == GameCore.State.BLACK_WIN else GameCore.WHITE
		if mode == Mode.PVE:
			who += "（%s）" % ("你赢了" if winner_color == human_color() else "AI 赢了")
	_result_title.text = who
	_result_detail.text = "共 %d 手" % core.move_count()
	_result.visible = true
	_update_ui()
