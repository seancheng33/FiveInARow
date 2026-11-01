# ui_skin.gd（自动加载单例 Ui）
# 界面外观的唯一入口：按 ui_palette.gd 的配色构建 Theme、棋盘样式、背景渐变，
# 记住当前主题（user://settings.cfg）并在切换时发出 changed 信号。
# 注意：不要写成 class_name —— Skin 是 Godot 内置类名，会与原生类冲突。
extends Node

signal changed

const SAVE_PATH := "user://settings.cfg"

# 主菜单标题用的行楷（马善政毛笔行楷，SIL OFL 1.1，可免费商用）
const TITLE_FONT_PATH := "res://assets/fonts/MaShanZheng-Regular.ttf"
# 主菜单国画背景
const ART_PATH := "res://assets/art/bg_shanshui.png"

var current_id := UiPalette.DEFAULT_ID
var palette: Dictionary = {}

var theme: Theme
var board_style: StyleBoxFlat
var frame_style: StyleBoxFlat

var _title_font: FontFile = null
var _btn_font: SystemFont = null
var _art: Texture2D = null


func _ready() -> void:
	load_saved()
	_load_fonts()
	rebuild()
	apply_to_root()


func _load_fonts() -> void:
	if ResourceLoader.exists(TITLE_FONT_PATH):
		_title_font = load(TITLE_FONT_PATH) as FontFile
	if _title_font == null:
		push_warning("行楷字体缺失：%s，标题回退到系统字体" % TITLE_FONT_PATH)


# ---------------- 对外接口 ----------------

func color(key: String) -> Color:
	return UiPalette.hex(str(palette.get(key, "#FF00FF")))


func current_name() -> String:
	return str(palette.get("name", ""))


func current_en() -> String:
	return str(palette.get("en", ""))


func set_theme(id: String, persist: bool = true) -> void:
	if not UiPalette.has_id(id):
		return
	current_id = id
	rebuild()
	apply_to_root()
	if persist:
		save_current()
	changed.emit()


func next_theme() -> void:
	var list := UiPalette.ids()
	var i := list.find(current_id)
	set_theme(list[(i + 1) % list.size()])


# 竖向渐变背景贴图，给 TextureRect 用
func bg_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, color("bg_top"))
	g.set_color(1, color("bg_bottom"))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	t.width = 8
	t.height = 128
	return t


# ---------------- 主菜单国画背景 ----------------

func art_texture() -> Texture2D:
	if _art == null and ResourceLoader.exists(ART_PATH):
		_art = load(ART_PATH) as Texture2D
	return _art


# 国画是暖白纸色，深色主题要乘上使其沉下去，浅色主题几乎原样
func art_tint() -> Color:
	return UiPalette.hex(str(palette.get("art_tint", "#FFFFFFFF")))


# 压在国画上的一层主题色薄膜，保证文字永远读得清
func veil_color() -> Color:
	return UiPalette.hex(str(palette.get("veil", "#00000000")))


# ---------------- 构建 ----------------

func rebuild() -> void:
	palette = UiPalette.get_by_id(current_id)
	theme = _build_theme()
	board_style = _build_board_style()
	frame_style = _build_frame_style()


func apply_to_root() -> void:
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.theme = theme


func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, alpha)


func _font() -> Font:
	var f := SystemFont.new()
	if bool(palette.get("serif", false)):
		f.font_names = PackedStringArray(["SimSun", "宋体", "Songti SC", "Source Han Serif SC", "Microsoft YaHei"])
	else:
		f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans SC"])
	return f


# 标题：行楷。字形偏小偏细，配大字号才立得住
func title_font() -> Font:
	if _title_font != null:
		return _title_font
	return _font()


# 按键：黑体（中易黑体优先，回退到其它无衬线黑体族）
func button_font() -> Font:
	if _btn_font == null:
		_btn_font = SystemFont.new()
		_btn_font.font_names = PackedStringArray(
			["SimHei", "黑体", "Heiti SC", "Microsoft YaHei UI", "Noto Sans SC", "PingFang SC"])
		_btn_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_btn_font.hinting = TextServer.HINTING_LIGHT
		_btn_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return _btn_font


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font()
	t.default_font_size = 18

	var accent := color("accent")
	var accent_text := color("accent_text")
	var btn_bg := color("btn_bg")
	var btn_border := color("btn_border")
	var text := color("text")
	var muted := color("muted")
	var rb := int(palette["radius_btn"])

	t.set_stylebox("normal", "Button", _flat(btn_bg, btn_border, 1, rb))
	t.set_stylebox("hover", "Button", _flat(btn_bg.lerp(accent, 0.10), accent, 1, rb))
	t.set_stylebox("pressed", "Button", _flat(btn_bg.lerp(accent, 0.22), accent, 1, rb))
	t.set_stylebox("disabled", "Button", _flat(_a(btn_bg.lerp(text, 0.05), 0.55), _a(btn_border, 0.35), 1, rb))
	var focus := _flat(Color(0, 0, 0, 0), accent, 2, rb)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)

	# 按键统一黑体
	var bf := button_font()
	t.set_font("font", "Button", bf)
	t.set_font("font", "OptionButton", bf)
	t.set_font("font", "CheckButton", bf)
	t.set_font("font", "PopupMenu", bf)
	t.set_color("font_color", "Button", color("btn_text"))
	t.set_color("font_hover_color", "Button", color("btn_text"))
	t.set_color("font_pressed_color", "Button", color("btn_text"))
	t.set_color("font_focus_color", "Button", color("btn_text"))
	t.set_color("font_disabled_color", "Button", _a(muted, 0.6))
	t.set_font_size("font_size", "Button", 18)

	# 强调按钮（主行动）
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", _flat(accent, accent, 0, rb))
	t.set_stylebox("hover", "AccentButton", _flat(accent.lightened(0.1), accent.lightened(0.1), 0, rb))
	t.set_stylebox("pressed", "AccentButton", _flat(accent.darkened(0.12), accent, 0, rb))
	t.set_font("font", "AccentButton", bf)
	t.set_color("font_color", "AccentButton", accent_text)
	t.set_color("font_hover_color", "AccentButton", accent_text)
	t.set_color("font_pressed_color", "AccentButton", accent_text)

	# 标签
	t.set_color("font_color", "Label", text)

	# 大标题：行楷。主菜单压在国画上，加一层反向柔影才浮得起来
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", title_font())
	t.set_color("font_color", "TitleLabel", text)
	var is_dark := color("bg_top").get_luminance() < 0.5
	t.set_color("font_shadow_color", "TitleLabel",
		Color(1, 1, 1, 0.55) if not is_dark else Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_x", "TitleLabel", 0)
	t.set_constant("shadow_offset_y", "TitleLabel", 2)
	t.set_constant("shadow_outline_size", "TitleLabel", 2)

	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", muted)

	# 主菜单的副标题/版本号直接压在国画上，比 muted 再深一档才看得清
	t.set_type_variation("SubtleLabel", "Label")
	t.set_color("font_color", "SubtleLabel", muted.lerp(text, 0.55))

	t.set_type_variation("AccentLabel", "Label")
	t.set_color("font_color", "AccentLabel", accent)

	# 卡片 / 面板
	var card := _flat(color("surface"), color("surface_border"), 1, int(palette["radius_card"]))
	card.content_margin_left = 26
	card.content_margin_right = 26
	card.content_margin_top = 22
	card.content_margin_bottom = 22
	var ss := int(palette["shadow_size"])
	if ss > 0:
		card.shadow_color = color("shadow")
		card.shadow_size = ss
		card.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", card)

	# 状态胶囊
	t.set_type_variation("StatusChip", "PanelContainer")
	var chip := _flat(color("chip_bg"), color("chip_border"), 1, 16)
	chip.content_margin_left = 16
	chip.content_margin_right = 16
	chip.content_margin_top = 5
	chip.content_margin_bottom = 5
	t.set_stylebox("panel", "StatusChip", chip)

	# 分隔线
	var sep := StyleBoxLine.new()
	sep.color = color("surface_border")
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)

	return t


func _flat(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 11
	s.content_margin_bottom = 11
	s.anti_aliasing = true
	return s


func _build_board_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color("board_bg")
	s.set_corner_radius_all(int(palette["radius_board"]))
	s.set_border_width_all(0)
	s.anti_aliasing = true
	return s


func _build_frame_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color("frame_bg")
	s.set_corner_radius_all(int(palette["radius_board"]) + 4)
	s.set_border_width_all(1)
	s.border_color = color("frame_border")
	s.anti_aliasing = true
	var ss := int(palette["shadow_size"])
	if ss > 0:
		s.shadow_color = color("shadow")
		s.shadow_size = ss
		s.shadow_offset = Vector2(0, 8)
	return s


# ---------------- 持久化 ----------------

func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var id := str(cfg.get_value("ui", "theme", UiPalette.DEFAULT_ID))
	if UiPalette.has_id(id):
		current_id = id


func save_current() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("ui", "theme", current_id)
	cfg.save(SAVE_PATH)
