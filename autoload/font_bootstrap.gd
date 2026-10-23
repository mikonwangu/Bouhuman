extends Node
## Web 向け: ラテン用フォントに CJK フォールバックを載せ、数字・英字・日本語を両立させる。

var ui_theme: Theme


func _ready() -> void:
	var latin: Font = load("res://fonts/DejaVuSans.ttf")
	var cjk: Font = load("res://fonts/DroidSansFallback.ttf")
	if latin == null or cjk == null:
		push_warning("FontBootstrap: font load failed")
		return
	var combined: Font = latin.duplicate(true)
	combined.fallbacks = [cjk]
	ThemeDB.fallback_font = combined
	ThemeDB.fallback_font_size = 16

	ui_theme = Theme.new()
	ui_theme.default_font = combined
	ui_theme.default_font_size = 16
	# プロジェクト Theme の default_font も差し替え
	if ResourceLoader.exists("res://theme/game_theme.tres"):
		var project_theme: Theme = load("res://theme/game_theme.tres")
		if project_theme:
			project_theme.default_font = combined
			project_theme.default_font_size = 16
			ui_theme = project_theme

	if get_tree() and get_tree().root:
		get_tree().root.theme = ui_theme
	# CanvasLayer 配下の Control は Window.theme を継がないことがあるため、追加時に付与
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if ui_theme == null:
		return
	if node is CanvasLayer:
		# 直下の Control にテーマを載せる
		for c in node.get_children():
			if c is Control and (c as Control).theme == null:
				(c as Control).theme = ui_theme
	elif node is Control:
		var parent := node.get_parent()
		if parent is CanvasLayer and (node as Control).theme == null:
			(node as Control).theme = ui_theme
