class_name StickFigure
extends Node2D
## 棒人間。敵アーキタイプ／装備武器・必殺で見た目と攻撃エフェクトが変わる。

enum AttackKind { NONE, WEAK, MID, STRONG, SPECIAL, HURT }
enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

@export var figure_color: Color = Color(0.9, 0.9, 0.85)
@export var accent_color: Color = Color(1.0, 1.0, 1.0)
@export var facing: float = 1.0
@export var pose_phase: float = 0.0

var attack_kind: AttackKind = AttackKind.NONE
var phase: Phase = Phase.IDLE
var phase_t: float = 0.0
var body_scale: float = 1.0
var line_width: float = 3.0
var head_radius: float = 10.0
var is_boss: bool = false
var weapon_style: String = "fist"
var weapon_color: Color = Color(0.9, 0.9, 0.9)
var weapon_flags: Dictionary = {}
var special_flash_color: Color = Color(0.6, 0.85, 1.0)
var special_kind: String = "projectile"
var attack_flash: float = 0.0
var attack_flash_color: Color = Color(1, 1, 1, 0.8)

var _phase_dur: float = 0.0
var _windup: float = 0.0
var _active: float = 0.0
var _recovery: float = 0.0
var _on_active_cb: Callable = Callable()
var _active_fired: bool = false
var _last_arm_r := Vector2(20, 0)


func apply_body_style(style: Dictionary) -> void:
	if style.has("color"):
		figure_color = style["color"]
	if style.has("accent"):
		accent_color = style["accent"]
	body_scale = float(style.get("body_scale", 1.0))
	line_width = float(style.get("line_width", 3.0))
	head_radius = float(style.get("head_radius", 10.0))
	is_boss = bool(style.get("is_boss", false))


func apply_weapon_visual(vis: Dictionary) -> void:
	weapon_style = str(vis.get("style", "fist"))
	weapon_color = vis.get("color", Color(0.9, 0.9, 0.9))
	weapon_flags = vis.duplicate(true)
	attack_flash_color = vis.get("flash", Color(1, 1, 1, 0.75))


func apply_special_visual(vis: Dictionary) -> void:
	special_flash_color = vis.get("flash", Color(0.6, 0.85, 1.0))
	special_kind = str(vis.get("kind", vis.get("style", "projectile")))


func is_busy() -> bool:
	return phase != Phase.IDLE


func play_attack(kind: AttackKind, windup: float, active: float, recovery: float, on_active: Callable = Callable()) -> void:
	attack_kind = kind
	_windup = maxf(0.02, windup)
	_active = maxf(0.02, active)
	_recovery = maxf(0.02, recovery)
	_on_active_cb = on_active
	_active_fired = false
	attack_flash = 0.0
	_enter_phase(Phase.WINDUP, _windup)


func play_hurt(duration: float = 0.12) -> void:
	attack_kind = AttackKind.HURT
	_on_active_cb = Callable()
	_active_fired = true
	_enter_phase(Phase.RECOVERY, maxf(0.06, duration))


func _enter_phase(p: Phase, dur: float) -> void:
	phase = p
	_phase_dur = dur
	phase_t = 0.0
	if p == Phase.ACTIVE:
		attack_flash = 1.0
		if attack_kind == AttackKind.SPECIAL:
			attack_flash_color = special_flash_color


func _process(delta: float) -> void:
	pose_phase += delta * (14.0 if phase == Phase.ACTIVE else 6.0)
	if attack_flash > 0.0:
		attack_flash = maxf(0.0, attack_flash - delta * 4.5)
	if phase != Phase.IDLE:
		phase_t += delta / maxf(0.001, _phase_dur)
		if phase == Phase.ACTIVE and not _active_fired and phase_t >= 0.15:
			_active_fired = true
			if _on_active_cb.is_valid():
				_on_active_cb.call()
		if phase_t >= 1.0:
			_advance_phase()
	queue_redraw()


func _advance_phase() -> void:
	match phase:
		Phase.WINDUP:
			_enter_phase(Phase.ACTIVE, _active)
		Phase.ACTIVE:
			if not _active_fired:
				_active_fired = true
				if _on_active_cb.is_valid():
					_on_active_cb.call()
			_enter_phase(Phase.RECOVERY, _recovery)
		Phase.RECOVERY:
			phase = Phase.IDLE
			attack_kind = AttackKind.NONE
			phase_t = 0.0
		_:
			phase = Phase.IDLE


func _draw() -> void:
	var c := figure_color
	var s := body_scale
	var f := facing
	var w := line_width
	var bob := sin(pose_phase) * 2.0
	var lean := 0.0
	var arm_l := Vector2(-22.0 * f, -5.0)
	var arm_r := Vector2(20.0 * f, 0.0)
	var leg_l := Vector2(-12.0 * f, 42.0)
	var leg_r := Vector2(12.0 * f, 42.0)
	var stretch := 1.0

	if phase == Phase.IDLE:
		var swing := sin(pose_phase) * 8.0 * f
		arm_l = Vector2((-22.0 + swing) * f, -5.0)
		arm_r = Vector2((20.0 + swing * 0.3) * f, 0.0)
		var step := sin(pose_phase * 0.5) * 6.0
		leg_l = Vector2((-12.0 - step) * f, 42.0)
		leg_r = Vector2((12.0 + step) * f, 42.0)
	else:
		var pose := _attack_pose_vectors(f)
		arm_l = pose["arm_l"]
		arm_r = pose["arm_r"]
		leg_l = pose["leg_l"]
		leg_r = pose["leg_r"]
		lean = pose["lean"]
		stretch = pose["stretch"]
		bob *= 0.4

	_last_arm_r = arm_r
	var origin := Vector2(lean, bob)
	# ボス輪郭
	if is_boss:
		draw_circle((origin + Vector2(0, -40 * stretch)) * s, (head_radius + 3.0) * s, accent_color.darkened(0.35))
	# 頭
	draw_circle((origin + Vector2(0, -40 * stretch)) * s, head_radius * s, c)
	# 胴
	draw_line((origin + Vector2(0, -30 * stretch)) * s, (origin + Vector2(0, 10)) * s, c, w)
	# 腕
	draw_line((origin + Vector2(0, -18)) * s, (origin + arm_l) * s, c, w)
	draw_line((origin + Vector2(0, -18)) * s, (origin + arm_r) * s, c, w)
	# 脚
	draw_line((origin + Vector2(0, 10)) * s, (origin + leg_l) * s, c, w)
	draw_line((origin + Vector2(0, 10)) * s, (origin + leg_r) * s, c, w)
	# 武器
	_draw_weapon(origin, arm_r, s, f)
	# 攻撃フラッシュ
	if attack_flash > 0.05:
		_draw_attack_fx(origin, arm_r, s, f)


func _draw_weapon(origin: Vector2, arm_r: Vector2, s: float, f: float) -> void:
	var hand := (origin + arm_r) * s
	var dir := Vector2(f, 0).normalized()
	var col := weapon_color
	match weapon_style:
		"fist":
			var r := 5.0 * s * (1.35 if bool(weapon_flags.get("thick_fist", false)) else 1.0)
			draw_circle(hand, r, col)
			if bool(weapon_flags.get("fire", false)):
				draw_circle(hand + Vector2(0, -4) * s, r * 0.7, Color(1.0, 0.6, 0.2, 0.7))
		"staff", "pipe":
			var tip := hand + dir * (28.0 if weapon_style == "pipe" else 32.0) * s + Vector2(0, -4) * s
			draw_line(hand, tip, col, line_width + (1.5 if weapon_style == "pipe" else 0.5))
		"blade":
			var len := 36.0 if bool(weapon_flags.get("long", false)) else 26.0
			var tip := hand + dir * len * s + Vector2(0, -6) * s
			draw_line(hand, tip, col, 2.2)
			if bool(weapon_flags.get("spark", false)):
				draw_circle(tip, 3.0 * s, accent_color)
		"spear":
			var tip := hand + dir * 48.0 * s + Vector2(0, -2) * s
			draw_line(hand, tip, col, 2.0)
			draw_line(tip, tip + dir * 8.0 * s + Vector2(0, -5) * s, col, 2.0)
			draw_line(tip, tip + dir * 8.0 * s + Vector2(0, 5) * s, col, 2.0)
		"hammer":
			var tip := hand + dir * 22.0 * s
			draw_line(hand, tip, col, 2.5)
			var hs := 8.0 * s
			draw_rect(Rect2(tip - Vector2(hs * 0.3, hs), Vector2(hs * 1.4, hs * 1.1)), col)
		"chain":
			var tip := hand + dir * 40.0 * s
			for i in 5:
				var a := hand.lerp(tip, float(i) / 5.0)
				var b := hand.lerp(tip, float(i + 1) / 5.0)
				draw_line(a, b, col, 1.8)
				draw_circle(b, 2.0 * s, col)
		"shield":
			var center := hand + dir * 8.0 * s
			draw_circle(center, 11.0 * s, col)
			draw_arc(center, 11.0 * s, 0, TAU, 16, accent_color, 2.0)
		"claw":
			for i in 3:
				var ang := -0.35 + i * 0.35
				var tip := hand + Vector2(cos(ang) * f, sin(ang)) * 22.0 * s
				draw_line(hand, tip, col, 2.0)
		"nunchaku":
			var mid := hand + dir * 14.0 * s + Vector2(0, 8) * s
			var tip := hand + dir * 28.0 * s + Vector2(0, -4) * s
			draw_line(hand, mid, col, 2.0)
			draw_line(mid, tip, col, 2.0)
			draw_circle(tip, 3.5 * s, col)
		_:
			pass


func _draw_attack_fx(origin: Vector2, arm_r: Vector2, s: float, f: float) -> void:
	var a := clampf(attack_flash, 0.0, 1.0)
	var col := Color(attack_flash_color.r, attack_flash_color.g, attack_flash_color.b, 0.55 * a)
	var hand := (origin + arm_r) * s
	match attack_kind:
		AttackKind.WEAK:
			draw_circle(hand + Vector2(10 * f, 0) * s, 6.0 * s * a, col)
		AttackKind.MID:
			draw_arc(hand, 18.0 * s, -0.8 if f > 0 else PI - 0.8, 0.8 if f > 0 else PI + 0.8, 12, col, 3.0)
		AttackKind.STRONG:
			draw_line(hand + Vector2(-6 * f, -16) * s, hand + Vector2(14 * f, 18) * s, col, 4.0)
		AttackKind.SPECIAL:
			_draw_special_fx(hand, s, f, col, a)
		_:
			pass


func _draw_special_fx(hand: Vector2, s: float, f: float, col: Color, a: float) -> void:
	match special_kind:
		"melee":
			draw_arc(hand, 22.0 * s, -1.0 if f > 0 else PI - 1.0, 1.0 if f > 0 else PI + 1.0, 14, col, 4.0)
		"melee_multi":
			for i in 3:
				var tip := hand + Vector2(f * (28.0 + i * 14.0), -6.0 + i * 4.0) * s
				draw_circle(tip, 5.0 * s * a, col)
		"ground":
			var base := hand + Vector2(0, 18) * s
			draw_line(base, base + Vector2(f * 70.0, 0) * s, col, 6.0)
			draw_circle(base + Vector2(f * 70.0, 0) * s, 7.0 * s * a, col)
		"beam":
			draw_line(hand, hand + Vector2(f * 110.0, 0) * s, col, 7.0)
			draw_circle(hand + Vector2(f * 110.0, 0) * s, 6.0 * s * a, col)
		"explode":
			var tip := hand + Vector2(f * 48.0, 0) * s
			draw_circle(tip, 16.0 * s * a, col)
			draw_arc(tip, 22.0 * s * a, 0, TAU, 16, col, 2.5)
		"delayed_double":
			draw_circle(hand + Vector2(f * 36.0, -4) * s, 7.0 * s * a, col)
			draw_circle(hand + Vector2(f * 58.0, 6) * s, 5.0 * s * a, Color(col.r, col.g, col.b, col.a * 0.6))
		"multi_hit":
			for i in 4:
				var tip := hand + Vector2(f * (24.0 + i * 18.0), sin(i) * 8.0) * s
				draw_line(hand + Vector2(f * i * 10.0, 0) * s, tip, col, 2.5)
		"projectile_up":
			var tip := hand + Vector2(f * 36.0, -42.0) * s
			draw_line(hand, tip, col, 4.0)
			draw_circle(tip, 7.0 * s * a, col)
		_:
			# projectile default
			var tip := hand + Vector2(f * 50.0, 0) * s
			draw_line(hand, tip, col, 5.0)
			draw_circle(tip, 8.0 * s * a, col)


func _attack_pose_vectors(f: float) -> Dictionary:
	var t := clampf(phase_t, 0.0, 1.0)
	var arm_l := Vector2(-18.0 * f, -4.0)
	var arm_r := Vector2(16.0 * f, 0.0)
	var leg_l := Vector2(-12.0 * f, 42.0)
	var leg_r := Vector2(12.0 * f, 42.0)
	var lean := 0.0
	var stretch := 1.0
	# 槍・長物は腕をもう少し伸ばす
	var reach_pose := 1.0
	if weapon_style in ["spear", "staff", "blade"] and bool(weapon_flags.get("long", false)):
		reach_pose = 1.15
	elif weapon_style == "spear":
		reach_pose = 1.2

	match attack_kind:
		AttackKind.WEAK:
			if phase == Phase.WINDUP:
				arm_r = Vector2(8.0 * f, -12.0)
				lean = -2.0 * f
			elif phase == Phase.ACTIVE:
				arm_r = Vector2((34.0 + 8.0 * t) * f * reach_pose, -2.0)
				lean = 4.0 * f
			else:
				arm_r = Vector2(14.0 * f, 4.0)
		AttackKind.MID:
			if phase == Phase.WINDUP:
				arm_r = Vector2(-6.0 * f, -18.0)
				arm_l = Vector2(-10.0 * f, 6.0)
				lean = -4.0 * f
			elif phase == Phase.ACTIVE:
				arm_r = Vector2((28.0 + 10.0 * t) * f * reach_pose, -8.0 + 16.0 * t)
				arm_l = Vector2(-24.0 * f, 4.0)
				lean = 8.0 * f
			else:
				arm_r = Vector2(18.0 * f, 10.0)
				lean = 2.0 * f
		AttackKind.STRONG:
			if phase == Phase.WINDUP:
				arm_l = Vector2(-10.0 * f, -36.0)
				arm_r = Vector2(10.0 * f, -38.0)
				lean = -2.0 * f
				stretch = 1.05
			elif phase == Phase.ACTIVE:
				arm_l = Vector2(8.0 * f, 18.0)
				arm_r = Vector2((30.0 + 6.0 * t) * f * reach_pose, 22.0)
				lean = 10.0 * f
				stretch = 0.95
			else:
				arm_l = Vector2(-14.0 * f, 8.0)
				arm_r = Vector2(16.0 * f, 12.0)
				lean = 3.0 * f
		AttackKind.SPECIAL:
			if phase == Phase.WINDUP:
				arm_l = Vector2(-8.0 * f, -20.0)
				arm_r = Vector2(8.0 * f, -22.0)
				stretch = 1.08
			elif phase == Phase.ACTIVE:
				arm_l = Vector2((26.0 + 6.0 * t) * f, -6.0)
				arm_r = Vector2((36.0 + 8.0 * t) * f, 0.0)
				lean = 6.0 * f
				stretch = 1.12
			else:
				arm_l = Vector2(10.0 * f, 4.0)
				arm_r = Vector2(18.0 * f, 6.0)
				stretch = 1.02
		AttackKind.HURT:
			arm_l = Vector2(-28.0 * f, -10.0)
			arm_r = Vector2(6.0 * f, 12.0)
			lean = -10.0 * f
			leg_l = Vector2(-18.0 * f, 40.0)
			leg_r = Vector2(8.0 * f, 44.0)
		_:
			pass

	return {
		"arm_l": arm_l,
		"arm_r": arm_r,
		"leg_l": leg_l,
		"leg_r": leg_r,
		"lean": lean,
		"stretch": stretch,
	}
