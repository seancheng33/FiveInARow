extends Node
# 深度极限探针：同一中局下给不同时间预算，看 AI 实际能完成到第几层

var f: FileAccess
var board: GameCore


func _ready() -> void:
	f = FileAccess.open("res://tests/depth.log", FileAccess.WRITE)
	log_line("=== DEPTH PROBE ===")
	board = build_midgame()
	log_line("中局 %d 手" % board.move_count())

	for budget in [400, 1000, 2500, 6000, 15000]:
		probe(budget)
	log_line("=== DONE ===")
	f.close()
	get_tree().quit(0)


func log_line(s: String) -> void:
	print(s)
	if f:
		f.store_line(s)
		f.flush()


func probe(budget_ms: int) -> void:
	var ai := AdvancedAI.new()
	ai.time_budget_ms = budget_ms
	ai.search_depth = 20
	var t0 := Time.get_ticks_msec()
	var mv: Vector2i = ai.get_next_move(board.snapshot(), GameCore.WHITE)
	var dt := Time.get_ticks_msec() - t0
	log_line("预算 %5d ms -> 实际完成 %d 层，耗时 %5d ms，节点 %d，落点 %s" % [
		budget_ms, ai.last_depth, dt, ai.last_nodes, str(mv)])


func build_midgame() -> GameCore:
	var g := GameCore.new()
	var adv := AdvancedAI.new()
	adv.time_budget_ms = 150
	var dft := DefensiveAI.new()
	for i in range(20):
		var ai: AIBase = adv if g.turn == GameCore.BLACK else dft
		var mv: Vector2i = ai.get_next_move(g.snapshot(), g.turn)
		if not g.place(mv.x, mv.y):
			break
	return g
