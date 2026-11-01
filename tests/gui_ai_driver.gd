extends Node
# 人机对战（困难）实测：AI 计算期间主线程是否仍然流畅（帧间隔 / 帧数）

var logf: FileAccess
var menu: Control
var board
var frames := 0
var max_gap := 0
var last_ms := 0
var _marks := {}


func _ready() -> void:
	logf = FileAccess.open("res://tests/gui_ai.log", FileAccess.WRITE)
	log_line("=== GUI AI DRIVER START ===")
	await run()
	log_line("=== GUI AI DRIVER END ===")
	if logf:
		logf.close()
	get_tree().quit(0)


func _process(_d: float) -> void:
	frames += 1
	var now := Time.get_ticks_msec()
	if last_ms > 0:
		var gap := now - last_ms
		if gap > max_gap:
			max_gap = gap
	last_ms = now


func log_line(s: String) -> void:
	print(s)
	if logf:
		logf.store_line(s)
		logf.flush()


func _send_motion(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)


func click_at(p: Vector2) -> void:
	Input.warp_mouse(p)
	_send_motion(p)
	await get_tree().process_frame
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

	await click_node(menu.get_node("%BtnPVEBlack"))
	await get_tree().process_frame
	log_line("difficulty visible=%s" % str(menu._difficulty.visible))
	await click_node(menu.get_node("%BtnHard"))
	await get_tree().process_frame

	board = menu._board
	log_line("board=%s mode=%d ai_white=%s depth=%d" % [
		str(board != null), -1 if board == null else board.mode,
		"null" if board == null or board._ai_white == null else board._ai_white.get_ai_name(),
		-1 if board == null else board.search_depth])
	if board == null:
		return

	# 第 1 步：玩家执黑落子，等 AI 应答
	for turn in range(3):
		var cell: Vector2i = [Vector2i(7, 7), Vector2i(5, 5), Vector2i(9, 9)][turn]
		if turn > 0:
			while board.core.turn != GameCore.BLACK:
				await get_tree().process_frame
		var stones_before: int = board.core.move_count()
		frames = 0
		max_gap = 0
		var t0 := Time.get_ticks_msec()
		await click_cell(cell.x, cell.y)
		# 等 AI 落子完成（+1 手）
		while board.core.move_count() < stones_before + 2 and Time.get_ticks_msec() - t0 < 20000:
			await get_tree().process_frame
		var dt := Time.get_ticks_msec() - t0
		log_line("round %d: ai_turn=%d ms, frames=%d, max_frame_gap=%d ms, stones=%d" % [
			turn + 1, dt, frames, max_gap, board.core.move_count()])

	# 思考期间玩家点击是否被挡住
	var before: int = board.core.move_count()
	await click_cell(1, 1)
	log_line("guard: stones %d -> %d (应相等或仅多 AI 一手)" % [before, board.core.move_count()])
