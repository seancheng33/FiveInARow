# ai_base.gd
# AI 基类：RefCounted（不进场景树），提供共用的棋盘转换、候选点生成与落点评分工具。
class_name AIBase
extends RefCounted

const DEFAULT_SIZE := 15

var board_size: int = DEFAULT_SIZE
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


# 子类实现：返回落点，无路可走时返回 Vector2i(-1, -1)
func get_next_move(_board_state: Array, _player_type: int) -> Vector2i:
	push_error("AIBase.get_next_move() 必须在子类中重写")
	return Vector2i(-1, -1)


func get_ai_name() -> String:
	return "AI"

func get_difficulty() -> String:
	return "未定义"


# ---------- 共用工具 ----------

# Array[x][y] 快照 -> 扁平 PackedByteArray（idx = y * size + x）
static func to_flat(board_state: Array) -> PackedByteArray:
	var size: int = board_state.size()
	var flat := PackedByteArray()
	flat.resize(size * size)
	for x in range(size):
		var col = board_state[x]
		for y in range(size):
			flat[y * size + x] = int(col[y])
	return flat


# 只保留"附近有子"的空点，避免把棋盘角上的孤立空点当候选
static func candidates(cells: PackedByteArray, size: int, radius: int = 2) -> Array:
	var out: Array = []
	var any_stone := false
	for y in range(size):
		for x in range(size):
			if cells[y * size + x] != 0:
				any_stone = true
				break
		if any_stone:
			break

	if not any_stone:
		out.append(Vector2i(size / 2, size / 2))
		return out

	for y in range(size):
		for x in range(size):
			if cells[y * size + x] != 0:
				continue
			if _has_neighbor(cells, size, x, y, radius):
				out.append(Vector2i(x, y))
	return out


static func _has_neighbor(cells: PackedByteArray, size: int, x: int, y: int, radius: int) -> bool:
	var x0 := maxi(0, x - radius)
	var x1 := mini(size - 1, x + radius)
	var y0 := maxi(0, y - radius)
	var y1 := mini(size - 1, y + radius)
	for ny in range(y0, y1 + 1):
		var row := ny * size
		for nx in range(x0, x1 + 1):
			if cells[row + nx] != 0:
				return true
	return false


# 在扁平棋盘上判断 idx 处落子后是否五连（不修改棋盘）
static func makes_five(cells: PackedByteArray, size: int, idx: int, player: int) -> bool:
	var x: int = idx % size
	var y: int = idx / size
	for d in GameCore.DIRS:
		var n := 1
		var cx: int = x + d.x
		var cy: int = y + d.y
		while cx >= 0 and cx < size and cy >= 0 and cy < size and cells[cy * size + cx] == player:
			n += 1
			cx += d.x
			cy += d.y
		cx = x - d.x
		cy = y - d.y
		while cx >= 0 and cx < size and cy >= 0 and cy < size and cells[cy * size + cx] == player:
			n += 1
			cx -= d.x
			cy -= d.y
		if n >= 5:
			return true
	return false


# 邻近棋子密度（廉价的着法排序依据）
static func neighbor_weight(cells: PackedByteArray, size: int, x: int, y: int, player: int) -> int:
	var w := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or nx >= size or ny < 0 or ny >= size:
				continue
			var v := cells[ny * size + nx]
			if v == player:
				w += 3
			elif v != 0:
				w += 2
	return w


static func center_bonus(x: int, y: int, size: int) -> int:
	var c := size / 2
	return maxi(0, (size - (absi(x - c) + absi(y - c))))


# 候选点综合评分：进攻分 + 防守分。idx 为扁平下标。
func score_move(cells: PackedByteArray, idx: int, me: int, opp: int) -> int:
	var size: int = board_size
	var x: int = idx % size
	var y: int = idx / size

	cells[idx] = me
	var my_type := PatternDetector.analyze(cells, size, x, y, me)
	cells[idx] = opp
	var opp_type := PatternDetector.analyze(cells, size, x, y, opp)
	cells[idx] = 0

	var s := PatternDetector.score_of(my_type) * 2 + int(PatternDetector.score_of(opp_type) * 1.5)
	s += center_bonus(x, y, size) * 2
	s += neighbor_weight(cells, size, x, y, me)
	return s


func pick_tied(best_list: Array) -> Vector2i:
	if best_list.is_empty():
		return Vector2i(-1, -1)
	return best_list[rng.randi_range(0, best_list.size() - 1)]
