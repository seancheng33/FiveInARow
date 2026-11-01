extends Node
# 逐主题截图：5 套配色各拍「主菜单 / 对局中 / 结束面板」，写到 res://tests/shots/

const OUT_DIR := "res://tests/shots/"
const OPENERS := [Vector2i(7, 7), Vector2i(6, 8), Vector2i(8, 6)]

var logf: FileAccess
var menu: Control


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	logf = FileAccess.open("res://tests/theme_shots.log", FileAccess.WRITE)
	log_line("=== THEME SHOTS START ===")
	await run()
	log_line("=== DONE ===")
	if logf:
		logf.close()
	get_tree().quit(0)


func log_line(s: String) -> void:
	print(s)
	if logf:
		logf.store_line(s)
		logf.flush()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + name + ".png")
	log_line("SHOT %s %s" % [name, str(img.get_size())])


func run() -> void:
	var scene: Node = load("res://main_scene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	menu = scene.get_node("MainMenu")

	for p in UiPalette.all():
		var id := str(p["id"])
		Ui.set_theme(id, false)
		if menu._board != null:
			menu._on_board_return()
			await get_tree().process_frame
		await get_tree().process_frame
		await shot("m_menu_%s" % id)

		# 只给第一套拍弹窗与难度面板，避免刷屏
		if id == "a_sakura":
			menu._open_theme_picker()
			await get_tree().process_frame
			await shot("m_picker")
			menu._picker.close()
			await get_tree().process_frame
			menu._on_pve_player_first()
			await get_tree().process_frame
			await shot("m_difficulty")
			menu._hide_difficulty()
			await get_tree().process_frame

		# 真实人机对局：玩家执黑走三步，困难档 AI 应答
		menu._start_game(1, 2, false)
		await get_tree().process_frame
		var board = menu._board
		board.min_think_ms = 0
		for c in OPENERS:
			board._on_cell_clicked(c)
			var guard := 0
			while board._thinking and guard < 400:
				guard += 1
				await get_tree().process_frame
		await get_tree().create_timer(1.3).timeout
		await get_tree().process_frame
		await shot("m_game_%s" % id)
		log_line("  %s 手数=%d 用时=%s 层数=%s | running=%s elapsed_ms=%s start=%s now=%s" % [
			id, board.core.move_count(), board.elapsed_text(), board._depth_label.text,
			str(board._clock_running), str(board._elapsed_ms), str(board._clock_start_ms),
			str(Time.get_ticks_msec())])

		# 构造一个已分出胜负的局面，看结束面板（含用时）
		_build_win(board)
		await get_tree().process_frame
		await shot("m_result_%s" % id)


func _build_win(board) -> void:
	board._stop_ai()
	board.core.reset()
	var seq := [
		[Vector2i(3, 7), GameCore.BLACK], [Vector2i(0, 0), GameCore.WHITE],
		[Vector2i(4, 7), GameCore.BLACK], [Vector2i(0, 1), GameCore.WHITE],
		[Vector2i(5, 7), GameCore.BLACK], [Vector2i(0, 2), GameCore.WHITE],
		[Vector2i(6, 7), GameCore.BLACK], [Vector2i(0, 3), GameCore.WHITE],
		[Vector2i(7, 7), GameCore.BLACK],
	]
	for item in seq:
		board.core.turn = item[1]
		board.core.place(item[0].x, item[0].y)
	board._show_result()
	board._canvas.queue_redraw()
