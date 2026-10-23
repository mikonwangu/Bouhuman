extends Node
## Setting: マスター音量10段階 / ブラウザ大きさ / 画質 低・中・大

signal settings_changed

const SAVE_PATH := "user://settings.cfg"

## 0..9 → 線形で 0.0..1.0
var master_volume_step: int = 7
## small / medium / large / fullscreen
var browser_size: String = "medium"
## low / mid / high （要件: 低 / 中 / 大）
var quality: String = "mid"

const BROWSER_SIZES := {
	"small": Vector2i(640, 360),
	"medium": Vector2i(960, 540),
	"large": Vector2i(1280, 720),
	"fullscreen": Vector2i(0, 0),
}


func _ready() -> void:
	load_settings()
	apply_all()


func volume_linear() -> float:
	return clampf(float(master_volume_step) / 9.0, 0.0, 1.0)


func set_master_volume_step(step: int) -> void:
	master_volume_step = clampi(step, 0, 9)
	apply_audio()
	save_settings()
	settings_changed.emit()


func set_browser_size(size_key: String) -> void:
	if size_key not in BROWSER_SIZES:
		return
	browser_size = size_key
	apply_display()
	save_settings()
	settings_changed.emit()


func set_quality(q: String) -> void:
	if q not in ["low", "mid", "high"]:
		return
	quality = q
	apply_quality()
	save_settings()
	settings_changed.emit()


func apply_all() -> void:
	apply_audio()
	apply_display()
	apply_quality()


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	var linear := volume_linear()
	if linear <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(linear))


func apply_display() -> void:
	if browser_size not in BROWSER_SIZES:
		browser_size = "medium"
	if browser_size == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size: Vector2i = BROWSER_SIZES[browser_size]
	DisplayServer.window_set_size(size)
	# Web 向け: JS で canvas サイズを変えるフック（エクスポート時に有効）
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"if (typeof window !== 'undefined' && window.BouhumanSetSize) { window.BouhumanSetSize(%d, %d); }"
			% [size.x, size.y]
		)


func apply_quality() -> void:
	match quality:
		"low":
			Engine.max_fps = 30
			get_tree().root.content_scale_factor = 0.75
		"mid":
			Engine.max_fps = 60
			get_tree().root.content_scale_factor = 1.0
		"high":
			Engine.max_fps = 0
			get_tree().root.content_scale_factor = 1.0


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume_step", master_volume_step)
	cfg.set_value("display", "browser_size", browser_size)
	cfg.set_value("display", "quality", quality)
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_volume_step = clampi(int(cfg.get_value("audio", "master_volume_step", master_volume_step)), 0, 9)
	browser_size = str(cfg.get_value("display", "browser_size", browser_size))
	if browser_size not in BROWSER_SIZES:
		browser_size = "medium"
	quality = str(cfg.get_value("display", "quality", quality))
	if quality not in ["low", "mid", "high"]:
		quality = "mid"


func quality_label_ja() -> String:
	match quality:
		"low":
			return "低"
		"mid":
			return "中"
		"high":
			return "大"
		_:
			return quality


func browser_size_label_ja() -> String:
	match browser_size:
		"small":
			return "小 (640×360)"
		"medium":
			return "中 (960×540)"
		"large":
			return "大 (1280×720)"
		"fullscreen":
			return "フルスクリーン"
		_:
			return browser_size
