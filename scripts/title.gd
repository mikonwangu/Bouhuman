extends Control


func _ready() -> void:
	GameState.phase = GameState.Phase.TITLE
	var play := get_node_or_null("Center/VBox/PlayButton") as Button
	if play:
		play.grab_focus()


func _on_play_pressed() -> void:
	GameState.go_char_select()


func _on_setting_pressed() -> void:
	GameState.go_setting()


func _on_end_pressed() -> void:
	# Web ではウィンドウを閉じられないことが多いのでタイトルに留まるメッセージ
	if OS.has_feature("web"):
		$Center/VBox/HintLabel.text = "ブラウザタブを閉じて終了してください。"
		return
	get_tree().quit()
