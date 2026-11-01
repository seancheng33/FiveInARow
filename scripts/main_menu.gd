# main_menu.gd
# 主菜单：只做"选模式 / 选难度 / 创建对局"，对局参数通过 configure() 明确注入。
extends Control

const BOARD_SCENE := preload("res://scenes/board.tscn")

@onready var _menu_box: Control = %MenuBox
@onready var _difficulty: Control = %Difficulty
@onready var _depth_spin: SpinBox = %DepthSpin

var _board: Node = null
var _pending_mode := 0
var _pending_ai_first := false


func _ready() -> void:
	# 窗口最小尺寸，防止布局被压坏
	var win := get_window()
	if win != null:
		win.min_size = Vector2i(720, 600)

	%BtnPVP.pressed.connect(_on_pvp)
	%BtnPVEBlack.pressed.connect(_on_pve_player_first)
	%BtnPVEWhite.pressed.connect(_on_pve_ai_first)
	%BtnEVE.pressed.connect(_on_eve)
	%BtnQuit.pressed.connect(_on_quit)

	%BtnEasy.pressed.connect(_on_difficulty.bind(0))
	%BtnNormal.pressed.connect(_on_difficulty.bind(1))
	%BtnHard.pressed.connect(_on_difficulty.bind(2))
	%BtnBackToMenu.pressed.connect(_hide_difficulty)

	_difficulty.visible = false
	_menu_box.visible = true
	_clear_board()


func _on_pvp() -> void:
	_start_game(0, 0, false)


func _on_pve_player_first() -> void:
	_ask_difficulty(1, false)


func _on_pve_ai_first() -> void:
	_ask_difficulty(1, true)


func _on_eve() -> void:
	_ask_difficulty(2, false)


func _ask_difficulty(mode: int, ai_first: bool) -> void:
	_pending_mode = mode
	_pending_ai_first = ai_first
	_menu_box.visible = false
	_difficulty.visible = true


func _hide_difficulty() -> void:
	_difficulty.visible = false
	_menu_box.visible = true


func _on_difficulty(diff: int) -> void:
	_hide_difficulty()
	_start_game(_pending_mode, diff, _pending_ai_first)


func _start_game(mode: int, diff: int, ai_first: bool) -> void:
	_clear_board()
	_board = BOARD_SCENE.instantiate()
	_board.search_depth = int(_depth_spin.value)
	_board.configure(mode, diff, ai_first)
	_board.return_to_menu.connect(_on_board_return)
	add_child(_board)
	_menu_box.visible = false
	_difficulty.visible = false


func _on_board_return() -> void:
	_clear_board()
	_menu_box.visible = true
	_difficulty.visible = false


func _clear_board() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
	_board = null


func _on_quit() -> void:
	get_tree().quit()
