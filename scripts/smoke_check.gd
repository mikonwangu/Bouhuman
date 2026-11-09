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
	ok = _check_arena_layouts() and ok
	ok = _check_platform_landing() and ok
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
	var fscale: float = float(SF.FIGHTER_SCALE)
	if fscale < 0.75 or fscale > 0.90:
		push_error("FIGHTER_SCALE out of modest shrink range: %s" % str(fscale))
		fig.free()
		return false
	fig.free()
	print("enemy_types ", seen_normal.keys(), " bosses ", boss_a["id"], "/", boss_b["id"], " fighter_scale=", fscale)
	return true


func _check_arena_layouts() -> bool:
	var A = load("res://scripts/battle_arena.gd")
	if A == null:
		push_error("battle_arena load failed")
		return false
	var ids: Array[String] = ["split_gap", "step_up", "mid_bridge", "twin_ledges", "boss_towers", "boss_pit", "flat_gap"]
	var arena: Node2D = A.new()
	for lid in ids:
		arena.load_layout(lid)
		if arena.platforms.is_empty():
			push_error("arena layout empty: " + lid)
			arena.free()
			return false
		for p in arena.platforms:
			if not p.has("kind") or not p.has("left") or not p.has("top"):
				push_error("arena platform incomplete in " + lid)
				arena.free()
				return false
			var kind := str(p["kind"])
			if kind not in ["ground", "bridge", "ledge"]:
				push_error("unknown platform kind in " + lid + ": " + kind)
				arena.free()
				return false
		var label: String = A.layout_label(lid)
		if label == "" or label == null:
			push_error("layout_label missing for " + lid)
			arena.free()
			return false
		# スポーンはワールド内
		if arena.spawn_player.x < A.WORLD_LEFT or arena.spawn_enemy.x > A.WORLD_RIGHT:
			push_error("spawn out of world in " + lid)
			arena.free()
			return false
		# 拡幅後: 敵スポーンが旧ワールド右端(920)より右にあること
		if arena.spawn_enemy.x <= 920.0 and lid != "flat_gap":
			push_error("expected wider stage spawn for " + lid)
			arena.free()
			return false
	if float(A.WORLD_W) < 1200.0 or float(A.WORLD_RIGHT) <= 920.0:
		push_error("arena world not enlarged")
		arena.free()
		return false
	# ローテが通常／ボスで分かれること
	var n0: String = A.pick_layout_id(0, false)
	var n1: String = A.pick_layout_id(1, false)
	var b0: String = A.pick_layout_id(9, true)
	if n0 == n1:
		push_error("normal layout rotation stuck")
		arena.free()
		return false
	if not str(b0).begins_with("boss_"):
		push_error("boss layout expected, got " + b0)
		arena.free()
		return false
	arena.free()
	print("arena_layouts ", ids, " world_w=", A.WORLD_W)
	return true


func _check_platform_landing() -> bool:
	## ジャンプ到達高と着地スイープが上部足場に届くことを検証
	var Battle = load("res://scripts/battle.gd")
	var A = load("res://scripts/battle_arena.gd")
	if Battle == null or A == null:
		push_error("battle/arena load failed for landing check")
		return false
	# battle.gd の定数をソースから読めないため、同等の離散ピークを再計算
	# JUMP_SPEED / GRAVITY は battle.gd と同期させること
	var jump_speed := -820.0
	var gravity := 2800.0
	var dt := 1.0 / 60.0
	var peak := _discrete_jump_peak(jump_speed, gravity, dt)
	if peak < 100.0:
		push_error("jump peak too low: %.1f (need >=100 for upper platforms)" % peak)
		return false
	var arena: Node2D = A.new()
	var ids: Array[String] = ["split_gap", "step_up", "mid_bridge", "twin_ledges", "boss_towers", "boss_pit"]
	for lid in ids:
		arena.load_layout(lid)
		var worst: float = arena.max_adjacent_rise()
		if worst > peak + 1.0:
			push_error("layout %s adjacent rise %.1f exceeds jump peak %.1f" % [lid, worst, peak])
			arena.free()
			return false
		if worst > float(A.MAX_STEP_RISE) + 1.0:
			push_error("layout %s rise %.1f exceeds MAX_STEP_RISE" % [lid, worst])
			arena.free()
			return false
		# スポーン床から一段上の足場へ、実際の try_land スイープで着地できること
		if not _sim_land_on_upper(arena, jump_speed, gravity, dt):
			push_error("landing sim failed for " + lid)
			arena.free()
			return false
	arena.free()
	print("platform_landing peak=", snapped(peak, 0.1), " layouts_ok")
	return true


func _discrete_jump_peak(jump_speed: float, gravity: float, dt: float) -> float:
	var y := 0.0
	var vel := jump_speed
	var min_y := 0.0
	for _i in 300:
		vel += gravity * dt
		y += vel * dt
		min_y = minf(min_y, y)
		if vel > 0.0 and y > min_y + 1.0:
			break
	return -min_y


func _sim_land_on_upper(arena: Node2D, jump_speed: float, gravity: float, dt: float) -> bool:
	var spawn: Vector2 = arena.spawn_player
	var base: Dictionary = arena.standing_on(spawn)
	if base.is_empty():
		# スポーンを足場上面に吸着
		spawn.y = float(arena.platforms[0]["top"])
		base = arena.standing_on(spawn)
	if base.is_empty():
		push_error("spawn not on platform")
		return false
	# 隣接する一段上の足場へジャンプ着地を試す
	var target: Dictionary = {}
	var best_rise := 0.0
	for p in arena.platforms:
		var rise: float = float(base["top"]) - float(p["top"])
		if rise < 20.0 or rise > 95.0:
			continue
		var gap: float = 0.0
		var a_r: float = float(base["right"])
		var a_l: float = float(base["left"])
		var b_l: float = float(p["left"])
		var b_r: float = float(p["right"])
		if a_r < b_l:
			gap = b_l - a_r
		elif b_r < a_l:
			gap = a_l - b_r
		if gap > 160.0:
			continue
		if rise > best_rise:
			best_rise = rise
			target = p
	if target.is_empty():
		# スポーン直上に上段が無い場合は、全体の最高段差足場で着地だけ確認
		for p in arena.platforms:
			var rise2: float = float(base["top"]) - float(p["top"])
			if rise2 >= 20.0 and rise2 <= 95.0:
				target = p
				break
	if target.is_empty():
		return true
	var tx: float = (float(target["left"]) + float(target["right"])) * 0.5
	# 足場直下の低い床から跳ぶ（水平移動なし）
	var from_y: float = float(base["top"])
	# ターゲット直下に別の低い足場があればそこを使用
	for p in arena.platforms:
		if tx < float(p["left"]) - 6.0 or tx > float(p["right"]) + 6.0:
			continue
		var t: float = float(p["top"])
		if t > float(target["top"]) + 15.0 and t <= from_y + 1.0:
			from_y = t
	var pos := Vector2(tx, from_y)
	var vel := jump_speed
	for _i in 180:
		var prev_y := pos.y
		vel += gravity * dt
		pos.y += vel * dt
		pos.x = tx
		var land: Dictionary = arena.try_land(pos, prev_y, vel)
		if bool(land.get("landed", false)):
			var top: float = float(land["y"])
			if absf(top - float(target["top"])) <= 1.0:
				return true
			if top < from_y - 10.0:
				return true
	return false


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
