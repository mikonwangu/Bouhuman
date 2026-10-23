extends Control

const CharacterTypesScript = preload("res://data/character_types.gd")
const StickFigureScript = preload("res://scripts/stick_figure.gd")

@onready var preview_host: Node2D = %PreviewHost
@onready var desc_label: Label = %DescLabel
@onready var name_label: Label = %NameLabel

var _selected: int = CharacterTypesScript.Type.BALANCE
var _preview: StickFigure


func _ready() -> void:
	GameState.phase = GameState.Phase.CHAR_SELECT
	_preview = StickFigureScript.new()
	preview_host.add_child(_preview)
	_select(CharacterTypesScript.Type.BALANCE)
	# Web / 自動化向け: 開始ボタンにフォーカス（Enter で進行可能）
	var confirm := get_node_or_null("Margin/VBox/Actions/ConfirmButton") as Button
	if confirm:
		confirm.grab_focus()


func _select(t: int) -> void:
	_selected = t
	var data: Dictionary = CharacterTypesScript.get_type(t)
	name_label.text = data["name"]
	# ASCII "x" — Web 埋め込みフォントで乗算記号 × が欠けることがある
	desc_label.text = "%s\n攻撃補正 x%.2f / 速度補正 x%.2f" % [
		data["desc"], data["attack_mul"], data["speed_mul"]
	]
	_preview.figure_color = data["color"]


func _on_power_pressed() -> void:
	_select(CharacterTypesScript.Type.POWER)


func _on_speed_pressed() -> void:
	_select(CharacterTypesScript.Type.SPEED)


func _on_balance_pressed() -> void:
	_select(CharacterTypesScript.Type.BALANCE)


func _on_confirm_pressed() -> void:
	GameState.start_new_run(_selected)


func _on_back_pressed() -> void:
	GameState.go_title()
