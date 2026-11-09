class_name CombatVisuals
extends RefCounted
## 装備武器／必殺から戦闘見た目スタイルを解決。


static func weapon_style(weapon_id: String) -> Dictionary:
	# style: fist/staff/blade/spear/hammer/chain/shield/claw/pipe/nunchaku
	# color: 武器色, flash: ヒット時エフェクト色, reach_bonus: 見た目リーチ加算
	match weapon_id:
		"W-N1":
			return {"style": "fist", "color": Color(0.95, 0.85, 0.75), "flash": Color(1, 1, 1, 0.7), "reach_bonus": 0.0}
		"W-N2":
			return {"style": "staff", "color": Color(0.55, 0.35, 0.18), "flash": Color(0.8, 0.6, 0.3), "reach_bonus": 12.0}
		"W-N3":
			return {"style": "fist", "color": Color(0.9, 0.55, 0.35), "flash": Color(1.0, 0.7, 0.4), "reach_bonus": 0.0, "thick_fist": true}
		"W-N4":
			return {"style": "blade", "color": Color(0.75, 0.78, 0.85), "flash": Color(0.9, 0.95, 1.0), "reach_bonus": 6.0}
		"W-R1":
			return {"style": "pipe", "color": Color(0.55, 0.58, 0.62), "flash": Color(0.7, 0.75, 0.8), "reach_bonus": 14.0}
		"W-R2":
			return {"style": "chain", "color": Color(0.65, 0.65, 0.7), "flash": Color(0.85, 0.85, 0.9), "reach_bonus": 18.0}
		"W-R3":
			return {"style": "shield", "color": Color(0.7, 0.72, 0.78), "flash": Color(0.9, 0.9, 1.0), "reach_bonus": 4.0}
		"W-R4":
			return {"style": "hammer", "color": Color(0.45, 0.4, 0.35), "flash": Color(1.0, 0.8, 0.4), "reach_bonus": 8.0}
		"W-HR1":
			return {"style": "blade", "color": Color(0.85, 0.88, 0.95), "flash": Color(0.7, 0.85, 1.0), "reach_bonus": 22.0, "long": true}
		"W-HR2":
			return {"style": "nunchaku", "color": Color(0.35, 0.25, 0.2), "flash": Color(1.0, 0.85, 0.5), "reach_bonus": 10.0}
		"W-HR3":
			return {"style": "spear", "color": Color(0.7, 0.65, 0.5), "flash": Color(0.95, 0.9, 0.7), "reach_bonus": 28.0}
		"W-SR1":
			return {"style": "blade", "color": Color(0.55, 0.85, 1.0), "flash": Color(0.4, 0.9, 1.0), "reach_bonus": 18.0, "spark": true}
		"W-SR2":
			return {"style": "fist", "color": Color(1.0, 0.45, 0.2), "flash": Color(1.0, 0.5, 0.15), "reach_bonus": 4.0, "thick_fist": true, "fire": true}
		"W-SR3":
			return {"style": "claw", "color": Color(0.45, 0.25, 0.55), "flash": Color(0.7, 0.4, 0.9), "reach_bonus": 10.0}
		_:
			return {"style": "fist", "color": Color(0.9, 0.9, 0.9), "flash": Color(1, 1, 1, 0.6), "reach_bonus": 0.0}


static func special_style(special: Dictionary) -> Dictionary:
	var kind := str(special.get("kind", "projectile"))
	var rarity = special.get("rarity", 0)
	var flash := Color(0.85, 0.9, 1.0)
	match kind:
		"projectile", "projectile_up":
			flash = Color(0.45, 0.85, 1.0)
		"melee", "melee_multi":
			flash = Color(1.0, 0.9, 0.45)
		"ground":
			flash = Color(0.85, 0.65, 0.35)
		"beam":
			flash = Color(0.7, 0.95, 1.0)
		"explode":
			flash = Color(1.0, 0.55, 0.25)
		"delayed_double":
			flash = Color(0.75, 0.7, 1.0)
		"multi_hit":
			flash = Color(0.55, 0.8, 1.0)
		_:
			pass
	if int(rarity) >= 3:
		flash = flash.lightened(0.15)
	return {"kind": kind, "flash": flash, "style": kind}
