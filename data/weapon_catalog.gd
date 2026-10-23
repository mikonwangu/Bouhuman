class_name WeaponCatalog
extends RefCounted
## 武器カタログ（要件 §4.3）。弱／中／強は装備武器に依存。

enum Rarity { N, R, HR, SR }

const WEAPONS := {
	"W-N1": {
		"id": "W-N1", "name": "素手", "rarity": Rarity.N,
		"weak": {"name": "ジャブ", "damage": 8, "cooldown": 0.14, "reach": 48.0},
		"mid": {"name": "ストレート", "damage": 14, "cooldown": 0.26, "reach": 56.0},
		"strong": {"name": "スマッシュ", "damage": 24, "cooldown": 0.49, "reach": 60.0},
		"note": "初期装備",
	},
	"W-N2": {
		"id": "W-N2", "name": "木の棒", "rarity": Rarity.N,
		"weak": {"name": "小振り", "damage": 9, "cooldown": 0.17, "reach": 72.0},
		"mid": {"name": "横薙ぎ", "damage": 16, "cooldown": 0.29, "reach": 80.0},
		"strong": {"name": "振り下ろし", "damage": 28, "cooldown": 0.55, "reach": 84.0},
		"note": "リーチやや長",
	},
	"W-N3": {
		"id": "W-N3", "name": "手袋", "rarity": Rarity.N,
		"weak": {"name": "連打起点", "damage": 7, "cooldown": 0.12, "reach": 44.0},
		"mid": {"name": "フック", "damage": 13, "cooldown": 0.23, "reach": 50.0},
		"strong": {"name": "アッパー", "damage": 22, "cooldown": 0.43, "reach": 52.0},
		"note": "発生速め",
	},
	"W-N4": {
		"id": "W-N4", "name": "短刀", "rarity": Rarity.N,
		"weak": {"name": "斬り上げ", "damage": 8, "cooldown": 0.13, "reach": 40.0},
		"mid": {"name": "突き", "damage": 15, "cooldown": 0.22, "reach": 48.0},
		"strong": {"name": "二連斬り", "damage": 26, "cooldown": 0.41, "reach": 46.0},
		"note": "リーチ短・発生速",
	},
	"W-R1": {
		"id": "W-R1", "name": "鉄パイプ", "rarity": Rarity.R,
		"weak": {"name": "端叩き", "damage": 12, "cooldown": 0.2, "reach": 76.0},
		"mid": {"name": "薙ぎ払い", "damage": 20, "cooldown": 0.32, "reach": 88.0},
		"strong": {"name": "振り下ろし強化", "damage": 36, "cooldown": 0.61, "reach": 92.0},
		"note": "ダメ↑・やや遅",
	},
	"W-R2": {
		"id": "W-R2", "name": "鎖", "rarity": Rarity.R,
		"weak": {"name": "先端ヒット", "damage": 11, "cooldown": 0.19, "reach": 96.0},
		"mid": {"name": "巻き込み", "damage": 18, "cooldown": 0.3, "reach": 100.0},
		"strong": {"name": "叩きつけ", "damage": 34, "cooldown": 0.58, "reach": 104.0},
		"note": "中距離寄り",
	},
	"W-R3": {
		"id": "W-R3", "name": "盾拳", "rarity": Rarity.R,
		"weak": {"name": "盾押し", "damage": 10, "cooldown": 0.17, "reach": 52.0},
		"mid": {"name": "盾殴り", "damage": 17, "cooldown": 0.28, "reach": 56.0},
		"strong": {"name": "突進殴打", "damage": 32, "cooldown": 0.52, "reach": 70.0},
		"note": "削り・前進あり",
	},
	"W-R4": {
		"id": "W-R4", "name": "ハンマー", "rarity": Rarity.R,
		"weak": {"name": "小振り", "damage": 13, "cooldown": 0.23, "reach": 64.0},
		"mid": {"name": "叩き", "damage": 22, "cooldown": 0.38, "reach": 68.0},
		"strong": {"name": "叩きつけ爆発風", "damage": 40, "cooldown": 0.7, "reach": 72.0},
		"note": "単発特化",
	},
	"W-HR1": {
		"id": "W-HR1", "name": "大剣", "rarity": Rarity.HR,
		"weak": {"name": "縦斬り小", "damage": 16, "cooldown": 0.23, "reach": 90.0},
		"mid": {"name": "横一閃", "damage": 28, "cooldown": 0.41, "reach": 110.0},
		"strong": {"name": "叩き斬り", "damage": 48, "cooldown": 0.75, "reach": 100.0},
		"note": "高ダメ・硬直長",
	},
	"W-HR2": {
		"id": "W-HR2", "name": "双節棍", "rarity": Rarity.HR,
		"weak": {"name": "速攻端", "damage": 14, "cooldown": 0.14, "reach": 70.0},
		"mid": {"name": "回転打", "damage": 24, "cooldown": 0.26, "reach": 78.0},
		"strong": {"name": "連続回転", "damage": 42, "cooldown": 0.55, "reach": 82.0},
		"note": "多段向き",
	},
	"W-HR3": {
		"id": "W-HR3", "name": "槍", "rarity": Rarity.HR,
		"weak": {"name": "小突き", "damage": 15, "cooldown": 0.17, "reach": 120.0},
		"mid": {"name": "中突き", "damage": 26, "cooldown": 0.32, "reach": 130.0},
		"strong": {"name": "踏み込み突き", "damage": 44, "cooldown": 0.64, "reach": 140.0},
		"note": "最長リーチ級",
	},
	"W-SR1": {
		"id": "W-SR1", "name": "雷刃", "rarity": Rarity.SR,
		"weak": {"name": "電撃斬り小", "damage": 18, "cooldown": 0.19, "reach": 88.0},
		"mid": {"name": "電撃一閃", "damage": 32, "cooldown": 0.35, "reach": 100.0},
		"strong": {"name": "落雷斬り", "damage": 55, "cooldown": 0.67, "reach": 105.0},
		"note": "短い硬直付与",
	},
	"W-SR2": {
		"id": "W-SR2", "name": "炎拳", "rarity": Rarity.SR,
		"weak": {"name": "炎ジャブ", "damage": 17, "cooldown": 0.16, "reach": 50.0},
		"mid": {"name": "炎ストレート", "damage": 30, "cooldown": 0.29, "reach": 58.0},
		"strong": {"name": "爆炎アッパー", "damage": 52, "cooldown": 0.61, "reach": 62.0},
		"note": "ヒット後小ダメージ追加",
	},
	"W-SR3": {
		"id": "W-SR3", "name": "影の爪", "rarity": Rarity.SR,
		"weak": {"name": "残像斬り", "damage": 16, "cooldown": 0.14, "reach": 66.0},
		"mid": {"name": "二連爪", "damage": 29, "cooldown": 0.28, "reach": 72.0},
		"strong": {"name": "急接近強撃", "damage": 50, "cooldown": 0.55, "reach": 90.0},
		"note": "発生と移動を両立",
	},
}

const STARTER_ID := "W-N1"

const NORMAL_DROP_IDS: Array[String] = ["W-N2", "W-N3", "W-N4", "W-R1", "W-R2", "W-R3", "W-R4"]
const BOSS_DROP_IDS: Array[String] = ["W-HR1", "W-HR2", "W-HR3", "W-SR1", "W-SR2", "W-SR3"]


static func get_weapon(weapon_id: String) -> Dictionary:
	return WEAPONS.get(weapon_id, WEAPONS[STARTER_ID]).duplicate(true)


static func rarity_label(rarity: int) -> String:
	match rarity:
		Rarity.N:
			return "N"
		Rarity.R:
			return "R"
		Rarity.HR:
			return "HR"
		Rarity.SR:
			return "SR"
		_:
			return "?"


## 未所持が無い場合は空文字（呼び出し側で枠を出さない）
static func pick_normal_drop(owned: Array) -> String:
	var candidates: Array[String] = []
	for wid in NORMAL_DROP_IDS:
		if wid not in owned:
			candidates.append(wid)
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]


## 未所持が無い場合は空文字。SR 低確率 / それ以外 HR。
static func pick_boss_drop(owned: Array) -> String:
	var candidates: Array[String] = []
	for wid in BOSS_DROP_IDS:
		if wid not in owned:
			candidates.append(wid)
	if candidates.is_empty():
		return ""
	var sr: Array[String] = []
	var hr: Array[String] = []
	for wid in candidates:
		if String(wid).begins_with("W-SR"):
			sr.append(wid)
		else:
			hr.append(wid)
	var roll := randf()
	if roll < 0.2 and not sr.is_empty():
		return sr[randi() % sr.size()]
	if not hr.is_empty():
		return hr[randi() % hr.size()]
	return candidates[randi() % candidates.size()]


static func has_unowned_normal_drop(owned: Array) -> bool:
	for wid in NORMAL_DROP_IDS:
		if wid not in owned:
			return true
	return false


static func has_unowned_boss_drop(owned: Array) -> bool:
	for wid in BOSS_DROP_IDS:
		if wid not in owned:
			return true
	return false
