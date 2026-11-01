# board_canvas.gd
# 只负责"画棋盘"和"把鼠标位置翻译成格子坐标"，不碰规则、不碰 AI。
# 所有颜色都来自自动加载单例 AppSkin，切换主题后自动重绘。
class_name BoardCanvas
extends Control

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const PAD := 6.0        # 画布内自身留白
const FRAME := 0.30     # 木质外框宽度（单位：格）

var core: GameCore = null
var hover := Vector2i(-1, -1)
var show_hover := false

var _cell := 40.0
var _origin := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	Ui.changed.connect(_on_skin_changed)
	_recalc()


func _on_resized() -> void:
	_recalc()
	queue_redraw()


func _on_skin_changed() -> void:
	queue_redraw()


func set_core(c: GameCore) -> void:
	core = c
	_recalc()
	queue_redraw()


func _board_size() -> int:
	return 15 if core == null else core.size


# 棋盘（含外框）总宽高 = (n-1) 格 + 两侧各半格 + 两侧外框
func _recalc() -> void:
	var n := _board_size()
	var span := float(n - 1) + 1.0 + FRAME * 2.0
	var avail := minf(size.x, size.y) - PAD * 2.0
	if avail <= 12.0:
		avail = 12.0
	_cell = avail / span
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
	var n := _board_size()
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
	var n := _board_size()
	_recalc()

	var board_rect := Rect2(_origin - Vector2(_cell, _cell) * 0.5, Vector2(_cell, _cell) * float(n))
	var frame_rect := board_rect.grow(_cell * FRAME)

	# 木质外框 + 棋盘面（圆角与阴影都放在 StyleBoxFlat 里）
	draw_style_box(Ui.frame_style, frame_rect)
	draw_style_box(Ui.board_style, board_rect)

	var line_col := Ui.color("board_line")
	var span := _cell * (n - 1)
	var lw := maxf(1.0, _cell * 0.024)
	for i in range(n):
		var p := _origin + Vector2(0, i * _cell)
		draw_line(p, p + Vector2(span, 0), line_col, lw)
		p = _origin + Vector2(i * _cell, 0)
		draw_line(p, p + Vector2(0, span), line_col, lw)

	# 星位
	var star_col := Ui.color("board_star")
	for s in _star_points(n):
		draw_circle(_origin + Vector2(s) * _cell, maxf(2.0, _cell * 0.085), star_col)

	if core == null:
		return

	# 悬停预览
	if show_hover and hover.x >= 0 and core.can_place(hover.x, hover.y):
		var base := Ui.color("stone_black") if core.turn == GameCore.BLACK else Ui.color("stone_white")
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
		var dot_col := Ui.color("accent")
		if lv == GameCore.WHITE:
			dot_col = Ui.color("win")
		draw_circle(cell_center(last), maxf(2.0, _cell * 0.1), dot_col)

	# 获胜连线
	if not core.win_line.is_empty():
		var win_col := Ui.color("win")
		for p in core.win_line:
			var v := Vector2i(p)
			draw_arc(cell_center(v), _cell * 0.46, 0, TAU, 28, win_col, maxf(2.0, _cell * 0.07))


func _draw_stone(cell: Vector2i, v: int) -> void:
	var c := cell_center(cell)
	var r := _cell * 0.42
	if v == GameCore.BLACK:
		var base := Ui.color("stone_black")
		var hi := Ui.color("stone_black_hi")
		draw_circle(c, r, base)
		draw_circle(c - Vector2(r, r) * 0.28, r * 0.32, Color(hi.r, hi.g, hi.b, 0.55))
	else:
		var base := Ui.color("stone_white")
		var edge := Ui.color("stone_white_edge")
		draw_circle(c, r, base)
		draw_arc(c, r - 0.5, 0, TAU, 28, edge, maxf(1.0, _cell * 0.03))
		draw_circle(c - Vector2(r, r) * 0.28, r * 0.28, Color(1, 1, 1, 0.9))


func _star_points(n: int) -> Array:
	if n != 15:
		return []
	var m: int = n / 2
	var q: int = n / 4
	return [Vector2i(q, q), Vector2i(n - 1 - q, q), Vector2i(m, m),
		Vector2i(q, n - 1 - q), Vector2i(n - 1 - q, n - 1 - q)]
