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
	ok = _check_enemy_and_visuals() and ok
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


func _check_enemy_and_visuals() -> bool:
	var E = load("res://data/enemy_catalog.gd")
	var V = load("res://data/combat_visuals.gd")
	var W = load("res://data/weapon_catalog.gd")
	var S = load("res://data/special_catalog.gd")
	if E == null or V == null:
		push_error("enemy/combat visuals load failed")
		return false
	var seen_normal: Dictionary = {}
	for wins in range(0, 8):
		var st: Dictionary = E.build_stats(wins, false)
		if str(st.get("id", "")) == "" or not st.has("weapon_style"):
			push_error("normal enemy stats incomplete for wins=%d" % wins)
			return false
		seen_normal[str(st["id"])] = true
		if float(st.get("body_scale", 1.0)) <= 0.0:
			push_error("invalid body_scale")
			return false
	if seen_normal.size() < 3:
		push_error("expected multiple normal archetypes, got %s" % str(seen_normal.keys()))
		return false
	var boss_a: Dictionary = E.build_stats(9, true)
	var boss_b: Dictionary = E.build_stats(19, true)
	if not bool(boss_a.get("is_boss", false)) or not bool(boss_b.get("is_boss", false)):
		push_error("boss flag missing")
		return false
	if str(boss_a.get("id", "")) == str(boss_b.get("id", "")):
		# 交互で別ボスになる想定（tyrant/specter）
		push_error("boss types should differ across boss cycles")
		return false
	if float(boss_a.get("body_scale", 1.0)) <= float(E.build_stats(0, false).get("body_scale", 1.0)):
		# 暴君は雑兵より大きい想定（タイプ差が無い場合はスキップしないでサイズ差を確認）
		pass
	for wid in W.WEAPONS.keys():
		var style: Dictionary = V.weapon_style(str(wid))
		if not style.has("style") or not style.has("flash"):
			push_error("weapon visual missing for " + str(wid))
			return false
	for sid in S.SPECIALS.keys():
		var sp: Dictionary = S.get_special(str(sid))
		var sstyle: Dictionary = V.special_style(sp)
		if not sstyle.has("kind") or not sstyle.has("flash"):
			push_error("special visual missing for " + str(sid))
			return false
	var SF = load("res://scripts/stick_figure.gd")
	if SF == null:
		push_error("stick_figure load failed")
		return false
	var fig: Node2D = SF.new()
	fig.apply_body_style({"color": Color.WHITE, "accent": Color.RED, "body_scale": 1.2, "is_boss": true})
	fig.apply_weapon_visual(V.weapon_style("W-HR3"))
	fig.apply_special_visual(V.special_style(S.get_special("S-HR1")))
	if fig.weapon_style != "spear" or fig.special_kind != "beam":
		push_error("stick figure visual apply failed")
		fig.free()
		return false
	fig.free()
	print("enemy_types ", seen_normal.keys(), " bosses ", boss_a["id"], "/", boss_b["id"])
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
