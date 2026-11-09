extends Node2D
## リアルタイム戦闘スタブ: 弱/中/強/必殺 + ジャンプ + モーション/ノックバック

const StickFigureScript = preload("res://scripts/stick_figure.gd")
const WeaponCatalogScript = preload("res://data/weapon_catalog.gd")

@onready var player_hp_bar: ProgressBar = %PlayerHP
@onready var enemy_hp_bar: ProgressBar = %EnemyHP
@onready var status_label: Label = %StatusLabel
@onready var log_label: Label = %LogLabel
@onready var arena: Node2D = %Arena

var _player: StickFigure
var _enemy: StickFigure
var _player_pos := Vector2(220, 320)
var _enemy_pos := Vector2(720, 320)
var _enemy_hp: int = 100
var _enemy_max_hp: int = 100
var _enemy_damage: int = 8
var _enemy_interval: float = 1.4
var _enemy_timer: float = 0.0
var _attack_cd: float = 0.0
var _finished: bool = false
var _char_data: Dictionary = {}
var _weapon: Dictionary = {}
var _move_speed: float = 280.0
var _enemy_move_speed: float = 140.0
var _vel_y: float = 0.0
var _on_ground: bool = true
var _player_kb := Vector2.ZERO
var _enemy_kb := Vector2.ZERO
var _pending_tier: String = ""
var _pending_dmg: int = 0
var _pending_reach: float = 0.0

const FLOOR_Y := 320.0
const LEFT_BOUND := 80.0
const RIGHT_BOUND := 880.0
## キビキビ寄り: 重力↑ + 初速調整（滞空が短く着地が早い）
const GRAVITY := 2800.0
const JUMP_SPEED := -620.0
## これより高く浮いていると敵の近接を回避（スタブ用）
const AIR_DODGE_HEIGHT := 40.0
const END_DELAY_SEC := 0.35
const BASE_MOVE_SPEED := 280.0
const KB_DECAY := 10.0
const KB_WEAK := 180.0
const KB_MID := 280.0
const KB_STRONG := 420.0
const KB_SPECIAL := 360.0
const KB_ENEMY := 240.0
const KB_STRONG_UP := -180.0

## 技モーション秒数（発生 / ヒット / 硬直）— 弱が最速・強が最遅
const MOTION := {
	"weak": {"windup": 0.04, "active": 0.06, "recovery": 0.08, "kind": StickFigure.AttackKind.WEAK},
	"mid": {"windup": 0.06, "active": 0.08, "recovery": 0.12, "kind": StickFigure.AttackKind.MID},
	"strong": {"windup": 0.10, "active": 0.10, "recovery": 0.18, "kind": StickFigure.AttackKind.STRONG},
	"special": {"windup": 0.08, "active": 0.12, "recovery": 0.16, "kind": StickFigure.AttackKind.SPECIAL},
	"enemy": {"windup": 0.08, "active": 0.08, "recovery": 0.10, "kind": StickFigure.AttackKind.MID},
}


func _ready() -> void:
	GameState.phase = GameState.Phase.BATTLE
	_char_data = GameState.get_character()
	_weapon = GameState.get_equipped_weapon()
	var enemy: Dictionary = GameState.enemy_stats_for_current_fight()
	_enemy_max_hp = int(enemy["max_hp"])
	_enemy_hp = _enemy_max_hp
	_enemy_damage = int(enemy["damage"])
	_enemy_interval = float(enemy["attack_interval"])
	_move_speed = BASE_MOVE_SPEED * float(_char_data["speed_mul"])

	_player = StickFigureScript.new()
	_player.figure_color = _char_data["color"]
	_player.facing = 1.0
	_player.position = _player_pos
	arena.add_child(_player)

	_enemy = StickFigureScript.new()
	_enemy.figure_color = enemy["color"]
	_enemy.facing = -1.0
	_enemy.position = _enemy_pos
	arena.add_child(_enemy)

	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value = GameState.hp
	enemy_hp_bar.max_value = _enemy_max_hp
	enemy_hp_bar.value = _enemy_hp
	_refresh_status()
	_log("戦闘開始！")


func _refresh_status() -> void:
	status_label.text = "%s vs 敵 | 必殺残 %d | Z弱 X中 C強 V必殺 | A/D移動 Spaceジャンプ" % [
		_char_data["name"], GameState.special_uses
	]


func _process(delta: float) -> void:
	if _finished:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_handle_move(delta)
	_handle_jump_input()
	_apply_gravity(delta)
	_apply_knockback(delta)
	_handle_attacks()
	# 勝利確定と同フレームで敵攻撃が通らないよう、await 前の _finished を再確認
	if _finished:
		return
	_enemy_ai(delta)
	if _finished:
		return
	_player.position = _player_pos
	_enemy.position = _enemy_pos
	player_hp_bar.value = GameState.hp
	enemy_hp_bar.value = _enemy_hp


func _handle_move(delta: float) -> void:
	if _finished:
		return
	# 発生・ヒット中は移動を弱める（硬直感）
	var move_mul := 1.0
	if _player.is_busy():
		if _player.phase == StickFigure.Phase.WINDUP or _player.phase == StickFigure.Phase.ACTIVE:
			move_mul = 0.35
		elif _player.phase == StickFigure.Phase.RECOVERY:
			move_mul = 0.55
	var dir := 0.0
	if Input.is_action_pressed("move_left"):
		dir -= 1.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	_player_pos.x = clampf(
		_player_pos.x + dir * _move_speed * move_mul * delta,
		LEFT_BOUND,
		RIGHT_BOUND - 120.0
	)
	_player.facing = 1.0 if _enemy_pos.x >= _player_pos.x else -1.0


func _handle_jump_input() -> void:
	if _finished:
		return
	if Input.is_action_just_pressed("jump"):
		_try_jump()


func _try_jump() -> void:
	if _finished or not _on_ground:
		return
	# 攻撃発生・ヒット中はジャンプ不可（硬直）。硬直後は可
	if _player.is_busy() and _player.phase != StickFigure.Phase.RECOVERY:
		return
	_vel_y = JUMP_SPEED
	_on_ground = false
	_log("ジャンプ！")


func _apply_gravity(delta: float) -> void:
	if _on_ground and _vel_y >= 0.0:
		_player_pos.y = FLOOR_Y
		_vel_y = 0.0
		return
	_vel_y += GRAVITY * delta
	_player_pos.y += _vel_y * delta
	if _player_pos.y >= FLOOR_Y:
		_player_pos.y = FLOOR_Y
		_vel_y = 0.0
		_on_ground = true


func _apply_knockback(delta: float) -> void:
	_player_pos.x = clampf(_player_pos.x + _player_kb.x * delta, LEFT_BOUND, RIGHT_BOUND - 120.0)
	_enemy_pos.x = clampf(_enemy_pos.x + _enemy_kb.x * delta, LEFT_BOUND + 120.0, RIGHT_BOUND)
	if absf(_player_kb.y) > 1.0:
		_on_ground = false
		_vel_y += _player_kb.y
		_player_kb.y = 0.0
	if absf(_enemy_kb.y) > 1.0:
		# 敵は簡易: 一瞬浮かせてすぐ戻す（強の見た目用）
		_enemy_pos.y = minf(FLOOR_Y, _enemy_pos.y + _enemy_kb.y * delta)
		_enemy_kb.y *= 0.2
	else:
		_enemy_pos.y = lerpf(_enemy_pos.y, FLOOR_Y, minf(1.0, 12.0 * delta))
	_player_kb.x = move_toward(_player_kb.x, 0.0, KB_DECAY * 80.0 * delta)
	_enemy_kb.x = move_toward(_enemy_kb.x, 0.0, KB_DECAY * 80.0 * delta)


func _handle_attacks() -> void:
	if _finished or _attack_cd > 0.0 or _player.is_busy():
		return
	if Input.is_action_just_pressed("attack_weak"):
		_do_weapon_attack("weak")
	elif Input.is_action_just_pressed("attack_mid"):
		_do_weapon_attack("mid")
	elif Input.is_action_just_pressed("attack_strong"):
		_do_weapon_attack("strong")
	elif Input.is_action_just_pressed("attack_special"):
		_do_special()


func _motion_total(tier: String) -> float:
	var m: Dictionary = MOTION[tier]
	return float(m["windup"]) + float(m["active"]) + float(m["recovery"])


func _do_weapon_attack(tier: String) -> void:
	if _finished or _player.is_busy():
		return
	var atk: Dictionary = _weapon[tier]
	var dmg := int(round(float(atk["damage"]) * float(_char_data["attack_mul"])))
	var reach: float = float(atk["reach"])
	var weapon_cd := float(atk["cooldown"]) / maxf(0.5, float(_char_data["speed_mul"]))
	_attack_cd = maxf(weapon_cd, _motion_total(tier) * 0.85)
	_pending_tier = tier
	_pending_dmg = dmg
	_pending_reach = reach
	var m: Dictionary = MOTION[tier]
	_player.facing = 1.0 if _enemy_pos.x >= _player_pos.x else -1.0
	_player.play_attack(
		m["kind"],
		float(m["windup"]),
		float(m["active"]),
		float(m["recovery"]),
		Callable(self, "_on_player_attack_active")
	)


func _do_special() -> void:
	if _finished or _player.is_busy():
		return
	if not GameState.try_consume_special():
		_log("必殺の残り回数がない")
		return
	var sp: Dictionary = GameState.get_equipped_special()
	var dmg := GameState.special_damage()
	var sp_cd := float(sp.get("cooldown", 0.55))
	_attack_cd = maxf(sp_cd, _motion_total("special") * 0.85)
	_pending_tier = "special"
	_pending_dmg = dmg
	_pending_reach = 999.0  # スタブ: 必殺は必中寄り
	var m: Dictionary = MOTION["special"]
	_player.facing = 1.0 if _enemy_pos.x >= _player_pos.x else -1.0
	_player.play_attack(
		m["kind"],
		float(m["windup"]),
		float(m["active"]),
		float(m["recovery"]),
		Callable(self, "_on_player_attack_active")
	)
	_refresh_status()


func _on_player_attack_active() -> void:
	if _finished:
		return
	var tier := _pending_tier
	var dmg := _pending_dmg
	var reach := _pending_reach
	var dist := absf(_enemy_pos.x - _player_pos.x)
	var air_ok := absf(_player_pos.y - FLOOR_Y) < 100.0
	var hit := false
	if tier == "special":
		hit = true
	elif dist <= reach and air_ok:
		hit = true
	if hit:
		_apply_knockback_to_enemy(tier)
		_hurt_enemy(dmg)
		var label := tier
		if tier != "special" and _weapon.has(tier):
			label = str(_weapon[tier].get("name", tier))
		elif tier == "special":
			label = str(GameState.get_equipped_special().get("name", "必殺"))
		_log("%s ヒット！ %d ダメージ" % [label, dmg])
	else:
		_log("攻撃 …届かず")


func _apply_knockback_to_enemy(tier: String) -> void:
	var push := signf(_enemy_pos.x - _player_pos.x)
	if push == 0.0:
		push = _player.facing
	var force := KB_MID
	var up := 0.0
	match tier:
		"weak":
			force = KB_WEAK
		"mid":
			force = KB_MID
		"strong":
			force = KB_STRONG
			up = KB_STRONG_UP
		"special":
			force = KB_SPECIAL
			up = KB_STRONG_UP * 0.5
	_enemy_kb.x = push * force
	_enemy_kb.y = up
	_enemy.play_hurt(0.10)


func _apply_knockback_to_player() -> void:
	var push := signf(_player_pos.x - _enemy_pos.x)
	if push == 0.0:
		push = -_enemy.facing
	_player_kb.x = push * KB_ENEMY
	_player.play_hurt(0.10)


func _hurt_enemy(amount: int) -> void:
	if _finished:
		return
	_enemy_hp = maxi(0, _enemy_hp - amount)
	enemy_hp_bar.value = _enemy_hp
	if _enemy_hp <= 0:
		_finish_win()


func _enemy_ai(delta: float) -> void:
	if _finished:
		return
	# ノックバック中は接近AIを弱める
	var ai_mul := 1.0 if absf(_enemy_kb.x) < 40.0 else 0.2
	if not _enemy.is_busy():
		var dir := signf(_player_pos.x - _enemy_pos.x)
		_enemy_pos.x = clampf(
			_enemy_pos.x + dir * _enemy_move_speed * ai_mul * delta,
			LEFT_BOUND + 120.0,
			RIGHT_BOUND
		)
		_enemy.facing = -1.0 if dir < 0 else 1.0
	_enemy_timer -= delta
	if _enemy_timer > 0.0:
		return
	_enemy_timer = _enemy_interval
	if _finished or _enemy.is_busy():
		return
	var dist := absf(_enemy_pos.x - _player_pos.x)
	if dist > 70.0:
		return
	var height := FLOOR_Y - _player_pos.y
	var m: Dictionary = MOTION["enemy"]
	_enemy.facing = 1.0 if _player_pos.x >= _enemy_pos.x else -1.0
	if height >= AIR_DODGE_HEIGHT:
		_enemy.play_attack(m["kind"], float(m["windup"]), float(m["active"]), float(m["recovery"]))
		_log("敵の攻撃をジャンプで回避！")
		return
	_enemy.play_attack(
		m["kind"],
		float(m["windup"]),
		float(m["active"]),
		float(m["recovery"]),
		Callable(self, "_on_enemy_attack_active")
	)


func _on_enemy_attack_active() -> void:
	if _finished:
		return
	var dist := absf(_enemy_pos.x - _player_pos.x)
	var height := FLOOR_Y - _player_pos.y
	if dist > 80.0 or height >= AIR_DODGE_HEIGHT:
		_log("敵の攻撃を回避！")
		return
	_apply_knockback_to_player()
	var alive := GameState.apply_damage_to_player(_enemy_damage)
	_log("敵の攻撃！ %d ダメージ" % _enemy_damage)
	player_hp_bar.value = GameState.hp
	if not alive:
		_finish_lose()


func _finish_win() -> void:
	if _finished:
		return
	_finished = true
	_log("勝利！")
	await get_tree().create_timer(END_DELAY_SEC).timeout
	GameState.on_battle_won()


func _finish_lose() -> void:
	if _finished:
		return
	_finished = true
	_log("敗北…")
	await get_tree().create_timer(END_DELAY_SEC).timeout
	GameState.on_battle_lost()


func _log(msg: String) -> void:
	log_label.text = msg


func _on_weak_pressed() -> void:
	if _finished or _attack_cd > 0.0 or _player.is_busy():
		return
	_do_weapon_attack("weak")


func _on_mid_pressed() -> void:
	if _finished or _attack_cd > 0.0 or _player.is_busy():
		return
	_do_weapon_attack("mid")


func _on_strong_pressed() -> void:
	if _finished or _attack_cd > 0.0 or _player.is_busy():
		return
	_do_weapon_attack("strong")


func _on_special_pressed() -> void:
	if _finished or _attack_cd > 0.0 or _player.is_busy():
		return
	_do_special()


func _on_jump_pressed() -> void:
	_try_jump()
