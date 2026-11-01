# sfx.gd（自动加载单例 Sfx）
# 音效的唯一入口：懒加载 wav、播放器轮转、开关与持久化，并自动给所有按钮挂上按键音。
# 素材是程序化合成的（见会话目录 audio/gen_sfx.py），无第三方版权。
extends Node

signal changed

const SAVE_PATH := "user://settings.cfg"

const STREAMS := {
	"place_black": "res://assets/audio/place_black.wav",
	"place_white": "res://assets/audio/place_white.wav",
	"win": "res://assets/audio/win.wav",
	"lose": "res://assets/audio/lose.wav",
	"draw": "res://assets/audio/draw.wav",
	"click": "res://assets/audio/click.wav",
}

# 各音效的基准音量：落子要轻，按键更轻，结算稍响
const VOLUMES := {
	"place_black": -7.0,
	"place_white": -7.0,
	"win": -3.0,
	"lose": -3.0,
	"draw": -3.0,
	"click": -13.0,
}

const VOICES := 4          # 同时能响几声（连下时不会互相掐断）

var enabled := true
var save_path := SAVE_PATH

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _cursor := 0


func _ready() -> void:
	load_saved()
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_voices.append(p)
	# 任何按钮进树时自动挂上按键音，不必逐个连
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("_sfx_hooked"):
		n.set_meta("_sfx_hooked", true)
		(n as BaseButton).pressed.connect(_on_any_button_pressed)


func _on_any_button_pressed() -> void:
	play("click")


# ---------------- 播放 ----------------

func play(id: String) -> void:
	if not enabled:
		return
	var st := stream(id)
	if st == null:
		return
	var p := _free_voice()
	p.stream = st
	p.volume_db = float(VOLUMES.get(id, -6.0))
	p.play()


func stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := str(STREAMS.get(id, ""))
	var st: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		st = load(path) as AudioStream
	_streams[id] = st
	return st


# 优先用空闲的播放器，都在响就轮转覆盖最老的那个
func _free_voice() -> AudioStreamPlayer:
	for p in _voices:
		if not p.playing:
			return p
	var p := _voices[_cursor % _voices.size()]
	_cursor += 1
	return p


func stop_all() -> void:
	for p in _voices:
		p.stop()


func _exit_tree() -> void:
	stop_all()
	for p in _voices:
		p.stream = null
	_streams.clear()


# ---------------- 开关 ----------------

func set_enabled(v: bool) -> void:
	if enabled == v:
		return
	enabled = v
	if not enabled:
		stop_all()
	save_current()
	changed.emit()


func toggle() -> void:
	set_enabled(not enabled)


# ---------------- 持久化（与主题共用一个文件，只动 [audio] 段） ----------------

func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	enabled = bool(cfg.get_value("audio", "enabled", true))


func save_current() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("audio", "enabled", enabled)
	cfg.save(save_path)
