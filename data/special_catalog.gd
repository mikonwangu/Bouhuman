class_name SpecialCatalog
extends RefCounted
## 必殺カタログ（要件 §4.4）。武器と独立。

enum Rarity { N, R, HR, SR }

const SPECIALS := {
	"S-N1": {
		"id": "S-N1", "name": "飛弾", "rarity": Rarity.N,
		"base_damage": 100, "cooldown": 0.8, "kind": "projectile",
		"note": "初期必殺・前方飛び道具",
	},
	"S-N2": {
		"id": "S-N2", "name": "衝撃波", "rarity": Rarity.N,
		"base_damage": 90, "cooldown": 0.7, "kind": "melee",
		"note": "近距離の短い衝撃",
	},
	"S-N3": {
		"id": "S-N3", "name": "トリプルスタブ", "rarity": Rarity.N,
		"base_damage": 110, "cooldown": 0.9, "kind": "melee_multi",
		"note": "前方に3発の連続殴り",
	},
	"S-R1": {
		"id": "S-R1", "name": "貫通弾", "rarity": Rarity.R,
		"base_damage": 120, "cooldown": 0.85, "kind": "projectile",
		"note": "敵を貫通する飛び道具",
	},
	"S-R2": {
		"id": "S-R2", "name": "地走り", "rarity": Rarity.R,
		"base_damage": 115, "cooldown": 0.9, "kind": "ground",
		"note": "地面を走る衝撃",
	},
	"S-R3": {
		"id": "S-R3", "name": "上昇弾", "rarity": Rarity.R,
		"base_damage": 118, "cooldown": 0.85, "kind": "projectile_up",
		"note": "斜め上に飛ぶ弾",
	},
	"S-HR1": {
		"id": "S-HR1", "name": "真空波", "rarity": Rarity.HR,
		"base_damage": 140, "cooldown": 1.0, "kind": "beam",
		"note": "画面横方向の長い飛び道具",
	},
	"S-HR2": {
		"id": "S-HR2", "name": "爆裂弾", "rarity": Rarity.HR,
		"base_damage": 135, "cooldown": 1.05, "kind": "explode",
		"note": "着弾で小爆発",
	},
	"S-HR3": {
		"id": "S-HR3", "name": "分身撃", "rarity": Rarity.HR,
		"base_damage": 145, "cooldown": 1.1, "kind": "delayed_double",
		"note": "わずかに遅れて2発目",
	},
	"S-SR1": {
		"id": "S-SR1", "name": "極・飛弾", "rarity": Rarity.SR,
		"base_damage": 180, "cooldown": 1.2, "kind": "projectile",
		"note": "高威力の大飛び道具",
	},
	"S-SR2": {
		"id": "S-SR2", "name": "雷龍波", "rarity": Rarity.SR,
		"base_damage": 170, "cooldown": 1.25, "kind": "multi_hit",
		"note": "多段ヒットの長射程技",
	},
}

const STARTER_ID := "S-N1"
const BOSS_SPECIAL_IDS: Array[String] = [
	"S-N2", "S-N3", "S-R1", "S-R2", "S-R3",
	"S-HR1", "S-HR2", "S-HR3", "S-SR1", "S-SR2",
]


static func get_special(special_id: String) -> Dictionary:
	return SPECIALS.get(special_id, SPECIALS[STARTER_ID]).duplicate(true)


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


static func pick_boss_special(owned: Array) -> String:
	var candidates: Array[String] = []
	for sid in BOSS_SPECIAL_IDS:
		if sid not in owned:
			candidates.append(sid)
	if candidates.is_empty():
		return BOSS_SPECIAL_IDS[randi() % BOSS_SPECIAL_IDS.size()]
	var roll := randf()
	var bucket: Array[String] = []
	for sid in candidates:
		var s: String = sid
		if roll < 0.1 and s.begins_with("S-SR"):
			bucket.append(s)
		elif roll < 0.45 and (s.begins_with("S-HR") or s.begins_with("S-SR")):
			bucket.append(s)
		elif roll < 0.75 and (s.begins_with("S-R") or s.begins_with("S-HR") or s.begins_with("S-SR")):
			bucket.append(s)
		else:
			bucket.append(s)
	# レア度フィルタが空なら全体から
	if bucket.is_empty():
		bucket = candidates
	return bucket[randi() % bucket.size()]
