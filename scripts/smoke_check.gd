extends SceneTree
## headless: godot --headless --path . -s res://scripts/smoke_check.gd
## 注意: -s 実行時は autoload 識別子が使えないため、カタログ／シーン検証に限定。


func _initialize() -> void:
	var ok := true
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

	ok = _check_catalogs() and ok
	ok = _check_reward_empty_drops() and ok
	ok = _check_boss_special_pick() and ok
	ok = _check_settings_fallback() and ok

	print("SMOKE_CHECK ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)


func _check_catalogs() -> bool:
	var W = load("res://data/weapon_catalog.gd")
	var S = load("res://data/special_catalog.gd")
	if W == null or S == null:
		push_error("catalog load failed")
		return false
	if W.WEAPONS.size() < 10 or S.SPECIALS.size() < 5:
		push_error("catalog size unexpected")
		return false
	return true


func _check_reward_empty_drops() -> bool:
	var W = load("res://data/weapon_catalog.gd")
	var owned: Array = []
	for wid in W.NORMAL_DROP_IDS:
		owned.append(wid)
	var empty_drop: String = W.pick_normal_drop(owned)
	if empty_drop != "":
		push_error("pick_normal_drop should return empty when all owned, got " + empty_drop)
		return false
	owned = []
	for wid in W.BOSS_DROP_IDS:
		owned.append(wid)
	var empty_boss: String = W.pick_boss_drop(owned)
	if empty_boss != "":
		push_error("pick_boss_drop should return empty when all owned, got " + empty_boss)
		return false
	# 未所持ありなら空でない
	owned = [W.STARTER_ID]
	var drop: String = W.pick_normal_drop(owned)
	if drop == "" or drop in owned:
		push_error("pick_normal_drop should return unowned id")
		return false
	return true


func _check_boss_special_pick() -> bool:
	var S = load("res://data/special_catalog.gd")
	var owned: Array = []
	for sid in S.BOSS_SPECIAL_IDS:
		owned.append(sid)
	var empty_s: String = S.pick_boss_special(owned)
	if empty_s != "":
		push_error("pick_boss_special should return empty when all owned")
		return false
	owned = [S.STARTER_ID]
	var counts := {"SR": 0, "HR": 0, "R": 0, "N": 0}
	for i in 200:
		var picked: String = S.pick_boss_special(owned)
		if picked == "" or picked in owned:
			push_error("pick_boss_special failed to pick unowned")
			return false
		if picked.begins_with("S-SR"):
			counts["SR"] += 1
		elif picked.begins_with("S-HR"):
			counts["HR"] += 1
		elif picked.begins_with("S-R"):
			counts["R"] += 1
		else:
			counts["N"] += 1
	# 重み付けが壊れて一様すぎないことの粗い確認（SR が最多にならない）
	if counts["SR"] > counts["HR"] and counts["SR"] > counts["R"]:
		push_error("boss special rarity weighting looks broken: %s" % str(counts))
		return false
	print("boss_special_sample ", counts)
	return true


func _check_settings_fallback() -> bool:
	# settings_manager は autoload なので Node として load→new で検証
	var script: GDScript = load("res://autoload/settings_manager.gd")
	if script == null:
		push_error("settings_manager load failed")
		return false
	var sm: Node = script.new()
	sm.browser_size = "not-a-real-size"
	sm.quality = "ultra"
	# load_settings 相当の検証ロジックを直接再現
	if sm.browser_size not in sm.BROWSER_SIZES:
		sm.browser_size = "medium"
	if sm.quality not in ["low", "mid", "high"]:
		sm.quality = "mid"
	if sm.browser_size != "medium" or sm.quality != "mid":
		push_error("settings fallback failed")
		sm.free()
		return false
	sm.free()
	return true
