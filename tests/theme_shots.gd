extends Node
# 逐主题截图：5 套配色各拍「主菜单」和「对局（含结束卡片）」，写到 res://tests/shots/

const OUT_DIR := "res://tests/shots/"
const SEQ := [
	Vector2i(3, 7), Vector2i(0, 0), Vector2i(4, 7), Vector2i(0, 1),
	Vector2i(5, 7), Vector2i(0, 2), Vector2i(6, 7), Vector2i(0, 3),
]

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
		# 上一轮留下对局时，先回到菜单，否则"菜单"这张会截到棋盘
		if menu._board != null:
			menu._on_board_return()
			await get_tree().process_frame
		await get_tree().process_frame
		await shot("t_%s_menu" % id)

		menu._start_game(0, 0, false)
		await get_tree().process_frame
		var board = menu._board
		for c in SEQ:
			board._on_cell_clicked(c)
		board._on_cell_clicked(Vector2i(7, 7))
		await get_tree().process_frame
		await shot("t_%s_board" % id)
		log_line("  theme=%s state=%d stones=%d" % [id, board.core.state, board.core.move_count()])
