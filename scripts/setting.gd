extends Control

@onready var volume_label: Label = %VolumeLabel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var size_option: OptionButton = %SizeOption
@onready var quality_option: OptionButton = %QualityOption


func _ready() -> void:
	GameState.phase = GameState.Phase.SETTING
	volume_slider.min_value = 0
	volume_slider.max_value = 9
	volume_slider.step = 1
	volume_slider.value = SettingsManager.master_volume_step
	_refresh_volume_label()

	size_option.clear()
	size_option.add_item("小 (640x360)", 0)
	size_option.add_item("中 (960x540)", 1)
	size_option.add_item("大 (1280x720)", 2)
	size_option.add_item("フルスクリーン", 3)
	var size_keys := ["small", "medium", "large", "fullscreen"]
	size_option.select(size_keys.find(SettingsManager.browser_size))

	quality_option.clear()
	quality_option.add_item("低", 0)
	quality_option.add_item("中", 1)
	quality_option.add_item("大", 2)
	var q_keys := ["low", "mid", "high"]
	quality_option.select(q_keys.find(SettingsManager.quality))


func _refresh_volume_label() -> void:
	var step: int = SettingsManager.master_volume_step
	volume_label.text = "マスター音量: %d / 10（段階 %d）" % [step + 1, step]


func _on_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume_step(int(value))
	_refresh_volume_label()


func _on_size_selected(index: int) -> void:
	var size_keys := ["small", "medium", "large", "fullscreen"]
	if index >= 0 and index < size_keys.size():
		SettingsManager.set_browser_size(size_keys[index])


func _on_quality_selected(index: int) -> void:
	var q_keys := ["low", "mid", "high"]
	if index >= 0 and index < q_keys.size():
		SettingsManager.set_quality(q_keys[index])


func _on_back_pressed() -> void:
	GameState.go_title()
