class_name StickFigure
extends Node2D
## 棒人間プレースホルダ。技種別の短い発生／ヒット／硬直ポーズ。

enum AttackKind { NONE, WEAK, MID, STRONG, SPECIAL, HURT }
enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

@export var figure_color: Color = Color(0.9, 0.9, 0.85)
@export var facing: float = 1.0
@export var pose_phase: float = 0.0

var attack_kind: AttackKind = AttackKind.NONE
var phase: Phase = Phase.IDLE
var phase_t: float = 0.0  # 0..1 within current phase
var _phase_dur: float = 0.0
var _windup: float = 0.0
var _active: float = 0.0
var _recovery: float = 0.0
var _base_scale := 1.0
var _on_active_cb: Callable = Callable()
var _active_fired: bool = false


func is_busy() -> bool:
	return phase != Phase.IDLE


func play_attack(kind: AttackKind, windup: float, active: float, recovery: float, on_active: Callable = Callable()) -> void:
	attack_kind = kind
	_windup = maxf(0.02, windup)
	_active = maxf(0.02, active)
	_recovery = maxf(0.02, recovery)
	_on_active_cb = on_active
	_active_fired = false
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


func _process(delta: float) -> void:
	pose_phase += delta * (14.0 if phase == Phase.ACTIVE else 6.0)
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
	var s := _base_scale
	var f := facing
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

	var origin := Vector2(lean, bob)
	# 頭
	draw_circle((origin + Vector2(0, -40 * stretch)) * s, 10 * s, c)
	# 胴
	draw_line((origin + Vector2(0, -30 * stretch)) * s, (origin + Vector2(0, 10)) * s, c, 3.0)
	# 腕
	draw_line((origin + Vector2(0, -18)) * s, (origin + arm_l) * s, c, 3.0)
	draw_line((origin + Vector2(0, -18)) * s, (origin + arm_r) * s, c, 3.0)
	# 脚
	draw_line((origin + Vector2(0, 10)) * s, (origin + leg_l) * s, c, 3.0)
	draw_line((origin + Vector2(0, 10)) * s, (origin + leg_r) * s, c, 3.0)


func _attack_pose_vectors(f: float) -> Dictionary:
	var t := clampf(phase_t, 0.0, 1.0)
	var arm_l := Vector2(-18.0 * f, -4.0)
	var arm_r := Vector2(16.0 * f, 0.0)
	var leg_l := Vector2(-12.0 * f, 42.0)
	var leg_r := Vector2(12.0 * f, 42.0)
	var lean := 0.0
	var stretch := 1.0

	match attack_kind:
		AttackKind.WEAK:
			# ジャブ: 前腕を短く突き出し
			if phase == Phase.WINDUP:
				arm_r = Vector2(8.0 * f, -12.0)
				lean = -2.0 * f
			elif phase == Phase.ACTIVE:
				arm_r = Vector2((34.0 + 8.0 * t) * f, -2.0)
				lean = 4.0 * f
			else:
				arm_r = Vector2(14.0 * f, 4.0)
		AttackKind.MID:
			# フック: 横に大きく振る
			if phase == Phase.WINDUP:
				arm_r = Vector2(-6.0 * f, -18.0)
				arm_l = Vector2(-10.0 * f, 6.0)
				lean = -4.0 * f
			elif phase == Phase.ACTIVE:
				arm_r = Vector2((28.0 + 10.0 * t) * f, -8.0 + 16.0 * t)
				arm_l = Vector2(-24.0 * f, 4.0)
				lean = 8.0 * f
			else:
				arm_r = Vector2(18.0 * f, 10.0)
				lean = 2.0 * f
		AttackKind.STRONG:
			# 振り下ろし: 両腕を上げて叩く
			if phase == Phase.WINDUP:
				arm_l = Vector2(-10.0 * f, -36.0)
				arm_r = Vector2(10.0 * f, -38.0)
				lean = -2.0 * f
				stretch = 1.05
			elif phase == Phase.ACTIVE:
				arm_l = Vector2(8.0 * f, 18.0)
				arm_r = Vector2((30.0 + 6.0 * t) * f, 22.0)
				lean = 10.0 * f
				stretch = 0.95
			else:
				arm_l = Vector2(-14.0 * f, 8.0)
				arm_r = Vector2(16.0 * f, 12.0)
				lean = 3.0 * f
		AttackKind.SPECIAL:
			# 必殺: 両腕を前方へ伸ばす
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
