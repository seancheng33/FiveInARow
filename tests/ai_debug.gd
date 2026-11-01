extends Node
# AI 诊断：把困难档根节点每个候选的「静态棋型分」和「搜索值」打出来，看两者是否打架

var f: FileAccess

func _ready() -> void:
	f = FileAccess.open("res://tests/ai_debug.log", FileAccess.WRITE)
	log_line("=== AI DEBUG ===")
	dump_after_opening()
	f.close()
	get_tree().quit(0)


func log_line(s: String) -> void:
	print(s)
	if f:
		f.store_line(s)
		f.flush()


func dump_after_opening() -> void:
	# 让 普通AI(白) 陪 困难AI(黑) 走 10 手，取一个真实中局
	var g := GameCore.new()
	var adv := AdvancedAI.new()
	adv.time_budget_ms = 650
	var dft := DefensiveAI.new()
	for i in range(10):
		var ai: AIBase = adv if g.turn == GameCore.BLACK else dft
		var mv: Vector2i = ai.get_next_move(g.snapshot(), g.turn)
		g.place(mv.x, mv.y)
	log_line("局面（黑白各 5 手）:")
	for line in g.to_ascii().split("\n"):
		log_line("  " + line)

	# 现在轮到白（普通AI 的一手已下完），换成让困难档执白思考
	var probe := AdvancedAI.new()
	probe.time_budget_ms = 650
	probe.board_size = 15
	probe._cells = g.flat_snapshot()
	probe._size = 15
	probe._me = GameCore.WHITE
	probe._opp = GameCore.BLACK
	probe._deadline = Time.get_ticks_msec() + 650
	probe._stop = false
	probe._nodes = 0
	if probe._lines.is_empty():
		probe._build_lines(15)

	var cands := AIBase.candidates(probe._cells, 15, 2)
	var rows: Array = []
	for c in cands:
		var idx: int = c.y * 15 + c.x
		rows.append({"pos": c, "static": probe.score_move(probe._cells, idx, probe._me, probe._opp)})
	rows.sort_custom(func(a, b): return a["static"] > b["static"])
	if rows.size() > 10:
		rows.resize(10)

	log_line("候选（按静态棋型分排序，前 10）:")
	for r in rows:
		var idx: int = r["pos"].y * 15 + r["pos"].x
		probe._cells[idx] = probe._me
		var v := probe._minimax(3, false, -AdvancedAI.INF, AdvancedAI.INF)
		var ev := probe._evaluate()
		probe._cells[idx] = 0
		log_line("  %s  static=%d  search(depth4)=%d  leaf_eval=%d" % [
			str(r["pos"]), r["static"], v, ev])

	log_line("最终选择: %s" % str(probe.get_next_move(g.snapshot(), GameCore.WHITE)))
	# 普通AI 在同一局面的选择
	var dft2 := DefensiveAI.new()
	log_line("普通AI 选择: %s" % str(dft2.get_next_move(g.snapshot(), GameCore.WHITE)))
