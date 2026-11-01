# board_canvas.gd
# 只负责"画棋盘"和"把鼠标位置翻译成格子坐标"，不碰规则、不碰 AI。
class_name BoardCanvas
extends Control

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const PAD := 20.0

const COL_BOARD_BG := Color(0.87, 0.71, 0.47)
const COL_BOARD_EDGE := Color(0.42, 0.28, 0.15)
const COL_LINE := Color(0.36, 0.24, 0.13)
const COL_STAR := Color(0.28, 0.18, 0.09)
const COL_BLACK := Color(0.11, 0.12, 0.14)
const COL_BLACK_HI := Color(0.42, 0.45, 0.5)
const COL_WHITE := Color(0.97, 0.96, 0.93)
const COL_WHITE_EDGE := Color(0.55, 0.48, 0.4)
const COL_WIN := Color(0.98, 0.31, 0.25)
const COL_LAST := Color(0.9, 0.2, 0.2)

var core: GameCore = null
var hover := Vector2i(-1, -1)
var show_hover := false

var _cell := 40.0
var _origin := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_recalc()


func _on_resized() -> void:
	_recalc()
	queue_redraw()


func set_core(c: GameCore) -> void:
	core = c
	_recalc()
	queue_redraw()


func _recalc() -> void:
	var n := 15
	if core != null:
		n = core.size
	var avail := minf(size.x, size.y) - PAD * 2.0
	if avail <= 10.0:
		avail = 10.0
	_cell = avail / float(n - 1)
	_origin = Vector2(
		(size.x - _cell * (n - 1)) * 0.5,
		(size.y - _cell * (n - 1)) * 0.5)


func cell_center(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell) * _cell


func cell_from_position(pos: Vector2) -> Vector2i:
	_recalc()
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var rel := (pos - _origin) / _cell
	var c := Vector2i(roundi(rel.x), roundi(rel.y))
	var n := 15 if core == null else core.size
	if c.x < 0 or c.x >= n or c.y < 0 or c.y >= n:
		return Vector2i(-1, -1)
	if absf(rel.x - c.x) > 0.45 or absf(rel.y - c.y) > 0.45:
		return Vector2i(-1, -1)
	return c


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := cell_from_position(event.position)
		if c != hover:
			hover = c
			cell_hovered.emit(c)
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var c := cell_from_position(event.position)
			if c.x >= 0:
				cell_clicked.emit(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = Vector2i(-1, -1)
		queue_redraw()


# ---------------- 绘制 ----------------

func _draw() -> void:
	var n := 15
	if core != null:
		n = core.size
	_recalc()

	# 棋盘底板 + 外框
	var board_rect := Rect2(_origin - Vector2(_cell, _cell) * 0.5,
		Vector2(_cell, _cell) * float(n))
	draw_rect(board_rect, COL_BOARD_BG, true)
	draw_rect(board_rect, COL_BOARD_EDGE, false, 2.0)

	# 网格
	var span := _cell * (n - 1)
	for i in range(n):
		var p := _origin + Vector2(0, i * _cell)
		draw_line(p, p + Vector2(span, 0), COL_LINE, 1.0)
		p = _origin + Vector2(i * _cell, 0)
		draw_line(p, p + Vector2(0, span), COL_LINE, 1.0)

	# 星位
	for s in _star_points(n):
		draw_circle(_origin + Vector2(s) * _cell, maxf(2.0, _cell * 0.09), COL_STAR)

	if core == null:
		return

	# 悬停预览
	if show_hover and hover.x >= 0 and core.can_place(hover.x, hover.y):
		var base := COL_BLACK if core.turn == GameCore.BLACK else COL_WHITE
		draw_circle(cell_center(hover), _cell * 0.42, Color(base.r, base.g, base.b, 0.35))

	# 棋子
	for y in range(n):
		for x in range(n):
			var v := core.cells[y * n + x]
			if v == 0:
				continue
			_draw_stone(Vector2i(x, y), v)

	# 最后一手标记
	if not core.history.is_empty():
		var last := core.last_move()
		var lv := core.at(last.x, last.y)
		var dot_col := COL_WHITE if lv == GameCore.BLACK else COL_BLACK
		draw_circle(cell_center(last), maxf(2.0, _cell * 0.11), dot_col)

	# 获胜连线
	if not core.win_line.is_empty():
		for p in core.win_line:
			var v := Vector2i(p)
			draw_arc(cell_center(v), _cell * 0.46, 0, TAU, 28, COL_WIN, maxf(2.0, _cell * 0.07))


func _draw_stone(cell: Vector2i, v: int) -> void:
	var c := cell_center(cell)
	var r := _cell * 0.42
	if v == GameCore.BLACK:
		draw_circle(c, r, COL_BLACK)
		draw_circle(c - Vector2(r, r) * 0.28, r * 0.34, Color(COL_BLACK_HI.r, COL_BLACK_HI.g, COL_BLACK_HI.b, 0.55))
	else:
		draw_circle(c, r, COL_WHITE)
		draw_arc(c, r - 0.5, 0, TAU, 28, COL_WHITE_EDGE, 1.4)
		draw_circle(c - Vector2(r, r) * 0.28, r * 0.3, Color(1, 1, 1, 0.9))


func _star_points(n: int) -> Array:
	if n != 15:
		return []
	var m: int = n / 2
	var q: int = n / 4
	return [Vector2i(q, q), Vector2i(n - 1 - q, q), Vector2i(m, m),
		Vector2i(q, n - 1 - q), Vector2i(n - 1 - q, n - 1 - q)]
