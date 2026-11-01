extends Node
# GUI 驱动器：真实窗口里用注入的鼠标事件走一遍新界面
#   菜单 → 人机对战(简单) → 落子 → 打开外观弹窗换主题 → 悔棋 → 返回菜单

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

	log_line("menu: pvp_visible=%s depth_items=%d" % [
		str(menu.get_node("%BtnPVP").visible), menu._depth_option.item_count])
	await shot("g1_menu")

	# 人机对战 · 我执黑 → 简单
	await click_node(menu.get_node("%BtnPVEBlack"))
	await get_tree().process_frame
	await click_node(menu.get_node("%BtnEasy"))
	await get_tree().process_frame
	board = menu._board
	log_line("board created=%s mode=%d" % [str(board != null), -1 if board == null else board.mode])
	if board == null:
		return
	await shot("g2_board")

	# 真实点击落子
	await click_cell(7, 7)
	await get_tree().process_frame
	log_line("after click: stones=%d" % board.core.move_count())

	# 等 AI 应答
	var guard := 0
	while board.core.move_count() < 2 and guard < 60:
		guard += 1
		await get_tree().create_timer(0.1).timeout
	log_line("after ai: stones=%d depth_label=%s" % [board.core.move_count(), board._depth_label.text])
	await shot("g3_playing")

	# 侧栏「外观主题」→ 弹窗 → 点第二行换主题
	await click_node(board.get_node("%ThemeButton"))
	await get_tree().process_frame
	var picker: Control = board.get_node("%ThemePicker")
	log_line("picker visible=%s rows=%d" % [str(picker.visible), picker.row_count()])
	await shot("g4_picker")

	var rows: VBoxContainer = picker._list
	var row2: Control = rows.get_child(1)
	var rr := row2.get_global_rect()
	var before := Ui.current_id
	await click_at(rr.position + rr.size * 0.5)
	await get_tree().process_frame
	log_line("theme %s -> %s" % [before, Ui.current_id])
	await shot("g5_theme_switched")

	await click_node(picker.get_node("%CloseButton"))
	await get_tree().process_frame
	log_line("picker closed=%s" % str(not picker.visible))

	# 悔棋
	var before_undo: int = board.core.move_count()
	await click_node(board.get_node("%UndoButton"))
	await get_tree().process_frame
	log_line("undo: %d -> %d" % [before_undo, board.core.move_count()])

	# 返回菜单
	await click_node(board.get_node("%BackButton"))
	await get_tree().process_frame
	log_line("back: board=%s menu_visible=%s" % [
		str(menu._board == null), str(menu._menu_box.visible)])
	await shot("g6_back_to_menu")
