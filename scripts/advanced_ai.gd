# advanced_ai.gd
# 困难难度：Minimax + Alpha-Beta + 迭代加深 + 时间预算。
# 关键设计：
#   1) 搜索直接在扁平棋盘上 make/unmake，不再每个节点深拷贝整盘；
#   2) 每个节点都有时间检查，到点立刻回退到上一层已完成的结果；
#   3) 根节点用完整棋型评分排序，内部节点用廉价的邻接权重排序并截断宽度；
#   4) 叶子评估按"预分割的直线"单遍扫描，避免每格重复数四方向。
class_name AdvancedAI
extends AIBase

const WIN_SCORE := 10000000
const INF := 1 << 30

var search_depth := 4          # 最大搜索深度（菜单可调 1~5）
var time_budget_ms := 650      # 单次思考预算，超时就用上一层结果
var root_width := 14           # 根节点保留的候选数
var inner_width := 9           # 内部节点保留的候选数

var _cells := PackedByteArray()
var _size := 15
var _me := 1
var _opp := 2
var _deadline := 0
var _stop := false
var _nodes := 0
var _lines: Array = []


func _init() -> void:
	super()
	_build_lines(15)


func get_next_move(board_state: Array, player_type: int) -> Vector2i:
	board_size = board_state.size()
	_size = board_size
	_cells = AIBase.to_flat(board_state)
	_me = player_type
	_opp = GameCore.opponent(player_type)
	_deadline = Time.get_ticks_msec() + time_budget_ms
	_stop = false
	_nodes = 0
	if _lines.is_empty() or _lines[0].size() != _size:
		_build_lines(_size)

	var cands := AIBase.candidates(_cells, _size, 2)
	if cands.is_empty():
		return Vector2i(_size / 2, _size / 2)

	# 一步制胜 / 一步必防，先做掉
	for c in cands:
		if AIBase.makes_five(_cells, _size, c.y * _size + c.x, _me):
			return c
	for c in cands:
		if AIBase.makes_five(_cells, _size, c.y * _size + c.x, _opp):
			return c

	# 根节点排序
	var scored: Array = []
	for c in cands:
		scored.append({"pos": c, "score": score_move(_cells, c.y * _size + c.x, _me, _opp)})
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	if scored.size() > root_width:
		scored.resize(root_width)

	var best: Vector2i = scored[0]["pos"]
	var depth := 2
	while depth <= search_depth:
		if Time.get_ticks_msec() > _deadline:
			break
		_stop = false
		var alpha := -INF
		var layer_best := -INF
		var layer_moves: Array = []
		for entry in scored:
			var idx: int = entry["pos"].y * _size + entry["pos"].x
			_cells[idx] = _me
			var val: int
			if AIBase.makes_five(_cells, _size, idx, _me):
				val = WIN_SCORE
			else:
				val = _minimax(depth - 1, false, alpha, INF)
			_cells[idx] = 0
			if val > layer_best:
				layer_best = val
				layer_moves = [entry["pos"]]
			elif val == layer_best:
				layer_moves.append(entry["pos"])
			if layer_best > alpha:
				alpha = layer_best
			if _stop:
				break
		# 只要这一层被时间切断就丢弃它（半层结果比上一层更不可信）
		if _stop:
			break
		if not layer_moves.is_empty():
			best = pick_tied(layer_moves)
		depth += 1

	return best


# ---------------- 搜索核心 ----------------

func _minimax(depth: int, maximizing: bool, alpha: int, beta: int) -> int:
	if _stop:
		return _evaluate()

	_nodes += 1
	if (_nodes & 63) == 0 and Time.get_ticks_msec() > _deadline:
		_stop = true
		return _evaluate()

	if depth <= 0:
		return _evaluate()

	var side := _me if maximizing else _opp
	var cands := _inner_candidates(side)
	if cands.is_empty():
		return _evaluate()

	if maximizing:
		var best := -INF
		for c in cands:
			var idx: int = c.y * _size + c.x
			_cells[idx] = side
			var val: int
			if AIBase.makes_five(_cells, _size, idx, side):
				val = WIN_SCORE - (64 - depth)
			else:
				val = _minimax(depth - 1, false, alpha, beta)
			_cells[idx] = 0
			if val > best:
				best = val
			if best > alpha:
				alpha = best
			if alpha >= beta:
				break
		return best
	else:
		var best2 := INF
		for c in cands:
			var idx: int = c.y * _size + c.x
			_cells[idx] = side
			var val: int
			if AIBase.makes_five(_cells, _size, idx, side):
				val = -WIN_SCORE + (64 - depth)
			else:
				val = _minimax(depth - 1, true, alpha, beta)
			_cells[idx] = 0
			if val < best2:
				best2 = val
			if best2 < beta:
				beta = best2
			if beta <= alpha:
				break
		return best2


# 内部节点候选：
#   1) 谁能一步成五就先走那一步（避免"认为自己不会输"的乐观模型）
#   2) 其余候选与根节点用同一套棋型评分排序，保证搜索里的对手和真实对手一样凶
func _inner_candidates(side: int) -> Array:
	var opp := GameCore.opponent(side)
	var raw: Array = []
	for y in range(_size):
		var row := y * _size
		var y0 := maxi(0, y - 1)
		var y1 := mini(_size - 1, y + 1)
		for x in range(_size):
			var idx := row + x
			if _cells[idx] != 0:
				continue
			if not _has_neighbor1(x, y, y0, y1):
				continue
			raw.append(Vector2i(x, y))

	if raw.is_empty():
		return []

	for c in raw:
		if AIBase.makes_five(_cells, _size, c.y * _size + c.x, side):
			return [c]

	if raw.size() <= inner_width:
		return raw

	var scored: Array = []
	for c in raw:
		scored.append({"pos": c, "w": score_move(_cells, c.y * _size + c.x, side, opp)})
	scored.sort_custom(func(a, b): return a["w"] > b["w"])
	scored.resize(inner_width)
	return scored.map(func(e): return e["pos"])


func _has_neighbor1(x: int, y: int, y0: int, y1: int) -> bool:
	var x0 := maxi(0, x - 1)
	var x1 := mini(_size - 1, x + 1)
	for ny in range(y0, y1 + 1):
		var row := ny * _size
		for nx in range(x0, x1 + 1):
			if nx == x and ny == y:
				continue
			if _cells[row + nx] != 0:
				return true
	return false


# ---------------- 评估 ----------------

func _evaluate() -> int:
	var my := 0
	var op := 0
	for line in _lines:
		var n: int = line.size()
		var i := 0
		while i < n:
			var v: int = _cells[line[i]]
			if v == 0:
				i += 1
				continue
			var j := i + 1
			while j < n and _cells[line[j]] == v:
				j += 1
			var run := j - i
			var open_a := 1 if (i > 0 and _cells[line[i - 1]] == 0) else 0
			var open_b := 1 if (j < n and _cells[line[j]] == 0) else 0
			var s := _run_score(run, open_a + open_b)
			if v == _me:
				my += s
			else:
				op += s
			i = j
	return my - int(op * 1.25)


static func _run_score(run: int, open_count: int) -> int:
	if run >= 5:
		return WIN_SCORE
	if open_count == 0:
		return 0
	if run == 4:
		return 120000 if open_count == 2 else 12000
	if run == 3:
		return 8000 if open_count == 2 else 700
	if run == 2:
		return 400 if open_count == 2 else 60
	return 20 if open_count == 2 else 4


# 预先把所有直线（横/竖/两斜）切成下标数组，评估时顺序访问
func _build_lines(size: int) -> void:
	_lines = []
	for y in range(size):
		var l := PackedInt32Array()
		for x in range(size):
			l.append(y * size + x)
		_lines.append(l)
	for x in range(size):
		var l := PackedInt32Array()
		for y in range(size):
			l.append(y * size + x)
		_lines.append(l)
	for y in range(size):
		var l := PackedInt32Array()
		var cx := 0
		var cy := y
		while cx < size and cy < size:
			l.append(cy * size + cx)
			cx += 1
			cy += 1
		_lines.append(l)
	for x in range(1, size):
		var l := PackedInt32Array()
		var cx := x
		var cy := 0
		while cx < size and cy < size:
			l.append(cy * size + cx)
			cx += 1
			cy += 1
		_lines.append(l)
	for y in range(size):
		var l := PackedInt32Array()
		var cx := 0
		var cy := y
		while cx < size and cy >= 0:
			l.append(cy * size + cx)
			cx += 1
			cy -= 1
		_lines.append(l)
	for x in range(1, size):
		var l := PackedInt32Array()
		var cx := x
		var cy := size - 1
		while cx < size and cy >= 0:
			l.append(cy * size + cx)
			cx += 1
			cy -= 1
		_lines.append(l)


func get_ai_name() -> String:
	return "困难AI"

func get_difficulty() -> String:
	return "困难"
