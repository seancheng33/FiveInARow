# main_menu.gd
# 主菜单：选模式 / 选难度 / 选外观 / 创建对局。对局参数通过 configure() 明确注入。
extends Control

const BOARD_SCENE := preload("res://scenes/board.tscn")

# 困难档可选层数。预算是按实测填的：3 层≈0.44 s、4 层≈6.1 s、5 层≈15.2 s，
# 每多一层耗时约 ×6~8，再往上（6 层≈2 分钟）已经不是对局的节奏了。
const DEPTH_LEVELS := [
	{"depth": 2, "budget": 150, "label": "2 层 · 秒回"},
	{"depth": 3, "budget": 600, "label": "3 层 · 约 0.5 秒"},
	{"depth": 4, "budget": 7000, "label": "4 层 · 约 6 秒"},
	{"depth": 5, "budget": 17000, "label": "5 层 · 约 15 秒"},
]
const DEFAULT_DEPTH_INDEX := 1

@onready var _menu_box: Control = %MenuBox
@onready var _difficulty: Control = %Difficulty
@onready var _depth_option: OptionButton = %DepthOption
@onready var _bg: TextureRect = %Bg
@onready var _picker: Control = %ThemePicker

var _board: Node = null
var _pending_mode := 0
var _pending_ai_first := false


func _ready() -> void:
	var win := get_window()
	if win != null:
		win.min_size = Vector2i(1000, 660)

	# 双人对战（%BtnPVP）暂时隐藏，留给后续网络对战，这里不连信号
	%BtnPVEBlack.pressed.connect(_on_pve_player_first)
	%BtnPVEWhite.pressed.connect(_on_pve_ai_first)
	%BtnEVE.pressed.connect(_on_eve)
	%BtnTheme.pressed.connect(_open_theme_picker)
	%BtnQuit.pressed.connect(_on_quit)

	%BtnEasy.pressed.connect(_on_difficulty.bind(0))
	%BtnNormal.pressed.connect(_on_difficulty.bind(1))
	%BtnHard.pressed.connect(_on_difficulty.bind(2))
	%BtnBackToMenu.pressed.connect(_hide_difficulty)

	_fill_depth_options()
	theme = Ui.theme
	Ui.changed.connect(_on_skin_changed)
	_on_skin_changed()

	_difficulty.visible = false
	_menu_box.visible = true
	_clear_board()


func _on_skin_changed() -> void:
	theme = Ui.theme
	_bg.texture = Ui.bg_texture()


# ---------------- 外观 ----------------

func _open_theme_picker() -> void:
	if _picker != null:
		_picker.open()


# ---------------- 层数下拉 ----------------

func _fill_depth_options() -> void:
	_depth_option.clear()
	for lvl in DEPTH_LEVELS:
		_depth_option.add_item(str(lvl["label"]))
	_depth_option.select(DEFAULT_DEPTH_INDEX)


func _current_level() -> Dictionary:
	var i := clampi(_depth_option.selected, 0, DEPTH_LEVELS.size() - 1)
	return DEPTH_LEVELS[i]


# ---------------- 模式 ----------------

# 预留：双人对战 / 网络对战入口。联机做好后把 %BtnPVP 的 visible 打开并连到这里即可
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
	var lvl := _current_level()
	_board = BOARD_SCENE.instantiate()
	_board.search_depth = int(lvl["depth"])
	_board.ai_time_budget_ms = int(lvl["budget"])
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
