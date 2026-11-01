# ui_palette.gd
# 五套界面配色的唯一数据源。所有颜色都是 "#RRGGBB" 或 "#RRGGBBAA" 字符串，
# 由 ui_skin.gd 解析成 Color 并构建 Theme / 棋盘样式 / 主菜单国画背景的染色。
class_name UiPalette
extends RefCounted

const DEFAULT_ID := "a_sakura"

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		_cache = _build()
	return _cache


static func ids() -> Array:
	var out: Array = []
	for p in all():
		out.append(p["id"])
	return out


static func get_by_id(id: String) -> Dictionary:
	for p in all():
		if p["id"] == id:
			return p
	return all()[0]


static func has_id(id: String) -> bool:
	return get_by_id(id)["id"] == id


# "#RRGGBB" / "#RRGGBBAA" -> Color
static func hex(s: String) -> Color:
	var h := s.trim_prefix("#")
	var r := h.substr(0, 2).hex_to_int() / 255.0
	var g := h.substr(2, 2).hex_to_int() / 255.0
	var b := h.substr(4, 2).hex_to_int() / 255.0
	var a := 1.0
	if h.length() >= 8:
		a = h.substr(6, 2).hex_to_int() / 255.0
	return Color(r, g, b, a)


static func _build() -> Array:
	return [
		{
			"id": "a_sakura",
			"name": "樱雾",
			"en": "SAKURA MIST",
			"desc": "米白偏粉，樱木棋盘，桃粉强调。最柔最粉。",
			"serif": false,
			"bg_top": "#FFFAFB", "bg_bottom": "#FBF0F3",
			"text": "#4B3238", "muted": "#A4818B",
			"accent": "#E8698B", "accent_text": "#FFFFFF",
			"surface": "#FFFDFDF2", "surface_border": "#C4929E5C",
			"btn_bg": "#FFFFFFEE", "btn_text": "#6B4551", "btn_border": "#C4929E66",
			"chip_bg": "#FFFFFFB8", "chip_border": "#C4929E57",
			"board_bg": "#F7E2D6", "board_line": "#B5867A", "board_star": "#96685C",
			"frame_bg": "#FFF6EF", "frame_border": "#E4C3B6",
			"stone_black": "#463034", "stone_black_hi": "#8D6D73",
			"stone_white": "#FFFAF7", "stone_white_edge": "#DCC3BD",
			"win": "#E8698B", "scrim": "#2B1A1E1A",
			"radius_btn": 12, "radius_card": 18, "radius_board": 16,
			"shadow": "#BE788C4D", "shadow_size": 10,
			"art_tint": "#FFFFFFF2", "veil": "#FBE6EE5E",
		},
		{
			"id": "b_warmwood",
			"name": "暖木",
			"en": "WARM WOOD",
			"desc": "奶油底配胡桃木棋盘，珊瑚红强调。像真实棋具。",
			"serif": false,
			"bg_top": "#FDF3E7", "bg_bottom": "#F4DFC8",
			"text": "#43301F", "muted": "#9B7C62",
			"accent": "#E2604A", "accent_text": "#FFF8F2",
			"surface": "#FFF8EEF2", "surface_border": "#A0745047",
			"btn_bg": "#FFF6EAF2", "btn_text": "#6B4A2E", "btn_border": "#A0745059",
			"chip_bg": "#FFF9F2CC", "chip_border": "#A074504D",
			"board_bg": "#E3BB8C", "board_line": "#8A5A34", "board_star": "#7A4A26",
			"frame_bg": "#8D5A34", "frame_border": "#6F4325",
			"stone_black": "#2E2018", "stone_black_hi": "#8A6A52",
			"stone_white": "#FFFAF0", "stone_white_edge": "#CBB193",
			"win": "#E2604A", "scrim": "#3A24152E",
			"radius_btn": 8, "radius_card": 14, "radius_board": 8,
			"shadow": "#78503266", "shadow_size": 12,
			"art_tint": "#FFFFFFF5", "veil": "#FBEFDE52",
		},
		{
			"id": "c_berry",
			"name": "莓夜",
			"en": "BERRY NIGHT",
			"desc": "深莓紫底，霓虹粉，暖米色棋盘。反差最大。",
			"serif": false,
			"bg_top": "#2B1822", "bg_bottom": "#170E13",
			"text": "#FBEEF2", "muted": "#C39AA8",
			"accent": "#FF5F8D", "accent_text": "#25101A",
			"surface": "#2A1A22F0", "surface_border": "#FF8AAA38",
			"btn_bg": "#FFFFFF12", "btn_text": "#F6DDE4", "btn_border": "#FF8AAA3D",
			"chip_bg": "#FF5F8D24", "chip_border": "#FF8AAA4D",
			"board_bg": "#F3DDCB", "board_line": "#A9786A", "board_star": "#8E5F52",
			"frame_bg": "#452332", "frame_border": "#FF8AAA2E",
			"stone_black": "#2A1C22", "stone_black_hi": "#A98E97",
			"stone_white": "#FFF6F1", "stone_white_edge": "#D9BDB2",
			"win": "#FF5F8D", "scrim": "#0B060A24",
			"radius_btn": 12, "radius_card": 20, "radius_board": 18,
			"shadow": "#000000B3", "shadow_size": 14,
			"art_tint": "#8A6274C4", "veil": "#2B18226E",
		},
		{
			"id": "d_washi",
			"name": "和纸",
			"en": "WASHI BENI",
			"desc": "米纸底，朱红，衬线标题，直角细边。像棋谱。",
			"serif": true,
			"bg_top": "#FBF6EC", "bg_bottom": "#F1E5D0",
			"text": "#3A2A20", "muted": "#8A7052",
			"accent": "#C0442C", "accent_text": "#FDF6EA",
			"surface": "#FFFCF4E6", "surface_border": "#78583866",
			"btn_bg": "#FDF8EEF2", "btn_text": "#5A4530", "btn_border": "#78583880",
			"chip_bg": "#FFFCF4E6", "chip_border": "#78583866",
			"board_bg": "#ECD9B8", "board_line": "#7D5A38", "board_star": "#634323",
			"frame_bg": "#DDC39B", "frame_border": "#B99568",
			"stone_black": "#2B2118", "stone_black_hi": "#7A6650",
			"stone_white": "#FFFDF4", "stone_white_edge": "#C8B291",
			"win": "#C0442C", "scrim": "#3A2A2024",
			"radius_btn": 2, "radius_card": 2, "radius_board": 2,
			"shadow": "#5A402600", "shadow_size": 0,
			"art_tint": "#FFFDF4F5", "veil": "#FAF1E04C",
		},
		{
			# 混合款：樱雾的粉色界面 + 暖木的木质棋盘
			"id": "e_sakuraw",
			"name": "樱木",
			"en": "SAKURA WOOD",
			"desc": "樱雾的浅粉界面，配暖木的木质棋盘与暖调棋子。",
			"serif": false,
			"bg_top": "#FFFAFB", "bg_bottom": "#FBF0F3",
			"text": "#4B3238", "muted": "#A4818B",
			"accent": "#E8698B", "accent_text": "#FFFFFF",
			"surface": "#FFFDFDF2", "surface_border": "#C4929E5C",
			"btn_bg": "#FFFFFFEE", "btn_text": "#6B4551", "btn_border": "#C4929E66",
			"chip_bg": "#FFFFFFB8", "chip_border": "#C4929E57",
			"board_bg": "#E3BB8C", "board_line": "#8A5A34", "board_star": "#7A4A26",
			"frame_bg": "#8D5A34", "frame_border": "#6F4325",
			"stone_black": "#2E2018", "stone_black_hi": "#8A6A52",
			"stone_white": "#FFFAF0", "stone_white_edge": "#CBB193",
			"win": "#E8698B", "scrim": "#2B1A1E1A",
			"radius_btn": 12, "radius_card": 18, "radius_board": 8,
			"shadow": "#BE788C4D", "shadow_size": 10,
			"art_tint": "#FFFFFFF2", "veil": "#FBE6EE5E",
		},
	]
