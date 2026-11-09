class_name EnemyCatalog
extends RefCounted
## 通常敵アーキタイプとボス差分（見た目・簡易ステータス／AI）。

const NORMAL_TYPES := ["grunt", "rusher", "bruiser", "shield"]
const BOSS_TYPES := ["tyrant", "specter"]


static func pick_type(wins: int, is_boss: bool) -> String:
	if is_boss:
		return BOSS_TYPES[(wins / 10) % BOSS_TYPES.size()]
	return NORMAL_TYPES[wins % NORMAL_TYPES.size()]


static func build_stats(wins: int, is_boss: bool) -> Dictionary:
	var t := pick_type(wins, is_boss)
	var base: Dictionary = _archetype(t)
	var hp: int
	var dmg: int
	var interval: float
	var move_mul: float = float(base.get("move_mul", 1.0))
	if is_boss:
		hp = int(base["hp_base"]) + wins * int(base.get("hp_per_win", 3))
		dmg = int(base["damage_base"]) + wins / 5
		interval = float(base["attack_interval"])
	else:
		hp = int(base["hp_base"]) + wins * int(base.get("hp_per_win", 6))
		dmg = int(base["damage_base"]) + wins / 4
		interval = float(base["attack_interval"])
	return {
		"id": t,
		"name": str(base["name"]),
		"max_hp": hp,
		"damage": dmg,
		"attack_interval": interval,
		"move_mul": move_mul,
		"jump_bias": float(base.get("jump_bias", 0.35)),
		"color": base["color"],
		"accent": base.get("accent", base["color"]),
		"body_scale": float(base.get("body_scale", 1.0)),
		"line_width": float(base.get("line_width", 3.0)),
		"head_radius": float(base.get("head_radius", 10.0)),
		"is_boss": is_boss,
		"reach_mul": float(base.get("reach_mul", 1.0)),
		"weapon_style": str(base.get("weapon_style", "fist")),
		"weapon_color": base.get("weapon_color", Color(0.7, 0.7, 0.7)),
		"attack_kind": str(base.get("attack_kind", "mid")),
	}


static func _archetype(t: String) -> Dictionary:
	match t:
		"rusher":
			return {
				"name": "切り込み兵",
				"hp_base": 38, "hp_per_win": 5,
				"damage_base": 5, "attack_interval": 0.85,
				"move_mul": 1.35, "jump_bias": 0.55,
				"color": Color(0.35, 0.70, 0.85),
				"accent": Color(0.55, 0.90, 1.0),
				"body_scale": 0.92, "line_width": 2.5, "head_radius": 9.0,
				"reach_mul": 0.9,
				"weapon_style": "blade", "weapon_color": Color(0.7, 0.85, 0.95),
				"attack_kind": "weak",
			}
		"bruiser":
			return {
				"name": "豪腕兵",
				"hp_base": 58, "hp_per_win": 7,
				"damage_base": 9, "attack_interval": 1.25,
				"move_mul": 0.75, "jump_bias": 0.2,
				"color": Color(0.85, 0.40, 0.22),
				"accent": Color(1.0, 0.55, 0.25),
				"body_scale": 1.12, "line_width": 4.2, "head_radius": 12.0,
				"reach_mul": 1.1,
				"weapon_style": "hammer", "weapon_color": Color(0.5, 0.35, 0.25),
				"attack_kind": "strong",
			}
		"shield":
			return {
				"name": "盾持ち",
				"hp_base": 70, "hp_per_win": 8,
				"damage_base": 5, "attack_interval": 1.35,
				"move_mul": 0.7, "jump_bias": 0.15,
				"color": Color(0.55, 0.58, 0.62),
				"accent": Color(0.75, 0.78, 0.85),
				"body_scale": 1.05, "line_width": 3.8, "head_radius": 10.5,
				"reach_mul": 0.95,
				"weapon_style": "shield", "weapon_color": Color(0.72, 0.74, 0.8),
				"attack_kind": "mid",
			}
		"tyrant":
			return {
				"name": "暴君ボス",
				"hp_base": 160, "hp_per_win": 4,
				"damage_base": 14, "attack_interval": 0.9,
				"move_mul": 0.95, "jump_bias": 0.3,
				"color": Color(0.72, 0.12, 0.18),
				"accent": Color(1.0, 0.35, 0.2),
				"body_scale": 1.35, "line_width": 5.0, "head_radius": 14.0,
				"reach_mul": 1.25,
				"weapon_style": "pipe", "weapon_color": Color(0.85, 0.25, 0.2),
				"attack_kind": "strong",
			}
		"specter":
			return {
				"name": "幻影ボス",
				"hp_base": 130, "hp_per_win": 3,
				"damage_base": 11, "attack_interval": 0.75,
				"move_mul": 1.25, "jump_bias": 0.7,
				"color": Color(0.55, 0.30, 0.75),
				"accent": Color(0.85, 0.55, 1.0),
				"body_scale": 1.15, "line_width": 2.8, "head_radius": 11.0,
				"reach_mul": 1.15,
				"weapon_style": "claw", "weapon_color": Color(0.7, 0.4, 0.95),
				"attack_kind": "weak",
			}
		_:
			# grunt
			return {
				"name": "雑兵",
				"hp_base": 48, "hp_per_win": 6,
				"damage_base": 6, "attack_interval": 1.05,
				"move_mul": 1.0, "jump_bias": 0.35,
				"color": Color(0.55, 0.45, 0.40),
				"accent": Color(0.75, 0.60, 0.45),
				"body_scale": 1.0, "line_width": 3.0, "head_radius": 10.0,
				"reach_mul": 1.0,
				"weapon_style": "staff", "weapon_color": Color(0.55, 0.4, 0.3),
				"attack_kind": "mid",
			}
