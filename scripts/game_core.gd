# game_core.gd
# 五子棋纯规则层：不含任何渲染、输入、AI 逻辑，可脱离场景树直接单测。
# 坐标约定：x = 列（左右），y = 行（上下），内部用扁平数组 idx = y * size + x 存储。
class_name GameCore
extends RefCounted

const SIZE := 15

const EMPTY := 0
const BLACK := 1
const WHITE := 2

# 四个方向：横、竖、右下斜、右上斜
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(1, -1),
]

enum State {
	PLAYING,
	BLACK_WIN,
	WHITE_WIN,
	DRAW,
}

var size: int = SIZE
var cells := PackedByteArray()   # idx = y * size + x
var turn: int = BLACK            # 当前该谁走
var state: int = State.PLAYING
var win_line: Array = []         # 获胜的那条线（长度 >= 5），仅在分出胜负时非空
var history: Array = []          # [{idx, x, y, stone, state_before}]


func _init(board_size: int = SIZE) -> void:
	size = board_size
	reset()


func reset() -> void:
	cells = PackedByteArray()
	cells.resize(size * size)
	cells.fill(EMPTY)
	turn = BLACK
	state = State.PLAYING
	win_line = []
	history = []


# ---------- 基础查询 ----------

func idx(x: int, y: int) -> int:
	return y * size + x


func inside(x: int, y: int) -> bool:
	return x >= 0 and x < size and y >= 0 and y < size


func at(x: int, y: int) -> int:
	if not inside(x, y):
		return -1
	return cells[idx(x, y)]


func is_playing() -> bool:
	return state == State.PLAYING


func is_full() -> bool:
	return history.size() >= size * size


func move_count() -> int:
	return history.size()


func last_move() -> Vector2i:
	if history.is_empty():
		return Vector2i(-1, -1)
	var rec: Dictionary = history.back()
	return Vector2i(rec["x"], rec["y"])


# 规则层面的合法性（不包含"现在轮到谁""这一方是不是人类"这类对局控制）
func can_place(x: int, y: int) -> bool:
	if state != State.PLAYING:
		return false
	if not inside(x, y):
		return false
	return cells[idx(x, y)] == EMPTY


# ---------- 落子 ----------

# 返回 true 表示落子成功。失败原因可通过 state / can_place 判断。
func place(x: int, y: int) -> bool:
	if not can_place(x, y):
		return false

	var stone := turn
	var i := idx(x, y)
	cells[i] = stone
	history.append({
		"idx": i,
		"x": x,
		"y": y,
		"stone": stone,
		"state_before": state,
	})

	var line := find_five(x, y, stone)
	if not line.is_empty():
		win_line = line
		state = State.BLACK_WIN if stone == BLACK else State.WHITE_WIN
		# 分出胜负后 turn 保持不变（仍停在获胜方，便于界面显示）
	elif is_full():
		state = State.DRAW
	else:
		turn = opponent(stone)
	return true


# 悔棋一步。返回 true 表示撤掉了。
func undo() -> bool:
	if history.is_empty():
		return false
	var rec: Dictionary = history.pop_back()
	cells[rec["idx"]] = EMPTY
	state = rec["state_before"]
	# 撤掉这一手之后，重新轮到刚撤掉的那一方
	turn = rec["stone"]
	win_line = []
	return true


# ---------- 胜负 ----------

static func opponent(stone: int) -> int:
	return WHITE if stone == BLACK else BLACK


# 找出以 (x, y) 为落点、沿某方向构成的连续同色线；达到 5 连即返回整条线
func find_five(x: int, y: int, stone: int) -> Array:
	for d in DIRS:
		var before: Array = []
		var cx: int = x - d.x
		var cy: int = y - d.y
		while inside(cx, cy) and cells[idx(cx, cy)] == stone:
			before.append(Vector2i(cx, cy))
			cx -= d.x
			cy -= d.y

		var after: Array = []
		cx = x + d.x
		cy = y + d.y
		while inside(cx, cy) and cells[idx(cx, cy)] == stone:
			after.append(Vector2i(cx, cy))
			cx += d.x
			cy += d.y

		if before.size() + 1 + after.size() >= 5:
			before.reverse()
			var line: Array = before
			line.append(Vector2i(x, y))
			line.append_array(after)
			return line

	return []


# ---------- 给 AI / 存档的快照 ----------

# 兼容旧 AI 接口：Array[x][y]，每列一个 PackedByteArray
func snapshot() -> Array:
	var out: Array = []
	out.resize(size)
	for x in range(size):
		var col := PackedByteArray()
		col.resize(size)
		for y in range(size):
			col[y] = cells[idx(x, y)]
		out[x] = col
	return out


func flat_snapshot() -> PackedByteArray:
	return cells.duplicate()


# ---------- 调试 ----------

func to_ascii() -> String:
	var lines: Array = []
	for y in range(size):
		var s := ""
		for x in range(size):
			match cells[idx(x, y)]:
				EMPTY: s += "."
				BLACK: s += "X"
				_: s += "O"
		lines.append(s)
	return "\n".join(lines)
