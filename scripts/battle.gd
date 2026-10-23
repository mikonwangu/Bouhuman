extends Node2D
## リアルタイム戦闘スタブ: 弱/中/強/必殺 vs 単純敵

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
var _move_speed: float = 180.0
const FLOOR_Y := 320.0
const LEFT_BOUND := 80.0
const RIGHT_BOUND := 880.0


func _ready() -> void:
	GameState.phase = GameState.Phase.BATTLE
	_char_data = GameState.get_character()
	_weapon = GameState.get_equipped_weapon()
	var enemy: Dictionary = GameState.enemy_stats_for_current_fight()
	_enemy_max_hp = int(enemy["max_hp"])
	_enemy_hp = _enemy_max_hp
	_enemy_damage = int(enemy["damage"])
	_enemy_interval = float(enemy["attack_interval"])
	_move_speed = 180.0 * float(_char_data["speed_mul"])

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
	status_label.text = "%s vs %s | 必殺残 %d | Z弱 X中 C強 V必殺 | A/D移動" % [
		_char_data["name"], enemy["name"], GameState.special_uses
	]
	_log("戦闘開始！")


func _process(delta: float) -> void:
	if _finished:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_handle_move(delta)
	_handle_attacks()
	_enemy_ai(delta)
	_player.position = _player_pos
	_enemy.position = _enemy_pos
	player_hp_bar.value = GameState.hp
	enemy_hp_bar.value = _enemy_hp


func _handle_move(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("move_left"):
		dir -= 1.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	_player_pos.x = clampf(_player_pos.x + dir * _move_speed * delta, LEFT_BOUND, RIGHT_BOUND - 120.0)
	_player_pos.y = FLOOR_Y
	_player.facing = 1.0 if _enemy_pos.x >= _player_pos.x else -1.0


func _handle_attacks() -> void:
	if _attack_cd > 0.0:
		return
	if Input.is_action_just_pressed("attack_weak"):
		_do_weapon_attack("weak")
	elif Input.is_action_just_pressed("attack_mid"):
		_do_weapon_attack("mid")
	elif Input.is_action_just_pressed("attack_strong"):
		_do_weapon_attack("strong")
	elif Input.is_action_just_pressed("attack_special"):
		_do_special()


func _do_weapon_attack(tier: String) -> void:
	var atk: Dictionary = _weapon[tier]
	var dmg := int(round(float(atk["damage"]) * float(_char_data["attack_mul"])))
	var reach: float = float(atk["reach"])
	_attack_cd = float(atk["cooldown"]) / maxf(0.5, float(_char_data["speed_mul"]))
	_player.attacking = true
	get_tree().create_timer(0.2).timeout.connect(func(): _player.attacking = false)
	var dist := absf(_enemy_pos.x - _player_pos.x)
	if dist <= reach:
		_hurt_enemy(dmg)
		_log("%s ヒット！ %d ダメージ" % [atk["name"], dmg])
	else:
		_log("%s …届かず" % atk["name"])


func _do_special() -> void:
	if not GameState.try_consume_special():
		_log("必殺の残り回数がない")
		return
	var sp: Dictionary = GameState.get_equipped_special()
	var dmg := GameState.special_damage()
	# スタブ: 必殺はリーチ長め・必中寄り
	_attack_cd = float(sp.get("cooldown", 0.8))
	_player.attacking = true
	get_tree().create_timer(0.35).timeout.connect(func(): _player.attacking = false)
	_hurt_enemy(dmg)
	_log("%s！ %d ダメージ（残 %d）" % [sp["name"], dmg, GameState.special_uses])
	status_label.text = "%s | 必殺残 %d | Z弱 X中 C強 V必殺" % [_char_data["name"], GameState.special_uses]


func _hurt_enemy(amount: int) -> void:
	_enemy_hp = maxi(0, _enemy_hp - amount)
	enemy_hp_bar.value = _enemy_hp
	if _enemy_hp <= 0:
		_finish_win()


func _enemy_ai(delta: float) -> void:
	# プレイヤーへ接近して攻撃
	var dir := signf(_player_pos.x - _enemy_pos.x)
	_enemy_pos.x = clampf(_enemy_pos.x + dir * 90.0 * delta, LEFT_BOUND + 120.0, RIGHT_BOUND)
	_enemy_pos.y = FLOOR_Y
	_enemy.facing = -1.0 if dir < 0 else 1.0
	_enemy_timer -= delta
	if _enemy_timer > 0.0:
		return
	_enemy_timer = _enemy_interval
	var dist := absf(_enemy_pos.x - _player_pos.x)
	if dist > 70.0:
		return
	_enemy.attacking = true
	get_tree().create_timer(0.2).timeout.connect(func(): _enemy.attacking = false)
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
	await get_tree().create_timer(0.6).timeout
	GameState.on_battle_won()


func _finish_lose() -> void:
	if _finished:
		return
	_finished = true
	_log("敗北…")
	await get_tree().create_timer(0.6).timeout
	GameState.on_battle_lost()


func _log(msg: String) -> void:
	log_label.text = msg


func _on_weak_pressed() -> void:
	if _finished or _attack_cd > 0.0:
		return
	_do_weapon_attack("weak")


func _on_mid_pressed() -> void:
	if _finished or _attack_cd > 0.0:
		return
	_do_weapon_attack("mid")


func _on_strong_pressed() -> void:
	if _finished or _attack_cd > 0.0:
		return
	_do_weapon_attack("strong")


func _on_special_pressed() -> void:
	if _finished or _attack_cd > 0.0:
		return
	_do_special()
