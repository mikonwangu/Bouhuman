extends Control

const WeaponCatalogScript = preload("res://data/weapon_catalog.gd")
const SpecialCatalogScript = preload("res://data/special_catalog.gd")

@onready var title_label: Label = %TitleLabel
@onready var choices: VBoxContainer = %Choices
@onready var weapon_list: ItemList = %WeaponList
@onready var special_list: ItemList = %SpecialList
@onready var continue_btn: Button = %ContinueButton
@onready var equip_panel: VBoxContainer = %EquipPanel

var _picked: bool = false


func _ready() -> void:
	GameState.phase = GameState.Phase.REWARD
	var boss := GameState.last_battle_was_boss
	title_label.text = "ボス報酬を選んでください" if boss else "報酬を選んでください（3つから1つ）"
	equip_panel.visible = false
	continue_btn.visible = false
	_build_choices()
	_refresh_equip_lists()


func _build_choices() -> void:
	for c in choices.get_children():
		c.queue_free()
	for reward in GameState.pending_rewards:
		var btn := Button.new()
		btn.text = "%s\n%s" % [reward.get("title", "?"), reward.get("desc", "")]
		btn.custom_minimum_size = Vector2(0, 64)
		var captured: Dictionary = reward
		btn.pressed.connect(func(): _on_pick(captured))
		choices.add_child(btn)


func _on_pick(reward: Dictionary) -> void:
	if _picked:
		return
	_picked = true
	GameState.apply_reward(reward)
	for c in choices.get_children():
		c.disabled = true
	# 武器／必殺入手時は装備切替 UI を出す（要件: 報酬選択時に装備・入れ替え可）
	var rid := str(reward.get("id", ""))
	if rid in ["R5", "B2", "B1"]:
		equip_panel.visible = true
		_refresh_equip_lists()
		# 新規入手を自動装備候補としてハイライト
		if rid in ["R5", "B2"] and reward.has("weapon_id"):
			GameState.equip_weapon(str(reward["weapon_id"]))
			_refresh_equip_lists()
		if rid == "B1" and reward.has("special_id"):
			GameState.equip_special(str(reward["special_id"]))
			_refresh_equip_lists()
	else:
		# ステータス系でも装備変更は可能なのでパネルを出す
		equip_panel.visible = true
	continue_btn.visible = true
	title_label.text = "受け取りました。装備を確認して続行してください。"


func _refresh_equip_lists() -> void:
	weapon_list.clear()
	var wi := 0
	var wsel := 0
	for wid in GameState.owned_weapons:
		var w: Dictionary = WeaponCatalogScript.get_weapon(wid)
		weapon_list.add_item("%s [%s]" % [w["name"], WeaponCatalogScript.rarity_label(w["rarity"])])
		if wid == GameState.equipped_weapon_id:
			wsel = wi
		wi += 1
	if weapon_list.item_count > 0:
		weapon_list.select(wsel)

	special_list.clear()
	var si := 0
	var ssel := 0
	for sid in GameState.owned_specials:
		var s: Dictionary = SpecialCatalogScript.get_special(sid)
		special_list.add_item("%s [%s]" % [s["name"], SpecialCatalogScript.rarity_label(s["rarity"])])
		if sid == GameState.equipped_special_id:
			ssel = si
		si += 1
	if special_list.item_count > 0:
		special_list.select(ssel)


func _on_weapon_selected(index: int) -> void:
	if index < 0 or index >= GameState.owned_weapons.size():
		return
	GameState.equip_weapon(GameState.owned_weapons[index])


func _on_special_selected(index: int) -> void:
	if index < 0 or index >= GameState.owned_specials.size():
		return
	GameState.equip_special(GameState.owned_specials[index])


func _on_continue_pressed() -> void:
	GameState.after_reward_continue()
