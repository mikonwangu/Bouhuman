class_name BattleArena
extends Node2D
## 横スクロール風の短いアリーナ。複数レイアウトを win 数 / ボスで切替。

## 足場: { "left": float, "right": float, "top": float, "thick": float }
var platforms: Array[Dictionary] = []
var layout_id: String = "flat_gap"
var spawn_player := Vector2(160, 320)
var spawn_enemy := Vector2(780, 320)

const WORLD_LEFT := 40.0
const WORLD_RIGHT := 920.0
const FALL_Y := 560.0
const FOOT_EPS := 6.0


static func pick_layout_id(wins: int, is_boss: bool) -> String:
	if is_boss:
		# ボスは専用 or 高難度レイアウトをローテ
		var boss_ids: Array[String] = ["boss_towers", "boss_pit"]
		return boss_ids[(wins / 10) % boss_ids.size()]
	var normal_ids: Array[String] = ["split_gap", "step_up", "mid_bridge", "twin_ledges"]
	return normal_ids[wins % normal_ids.size()]


func load_layout(layout: String) -> void:
	layout_id = layout
	platforms.clear()
	match layout:
		"split_gap":
			# 左右の地面 + 中央ギャップ（ジャンプ必須）+ 低めの足場
			_add(60, 360, 360, 40)
			_add(420, 540, 300, 28)
			_add(600, 900, 360, 40)
			spawn_player = Vector2(180, 360)
			spawn_enemy = Vector2(760, 360)
		"step_up":
			# 左低 → 中段 → 右高の階段状
			_add(60, 340, 380, 40)
			_add(300, 560, 300, 28)
			_add(520, 780, 240, 28)
			_add(740, 920, 320, 36)
			spawn_player = Vector2(160, 380)
			spawn_enemy = Vector2(820, 320)
		"mid_bridge":
			# 左右地面を中央の長い橋でつなぐ + 上段の小足場
			_add(50, 280, 380, 40)
			_add(250, 710, 300, 24)
			_add(680, 920, 380, 40)
			_add(400, 560, 220, 22)
			spawn_player = Vector2(140, 380)
			spawn_enemy = Vector2(820, 380)
		"twin_ledges":
			# 中央低床 + 左右の高い出島（高低差戦）
			_add(80, 300, 260, 28)
			_add(320, 640, 380, 40)
			_add(660, 900, 260, 28)
			_add(200, 320, 340, 22)
			_add(640, 760, 340, 22)
			spawn_player = Vector2(160, 260)
			spawn_enemy = Vector2(800, 260)
		"boss_towers":
			# ボス: 左右タワー + 中央島 + ギャップ多め
			_add(40, 260, 280, 36)
			_add(300, 420, 360, 28)
			_add(460, 620, 240, 26)
			_add(660, 820, 360, 28)
			_add(780, 940, 280, 36)
			_add(380, 540, 180, 22)
			spawn_player = Vector2(120, 280)
			spawn_enemy = Vector2(860, 280)
		"boss_pit":
			# ボス: 深い中央ピットを橋と両翼で挟む
			_add(40, 300, 360, 40)
			_add(340, 460, 280, 24)
			_add(500, 660, 200, 22)
			_add(620, 760, 280, 24)
			_add(740, 940, 360, 40)
			_add(420, 580, 320, 20)
			spawn_player = Vector2(140, 360)
			spawn_enemy = Vector2(860, 360)
		_:
			_add(60, 900, 360, 40)
			spawn_player = Vector2(200, 360)
			spawn_enemy = Vector2(760, 360)
	_rebuild_visuals()


func _add(left: float, right: float, top: float, thick: float) -> void:
	platforms.append({"left": left, "right": right, "top": top, "thick": thick})


func _rebuild_visuals() -> void:
	for c in get_children():
		c.queue_free()
	# ピット背景（下層）
	var pit := ColorRect.new()
	pit.color = Color(0.10, 0.11, 0.14, 1)
	pit.position = Vector2(0, 400)
	pit.size = Vector2(960, 160)
	add_child(pit)
	for p in platforms:
		var rect := ColorRect.new()
		rect.color = Color(0.28, 0.32, 0.38, 1)
		rect.position = Vector2(float(p["left"]), float(p["top"]))
		rect.size = Vector2(float(p["right"]) - float(p["left"]), float(p["thick"]))
		add_child(rect)
		# 上面ハイライト
		var lip := ColorRect.new()
		lip.color = Color(0.42, 0.48, 0.55, 1)
		lip.position = Vector2(float(p["left"]), float(p["top"]))
		lip.size = Vector2(float(p["right"]) - float(p["left"]), 4)
		add_child(lip)


## 落下中（vel_y>=0）に足場上面へ着地できるか。戻り: {landed, y, platform}
func try_land(pos: Vector2, prev_y: float, vel_y: float) -> Dictionary:
	if vel_y < 0.0:
		return {"landed": false, "y": pos.y, "platform": {}}
	var best_y := INF
	var best: Dictionary = {}
	for p in platforms:
		var left: float = p["left"]
		var right: float = p["right"]
		var top: float = p["top"]
		if pos.x < left - 4.0 or pos.x > right + 4.0:
			continue
		# 前フレームより上、今フレームで上面を横切る／乗る
		if prev_y <= top + FOOT_EPS and pos.y >= top - FOOT_EPS:
			if top < best_y:
				best_y = top
				best = p
	if best.is_empty():
		return {"landed": false, "y": pos.y, "platform": {}}
	return {"landed": true, "y": float(best["top"]), "platform": best}


func standing_on(pos: Vector2) -> Dictionary:
	for p in platforms:
		var left: float = p["left"]
		var right: float = p["right"]
		var top: float = p["top"]
		if pos.x < left - 2.0 or pos.x > right + 2.0:
			continue
		if absf(pos.y - top) <= FOOT_EPS:
			return p
	return {}


func clamp_x(x: float, margin_left: float = 0.0, margin_right: float = 0.0) -> float:
	return clampf(x, WORLD_LEFT + margin_left, WORLD_RIGHT - margin_right)


func is_fallen(pos: Vector2) -> bool:
	return pos.y > FALL_Y


## 簡易敵AI向け: 同高の足場なら歩き、違うなら端へ行ってジャンプを促す
func desired_enemy_action(enemy_pos: Vector2, player_pos: Vector2, on_ground: bool) -> Dictionary:
	var my_plat := standing_on(enemy_pos)
	var target_plat := standing_on(player_pos)
	var dir := signf(player_pos.x - enemy_pos.x)
	var want_jump := false
	if my_plat.is_empty():
		# 空中: 水平追従のみ
		return {"dir": dir, "jump": false}
	if target_plat.is_empty() or my_plat == target_plat:
		# 同じ床 or 相手空中: 近づく。端で落ちそうなら止まる／跳ぶ
		var left: float = my_plat["left"]
		var right: float = my_plat["right"]
		var next_x := enemy_pos.x + dir * 20.0
		if next_x < left + 12.0 or next_x > right - 12.0:
			# ギャップ越えが必要そう
			if absf(player_pos.x - enemy_pos.x) > 40.0:
				want_jump = on_ground
			else:
				dir = 0.0
		return {"dir": dir, "jump": want_jump}
	# 別足場: 相手側の端へ寄り、高さ差があればジャンプ
	var goal_x: float
	if player_pos.x >= enemy_pos.x:
		goal_x = float(my_plat["right"]) - 10.0
		dir = 1.0
	else:
		goal_x = float(my_plat["left"]) + 10.0
		dir = -1.0
	if absf(enemy_pos.x - goal_x) < 18.0 and on_ground:
		want_jump = true
	elif absf(float(target_plat["top"]) - float(my_plat["top"])) > 20.0 and on_ground:
		# 高低差があるとき、端付近でジャンプ
		if absf(enemy_pos.x - goal_x) < 40.0:
			want_jump = true
	return {"dir": dir, "jump": want_jump}
