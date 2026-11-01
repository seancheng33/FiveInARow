# difficulty.gd
# 五档难度的唯一数据源：一个级别 = 一层搜索深度。
# 档位与时间预算都是实测出来的（见 tests/depth_probe）：
#   1 层约 0.02 s、2 层约 0.05 s、3 层约 0.4 s、4 层约 6 s、5 层约 15 s。
# 再往上每层约 ×6~8，6 层≈2 分钟，已经不是对局节奏了，所以最高就到专家（5 层）。
class_name Difficulty
extends RefCounted

const DEFAULT := 2          # 默认给「普通」

const LEVELS: Array[Dictionary] = [
	{"name": "入门", "en": "NOVICE", "depth": 1, "budget": 120,
		"label": "入门 · 1 层 · 只看眼前一手"},
	{"name": "简单", "en": "EASY", "depth": 2, "budget": 220,
		"label": "简单 · 2 层 · 会算两步"},
	{"name": "普通", "en": "NORMAL", "depth": 3, "budget": 700,
		"label": "普通 · 3 层 · 会做杀棋（约 0.5 秒）"},
	{"name": "困难", "en": "HARD", "depth": 4, "budget": 7000,
		"label": "困难 · 4 层 · 每步约 6 秒"},
	{"name": "专家", "en": "EXPERT", "depth": 5, "budget": 17000,
		"label": "专家 · 5 层 · 每步约 15 秒"},
]


static func count() -> int:
	return LEVELS.size()


static func level(i: int) -> Dictionary:
	return LEVELS[clampi(i, 0, LEVELS.size() - 1)]


static func name_of(i: int) -> String:
	return str(level(i)["name"])


static func depth_of(i: int) -> int:
	return int(level(i)["depth"])


static func budget_of(i: int) -> int:
	return int(level(i)["budget"])


static func label_of(i: int) -> String:
	return str(level(i)["label"])
