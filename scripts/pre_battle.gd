extends Control

const WeaponCatalogScript = preload("res://data/weapon_catalog.gd")
const SpecialCatalogScript = preload("res://data/special_catalog.gd")

@onready var info_label: Label = %InfoLabel
@onready var weapon_list: ItemList = %WeaponList
@onready var special_list: ItemList = %SpecialList
@onready var enemy_label: Label = %EnemyLabel


func _ready() -> void:
	GameState.phase = GameState.Phase.PRE_BATTLE
	_refresh()
	var fight := get_node_or_null("Margin/VBox/FightButton") as Button
	if fight:
		fight.grab_focus()


func _refresh() -> void:
	var ch: Dictionary = GameState.get_character()
	var w: Dictionary = GameState.get_equipped_weapon()
	var sp: Dictionary = GameState.get_equipped_special()
	var enemy: Dictionary = GameState.enemy_stats_for_current_fight()
	info_label.text = (
		"%s | 勝利 %d / %d | HP %d/%d | 必殺残 %d | 必殺威力+%d%s"
		% [
			ch["name"],
			GameState.wins,
			GameState.CLEAR_WINS,
			GameState.hp,
			GameState.max_hp,
			GameState.special_uses,
			GameState.special_power_bonus,
			" | 即死回避あり" if GameState.has_death_avoid else "",
		]
	)
	enemy_label.text = "次の敵: %s（HP %d）%s" % [
		enemy["name"], enemy["max_hp"], " 【ボス】" if enemy["is_boss"] else ""
	]

	weapon_list.clear()
	var w_idx := 0
	var sel_w := 0
	for wid in GameState.owned_weapons:
		var wd: Dictionary = WeaponCatalogScript.get_weapon(wid)
		weapon_list.add_item("%s [%s]" % [wd["name"], WeaponCatalogScript.rarity_label(wd["rarity"])])
		if wid == GameState.equipped_weapon_id:
			sel_w = w_idx
		w_idx += 1
	if weapon_list.item_count > 0:
		weapon_list.select(sel_w)

	special_list.clear()
	var s_idx := 0
	var sel_s := 0
	for sid in GameState.owned_specials:
		var sd: Dictionary = SpecialCatalogScript.get_special(sid)
		special_list.add_item("%s [%s]" % [sd["name"], SpecialCatalogScript.rarity_label(sd["rarity"])])
		if sid == GameState.equipped_special_id:
			sel_s = s_idx
		s_idx += 1
	if special_list.item_count > 0:
		special_list.select(sel_s)

	%EquipHint.text = "装備中: %s / 必殺: %s" % [w["name"], sp["name"]]


func _on_weapon_selected(index: int) -> void:
	if index < 0 or index >= GameState.owned_weapons.size():
		return
	GameState.equip_weapon(GameState.owned_weapons[index])
	_refresh()


func _on_special_selected(index: int) -> void:
	if index < 0 or index >= GameState.owned_specials.size():
		return
	GameState.equip_special(GameState.owned_specials[index])
	_refresh()


func _on_fight_pressed() -> void:
	GameState.go_battle()
