# theme_picker.gd
# 外观主题弹窗：主菜单与对局内共用一个实例，点一下立即换肤。
extends Control

signal closed

const ROW_H := 52

@onready var _list: VBoxContainer = %List
@onready var _close_btn: Button = %CloseButton

var _built := false


static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, alpha)


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(close)
	Ui.changed.connect(_refresh)
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	for child in _list.get_children():
		child.queue_free()
	for p in UiPalette.all():
		_list.add_child(_make_row(p))


func _make_row(p: Dictionary) -> Control:
	var id := str(p["id"])
	var btn := Button.new()
	btn.name = "Row_" + id
	btn.custom_minimum_size = Vector2(0, ROW_H)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_pick.bind(id))

	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	btn.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(22, 22)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", _dot_style(p))
	h.add_child(dot)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [str(p["name"]), str(p["en"])]
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 16)
	v.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.name = "Desc"
	desc_lbl.text = str(p["desc"])
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Ui.color("muted"))
	v.add_child(desc_lbl)

	var check := Label.new()
	check.name = "Check"
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.add_theme_font_size_override("font_size", 12)
	h.add_child(check)

	return btn


func _dot_style(p: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiPalette.hex(str(p["accent"]))
	sb.set_corner_radius_all(11)
	sb.set_border_width_all(1)
	sb.border_color = _a(UiPalette.hex(str(p["text"])), 0.25)
	return sb


func row_count() -> int:
	return _list.get_child_count()


func _on_pick(id: String) -> void:
	Ui.set_theme(id)


func open() -> void:
	visible = true
	_refresh()
	move_to_front()


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	if not _built:
		return
	for p in UiPalette.all():
		var id := str(p["id"])
		var row := _list.get_node_or_null("Row_" + id) as Button
		if row == null:
			continue
		var selected := id == Ui.current_id
		var accent := UiPalette.hex(str(p["accent"]))
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = _a(accent, 0.14 if selected else 0.0)
			sb.set_corner_radius_all(10)
			sb.set_border_width_all(1)
			sb.border_color = accent if selected else _a(accent, 0.22)
			if st == "hover":
				sb.bg_color = _a(accent, 0.10)
			row.add_theme_stylebox_override(st, sb)
		var fo := StyleBoxFlat.new()
		fo.draw_center = false
		fo.set_corner_radius_all(10)
		fo.set_border_width_all(2)
		fo.border_color = accent
		row.add_theme_stylebox_override("focus", fo)

		var desc := row.find_child("Desc", true, false) as Label
		if desc != null:
			desc.add_theme_color_override("font_color", Ui.color("muted"))

		var check := row.find_child("Check", true, false) as Label
		if check != null:
			check.text = "✓ 当前" if selected else ""
			check.add_theme_color_override("font_color", accent)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		accept_event()
