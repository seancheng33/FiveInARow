# random_ai.gd
# 简单难度：在所有空位里随机挑一个（没有任何策略）
class_name RandomAI
extends AIBase


func get_next_move(board_state: Array, _player_type: int) -> Vector2i:
	var size: int = board_state.size()
	board_size = size
	var empty: Array = []
	for x in range(size):
		var col = board_state[x]
		for y in range(size):
			if int(col[y]) == 0:
				empty.append(Vector2i(x, y))
	if empty.is_empty():
		return Vector2i(-1, -1)
	return empty[rng.randi_range(0, empty.size() - 1)]


func get_ai_name() -> String:
	return "随机AI"

func get_difficulty() -> String:
	return "简单"
