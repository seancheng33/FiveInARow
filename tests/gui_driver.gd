extends Node
# GUI 驱动器：真实窗口里跑一遍「菜单 → 双人对战 → 取胜 → 悔棋 → 重开 → 返回」
# 截图用引擎自身视口抓取，落盘到 res://tests/shots/

const OUT_DIR := "res://tests/shots/"

var logf: FileAccess
var menu: Control
var board


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	logf = FileAccess.open("res://tests/gui.log", FileAccess.WRITE)
	log_line("=== GUI DRIVER START ===")
	log_line("window=%s viewport=%s" % [str(DisplayServer.window_get_size()), str(get_viewport().get_visible_rect().size)])
	await run()
	log_line("=== GUI DRIVER END ===")
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
	log_line("SHOT> %s %s" % [name, str(img.get_size())])


func _send_motion(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)


func move_to(p: Vector2) -> void:
	Input.warp_mouse(p)
	_send_motion(p)
	await get_tree().process_frame


func click_at(p: Vector2) -> void:
	await move_to(p)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)
	await get_tree().process_frame


func click_node(n: Control) -> void:
	var r := n.get_global_rect()
	await click_at(r.position + r.size * 0.5)


func click_cell(x: int, y: int) -> void:
	var canvas: Control = board.get_node("%Canvas")
	await click_at(canvas.global_position + canvas.cell_center(Vector2i(x, y)))


func run() -> void:
	var scene: Node = load("res://main_scene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	menu = scene.get_node("MainMenu")
	await shot("01_menu")

	await click_node(menu.get_node("%BtnPVP"))
	await get_tree().process_frame
	board = menu._board
	log_line("PVP board=%s mode=%d" % [str(board != null), -1 if board == null else board.mode])
	await shot("02_board")

	# 悬停预览
	var canvas: Control = board.get_node("%Canvas")
	await move_to(canvas.global_position + canvas.cell_center(Vector2i(6, 6)))
	log_line("hover=%s" % str(canvas.hover))
	await shot("03_hover")

	# 黑方五连：黑(3,7)(4,7)(5,7)(6,7)(7,7)；白(0,0)(0,1)(0,2)(0,3)
	var seq := [Vector2i(3, 7), Vector2i(0, 0), Vector2i(4, 7), Vector2i(0, 1),
		Vector2i(5, 7), Vector2i(0, 2), Vector2i(6, 7), Vector2i(0, 3)]
	for c in seq:
		await click_cell(c.x, c.y)
	log_line("before win: stones=%d state=%d" % [board.core.move_count(), board.core.state])
	await shot("04_midgame")
	await click_cell(7, 7)
	log_line("after win: stones=%d state=%d win_line=%d panel=%s" % [
		board.core.move_count(), board.core.state, board.core.win_line.size(),
		str(board.get_node("%Result").visible)])
	await shot("05_win")

	# 结果面板上的悔棋
	await click_node(board.get_node("%ResultUndoButton"))
	await get_tree().process_frame
	log_line("after undo: stones=%d state=%d panel=%s" % [
		board.core.move_count(), board.core.state, str(board.get_node("%Result").visible)])
	await shot("06_after_undo")

	# 重新开始
	await click_node(board.get_node("%RestartButton"))
	await get_tree().process_frame
	log_line("after restart: stones=%d" % board.core.move_count())
	await shot("07_restart")

	# 返回菜单
	await click_node(board.get_node("%BackButton"))
	await get_tree().process_frame
	log_line("after back: board=%s menu_visible=%s" % [
		str(menu._board == null), str(menu._menu_box.visible)])
	await shot("08_back_to_menu")

	# 难度面板
	await click_node(menu.get_node("%BtnPVEBlack"))
	await get_tree().process_frame
	log_line("difficulty visible=%s" % str(menu._difficulty.visible))
	await shot("09_difficulty")
	await click_node(menu.get_node("%BtnBackToMenu"))
	await get_tree().process_frame

	# 窗口缩放：大窗 + 小窗
	await click_node(menu.get_node("%BtnPVP"))
	await get_tree().process_frame
	board = menu._board
	for c in [Vector2i(7, 7), Vector2i(8, 8), Vector2i(6, 6)]:
		await click_cell(c.x, c.y)

	get_window().size = Vector2i(1280, 820)
	await get_tree().process_frame
	await get_tree().process_frame
	canvas = board.get_node("%Canvas")
	log_line("resize big: window=%s viewport=%s canvas=%s cell=%s" % [
		str(get_window().size), str(get_viewport().get_visible_rect().size),
		str(canvas.size), str(Vector2(canvas.size) / 14.0)])
	await shot("10_big_window")

	get_window().size = Vector2i(760, 620)
	await get_tree().process_frame
	await get_tree().process_frame
	log_line("resize small: window=%s viewport=%s canvas=%s" % [
		str(get_window().size), str(get_viewport().get_visible_rect().size), str(canvas.size)])
	await shot("11_small_window")

	get_window().size = Vector2i(960, 740)
	await get_tree().process_frame
