extends Control


func _ready() -> void:
	GameState.phase = GameState.Phase.CLEAR
	%WinsLabel.text = "30回勝利！クリアおめでとうございます。"


func _on_title_pressed() -> void:
	GameState.go_title()
