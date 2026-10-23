class_name CharacterTypes
extends RefCounted
## 棒人間3タイプ。攻撃力とスピードのトレードオフ（要件未確定倍率のプレースホルダ）。

enum Type { POWER, SPEED, BALANCE }

const DATA := {
	Type.POWER: {
		"id": "power",
		"name": "パワー型",
		"attack_mul": 1.25,
		"speed_mul": 0.75,
		"color": Color(0.85, 0.35, 0.28),
		"desc": "攻撃力が高い／移動が遅い",
	},
	Type.SPEED: {
		"id": "speed",
		"name": "スピード型",
		"attack_mul": 0.75,
		"speed_mul": 1.25,
		"color": Color(0.30, 0.65, 0.85),
		"desc": "攻撃力が低い／移動が速い",
	},
	Type.BALANCE: {
		"id": "balance",
		"name": "バランス型",
		"attack_mul": 1.0,
		"speed_mul": 1.0,
		"color": Color(0.45, 0.78, 0.42),
		"desc": "攻撃力・移動ともに並",
	},
}


static func get_type(t: int) -> Dictionary:
	return DATA.get(t, DATA[Type.BALANCE]).duplicate(true)


static func all_types() -> Array:
	return [Type.POWER, Type.SPEED, Type.BALANCE]
