# main_menu.gd
# 主菜单：只做"选模式 / 选难度 / 创建对局"，对局参数通过 configure() 明确注入。
extends Control

const BOARD_SCENE := preload("res://scenes/board.tscn")

@onready var _menu_box: Control = %MenuBox
@onready var _difficulty: Control = %Difficulty
@onready var _depth_spin: SpinBox = %DepthSpin
@onready var _bg: TextureRect = %Bg
@onready var _dots: HBoxContainer = %ThemeDots
@onready var _theme_name: Label = %ThemeName

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
	theme = Ui.theme
	_build_theme_dots()
	Ui.changed.connect(_on_skin_changed)
	_on_skin_changed()


# ---------------- 外观（主题） ----------------

func _build_theme_dots() -> void:
	for p in UiPalette.all():
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s · %s" % [p["name"], p["desc"]]
		b.pressed.connect(_on_pick_theme.bind(str(p["id"])))
		_dots.add_child(b)


func _on_pick_theme(id: String) -> void:
	Ui.set_theme(id)


func _on_skin_changed() -> void:
	theme = Ui.theme
	_bg.texture = Ui.bg_texture()
	_theme_name.text = Ui.current_name()
	for i in range(UiPalette.all().size()):
		if i >= _dots.get_child_count():
			break
		var p: Dictionary = UiPalette.all()[i]
		_paint_dot(_dots.get_child(i), p, str(p["id"]) == Ui.current_id)


func _paint_dot(b: Button, p: Dictionary, selected: bool) -> void:
	var accent := UiPalette.hex(str(p["accent"]))
	var ring := UiPalette.hex(str(p["text"]))
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = accent if st != "pressed" else accent.darkened(0.15)
		sb.set_corner_radius_all(13)
		sb.set_border_width_all(2 if selected else 1)
		sb.border_color = ring if selected else accent.darkened(0.12)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		b.add_theme_stylebox_override(st, sb)
	var fo := StyleBoxFlat.new()
	fo.draw_center = false
	fo.set_corner_radius_all(13)
	fo.set_border_width_all(2)
	fo.border_color = accent
	b.add_theme_stylebox_override("focus", fo)


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
