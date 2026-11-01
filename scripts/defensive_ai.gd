# defensive_ai.gd
# 普通难度：一层棋型评估。先抢自己的五连，再堵对手的五连，其余按棋型分挑最优点。
# 和困难档用的是同一套评分（AIBase.score_move），区别只在于不做搜索。
class_name DefensiveAI
extends AIBase


func get_next_move(board_state: Array, player_type: int) -> Vector2i:
	board_size = board_state.size()
	var cells := AIBase.to_flat(board_state)
	var me := player_type
	var opp := GameCore.opponent(me)
	var size := board_size
	var cands := AIBase.candidates(cells, size, 2)
	if cands.is_empty():
		return Vector2i(-1, -1)

	# 1. 自己能五连
	for c in cands:
		if AIBase.makes_five(cells, size, c.y * size + c.x, me):
			return c

	# 2. 对手能五连（必须堵）
	for c in cands:
		if AIBase.makes_five(cells, size, c.y * size + c.x, opp):
			return c

	# 3. 按棋型评分；同分里随机挑一个，避免每局都一样
	var best_score := -1
	var best: Array = []
	for c in cands:
		var s := score_move(cells, c.y * size + c.x, me, opp)
		if s > best_score:
			best_score = s
			best = [c]
		elif s == best_score:
			best.append(c)
	return pick_tied(best)


func get_ai_name() -> String:
	return "普通AI"

func get_difficulty() -> String:
	return "普通"
