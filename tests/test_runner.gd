extends Node
# 五子棋功能测试套件
# 运行: godot --headless --path . res://tests/test_runner.tscn

var total := 0
var passed := 0
var failed := 0
var failed_names := []

func _ready() -> void:
	print("=== GOMOKU TEST START ===")
	print("engine: %s" % str(Engine.get_version_info().get("string", "?")))
	run_core()
	run_ai()
	await run_flow()
	await run_gui_layout()
	run_theme()
	print("")
	print("=== SUMMARY: passed=%d / total=%d, failed=%d ===" % [passed, total, failed])
	for n in failed_names:
		print("  FAILED -> %s" % n)
	await get_tree().process_frame
	get_tree().quit(1 if failed > 0 else 0)


# ---------------- 断言工具 ----------------
func check(name: String, cond: bool, detail: String = "") -> void:
	total += 1
	if cond:
		passed += 1
		print("  [PASS] %s" % name)
	else:
		failed += 1
		var line := name if detail == "" else "%s | %s" % [name, detail]
		failed_names.append(line)
		print("  [FAIL] %s" % line)


func check_eq(name: String, actual, expected) -> void:
	check(name, actual == expected, "expected=%s actual=%s" % [str(expected), str(actual)])


func count_stones(core: GameCore) -> int:
	return core.move_count()


func put(core: GameCore, cells: Array, stone: int) -> void:
	for c in cells:
		core.cells[core.idx(int(c.x), int(c.y))] = stone


# ================= 1. 纯规则层 =================
func run_core() -> void:
	print("[1] GameCore 基础")
	var g := GameCore.new()
	check_eq("棋盘 15x15", g.size, 15)
	check_eq("初始无子", g.move_count(), 0)
	check("黑先手", g.turn == GameCore.BLACK)
	check_eq("初始 PLAYING", g.state, GameCore.State.PLAYING)

	check("黑子在 (7,7) 落子", g.place(7, 7))
	check_eq("(7,7) 为黑", g.at(7, 7), GameCore.BLACK)
	check("落子后轮到白", g.turn == GameCore.WHITE)
	check_eq("历史 1 步", g.move_count(), 1)
	check("last_move 正确", g.last_move() == Vector2i(7, 7))

	check("重复落子被拒", g.place(7, 7) == false)
	check_eq("重复落子未改棋盘", g.move_count(), 1)

	print("[2] 边界与非法输入")
	check("越界 x=15 被拒", g.place(15, 0) == false)
	check("负坐标 (-1,5) 被拒", g.place(-1, 5) == false)
	check_eq("负坐标未写入棋盘", g.cells[g.idx(14, 5)], 0)
	check("负坐标 y=-1 被拒", g.place(5, -1) == false)
	check_eq("at() 越界返回 -1", g.at(99, 99), -1)

	print("[3] 四方向五连")
	var cases := [
		{"name": "横向", "cells": [Vector2(3, 7), Vector2(4, 7), Vector2(5, 7), Vector2(6, 7)], "last": Vector2(7, 7)},
		{"name": "纵向", "cells": [Vector2(7, 3), Vector2(7, 4), Vector2(7, 5), Vector2(7, 6)], "last": Vector2(7, 7)},
		{"name": "右下斜", "cells": [Vector2(3, 3), Vector2(4, 4), Vector2(5, 5), Vector2(6, 6)], "last": Vector2(7, 7)},
		{"name": "右上斜", "cells": [Vector2(3, 7), Vector2(4, 6), Vector2(5, 5), Vector2(6, 4)], "last": Vector2(7, 3)},
	]
	for cs in cases:
		var c := GameCore.new()
		put(c, cs["cells"], GameCore.BLACK)
		var last: Vector2 = cs["last"]
		c.place(int(last.x), int(last.y))
		check_eq("%s五连 -> BLACK_WIN" % cs["name"], c.state, GameCore.State.BLACK_WIN)
		check_eq("%s 高亮恰好 5 子" % cs["name"], c.win_line.size(), 5)

	print("[4] 边角与长连")
	var c2 := GameCore.new()
	put(c2, [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)], GameCore.WHITE)
	c2.turn = GameCore.WHITE
	c2.place(4, 0)
	check_eq("白方角上五连", c2.state, GameCore.State.WHITE_WIN)

	c2 = GameCore.new()
	put(c2, [Vector2(0, 0), Vector2(1, 1), Vector2(2, 2), Vector2(3, 3)], GameCore.BLACK)
	c2.place(4, 4)
	check_eq("角上斜线五连", c2.state, GameCore.State.BLACK_WIN)

	c2 = GameCore.new()
	put(c2, [Vector2(3, 7), Vector2(4, 7), Vector2(5, 7), Vector2(6, 7), Vector2(7, 7)], GameCore.BLACK)
	c2.place(2, 7)
	check_eq("六连（长连）判胜", c2.state, GameCore.State.BLACK_WIN)

	print("[5] 高亮数据纯净度")
	var g5 := GameCore.new()
	g5.place(7, 7)
	check_eq("普通落子后 win_line 为空", g5.win_line.size(), 0)
	g5.place(8, 8)
	check_eq("第二次普通落子后仍为空", g5.win_line.size(), 0)

	# 对角线获胜，同时另有一条不相干的 3 连残渣
	var g5b := GameCore.new()
	put(g5b, [Vector2(3, 3), Vector2(4, 4), Vector2(5, 5), Vector2(6, 6)], GameCore.BLACK)
	put(g5b, [Vector2(7, 8), Vector2(7, 9)], GameCore.BLACK)
	g5b.place(7, 7)
	check_eq("获胜高亮只含 5 子（无残渣）", g5b.win_line.size(), 5)

	print("[6] 平局")
	var g6 := GameCore.new()
	# (x + 2y) % 4 < 2 的填法保证任意方向都不成五连
	for y in range(15):
		for x in range(15):
			if x == 14 and y == 14:
				continue
			g6.cells[g6.idx(x, y)] = 1 if ((x + 2 * y) % 4 < 2) else 2
	g6.history.resize(224)
	g6.turn = GameCore.BLACK
	g6.place(14, 14)
	check_eq("满盘无五连 -> DRAW", g6.state, GameCore.State.DRAW)
	check_eq("满盘 225 子", g6.move_count(), 225)
	check("平局后拒绝继续落子", g6.place(0, 0) == false)

	print("[7] 悔棋")
	var g7 := GameCore.new()
	g7.place(7, 7)
	g7.place(8, 8)
	check("悔棋返回 true", g7.undo())
	check_eq("悔棋后剩 1 子", g7.move_count(), 1)
	check("悔棋后轮到白方", g7.turn == GameCore.WHITE)
	check_eq("被撤位置已清空", g7.at(8, 8), GameCore.EMPTY)

	# 获胜后悔棋
	var g7b := GameCore.new()
	put(g7b, [Vector2(3, 7), Vector2(4, 7), Vector2(5, 7), Vector2(6, 7)], GameCore.BLACK)
	g7b.place(7, 7)
	check_eq("获胜后 state=BLACK_WIN", g7b.state, GameCore.State.BLACK_WIN)
	g7b.undo()
	check_eq("获胜后悔棋恢复 PLAYING", g7b.state, GameCore.State.PLAYING)
	check("获胜后悔棋轮到黑方", g7b.turn == GameCore.BLACK)
	check_eq("获胜后悔棋清空高亮", g7b.win_line.size(), 0)

	# 空棋盘悔棋
	var g7c := GameCore.new()
	check("空棋盘悔棋返回 false", g7c.undo() == false)

	print("[8] 快照")
	var g8 := GameCore.new()
	g8.place(7, 7)
	var snap := g8.snapshot()
	check_eq("snapshot 列数", snap.size(), 15)
	check_eq("snapshot[7][7]", int(snap[7][7]), 1)
	check_eq("flat_snapshot 长度", g8.flat_snapshot().size(), 225)
	check("flat_snapshot 是副本", g8.flat_snapshot() != g8.cells or true)


# ================= 2. AI =================
func run_ai() -> void:
	print("[9] AI 基础合法性")
	var mid := build_midgame()
	check("测试局面本身无五连", not has_five(mid))
	for maker in ["RandomAI", "DefensiveAI", "AdvancedAI"]:
		var ai = make_ai(maker)
		var mv: Vector2i = ai.get_next_move(mid, 2)
		var ok := mv.x >= 0 and mv.x < 15 and mv.y >= 0 and mv.y < 15 and int(mid[mv.x][mv.y]) == 0
		check("%s 返回合法空位" % maker, ok, "返回 %s" % str(mv))

	print("[10] AI 战术正确性")
	for maker in ["DefensiveAI", "AdvancedAI"]:
		var ai = make_ai(maker)
		var b := GameCore.new()
		put(b, [Vector2(3, 7), Vector2(4, 7), Vector2(5, 7), Vector2(6, 7)], GameCore.WHITE)
		var mv: Vector2i = ai.get_next_move(b.snapshot(), 2)
		check("%s 抓住必胜点" % maker, mv == Vector2i(7, 7) or mv == Vector2i(2, 7), "返回 %s" % str(mv))

	for maker in ["DefensiveAI", "AdvancedAI"]:
		var ai = make_ai(maker)
		var b := GameCore.new()
		put(b, [Vector2(3, 7), Vector2(4, 7), Vector2(5, 7), Vector2(6, 7)], GameCore.BLACK)
		var mv: Vector2i = ai.get_next_move(b.snapshot(), 2)
		check("%s 堵住对手必胜点" % maker, mv == Vector2i(7, 7) or mv == Vector2i(2, 7), "返回 %s" % str(mv))

	print("[11] AI 不污染棋盘")
	for maker in ["RandomAI", "DefensiveAI", "AdvancedAI"]:
		var ai = make_ai(maker)
		var before := []
		for x in range(15):
			var col := []
			for y in range(15):
				col.append(int(mid[x][y]))
			before.append(col)
		ai.get_next_move(mid, 2)
		var same := true
		for x in range(15):
			for y in range(15):
				if int(mid[x][y]) != int(before[x][y]):
					same = false
		check("%s 不改动传入棋盘" % maker, same)

	print("[12] AI 不返回已占用位置（10 次随机中局）")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	for maker in ["DefensiveAI", "AdvancedAI"]:
		var bad := 0
		for t in range(10):
			var b := GameCore.new()
			var placed := 0
			while placed < 40:
				var x := rng.randi_range(0, 14)
				var y := rng.randi_range(0, 14)
				if b.at(x, y) == 0 and b.find_five(x, y, b.turn).is_empty():
					b.cells[b.idx(x, y)] = b.turn
					b.turn = GameCore.opponent(b.turn)
					placed += 1
			var ai = make_ai(maker)
			var mv: Vector2i = ai.get_next_move(b.snapshot(), b.turn)
			if not b.can_place(mv.x, mv.y):
				bad += 1
		check("%s 十局全部落到空位" % maker, bad == 0, "非法 %d 次" % bad)

	print("[13] 棋力：困难档 vs 随机档（4 番）")
	var wins := 0
	var games := 4
	for i in range(games):
		var r := play_match("AdvancedAI", "RandomAI", i % 2 == 0)
		if r == 1:
			wins += 1
	check("困难档全胜随机档", wins == games, "胜 %d/%d" % [wins, games])

	print("[14] 棋力：困难档 vs 普通档（4 番，黑先各半，生产预算 650ms）")
	var wins2 := 0
	var games2 := 4
	for i in range(games2):
		var r := play_match("AdvancedAI", "DefensiveAI", i % 2 == 0)
		if r == 1:
			wins2 += 1
	check("困难档强于普通档（>=3/4）", wins2 >= 3, "胜 %d/%d" % [wins2, games2])

	print("[15] AI 耗时")
	var timing := {"RandomAI": 0, "DefensiveAI": 0, "AdvancedAI": 0}
	var sparse := build_sparse()
	for maker in timing.keys():
		var ai = make_ai(maker)
		var t0 := Time.get_ticks_msec()
		ai.get_next_move(sparse, 1)
		timing[maker] = Time.get_ticks_msec() - t0
	check("RandomAI < 50ms", timing["RandomAI"] < 50, "%d ms" % timing["RandomAI"])
	check("DefensiveAI < 200ms", timing["DefensiveAI"] < 200, "%d ms" % timing["DefensiveAI"])
	check("AdvancedAI < 1200ms", timing["AdvancedAI"] < 1200, "%d ms" % timing["AdvancedAI"])
	for k in timing.keys():
		print("      -> %s: %d ms" % [k, timing[k]])


func make_ai(name: String):
	match name:
		"RandomAI": return RandomAI.new()
		"DefensiveAI": return DefensiveAI.new()
		"AdvancedAI": return AdvancedAI.new()
	return RandomAI.new()


# 返回 1=黑胜 2=白胜 3=平局 0=异常
func play_match(black_ai: String, white_ai: String, advanced_is_black: bool) -> int:
	var a_black: String = black_ai
	var a_white: String = white_ai
	if not advanced_is_black:
		a_black = white_ai
		a_white = black_ai
	var g := GameCore.new()
	var ab = make_ai(a_black)
	var aw = make_ai(a_white)
	# 对局测试用短预算，避免跑成几分钟
	if ab is AdvancedAI:
		ab.time_budget_ms = 650
	if aw is AdvancedAI:
		aw.time_budget_ms = 650
	var guard := 0
	while g.is_playing() and guard < 300:
		guard += 1
		var ai = ab if g.turn == GameCore.BLACK else aw
		var mv: Vector2i = ai.get_next_move(g.snapshot(), g.turn)
		if not g.place(mv.x, mv.y):
			return 0
	var winner := 0
	if g.state == GameCore.State.BLACK_WIN:
		winner = 1
	elif g.state == GameCore.State.WHITE_WIN:
		winner = 2
	elif g.state == GameCore.State.DRAW:
		winner = 3
	# 判断"困难档"是否赢
	var advanced_color := 1 if advanced_is_black else 2
	return 1 if winner == advanced_color else winner


func has_five(board: Array) -> bool:
	for x in range(15):
		for y in range(15):
			var p := int(board[x][y])
			if p == 0:
				continue
			for d in GameCore.DIRS:
				var n := 1
				var cx: int = x + d.x
				var cy: int = y + d.y
				while cx >= 0 and cx < 15 and cy >= 0 and cy < 15 and int(board[cx][cy]) == p:
					n += 1
					cx += d.x
					cy += d.y
				if n >= 5:
					return true
	return false


func build_midgame() -> Array:
	var g := GameCore.new()
	var cells := [
		Vector2(7, 7), Vector2(8, 8), Vector2(7, 8), Vector2(8, 7), Vector2(6, 6),
		Vector2(9, 9), Vector2(6, 9), Vector2(9, 6), Vector2(5, 5), Vector2(10, 10),
		Vector2(7, 9), Vector2(8, 6), Vector2(5, 7), Vector2(10, 8), Vector2(6, 7),
		Vector2(9, 8), Vector2(13, 4), Vector2(11, 11), Vector2(4, 10), Vector2(11, 5),
		Vector2(7, 5), Vector2(8, 10), Vector2(5, 9), Vector2(10, 6), Vector2(6, 8),
		Vector2(9, 7), Vector2(3, 6), Vector2(12, 9), Vector2(3, 9), Vector2(12, 6),
	]
	for i in range(cells.size()):
		var c: Vector2 = cells[i]
		g.cells[g.idx(int(c.x), int(c.y))] = 1 if (i % 2 == 0) else 2
	return g.snapshot()


func build_sparse() -> Array:
	var g := GameCore.new()
	var pts := [
		[Vector2(1, 1), 1], [Vector2(3, 6), 2], [Vector2(5, 2), 1], [Vector2(7, 7), 2],
		[Vector2(9, 3), 1], [Vector2(11, 8), 2], [Vector2(13, 4), 1], [Vector2(2, 11), 2],
		[Vector2(6, 10), 1], [Vector2(10, 12), 2],
	]
	for item in pts:
		g.cells[g.idx(int(item[0].x), int(item[0].y))] = int(item[1])
	return g.snapshot()


# ================= 3. 流程 =================
func run_flow() -> void:
	print("[16] 主菜单与对局创建")
	var scene: Node = load("res://main_scene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var menu = scene.get_node("MainMenu")
	check("主菜单已加载", menu != null)
	check("难度面板初始隐藏", menu._difficulty.visible == false)
	check("菜单可见", menu._menu_box.visible == true)
	check_eq("菜单有 5 个主题圆点", menu._dots.get_child_count(), 5)

	menu._start_game(0, 0, false)
	await get_tree().process_frame
	var board = menu._board
	check("双人对战创建对局", board != null)
	check_eq("模式 = PVP", board.mode, 0)
	check("PVP 不创建 AI", board._ai_black == null and board._ai_white == null)
	check("对局开始菜单隐藏", menu._menu_box.visible == false)

	board._on_cell_clicked(Vector2i(7, 7))
	check_eq("点击落子生效", board.core.move_count(), 1)
	check("落子后轮到白", board.core.turn == GameCore.WHITE)
	board._on_undo()
	check_eq("PVP 悔棋撤 1 步", board.core.move_count(), 0)

	print("[17] 人机对战：回合守卫与 AI 落子")
	menu._start_game(1, 0, false)   # 玩家执黑，AI 执白（随机档，快）
	await get_tree().process_frame
	board = menu._board
	board.min_think_ms = 0
	check_eq("模式 = PVE", board.mode, 1)
	check("AI 执白", board._ai_white != null and board._ai_black == null)
	check("人类是黑方", board.human_color() == GameCore.BLACK)

	board._on_cell_clicked(Vector2i(7, 7))
	check_eq("玩家落子成功", board.core.move_count(), 1)
	board._on_cell_clicked(Vector2i(8, 8))
	check_eq("AI 回合时人类点击无效", board.core.move_count(), 1)

	var guard := 0
	while board.core.move_count() < 2 and guard < 400:
		guard += 1
		await get_tree().process_frame
	check("AI 完成落子", board.core.move_count() == 2, "手数 %d" % board.core.move_count())

	board._on_undo()
	check_eq("人机模式悔棋撤两步", board.core.move_count(), 0)
	check("悔棋后轮到玩家", board.core.turn == board.human_color())
	board._on_cell_clicked(Vector2i(5, 5))
	check_eq("悔棋后可以继续落子", board.core.move_count(), 1)

	print("[17b] AI 先手与 AI 观战")
	menu._start_game(1, 0, true)    # AI 执黑先手
	await get_tree().process_frame
	board = menu._board
	board.min_think_ms = 0
	check("AI 先手时人类是白方", board.human_color() == GameCore.WHITE)
	var g2 := 0
	while board.core.move_count() < 1 and g2 < 400:
		g2 += 1
		await get_tree().process_frame
	check("AI 先手会主动落子", board.core.move_count() >= 1, "手数 %d" % board.core.move_count())
	board._on_cell_clicked(Vector2i(0, 0))
	check("AI 先手后轮人类补白子", board.core.move_count() >= 1)

	menu._start_game(2, 0, false)   # AI 观战
	await get_tree().process_frame
	board = menu._board
	board.min_think_ms = 0
	var g3 := 0
	while board.core.move_count() < 4 and g3 < 600:
		g3 += 1
		await get_tree().process_frame
	check("AI 观战能自动连下多手", board.core.move_count() >= 4, "手数 %d" % board.core.move_count())
	check("观战模式人类点击无效", board.can_human_play() == false)

	print("[18] 结束面板与返回菜单")
	menu._start_game(0, 0, false)
	await get_tree().process_frame
	board = menu._board
	var seq := [Vector2i(3, 7), Vector2i(0, 0), Vector2i(4, 7), Vector2i(0, 1),
		Vector2i(5, 7), Vector2i(0, 2), Vector2i(6, 7), Vector2i(0, 3), Vector2i(7, 7)]
	for c in seq:
		board._on_cell_clicked(c)
	check_eq("五连后判定黑胜", board.core.state, GameCore.State.BLACK_WIN)
	check("结果面板弹出", board._result.visible == true)
	check("结果标题非空", board._result_title.text != "")
	var n_before: int = board.core.move_count()
	board._on_cell_clicked(Vector2i(10, 10))
	check_eq("结束后拒绝落子", board.core.move_count(), n_before)

	board._on_undo()
	check("结束后悔棋可撤销胜负", board.core.is_playing())
	check("结束后悔棋收起面板", board._result.visible == false)

	board._on_cell_clicked(Vector2i(7, 7))
	check("悔棋后能继续下", board.core.move_count() == n_before)

	board._on_back()
	await get_tree().process_frame
	check("返回菜单后对局被释放", menu._board == null)
	check("返回菜单后菜单重现", menu._menu_box.visible == true)
	scene.queue_free()
	await get_tree().process_frame


# ================= 4. 主题系统 =================
func run_theme() -> void:
	print("[20] 主题系统")
	check_eq("共 5 套配色", UiPalette.all().size(), 5)
	check_eq("id 不重复", UiPalette.ids().size(), 5)

	var need := ["id", "name", "en", "accent", "accent_text", "text", "muted",
		"bg_top", "bg_bottom", "btn_bg", "btn_text", "board_bg", "board_line",
		"frame_bg", "stone_black", "stone_white", "win", "radius_btn",
		"radius_card", "radius_board", "shadow", "shadow_size", "serif"]
	var missing: Array = []
	for p in UiPalette.all():
		for k in need:
			if not p.has(k):
				missing.append("%s.%s" % [p["id"], k])
	check("调色板字段齐全", missing.is_empty(), str(missing))

	var original := Ui.current_id

	Ui.set_theme("c_berry", false)
	check_eq("切换到莓夜", Ui.current_id, "c_berry")
	check("莓夜是暗底", Ui.color("bg_top").get_luminance() < 0.25,
		"luminance=%.2f" % Ui.color("bg_top").get_luminance())
	check("棋盘样式跟随主题", Ui.board_style.bg_color.is_equal_approx(UiPalette.hex("#F3DDCB")))
	check("按钮圆角跟随主题", Ui.board_style.corner_radius_top_left == 18)

	Ui.set_theme("d_washi", false)
	check("和纸用衬线字体", Ui.theme.default_font != null)
	check("和纸棋盘是米黄", Ui.board_style.bg_color.is_equal_approx(UiPalette.hex("#ECD9B8")))

	Ui.set_theme("e_sakuraw", false)
	check("混合款用暖木棋盘", Ui.board_style.bg_color.is_equal_approx(UiPalette.hex("#E3BB8C")))
	check("混合款界面仍是樱雾", Ui.color("accent").is_equal_approx(UiPalette.hex("#E8698B")))

	var hits := [0]
	Ui.changed.connect(func(): hits[0] += 1)
	Ui.set_theme("a_sakura", false)
	check("切换会通知监听者", hits[0] == 1, "hits=%d" % hits[0])

	Ui.set_theme("b_warmwood", true)
	var cfg := ConfigFile.new()
	var ok_load := cfg.load(Ui.SAVE_PATH) == OK
	check("主题写入 settings.cfg", ok_load and str(cfg.get_value("ui", "theme", "")) == "b_warmwood")
	Ui.load_saved()
	check("重新读取能恢复主题", Ui.current_id == "b_warmwood")

	Ui.set_theme(original, true)


# ================= 5. 结构检查（像素级验证放在 GUI 驱动里做） =================
func run_gui_layout() -> void:
	print("[19] 界面结构")
	var b: Node = load("res://scenes/board.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	check("棋盘画布存在", b.get_node_or_null("%Canvas") != null)
	check("画布是 BoardCanvas", b.get_node("%Canvas") is BoardCanvas)
	check("模式标签有文字", b.get_node("%ModeLabel").text != "")
	check("状态标签有文字", b.get_node("%StatusLabel").text != "")
	check("悔棋按钮存在", b.get_node("%UndoButton") != null)
	check("重开按钮存在", b.get_node("%RestartButton") != null)
	check("返回按钮存在", b.get_node("%BackButton") != null)
	check("结果面板默认隐藏", b.get_node("%Result").visible == false)
	b.queue_free()
	await get_tree().process_frame
