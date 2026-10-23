extends Node
## ラン状態・戦闘ループ・報酬。要件 §3〜§4.5 に準拠。

const WeaponCatalogScript = preload("res://data/weapon_catalog.gd")
const SpecialCatalogScript = preload("res://data/special_catalog.gd")
const CharacterTypesScript = preload("res://data/character_types.gd")

const INITIAL_MAX_HP := 100
const INITIAL_SPECIAL_USES := 3
const HEAL_AMOUNT := 30
const MAX_HP_UP := 10
const SPECIAL_POWER_UP := 10
const CLEAR_WINS := 30
const BOSS_EVERY := 10

enum Phase { TITLE, SETTING, CHAR_SELECT, PRE_BATTLE, BATTLE, REWARD, GAME_OVER, CLEAR }

var phase: Phase = Phase.TITLE

# ラン状態
var character_type: int = CharacterTypesScript.Type.BALANCE
var wins: int = 0
var max_hp: int = INITIAL_MAX_HP
var hp: int = INITIAL_MAX_HP
var special_uses: int = INITIAL_SPECIAL_USES
var special_power_bonus: int = 0
var has_death_avoid: bool = false
var death_avoid_used: bool = false

var owned_weapons: Array[String] = []
var equipped_weapon_id: String = WeaponCatalogScript.STARTER_ID
var owned_specials: Array[String] = []
var equipped_special_id: String = SpecialCatalogScript.STARTER_ID

## 直近の報酬候補（最大3）
var pending_rewards: Array[Dictionary] = []
var last_battle_was_boss: bool = false


func reset_run() -> void:
	wins = 0
	max_hp = INITIAL_MAX_HP
	hp = INITIAL_MAX_HP
	special_uses = INITIAL_SPECIAL_USES
	special_power_bonus = 0
	has_death_avoid = false
	death_avoid_used = false
	owned_weapons = [WeaponCatalogScript.STARTER_ID]
	equipped_weapon_id = WeaponCatalogScript.STARTER_ID
	owned_specials = [SpecialCatalogScript.STARTER_ID]
	equipped_special_id = SpecialCatalogScript.STARTER_ID
	pending_rewards.clear()
	last_battle_was_boss = false


func start_new_run(char_type: int) -> void:
	reset_run()
	character_type = char_type
	go_pre_battle()


func is_boss_upcoming() -> bool:
	# 10勝目・20勝目・30勝目がボス（「10回ごとに強敵」）
	return (wins + 1) % BOSS_EVERY == 0


func is_clear() -> bool:
	return wins >= CLEAR_WINS


func get_character() -> Dictionary:
	return CharacterTypesScript.get_type(character_type)


func get_equipped_weapon() -> Dictionary:
	return WeaponCatalogScript.get_weapon(equipped_weapon_id)


func get_equipped_special() -> Dictionary:
	return SpecialCatalogScript.get_special(equipped_special_id)


func special_damage() -> int:
	var sp: Dictionary = get_equipped_special()
	return int(sp.get("base_damage", 100)) + special_power_bonus


func try_consume_special() -> bool:
	if special_uses <= 0:
		return false
	special_uses -= 1
	return true


func apply_damage_to_player(amount: int) -> bool:
	## false = 敗北確定
	hp -= amount
	if hp > 0:
		return true
	if has_death_avoid and not death_avoid_used:
		death_avoid_used = true
		has_death_avoid = false
		hp = 1
		return true
	hp = 0
	return false


func on_battle_won() -> void:
	last_battle_was_boss = is_boss_upcoming()
	wins += 1
	# フロー: 勝利 → 報酬選択 →（30勝ならクリア／否则次敵またはボス）
	_build_reward_choices()
	phase = Phase.REWARD
	get_tree().change_scene_to_file("res://scenes/reward.tscn")


func on_battle_lost() -> void:
	phase = Phase.GAME_OVER
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")


func _build_reward_choices() -> void:
	pending_rewards.clear()
	var pool: Array[Dictionary] = []
	if last_battle_was_boss:
		pool = _boss_reward_pool()
	else:
		pool = _normal_reward_pool()
	pool.shuffle()
	var count := mini(3, pool.size())
	for i in count:
		pending_rewards.append(pool[i])


func _stat_reward_options() -> Array[Dictionary]:
	return [
		{"id": "R1", "title": "最大HPアップ", "desc": "最大HP +%d" % MAX_HP_UP},
		{"id": "R2", "title": "HP回復", "desc": "現在HP +%d（最大まで）" % HEAL_AMOUNT},
		{"id": "R3", "title": "必殺回数＋1", "desc": "必殺の残り回数 +1"},
		{"id": "R4", "title": "必殺威力アップ", "desc": "必殺ダメージ基準 +%d" % SPECIAL_POWER_UP},
	]


func _normal_reward_pool() -> Array[Dictionary]:
	var list: Array[Dictionary] = _stat_reward_options()
	var drop_id := WeaponCatalogScript.pick_normal_drop(owned_weapons)
	if drop_id != "":
		var w: Dictionary = WeaponCatalogScript.get_weapon(drop_id)
		list.append({
			"id": "R5",
			"title": "武器ドロップ",
			"desc": "%s [%s] を入手" % [w["name"], WeaponCatalogScript.rarity_label(w["rarity"])],
			"weapon_id": drop_id,
		})
	return list


func _boss_reward_pool() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var sid := SpecialCatalogScript.pick_boss_special(owned_specials)
	if sid != "":
		var sp: Dictionary = SpecialCatalogScript.get_special(sid)
		list.append({
			"id": "B1",
			"title": "必殺技の入手",
			"desc": "%s [%s] を入手" % [sp["name"], SpecialCatalogScript.rarity_label(sp["rarity"])],
			"special_id": sid,
		})
	var wid := WeaponCatalogScript.pick_boss_drop(owned_weapons)
	if wid != "":
		var w: Dictionary = WeaponCatalogScript.get_weapon(wid)
		list.append({
			"id": "B2",
			"title": "上位武器の入手",
			"desc": "%s [%s] を入手" % [w["name"], WeaponCatalogScript.rarity_label(w["rarity"])],
			"weapon_id": wid,
		})
	if not has_death_avoid and not death_avoid_used:
		list.append({
			"id": "B3",
			"title": "即死回避",
			"desc": "致死ダメージを1回だけ回避（ラン中・通算1回）",
		})
	# ドロップ枯渇・即死回避済みでも最大3択になるようステータス報酬で補充
	if list.size() < 3:
		for filler in _stat_reward_options():
			if list.size() >= 3:
				break
			list.append(filler)
	return list


func apply_reward(reward: Dictionary) -> void:
	var rid: String = str(reward.get("id", ""))
	match rid:
		"R1":
			# 要件: 最大HP +10 のみ（現在HPは変更しない）
			max_hp += MAX_HP_UP
		"R2":
			hp = mini(hp + HEAL_AMOUNT, max_hp)
		"R3":
			special_uses += 1
		"R4":
			special_power_bonus += SPECIAL_POWER_UP
		"R5", "B2":
			var wid: String = str(reward.get("weapon_id", ""))
			if wid != "" and wid not in owned_weapons:
				owned_weapons.append(wid)
			# 装備切替は報酬画面の UI で行う（入手後に選べる）
		"B1":
			var sid: String = str(reward.get("special_id", ""))
			if sid != "" and sid not in owned_specials:
				owned_specials.append(sid)
		"B3":
			has_death_avoid = true
		_:
			pass


func after_reward_continue() -> void:
	if is_clear():
		phase = Phase.CLEAR
		get_tree().change_scene_to_file("res://scenes/clear.tscn")
		return
	go_pre_battle()


func go_pre_battle() -> void:
	phase = Phase.PRE_BATTLE
	get_tree().change_scene_to_file("res://scenes/pre_battle.tscn")


func go_battle() -> void:
	phase = Phase.BATTLE
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func go_title() -> void:
	phase = Phase.TITLE
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func go_setting() -> void:
	phase = Phase.SETTING
	get_tree().change_scene_to_file("res://scenes/setting.tscn")


func go_char_select() -> void:
	phase = Phase.CHAR_SELECT
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func equip_weapon(weapon_id: String) -> void:
	if weapon_id in owned_weapons:
		equipped_weapon_id = weapon_id


func equip_special(special_id: String) -> void:
	if special_id in owned_specials:
		equipped_special_id = special_id


func enemy_stats_for_current_fight() -> Dictionary:
	var boss := is_boss_upcoming()
	if boss:
		return {
			"name": "強敵ボス",
			"max_hp": 180 + wins * 4,
			"damage": 12 + wins / 5,
			"attack_interval": 1.1,
			"color": Color(0.75, 0.15, 0.2),
			"is_boss": true,
		}
	return {
		"name": "敵 %d" % (wins + 1),
		"max_hp": 60 + wins * 8,
		"damage": 6 + wins / 4,
		"attack_interval": 1.4,
		"color": Color(0.55, 0.45, 0.4),
		"is_boss": false,
	}
