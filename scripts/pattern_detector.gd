# pattern_detector.gd
# 棋型识别：把落点周围 11 格编码成字符串再做模式匹配，支持"跳三/跳四"这类带空档的棋型。
# 编码字符：1 = 己方，0 = 空点，2 = 阻挡（对方棋子或棋盘外）
class_name PatternDetector
extends RefCounted

enum Type {
	NONE,
	LIVE_TWO,
	BLOCK_TWO,
	LIVE_THREE,
	BLOCK_THREE,
	LIVE_FOUR,
	BLOCK_FOUR,
	FIVE,
}

const WINDOW := 5          # 中心向两侧各取 5 格
const CENTER := 5          # 中心在 11 字符串中的下标

const SCORES := {
	Type.NONE: 0,
	Type.LIVE_TWO: 400,
	Type.BLOCK_TWO: 50,
	Type.LIVE_THREE: 8000,
	Type.BLOCK_THREE: 700,
	Type.LIVE_FOUR: 100000,
	Type.BLOCK_FOUR: 12000,
	Type.FIVE: 10000000,
}

# 强到弱依次匹配；同一档内命中任意一个即算
const PATTERNS := [
	[Type.FIVE, ["11111"]],
	[Type.LIVE_FOUR, ["011110"]],
	[Type.BLOCK_FOUR, ["211110", "011112", "10111", "11011", "11101"]],
	[Type.LIVE_THREE, ["01110", "010110", "011010"]],
	[Type.BLOCK_THREE, [
		"211100", "001112", "211010", "010112", "210110", "011012",
		"10011", "11001", "10101",
	]],
	[Type.LIVE_TWO, ["00110", "01100", "01010", "010010"]],
	[Type.BLOCK_TWO, [
		"211000", "000112", "210100", "001012", "210010", "010012",
		"10001",
	]],
]

static func score_of(t: int) -> int:
	return int(SCORES.get(t, 0))


# 单方向：以 (x, y) 为中心取窗口，判断落在这里能形成什么棋型
static func line_type(cells: PackedByteArray, size: int, x: int, y: int, player: int, dir: Vector2i) -> int:
	var s := ""
	for step in range(-WINDOW, WINDOW + 1):
		var cx: int = x + dir.x * step
		var cy: int = y + dir.y * step
		if cx < 0 or cx >= size or cy < 0 or cy >= size:
			s += "2"
		else:
			var v := cells[cy * size + cx]
			if v == player:
				s += "1"
			elif v == 0:
				s += "0"
			else:
				s += "2"
	for entry in PATTERNS:
		var pats: Array = entry[1]
		var kind: int = entry[0]
		for pat in pats:
			if _match_with_center(s, str(pat), CENTER):
				return kind
	return Type.NONE


# 四方向取最强
static func analyze(cells: PackedByteArray, size: int, x: int, y: int, player: int) -> int:
	var best := Type.NONE
	for d in GameCore.DIRS:
		var t: int = line_type(cells, size, x, y, player, d)
		if t > best:
			best = t
			if best == Type.FIVE:
				break
	return best


# 该棋型是否属于"能赢/必须防"级别
static func is_threat(t: int) -> bool:
	return t >= Type.LIVE_FOUR


static func _match_with_center(s: String, pat: String, center: int) -> bool:
	var from := 0
	while true:
		var p := s.find(pat, from)
		if p < 0:
			return false
		if p <= center and center < p + pat.length():
			return true
		from = p + 1
	return false
