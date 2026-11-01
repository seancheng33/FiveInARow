extends Node
# 棋力对拼探针：可配置预算与局数，结果写 res://tests/match.log
# 用法：godot --headless --path . res://tests/match_probe.tscn

var f: FileAccess

func _ready() -> void:
	f = FileAccess.open("res://tests/match.log", FileAccess.WRITE)
	log_line("=== MATCH PROBE ===")
	var cases := [
		{"name": "困难(250ms) vs 普通", "a": "AdvancedAI", "budget": 250, "b": "DefensiveAI", "games": 4},
		{"name": "困难(650ms) vs 普通", "a": "AdvancedAI", "budget": 650, "b": "DefensiveAI", "games": 6},
		{"name": "困难(650ms) vs 随机", "a": "AdvancedAI", "budget": 650, "b": "RandomAI", "games": 4},
		{"name": "普通 vs 随机", "a": "DefensiveAI", "budget": 0, "b": "RandomAI", "games": 4},
		{"name": "困难 vs 困难(同配置)", "a": "AdvancedAI", "budget": 650, "b": "AdvancedAI", "games": 4},
	]
	for c in cases:
		run_case(c)
	log_line("=== DONE ===")
	f.close()
	get_tree().quit(0)


func log_line(s: String) -> void:
	print(s)
	if f:
		f.store_line(s)
		f.flush()


func make(name: String, budget: int) -> AIBase:
	var ai: AIBase
	match name:
		"AdvancedAI":
			ai = AdvancedAI.new()
			ai.time_budget_ms = budget
		"DefensiveAI":
			ai = DefensiveAI.new()
		_:
			ai = RandomAI.new()
	return ai


func run_case(c: Dictionary) -> void:
	var wins_a := 0
	var wins_b := 0
	var draws := 0
	var bad := 0
	for i in range(int(c["games"])):
		var a_is_black = (i % 2 == 0)
		var black = make(c["a"], int(c["budget"])) if a_is_black else make(c["b"], int(c["budget"]))
		var white = make(c["b"], int(c["budget"])) if a_is_black else make(c["a"], int(c["budget"]))
		var g := GameCore.new()
		var guard := 0
		while g.is_playing() and guard < 300:
			guard += 1
			var ai = black if g.turn == GameCore.BLACK else white
			var mv: Vector2i = ai.get_next_move(g.snapshot(), g.turn)
			if not g.place(mv.x, mv.y):
				bad += 1
				break
		if g.state == GameCore.State.BLACK_WIN:
			if a_is_black: wins_a += 1
			else: wins_b += 1
		elif g.state == GameCore.State.WHITE_WIN:
			if a_is_black: wins_b += 1
			else: wins_a += 1
		elif g.state == GameCore.State.DRAW:
			draws += 1
	log_line("%s -> A胜%d B胜%d 平%d 异常%d" % [c["name"], wins_a, wins_b, draws, bad])
