extends SceneTree
## headless: godot --headless --path . -s res://scripts/smoke_check.gd


func _initialize() -> void:
	var ok := true
	var w: Script = load("res://data/weapon_catalog.gd")
	var s: Script = load("res://data/special_catalog.gd")
	var c: Script = load("res://data/character_types.gd")
	if w == null or s == null or c == null:
		push_error("catalog load failed")
		ok = false
	# Instantiate via class constants through new() on RefCounted scripts
	var scenes := [
		"res://scenes/title.tscn",
		"res://scenes/setting.tscn",
		"res://scenes/character_select.tscn",
		"res://scenes/pre_battle.tscn",
		"res://scenes/battle.tscn",
		"res://scenes/reward.tscn",
		"res://scenes/game_over.tscn",
		"res://scenes/clear.tscn",
	]
	for path in scenes:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("scene load failed: " + path)
			ok = false
			continue
		var node := packed.instantiate()
		if node == null:
			push_error("scene instantiate failed: " + path)
			ok = false
		else:
			node.free()
	print("SMOKE_CHECK ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
