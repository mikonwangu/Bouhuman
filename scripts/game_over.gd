extends Control


func _ready() -> void:
	GameState.phase = GameState.Phase.GAME_OVER
	%WinsLabel.text = "勝利数: %d" % GameState.wins


func _on_title_pressed() -> void:
	GameState.go_title()
