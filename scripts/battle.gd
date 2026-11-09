extends Node2D
## リアルタイム戦闘: ジャンプ + モーション/ノックバック + 複数アリーナ

const StickFigureScript = preload("res://scripts/stick_figure.gd")
const WeaponCatalogScript = preload("res://data/weapon_catalog.gd")
const BattleArenaScript = preload("res://scripts/battle_arena.gd")
const CombatVisualsScript = preload("res://data/combat_visuals.gd")

@onready var player_hp_bar: ProgressBar = %PlayerHP
@onready var enemy_hp_bar: ProgressBar = %EnemyHP
@onready var status_label: Label = %StatusLabel
@onready var log_label: Label = %LogLabel
@onready var arena: Node2D = %Arena

var _stage: Node2D
var _player: StickFigure
var _enemy: StickFigure
var _player_pos := Vector2(220, 360)
var _enemy_pos := Vector2(720, 360)
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
var _enemy_jump_bias: float = 0.35
var _enemy_reach: float = 80.0
var _enemy_attack_kind: String = "mid"
var _weapon_reach_bonus: float = 0.0
var _vel_y: float = 0.0
var _enemy_vel_y: float = 0.0
var _on_ground: bool = true
var _enemy_on_ground: bool = true
var _player_kb := Vector2.ZERO
var _enemy_kb := Vector2.ZERO
var _pending_tier: String = ""
var _pending_dmg: int = 0
var _pending_reach: float = 0.0

## キビキビ寄り（重力はそのまま、ジャンプ初速だけ上げて到達高を伸ばす）
const GRAVITY := 2800.0
const JUMP_SPEED := -740.0
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
const FALL_PENALTY := 8

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
	_enemy_move_speed = 140.0 * float(enemy.get("move_mul", 1.0))
	_enemy_jump_bias = float(enemy.get("jump_bias", 0.35))
	_enemy_reach = 70.0 * float(enemy.get("reach_mul", 1.0))
	_enemy_attack_kind = str(enemy.get("attack_kind", "mid"))
	_move_speed = BASE_MOVE_SPEED * float(_char_data["speed_mul"])

	_stage = BattleArenaScript.new()
	var layout: String = BattleArenaScript.pick_layout_id(GameState.wins, bool(enemy.get("is_boss", false)))
	arena.add_child(_stage)
	_stage.load_layout(layout)
	_player_pos = _stage.spawn_player
	_enemy_pos = _stage.spawn_enemy

	var wvis: Dictionary = CombatVisualsScript.weapon_style(str(_weapon.get("id", "W-N1")))
	_weapon_reach_bonus = float(wvis.get("reach_bonus", 0.0))
	var svis: Dictionary = CombatVisualsScript.special_style(GameState.get_equipped_special())

	_player = StickFigureScript.new()
	_player.figure_color = _char_data["color"]
	_player.facing = 1.0
	_player.position = _player_pos
	_player.apply_weapon_visual(wvis)
	_player.apply_special_visual(svis)
	arena.add_child(_player)

	_enemy = StickFigureScript.new()
	_enemy.apply_body_style({
		"color": enemy["color"],
		"accent": enemy.get("accent", enemy["color"]),
		"body_scale": enemy.get("body_scale", 1.0),
		"line_width": enemy.get("line_width", 3.0),
		"head_radius": enemy.get("head_radius", 10.0),
		"is_boss": enemy.get("is_boss", false),
	})
	_enemy.apply_weapon_visual({
		"style": enemy.get("weapon_style", "fist"),
		"color": enemy.get("weapon_color", Color(0.7, 0.7, 0.7)),
		"flash": enemy.get("accent", Color(1, 0.5, 0.4)),
	})
	_enemy.facing = -1.0
	_enemy.position = _enemy_pos
	arena.add_child(_enemy)

	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value = GameState.hp
	enemy_hp_bar.max_value = _enemy_max_hp
	enemy_hp_bar.value = _enemy_hp
	_refresh_status(layout, str(enemy.get("name", "敵")))
	_log("戦闘開始！ %s / 武器:%s 必殺:%s" % [
		layout, str(_weapon.get("name", "?")), str(GameState.get_equipped_special().get("name", "?"))
	])


func _refresh_status(layout: String = "", enemy_name: String = "敵") -> void:
	var lay: String = layout
	if lay == "" and _stage != null:
		lay = str(_stage.layout_id)
	if lay == "":
		lay = "?"
	status_label.text = "%s vs %s | 必殺残 %d | ステージ %s | Spaceジャンプ" % [
		_char_data["name"], enemy_name, GameState.special_uses, lay
	]


func _process(delta: float) -> void:
	if _finished:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_handle_move(delta)
	_handle_jump_input()
	_apply_actor_physics(delta, true)
	_apply_knockback(delta)
	_handle_attacks()
	if _finished:
		return
	_enemy_ai(delta)
	_apply_actor_physics(delta, false)
	if _finished:
		return
	_check_falls()
	if _finished:
		return
	_player.position = _player_pos
	_enemy.position = _enemy_pos
	player_hp_bar.value = GameState.hp
	enemy_hp_bar.value = _enemy_hp


func _handle_move(delta: float) -> void:
	if _finished:
		return
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
	_player_pos.x = _stage.clamp_x(_player_pos.x + dir * _move_speed * move_mul * delta)
	_player.facing = 1.0 if _enemy_pos.x >= _player_pos.x else -1.0


func _handle_jump_input() -> void:
	if _finished:
		return
	if Input.is_action_just_pressed("jump"):
		_try_jump(true)


func _try_jump(is_player: bool) -> void:
	if _finished:
		return
	if is_player:
		if not _on_ground:
			return
		if _player.is_busy() and _player.phase != StickFigure.Phase.RECOVERY:
			return
		_vel_y = JUMP_SPEED
		_on_ground = false
		_log("ジャンプ！")
	else:
		if not _enemy_on_ground or _enemy.is_busy():
			return
		_enemy_vel_y = JUMP_SPEED
		_enemy_on_ground = false


func _apply_actor_physics(delta: float, is_player: bool) -> void:
	var pos := _player_pos if is_player else _enemy_pos
	var vel := _vel_y if is_player else _enemy_vel_y
	var grounded := _on_ground if is_player else _enemy_on_ground
	var prev_y := pos.y

	if grounded and vel >= 0.0:
		var stand: Dictionary = _stage.standing_on(pos)
		if stand.is_empty():
			grounded = false
		else:
			pos.y = float(stand["top"])
			vel = 0.0
			if is_player:
				_player_pos = pos
				_vel_y = vel
				_on_ground = grounded
			else:
				_enemy_pos = pos
				_enemy_vel_y = vel
				_enemy_on_ground = grounded
			return

	vel += GRAVITY * delta
	pos.y += vel * delta
	var land: Dictionary = _stage.try_land(pos, prev_y, vel)
	if land["landed"]:
		pos.y = float(land["y"])
		vel = 0.0
		grounded = true
	else:
		grounded = false

	if is_player:
		_player_pos = pos
		_vel_y = vel
		_on_ground = grounded
	else:
		_enemy_pos = pos
		_enemy_vel_y = vel
		_enemy_on_ground = grounded


func _apply_knockback(delta: float) -> void:
	_player_pos.x = _stage.clamp_x(_player_pos.x + _player_kb.x * delta)
	_enemy_pos.x = _stage.clamp_x(_enemy_pos.x + _enemy_kb.x * delta, 40.0, 40.0)
	if absf(_player_kb.y) > 1.0:
		_on_ground = false
		_vel_y += _player_kb.y
		_player_kb.y = 0.0
	if absf(_enemy_kb.y) > 1.0:
		_enemy_on_ground = false
		_enemy_vel_y += _enemy_kb.y
		_enemy_kb.y = 0.0
	_player_kb.x = move_toward(_player_kb.x, 0.0, KB_DECAY * 80.0 * delta)
	_enemy_kb.x = move_toward(_enemy_kb.x, 0.0, KB_DECAY * 80.0 * delta)


func _check_falls() -> void:
	if _stage.is_fallen(_player_pos):
		_respawn_player_after_fall()
	if _stage.is_fallen(_enemy_pos):
		_respawn_enemy_after_fall()


func _respawn_player_after_fall() -> void:
	_log("落下！")
	_player_pos = _stage.spawn_player
	_vel_y = 0.0
	_on_ground = true
	_player_kb = Vector2.ZERO
	var alive := GameState.apply_damage_to_player(FALL_PENALTY)
	player_hp_bar.value = GameState.hp
	if not alive:
		_finish_lose()


func _respawn_enemy_after_fall() -> void:
	_log("敵が落下！")
	_enemy_pos = _stage.spawn_enemy
	_enemy_vel_y = 0.0
	_enemy_on_ground = true
	_enemy_kb = Vector2.ZERO
	_hurt_enemy(12)


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
	var reach: float = float(atk["reach"]) + _weapon_reach_bonus * 0.35
	var weapon_cd := float(atk["cooldown"]) / maxf(0.5, float(_char_data["speed_mul"]))
	_attack_cd = maxf(weapon_cd, _motion_total(tier) * 0.85)
	_pending_tier = tier
	_pending_dmg = dmg
	_pending_reach = reach
	var m: Dictionary = MOTION[tier]
	_player.facing = 1.0 if _enemy_pos.x >= _player_pos.x else -1.0
	# 武器フラッシュ色を攻撃ごとに反映（必殺色は残す）
	var wvis: Dictionary = CombatVisualsScript.weapon_style(str(_weapon.get("id", "W-N1")))
	_player.attack_flash_color = wvis.get("flash", Color(1, 1, 1, 0.75))
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
	# 必殺種別で到達距離を変える（見た目差と揃える）
	var kind := str(sp.get("kind", "projectile"))
	match kind:
		"melee", "melee_multi":
			_pending_reach = 90.0
		"ground":
			_pending_reach = 160.0
		"beam", "multi_hit":
			_pending_reach = 280.0
		"explode", "delayed_double":
			_pending_reach = 200.0
		"projectile_up":
			_pending_reach = 180.0
		_:
			_pending_reach = 220.0
	var svis: Dictionary = CombatVisualsScript.special_style(sp)
	_player.apply_special_visual(svis)
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
	var vert := absf(_enemy_pos.y - _player_pos.y)
	var hit := false
	if tier == "special":
		var sp_kind := str(GameState.get_equipped_special().get("kind", "projectile"))
		var vert_ok := 140.0 if sp_kind == "projectile_up" else 120.0
		if sp_kind == "ground":
			vert_ok = 70.0
		hit = dist <= reach and vert < vert_ok
	elif dist <= reach and vert < 90.0:
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
	var ai_mul := 1.0 if absf(_enemy_kb.x) < 40.0 else 0.2
	if not _enemy.is_busy():
		var action: Dictionary = _stage.desired_enemy_action(_enemy_pos, _player_pos, _enemy_on_ground)
		var dir: float = float(action.get("dir", 0.0))
		_enemy_pos.x = _stage.clamp_x(
			_enemy_pos.x + dir * _enemy_move_speed * ai_mul * delta,
			40.0,
			40.0
		)
		if dir != 0.0:
			_enemy.facing = dir
		# ステージが要求するジャンプは実行。加えてプレイヤーが上にいるときだけ jump_bias で追従ジャンプ
		if bool(action.get("jump", false)):
			_try_jump(false)
		elif (
			_enemy_on_ground
			and _player_pos.y + 28.0 < _enemy_pos.y
			and randf() < _enemy_jump_bias * delta * 3.0
		):
			_try_jump(false)
	_enemy_timer -= delta
	if _enemy_timer > 0.0:
		return
	_enemy_timer = _enemy_interval
	if _finished or _enemy.is_busy():
		return
	var dist := absf(_enemy_pos.x - _player_pos.x)
	var vert := absf(_enemy_pos.y - _player_pos.y)
	if dist > _enemy_reach or vert > 80.0:
		return
	var height := _enemy_pos.y - _player_pos.y  # プレイヤーが上なら正寄り
	var tier := _enemy_attack_kind
	if not MOTION.has(tier):
		tier = "mid"
	var m: Dictionary = MOTION[tier]
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
	var vert := absf(_enemy_pos.y - _player_pos.y)
	if dist > _enemy_reach + 10.0 or vert > 80.0:
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
	_try_jump(true)
