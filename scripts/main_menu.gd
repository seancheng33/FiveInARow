# main_menu.gd
# 主菜单：选模式 / 选难度 / 选外观 / 创建对局。对局参数通过 configure() 明确注入。
extends Control

const BOARD_SCENE := preload("res://scenes/board.tscn")

@onready var _menu_box: Control = %MenuBox
@onready var _difficulty: Control = %Difficulty
@onready var _bg: ColorRect = %Bg
@onready var _art: TextureRect = %Art
@onready var _veil: ColorRect = %Veil
@onready var _picker: Control = %ThemePicker
@onready var _title: Label = %Title
@onready var _dim: ColorRect = %Dim

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
	%BtnBackToMenu.pressed.connect(_hide_difficulty)

	# 五档难度：一个级别一层搜索
	for i in range(Difficulty.count()):
		var b := get_node_or_null("%BtnLv" + str(i)) as Button
		if b != null:
			b.pressed.connect(_on_difficulty.bind(i))
			b.text = Difficulty.label_of(i)

	theme = Ui.theme
	Ui.changed.connect(_on_skin_changed)
	_on_skin_changed()

	_difficulty.visible = false
	_menu_box.visible = true
	_clear_board()


func _on_skin_changed() -> void:
	theme = Ui.theme
	_bg.color = Ui.color("bg_top")
	var art := Ui.art_texture()
	_art.texture = art
	_art.visible = art != null
	_art.modulate = Ui.art_tint()
	_veil.color = Ui.veil_color()
	# 难度面板后面的遮罩用主题底色，别拿死黑把国画压成脏灰
	var scrim := Ui.color("bg_bottom")
	scrim.a = 0.62
	_dim.color = scrim
	if is_instance_valid(_title):
		_title.modulate = Color(1, 1, 1, 1)


# ---------------- 外观 ----------------

func _open_theme_picker() -> void:
	if _picker != null:
		_picker.open()


func difficulty_button_count() -> int:
	var n := 0
	for i in range(Difficulty.count()):
		if get_node_or_null("%BtnLv" + str(i)) != null:
			n += 1
	return n


# ---------------- 模式 ----------------

# 预留：双人对战 / 网络对战入口。联机做好后把 %BtnPVP 的 visible 打开并连到这里即可
func _on_pvp() -> void:
	_start_game(0, Difficulty.DEFAULT, false)


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
	# 难度即层数：一到五层对应入门到专家
	_board.search_depth = Difficulty.depth_of(diff)
	_board.ai_time_budget_ms = Difficulty.budget_of(diff)
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
