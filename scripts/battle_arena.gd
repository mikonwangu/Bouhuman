class_name BattleArena
extends Node2D
## 横スクロール風の短いアリーナ。複数レイアウトを win 数 / ボスで切替。
## 足場・ピット・スポーン位置がすぐ読めるよう、シルエットと対比を優先して描画する。

## 足場: { "left","right","top","thick","kind" }  kind = ground | bridge | ledge
var platforms: Array[Dictionary] = []
var layout_id: String = "flat_gap"
var spawn_player := Vector2(160, 320)
var spawn_enemy := Vector2(780, 320)

const WORLD_LEFT := 40.0
const WORLD_RIGHT := 920.0
const FALL_Y := 560.0
## 着地・接地の許容（高速落下のトンネル抜け防止も兼ねる）
const FOOT_EPS := 10.0
const VIEW_W := 960.0
const VIEW_H := 540.0
## 隣接足場の最大段差目安（battle.gd のジャンプ到達高と揃える）
const MAX_STEP_RISE := 95.0

## 日本語向けレイアウト表示名（HUD 用）
const LAYOUT_LABELS := {
	"split_gap": "左右島＋中央ギャップ",
	"step_up": "段差階段",
	"mid_bridge": "中央の橋",
	"twin_ledges": "高低の出島",
	"boss_towers": "ボス・双塔",
	"boss_pit": "ボス・深坑",
	"flat_gap": "平床",
}


static func pick_layout_id(wins: int, is_boss: bool) -> String:
	if is_boss:
		# ボスは専用 or 高難度レイアウトをローテ
		var boss_ids: Array[String] = ["boss_towers", "boss_pit"]
		return boss_ids[(wins / 10) % boss_ids.size()]
	var normal_ids: Array[String] = ["split_gap", "step_up", "mid_bridge", "twin_ledges"]
	return normal_ids[wins % normal_ids.size()]


static func layout_label(layout: String) -> String:
	return str(LAYOUT_LABELS.get(layout, layout))


func load_layout(layout: String) -> void:
	layout_id = layout
	platforms.clear()
	match layout:
		"split_gap":
			# 左右の地面 + 中央ギャップ（ジャンプ必須）+ 低めの足場
			_add(60, 360, 360, 40, "ground")
			_add(420, 540, 300, 28, "bridge")
			_add(600, 900, 360, 40, "ground")
			spawn_player = Vector2(180, 360)
			spawn_enemy = Vector2(760, 360)
		"step_up":
			# 左低 → 中段 → 右高の階段状
			_add(60, 340, 380, 40, "ground")
			_add(300, 560, 300, 28, "bridge")
			_add(520, 780, 240, 28, "ledge")
			_add(740, 920, 320, 36, "ground")
			spawn_player = Vector2(160, 380)
			spawn_enemy = Vector2(820, 320)
		"mid_bridge":
			# 左右地面を中央の長い橋でつなぐ + 上段の小足場（橋から1段）
			_add(50, 280, 380, 40, "ground")
			_add(250, 710, 300, 24, "bridge")
			_add(680, 920, 380, 40, "ground")
			# 左右地面から水平に離し、橋からの段差〜80pxに抑える
			_add(450, 510, 220, 22, "ledge")
			spawn_player = Vector2(140, 380)
			spawn_enemy = Vector2(820, 380)
		"twin_ledges":
			# 中央低床 + 左右の高い出島（1ジャンプで届く高低差）
			_add(80, 300, 285, 28, "ledge")
			_add(320, 640, 380, 40, "ground")
			_add(660, 900, 285, 28, "ledge")
			_add(200, 320, 340, 22, "bridge")
			_add(640, 760, 340, 22, "bridge")
			spawn_player = Vector2(160, 285)
			spawn_enemy = Vector2(800, 285)
		"boss_towers":
			# ボス: 左右タワー + 中央島。重なる足場の段差はジャンプ到達内に収める
			_add(40, 260, 280, 36, "ground")
			_add(300, 420, 330, 28, "bridge")
			_add(460, 620, 250, 26, "ledge")
			_add(660, 820, 330, 28, "bridge")
			_add(780, 940, 280, 36, "ground")
			# 最上段は橋からでも届く高さ（段差 ≤95）に揃える
			_add(480, 600, 235, 22, "ledge")
			spawn_player = Vector2(120, 280)
			spawn_enemy = Vector2(860, 280)
		"boss_pit":
			# ボス: 深い中央ピットを橋と両翼で挟む（上段は中継足場経由）
			_add(40, 300, 360, 40, "ground")
			_add(340, 460, 285, 24, "bridge")
			_add(470, 560, 235, 22, "ledge")
			_add(620, 760, 285, 24, "bridge")
			_add(740, 940, 360, 40, "ground")
			_add(400, 560, 325, 20, "bridge")
			spawn_player = Vector2(140, 360)
			spawn_enemy = Vector2(860, 360)
		_:
			layout_id = "flat_gap"
			_add(60, 900, 360, 40, "ground")
			spawn_player = Vector2(200, 360)
			spawn_enemy = Vector2(760, 360)
	queue_redraw()


func _add(left: float, right: float, top: float, thick: float, kind: String = "ground") -> void:
	platforms.append({
		"left": left,
		"right": right,
		"top": top,
		"thick": thick,
		"kind": kind,
	})


func _draw() -> void:
	_draw_sky_and_depth()
	_draw_pit_and_hazards()
	_draw_platforms()
	_draw_spawn_cues()
	_draw_layout_caption()


func _draw_sky_and_depth() -> void:
	# 空〜地平のグラデーション（上明るめ／下暗め）で床との境界をはっきりさせる
	var bands := 12
	for i in bands:
		var t := float(i) / float(bands - 1)
		var c := Color(0.22, 0.34, 0.42, 1.0).lerp(Color(0.10, 0.14, 0.18, 1.0), t)
		var y0 := VIEW_H * float(i) / float(bands)
		var y1 := VIEW_H * float(i + 1) / float(bands)
		draw_rect(Rect2(0.0, y0, VIEW_W, y1 - y0 + 1.0), c)

	# 遠景シルエット（パララックス風・装飾のみ、当たり判定なし）
	var far := Color(0.08, 0.12, 0.16, 0.55)
	draw_rect(Rect2(40, 310, 110, 90), far)
	draw_rect(Rect2(180, 280, 70, 120), far)
	draw_rect(Rect2(280, 300, 140, 100), far)
	draw_rect(Rect2(520, 270, 90, 130), far)
	draw_rect(Rect2(680, 295, 120, 105), far)
	draw_rect(Rect2(840, 285, 80, 115), far)

	# 地平線の薄い帯
	draw_rect(Rect2(0.0, 395.0, VIEW_W, 3.0), Color(0.35, 0.48, 0.55, 0.35))


func _draw_pit_and_hazards() -> void:
	# 落下域（ピット）本体
	draw_rect(Rect2(0.0, 400.0, VIEW_W, VIEW_H - 400.0), Color(0.06, 0.07, 0.09, 1.0))

	# 斜めハッチで「落ちる場所」を示す
	var hatch := Color(0.55, 0.22, 0.18, 0.28)
	var y0 := 405.0
	var y1 := VIEW_H - 8.0
	var x := -40.0
	while x < VIEW_W + 40.0:
		draw_line(Vector2(x, y0), Vector2(x + 55.0, y1), hatch, 2.0)
		x += 28.0

	# ピット上縁の危険ライン
	draw_rect(Rect2(0.0, 400.0, VIEW_W, 4.0), Color(0.78, 0.32, 0.22, 0.85))
	draw_rect(Rect2(0.0, 404.0, VIEW_W, 2.0), Color(0.95, 0.55, 0.30, 0.35))

	# 同高度の足場間ギャップ直下に落下マーカー（他足場で埋まっている隙間は除外）
	for i in platforms.size():
		for j in range(i + 1, platforms.size()):
			var a: Dictionary = platforms[i]
			var b: Dictionary = platforms[j]
			# 高低差があっても横に抜けられる隙間は落とす（橋の脇など）
			if absf(float(a["top"]) - float(b["top"])) > 120.0:
				continue
			var a_right: float = float(a["right"])
			var a_left: float = float(a["left"])
			var b_right: float = float(b["right"])
			var b_left: float = float(b["left"])
			var gap_l: float
			var gap_r: float
			if a_right < b_left:
				gap_l = a_right
				gap_r = b_left
			elif b_right < a_left:
				gap_l = b_right
				gap_r = a_left
			else:
				continue
			var gap := gap_r - gap_l
			if gap < 28.0:
				continue
			var mid := (gap_l + gap_r) * 0.5
			# 真上に別足場がある中央ギャップはマーカー不要（橋本体の下など）
			if _x_has_platform(mid):
				continue
			_draw_gap_chevron(mid, 412.0, minf(gap * 0.45, 40.0))


func _x_has_platform(x: float) -> bool:
	for p in platforms:
		if x >= float(p["left"]) - 2.0 and x <= float(p["right"]) + 2.0:
			return true
	return false


func _draw_gap_chevron(cx: float, y: float, half_w: float) -> void:
	var col := Color(0.92, 0.45, 0.28, 0.75)
	draw_line(Vector2(cx - half_w, y), Vector2(cx, y + 14.0), col, 2.5)
	draw_line(Vector2(cx + half_w, y), Vector2(cx, y + 14.0), col, 2.5)
	draw_line(Vector2(cx - half_w * 0.65, y + 10.0), Vector2(cx, y + 22.0), col, 2.0)
	draw_line(Vector2(cx + half_w * 0.65, y + 10.0), Vector2(cx, y + 22.0), col, 2.0)


func _draw_platforms() -> void:
	for p in platforms:
		var left: float = p["left"]
		var right: float = p["right"]
		var top: float = p["top"]
		var thick: float = p["thick"]
		var kind: String = str(p.get("kind", "ground"))
		var w := right - left
		var body: Color
		var lip: Color
		var shade: Color
		match kind:
			"bridge":
				# 冷色の橋 — 空より明るく、地面と色相が違う
				body = Color(0.38, 0.52, 0.60, 1.0)
				lip = Color(0.78, 0.92, 0.98, 1.0)
				shade = Color(0.16, 0.24, 0.28, 1.0)
			"ledge":
				# 黄緑の出島 — 高所の目印
				body = Color(0.42, 0.48, 0.30, 1.0)
				lip = Color(0.90, 0.95, 0.55, 1.0)
				shade = Color(0.20, 0.22, 0.12, 1.0)
			_:
				# ground: 暖色の石床 — 空の青緑と対比
				body = Color(0.58, 0.46, 0.34, 1.0)
				lip = Color(0.98, 0.90, 0.70, 1.0)
				shade = Color(0.26, 0.18, 0.12, 1.0)

		# 影（接地感）
		draw_rect(Rect2(left + 3.0, top + thick - 2.0, w, 8.0), Color(0, 0, 0, 0.28))
		# 本体
		draw_rect(Rect2(left, top, w, thick), body)
		# 下縁の暗帯で厚みを出す
		draw_rect(Rect2(left, top + thick - 5.0, w, 5.0), shade)
		# 上面ハイライト（着地ライン）
		draw_rect(Rect2(left, top, w, 5.0), lip)
		# 外側アウトライン（シルエット）
		var outline := Color(0.05, 0.05, 0.07, 0.95)
		draw_rect(Rect2(left, top, w, thick), outline, false, 2.0)
		# 端の落差マーカー（ギャップ境界）
		var tick := Color(0.98, 0.92, 0.75, 0.95)
		draw_rect(Rect2(left - 2.0, top - 6.0, 4.0, 12.0), tick)
		draw_rect(Rect2(right - 2.0, top - 6.0, 4.0, 12.0), tick)


func _draw_spawn_cues() -> void:
	# スポーン足元の薄い色帯のみ（緑=自側 / 赤=敵側）。文字は付けずノイズを抑える。
	_draw_spawn_pad(spawn_player, Color(0.35, 0.85, 0.55, 0.65))
	_draw_spawn_pad(spawn_enemy, Color(0.95, 0.45, 0.40, 0.65))


func _draw_spawn_pad(pos: Vector2, col: Color) -> void:
	var pad_w := 52.0
	var pad_h := 7.0
	var rect := Rect2(pos.x - pad_w * 0.5, pos.y - 1.0, pad_w, pad_h)
	draw_rect(rect, Color(col.r, col.g, col.b, 0.28))
	draw_rect(rect, col, false, 1.5)
	# 内側の短いハイライトで「立つ位置」を示す
	draw_rect(Rect2(pos.x - 10.0, pos.y - 1.0, 20.0, 3.0), Color(1, 1, 1, 0.35))


func _draw_layout_caption() -> void:
	# 画面左下にレイアウト名だけ（操作説明の重複はしない）
	var label := layout_label(layout_id)
	var font: Font = ThemeDB.fallback_font
	var fs := 13
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad := Vector2(10, 6)
	var box_pos := Vector2(12, VIEW_H - 36)
	var box := Rect2(box_pos, text_size + pad * 2.0)
	draw_rect(box, Color(0.05, 0.07, 0.09, 0.55))
	draw_rect(box, Color(0.70, 0.78, 0.85, 0.35), false, 1.0)
	draw_string(font, box_pos + pad + Vector2(0, text_size.y - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.88, 0.92, 0.95, 0.9))


## 落下中（vel_y>=0）に足場上面へ着地できるか。戻り: {landed, y, platform}
## 上から抜けるワンウェイ足場。区間 [prev_y, pos.y] が上面を横切ったら着地。
func try_land(pos: Vector2, prev_y: float, vel_y: float) -> Dictionary:
	if vel_y < 0.0:
		return {"landed": false, "y": pos.y, "platform": {}}
	var best_y := INF
	var best: Dictionary = {}
	for p in platforms:
		var left: float = p["left"]
		var right: float = p["right"]
		var top: float = p["top"]
		if pos.x < left - 6.0 or pos.x > right + 6.0:
			continue
		# スイープ: 前フレームは上面より上（または僅かに下）、今フレームで上面以下
		if prev_y <= top + FOOT_EPS and pos.y >= top:
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
		if pos.x < left - 6.0 or pos.x > right + 6.0:
			continue
		if absf(pos.y - top) <= FOOT_EPS:
			return p
	return {}


## ジャンプ到達高（離散）内で、隣接足場へ登れるかのレイアウト健全性チェック用
func max_adjacent_rise() -> float:
	var worst := 0.0
	for i in platforms.size():
		var a: Dictionary = platforms[i]
		for j in platforms.size():
			if i == j:
				continue
			var b: Dictionary = platforms[j]
			var rise: float = float(a["top"]) - float(b["top"])
			if rise <= 0.0:
				continue
			# 水平に近い（ジャンプで渡れる距離）ものだけを隣接とみなす
			var gap: float = _horizontal_gap(a, b)
			if gap > 160.0:
				continue
			worst = maxf(worst, rise)
	return worst


func _horizontal_gap(a: Dictionary, b: Dictionary) -> float:
	var a_l: float = a["left"]
	var a_r: float = a["right"]
	var b_l: float = b["left"]
	var b_r: float = b["right"]
	if a_r < b_l:
		return b_l - a_r
	if b_r < a_l:
		return a_l - b_r
	return 0.0


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
